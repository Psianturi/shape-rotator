"""
Integration tests: full end-to-end flow including contract digest verification.

Run:
    cd backend
    python -m pytest tests/test_integration.py -v
"""

from decimal import Decimal

import pytest
from eth_account import Account
from eth_account.messages import encode_defunct
from eth_utils import keccak, to_checksum_address
from eth_abi.packed import encode_packed
from fastapi.testclient import TestClient

from app.main import app, _local_guardian_account as guardian_account

client = TestClient(app)

TRUSTED = "0xTrusted001"
RISKY = "0xNewRisk999"
# Valid 20-byte EVM addresses for contract digest tests
EVM_TRUSTED = "0x" + "b" * 40
EVM_RISKY = "0x" + "c" * 40
FAKE_CONTRACT = "0x" + "a" * 40


def _register(allowlist=None, max_amount=None):
    body = {"master_commitment": f"commitment_{id(allowlist)}_{id(max_amount)}", "allowlist": allowlist or [TRUSTED]}
    if max_amount:
        body["max_amount"] = max_amount
    r = client.post("/register", json=body)
    assert r.status_code == 200
    return r.json()["user_id"]


class TestAllowFlow:
    def test_full_allow_with_contract_digest(self):
        uid = _register(allowlist=[EVM_TRUSTED])
        r = client.post("/sign-intent", json={
            "user_id": uid,
            "destination": EVM_TRUSTED,
            "amount": 0.05,
            "user_partial_signature": "user_sig",
            "contract_address": FAKE_CONTRACT,
            "chain_id": 11155111,
            "nonce": 0,
        })
        body = r.json()
        assert body["status"] == "allow"
        assert body["guardian_partial_signature"] is not None
        assert body["evm_transfer_digest"] is not None
        assert body["guardian_signer_address"] == guardian_account.address

    def test_guardian_signature_is_valid_for_digest(self):
        """Verify the guardian signature actually recovers to guardian_account.address."""
        uid = _register(allowlist=[EVM_TRUSTED])
        r = client.post("/sign-intent", json={
            "user_id": uid,
            "destination": EVM_TRUSTED,
            "amount": 0.1,
            "user_partial_signature": "user_sig",
            "contract_address": FAKE_CONTRACT,
            "chain_id": 11155111,
            "nonce": 0,
        })
        body = r.json()
        assert body["status"] == "allow"

        digest_bytes = bytes.fromhex(body["evm_transfer_digest"])
        sig_bytes = bytes.fromhex(body["guardian_partial_signature"].lstrip("0x"))

        recovered = Account.recover_message(encode_defunct(digest_bytes), signature=sig_bytes)
        assert recovered.lower() == guardian_account.address.lower()

    def test_digest_matches_contract_logic(self):
        """Verify digest matches what PerisAIWallet.getTransferDigest would produce."""
        uid = _register(allowlist=[EVM_TRUSTED])
        amount_eth = 0.05
        amount_wei = int(Decimal(str(amount_eth)) * Decimal(10**18))
        nonce = 0
        chain_id = 11155111
        contract = to_checksum_address(FAKE_CONTRACT)
        dest = to_checksum_address(EVM_TRUSTED)

        # Replicate contract digest logic
        packed = encode_packed(
            ["address", "uint256", "address", "uint256", "uint256"],
            [contract, chain_id, dest, amount_wei, nonce],
        )
        message_hash = keccak(packed)
        expected_digest = keccak(b"\x19Ethereum Signed Message:\n32" + message_hash)

        r = client.post("/sign-intent", json={
            "user_id": uid,
            "destination": EVM_TRUSTED,
            "amount": amount_eth,
            "user_partial_signature": "user_sig",
            "contract_address": FAKE_CONTRACT,
            "chain_id": chain_id,
            "nonce": nonce,
        })
        body = r.json()
        assert body["evm_transfer_digest"] == expected_digest.hex()


class TestDenyFlow:
    def test_deny_high_amount(self):
        uid = _register()
        r = client.post("/sign-intent", json={
            "user_id": uid, "destination": TRUSTED,
            "amount": 900, "user_partial_signature": "sig",
        })
        body = r.json()
        assert body["status"] == "deny"
        assert body["guardian_partial_signature"] is None
        assert body["risk_score"] >= 60

    def test_deny_unknown_destination(self):
        uid = _register()
        r = client.post("/sign-intent", json={
            "user_id": uid, "destination": RISKY,
            "amount": 10, "user_partial_signature": "sig",
        })
        body = r.json()
        assert body["status"] == "deny"
        assert body["evm_transfer_digest"] is None

    def test_deny_does_not_reach_execute_transfer(self):
        """Denied intents must never produce a usable guardian signature."""
        uid = _register()
        r = client.post("/sign-intent", json={
            "user_id": uid, "destination": RISKY,
            "amount": 999, "user_partial_signature": "sig",
        })
        body = r.json()
        assert body["status"] == "deny"
        assert body["guardian_partial_signature"] is None


class TestPolicyEngine:
    def test_per_user_policy_isolation(self):
        uid1 = _register(allowlist=["0xAddrA"], max_amount=100)
        uid2 = _register(allowlist=["0xAddrB"], max_amount=1000)

        r1 = client.post("/sign-intent", json={
            "user_id": uid1, "destination": "0xAddrA",
            "amount": 50, "user_partial_signature": "sig",
        })
        assert r1.json()["status"] == "allow"

        r2 = client.post("/sign-intent", json={
            "user_id": uid2, "destination": "0xAddrA",  # not in uid2 allowlist
            "amount": 50, "user_partial_signature": "sig",
        })
        assert r2.json()["status"] == "deny"

    def test_policy_update_takes_effect(self):
        uid = _register(allowlist=["0xOld"])
        client.post(f"/policy/{uid}", json={"allowlist": ["0xNew"], "max_amount": 2000})

        r = client.post("/sign-intent", json={
            "user_id": uid, "destination": "0xNew",
            "amount": 1500, "user_partial_signature": "sig",
        })
        assert r.json()["status"] == "allow"

    def test_audit_log_records_both_outcomes(self):
        uid = _register()
        client.post("/sign-intent", json={
            "user_id": uid, "destination": TRUSTED,
            "amount": 50, "user_partial_signature": "sig_allow",
        })
        client.post("/sign-intent", json={
            "user_id": uid, "destination": RISKY,
            "amount": 999, "user_partial_signature": "sig_deny",
        })
        r = client.get("/audit-log")
        entries = r.json()
        statuses = {e["status"] for e in entries if e["user_id"] == uid}
        assert "allow" in statuses
        assert "deny" in statuses

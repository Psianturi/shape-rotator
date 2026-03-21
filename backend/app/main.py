from __future__ import annotations

import hashlib
import os
import secrets
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal
from typing import Dict, List, Optional
from uuid import uuid4

import logging

import httpx
from eth_abi.packed import encode_packed
from eth_account import Account
from eth_account.messages import encode_defunct
from eth_utils import keccak, to_checksum_address
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

app = FastAPI(title="PerisAI Guardian Service", version="0.2.0")

DEFAULT_CHAIN_ID = 11155111  # Sepolia

# ENCLAVE_URL: Cloud Run URL of the enclave signer service.

ENCLAVE_URL = os.environ.get("ENCLAVE_URL", "").rstrip("/")

# In-process fallback key — used only when ENCLAVE_URL is not configured.
_local_guardian_account = Account.create(secrets.token_hex(32))


def _fetch_id_token(audience: str) -> str:
    """
    Fetch a Google-signed OIDC ID token for service-to-service auth on Cloud Run.
    Uses the metadata server available inside any GCP runtime (Cloud Run, GCE, etc.).
    Raises RuntimeError if not running on GCP.
    """
    url = (
        f"http://metadata.google.internal/computeMetadata/v1/instance/service-accounts"
        f"/default/identity?audience={audience}"
    )
    resp = httpx.get(url, headers={"Metadata-Flavor": "Google"}, timeout=5)
    resp.raise_for_status()
    return resp.text.strip()


def _enclave_headers(audience: str) -> dict:
    """Return Authorization header with ID token, or empty dict if not on GCP."""
    try:
        token = _fetch_id_token(audience)
        return {"Authorization": f"Bearer {token}"}
    except httpx.HTTPError as exc:
        logger.warning("Could not fetch ID token (not on GCP?): %s", exc)
        return {}


def _enclave_candidates(path: str) -> list[str]:
    base = ENCLAVE_URL.rstrip("/")
    if not base:
        return []
    path = path.lstrip("/")
    if path.startswith("enclave/"):
        return [f"{base}/{path}", f"{base}/{path.removeprefix('enclave/')}"]
    return [f"{base}/{path}", f"{base}/enclave/{path}"]


def _get_enclave_json(path: str) -> dict:
    headers = _enclave_headers(ENCLAVE_URL)
    last_error: Exception | None = None
    for url in _enclave_candidates(path):
        try:
            response = httpx.get(url, headers=headers, timeout=5)
            response.raise_for_status()
            return response.json()
        except (httpx.HTTPError, ValueError) as exc:
            last_error = exc
    assert last_error is not None
    raise last_error


def _get_guardian_address() -> str:
    if ENCLAVE_URL:
        try:
            return _get_enclave_json("enclave/public-key")["signer_address"]
        except (httpx.HTTPError, KeyError, ValueError) as exc:
            logger.warning("Enclave unreachable, falling back to local key: %s", exc)
    return _local_guardian_account.address


guardian_address: str = _get_guardian_address()


# ── Data Models ────────────────────────────────────────────────────────────

@dataclass
class PolicyConfig:
    max_amount: Decimal = Decimal("500")
    allowlist: set[str] = field(default_factory=set)
    # Weights must sum to 100
    weight_amount: int = 60
    weight_allowlist: int = 40


@dataclass
class UserRecord:
    user_id: str
    master_commitment: str
    policy: PolicyConfig = field(default_factory=PolicyConfig)
    registered_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class AuditEntry:
    intent_id: str
    user_id: str
    destination: str
    amount: str
    status: str
    risk_score: int
    reason: str
    rule_evaluations: list
    timestamp: datetime


users: Dict[str, UserRecord] = {}
audit_log: List[AuditEntry] = []


# ── Request / Response Schemas ─────────────────────────────────────────────

class RegisterRequest(BaseModel):
    master_commitment: str = Field(min_length=8)
    allowlist: List[str] = Field(default_factory=list)
    max_amount: Optional[float] = None


class RegisterResponse(BaseModel):
    user_id: str
    registered_at: datetime
    zk_fast_path_hint: str


class PolicyUpdateRequest(BaseModel):
    max_amount: Optional[float] = None
    allowlist: Optional[List[str]] = None


class PolicyUpdateResponse(BaseModel):
    user_id: str
    max_amount: float
    allowlist: List[str]


class SignIntentRequest(BaseModel):
    user_id: str
    destination: str = Field(min_length=3)
    amount: float = Field(gt=0)
    user_partial_signature: str = Field(min_length=3)
    contract_address: Optional[str] = None
    chain_id: int = DEFAULT_CHAIN_ID
    nonce: int = 0


class RuleEvaluation(BaseModel):
    rule: str
    status: str
    severity: str  # info | warning | critical
    detail: str


class SignIntentResponse(BaseModel):
    intent_id: str
    status: str
    reason: str
    risk_score: int
    rule_evaluations: list[RuleEvaluation]
    guardian_partial_signature: Optional[str] = None
    guardian_signer_address: Optional[str] = None
    evm_transfer_digest: Optional[str] = None
    zk_fast_verification_ms: int


class AuditLogEntry(BaseModel):
    intent_id: str
    user_id: str
    destination: str
    amount: str
    status: str
    risk_score: int
    reason: str
    timestamp: str


class GuardianProfileResponse(BaseModel):
    guardian_signer_address: str
    chain_id: int
    enclave_mode: bool
    enclave_status: str
    intents_today: int
    allow_rate_percent: float
    policy_max_amount: float | None = None
    policy_allowlist: list[str] = []
    tracked_user_id: str | None = None


# ── Core Logic ─────────────────────────────────────────────────────────────

def simulate_map_to_curve_fast_verification(master_commitment: str) -> int:
    digest = hashlib.sha256(master_commitment.encode()).digest()
    prime_field = 2**255 - 19
    mapped = int.from_bytes(digest, "big") % prime_field
    return 3 if mapped % 2 == 0 else 4


def _amount_to_wei(amount: Decimal) -> int:
    return int(amount * Decimal(10**18))


def build_transfer_digest(contract_address: str, chain_id: int, destination: str, amount_wei: int, nonce: int) -> bytes:
    packed = encode_packed(
        ["address", "uint256", "address", "uint256", "uint256"],
        [to_checksum_address(contract_address), chain_id, to_checksum_address(destination), amount_wei, nonce],
    )
    message_hash = keccak(packed)
    return keccak(b"\x19Ethereum Signed Message:\n32" + message_hash)


def build_guardian_signature(digest: bytes) -> str:
    if ENCLAVE_URL:
        try:
            headers = _enclave_headers(ENCLAVE_URL)
            last_error: Exception | None = None
            for url in _enclave_candidates("enclave/sign"):
                try:
                    response = httpx.post(
                        url,
                        json={"digest_hex": digest.hex(), "request_id": secrets.token_hex(8)},
                        headers=headers,
                        timeout=10,
                    )
                    response.raise_for_status()
                    return response.json()["signature_hex"]
                except (httpx.HTTPError, KeyError, ValueError) as exc:
                    last_error = exc
            assert last_error is not None
            raise last_error
        except Exception as exc:
            raise RuntimeError(f"Enclave signing failed: {exc}") from exc
    signed = Account.unsafe_sign_hash(digest, private_key=_local_guardian_account.key)
    return signed.signature.hex()


def evaluate_risk(amount: Decimal, destination: str, policy: PolicyConfig) -> tuple[int, list[RuleEvaluation]]:
    evaluations: list[RuleEvaluation] = []

    # Rule 1: max amount
    if amount > policy.max_amount:
        evaluations.append(RuleEvaluation(
            rule="max_amount", status="fail", severity="critical",
            detail=f"Amount {amount} exceeds safe limit {policy.max_amount}.",
        ))
    else:
        evaluations.append(RuleEvaluation(
            rule="max_amount", status="pass", severity="info",
            detail=f"Amount {amount} is within safe limit {policy.max_amount}.",
        ))

    # Rule 2: allowlist
    if destination not in policy.allowlist:
        evaluations.append(RuleEvaluation(
            rule="allowlist_destination", status="fail", severity="critical",
            detail="Destination is not in user allowlist.",
        ))
    else:
        evaluations.append(RuleEvaluation(
            rule="allowlist_destination", status="pass", severity="info",
            detail="Destination is trusted.",
        ))

    # Weighted risk score
    amount_risk = int((min(amount, policy.max_amount * 2) / (policy.max_amount * 2)) * policy.weight_amount)
    if amount > policy.max_amount:
        amount_risk = policy.weight_amount  # max weight on breach

    allowlist_risk = policy.weight_allowlist if destination not in policy.allowlist else 0

    return min(amount_risk + allowlist_risk, 100), evaluations


# ── Endpoints ──────────────────────────────────────────────────────────────

@app.get("/health")
def health() -> dict:
    enclave_status = "not_configured"
    if ENCLAVE_URL:
        try:
            _get_enclave_json("enclave/health")
            enclave_status = "ok"
        except (httpx.HTTPError, ValueError):
            enclave_status = "unreachable"
    return {
        "status": "ok",
        "service": "perisai-guardian",
        "version": "0.2.0",
        "guardian_signer_address": _get_guardian_address(),
        "enclave_mode": bool(ENCLAVE_URL),
        "enclave_status": enclave_status,
        "chain_id": DEFAULT_CHAIN_ID,
        "audit_log_count": len(audit_log),
    }


@app.post("/register", response_model=RegisterResponse)
def register_identity(payload: RegisterRequest) -> RegisterResponse:
    user_id = f"user_{uuid4().hex[:10]}"
    policy = PolicyConfig(
        max_amount=Decimal(str(payload.max_amount)) if payload.max_amount else Decimal("500"),
        allowlist=set(payload.allowlist),
    )
    users[user_id] = UserRecord(user_id=user_id, master_commitment=payload.master_commitment, policy=policy)
    return RegisterResponse(
        user_id=user_id,
        registered_at=users[user_id].registered_at,
        zk_fast_path_hint="Map-to-curve fast path enabled (simulated).",
    )


@app.post("/policy/{user_id}", response_model=PolicyUpdateResponse)
def update_policy(user_id: str, payload: PolicyUpdateRequest) -> PolicyUpdateResponse:
    if user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")
    policy = users[user_id].policy
    if payload.max_amount is not None:
        policy.max_amount = Decimal(str(payload.max_amount))
    if payload.allowlist is not None:
        policy.allowlist = set(payload.allowlist)
    return PolicyUpdateResponse(
        user_id=user_id,
        max_amount=float(policy.max_amount),
        allowlist=list(policy.allowlist),
    )


@app.post("/sign-intent", response_model=SignIntentResponse)
def sign_intent(payload: SignIntentRequest) -> SignIntentResponse:
    if payload.user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")

    record = users[payload.user_id]
    intent_id = f"intent_{uuid4().hex[:8]}"
    verification_ms = simulate_map_to_curve_fast_verification(record.master_commitment)
    amount_decimal = Decimal(str(payload.amount))

    try:
        risk_score, rule_evaluations = evaluate_risk(amount_decimal, payload.destination, record.policy)
    except Exception as exc:
        # Fallback: deny on policy engine failure
        _write_audit(intent_id, payload, "deny", 100, f"Policy engine error: {exc}", [])
        return SignIntentResponse(
            intent_id=intent_id, status="deny",
            reason=f"Guardian denied: policy engine error — {exc}",
            risk_score=100, rule_evaluations=[],
            guardian_signer_address=guardian_address,
            zk_fast_verification_ms=verification_ms,
        )

    failures = [e.detail for e in rule_evaluations if e.status == "fail"]
    if failures:
        reason = "Guardian denied: " + " | ".join(failures)
        _write_audit(intent_id, payload, "deny", risk_score, reason, rule_evaluations)
        return SignIntentResponse(
            intent_id=intent_id, status="deny", reason=reason,
            risk_score=risk_score, rule_evaluations=rule_evaluations,
            guardian_signer_address=guardian_address,
            zk_fast_verification_ms=verification_ms,
        )

    # Build EVM-compatible digest and sign
    digest_hex: Optional[str] = None
    guardian_sig: str

    if payload.contract_address and _is_valid_evm_address(payload.destination):
        amount_wei = _amount_to_wei(amount_decimal)
        digest = build_transfer_digest(
            payload.contract_address, payload.chain_id,
            payload.destination, amount_wei, payload.nonce,
        )
        digest_hex = digest.hex()
        guardian_sig = build_guardian_signature(digest)
    else:
        fallback = f"{payload.user_id}|{payload.destination}|{amount_decimal:.6f}|{payload.chain_id}|{payload.nonce}".encode()
        fallback_digest = keccak(fallback)
        digest_hex = fallback_digest.hex()
        guardian_sig = build_guardian_signature(fallback_digest)

    reason = "Guardian approved: intent passed all safety checks."
    _write_audit(intent_id, payload, "allow", risk_score, reason, rule_evaluations)

    return SignIntentResponse(
        intent_id=intent_id, status="allow", reason=reason,
        risk_score=risk_score, rule_evaluations=rule_evaluations,
        guardian_partial_signature=guardian_sig,
        guardian_signer_address=guardian_address,
        evm_transfer_digest=digest_hex,
        zk_fast_verification_ms=verification_ms,
    )


@app.get("/audit-log", response_model=list[AuditLogEntry])
def get_audit_log(limit: int = 50) -> list[AuditLogEntry]:
    return [
        AuditLogEntry(
            intent_id=e.intent_id, user_id=e.user_id, destination=e.destination,
            amount=e.amount, status=e.status, risk_score=e.risk_score,
            reason=e.reason, timestamp=e.timestamp.isoformat(),
        )
        for e in audit_log[-limit:]
    ]


@app.get("/guardian-profile", response_model=GuardianProfileResponse)
def get_guardian_profile(user_id: str | None = None) -> GuardianProfileResponse:
    now = datetime.now(timezone.utc)
    day_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)

    if user_id is not None and user_id not in users:
        raise HTTPException(status_code=404, detail="User not found")

    relevant_entries = [
        entry for entry in audit_log
        if entry.timestamp >= day_start and (user_id is None or entry.user_id == user_id)
    ]
    intents_today = len(relevant_entries)
    allow_count = sum(1 for entry in relevant_entries if entry.status == "allow")
    allow_rate = (allow_count / intents_today * 100.0) if intents_today > 0 else 0.0

    policy_max_amount: float | None = None
    policy_allowlist: list[str] = []
    if user_id is not None:
        policy = users[user_id].policy
        policy_max_amount = float(policy.max_amount)
        policy_allowlist = sorted(list(policy.allowlist))

    enclave_status = "not_configured"
    if ENCLAVE_URL:
        try:
            headers = _enclave_headers(ENCLAVE_URL)
            response = httpx.get(f"{ENCLAVE_URL}/enclave/health", headers=headers, timeout=5)
            enclave_status = "ok" if response.status_code == 200 else "unreachable"
        except httpx.HTTPError:
            enclave_status = "unreachable"

    return GuardianProfileResponse(
        guardian_signer_address=guardian_address,
        chain_id=DEFAULT_CHAIN_ID,
        enclave_mode=bool(ENCLAVE_URL),
        enclave_status=enclave_status,
        intents_today=intents_today,
        allow_rate_percent=round(allow_rate, 2),
        policy_max_amount=policy_max_amount,
        policy_allowlist=policy_allowlist,
        tracked_user_id=user_id,
    )


def _is_valid_evm_address(addr: str) -> bool:
    """Check if string is a valid 20-byte hex EVM address."""
    try:
        to_checksum_address(addr)
        return True
    except Exception:
        return False


def _write_audit(intent_id: str, payload: SignIntentRequest, status: str, risk_score: int, reason: str, rules: list) -> None:
    audit_log.append(AuditEntry(
        intent_id=intent_id, user_id=payload.user_id,
        destination=payload.destination, amount=str(payload.amount),
        status=status, risk_score=risk_score, reason=reason,
        rule_evaluations=rules, timestamp=datetime.now(timezone.utc),
    ))

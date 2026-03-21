"""
Submit executeTransfer to PerisAIWallet on Sepolia.

Usage:
    python contracts/scripts/execute_transfer.py \
        --to 0xRecipient \
        --amount 0.001 \
        --user-key 0x<user_private_key>

The script calls /sign-intent on the backend to get guardian signature,
then submits executeTransfer to the contract.

Required .env:
    SEPOLIA_RPC_URL=...
    BACKEND_URL=http://127.0.0.1:8000
    USER_ID=user_xxxx
"""

import argparse
import json
import os
import sys
from decimal import Decimal
from pathlib import Path

import requests
from dotenv import load_dotenv
from eth_account import Account
from eth_account.messages import encode_defunct
from eth_utils import keccak, to_checksum_address
from web3 import Web3

load_dotenv()

RPC_URL = os.environ["SEPOLIA_RPC_URL"]
BACKEND_URL = os.environ.get("BACKEND_URL", "http://127.0.0.1:8000")
USER_ID = os.environ["USER_ID"]

CONFIG_PATH = Path(__file__).parent.parent / "config" / "deployed.json"
ABI_PATH = Path(__file__).parent.parent / "config" / "PerisAIWallet.abi"

w3 = Web3(Web3.HTTPProvider(RPC_URL))


def get_guardian_approval(destination: str, amount_eth: float, contract_address: str, nonce: int) -> dict:
    resp = requests.post(f"{BACKEND_URL}/sign-intent", json={
        "user_id": USER_ID,
        "destination": destination,
        "amount": amount_eth,
        "user_partial_signature": "user_sig_placeholder",
        "contract_address": contract_address,
        "chain_id": 11155111,
        "nonce": nonce,
    }, timeout=15)
    resp.raise_for_status()
    return resp.json()


def build_user_signature(user_account: Account, contract_address: str, destination: str, amount_wei: int, nonce: int) -> bytes:
    from eth_abi.packed import encode_packed
    packed = encode_packed(
        ["address", "uint256", "address", "uint256", "uint256"],
        [to_checksum_address(contract_address), 11155111, to_checksum_address(destination), amount_wei, nonce],
    )
    message_hash = keccak(packed)
    digest = keccak(b"\x19Ethereum Signed Message:\n32" + message_hash)
    signed = user_account.sign_message(encode_defunct(digest))
    return signed.signature


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--to", required=True)
    parser.add_argument("--amount", type=float, required=True, help="Amount in ETH")
    parser.add_argument("--user-key", required=True)
    args = parser.parse_args()

    if not CONFIG_PATH.exists():
        print("ERROR: deployed.json not found. Run deploy_sepolia.py first.")
        sys.exit(1)

    config = json.loads(CONFIG_PATH.read_text())
    contract_address = config["PerisAIWallet"]
    abi = json.loads(ABI_PATH.read_text())

    user_account = Account.from_key(args.user_key)
    amount_wei = w3.to_wei(args.amount, "ether")
    contract = w3.eth.contract(address=Web3.to_checksum_address(contract_address), abi=abi)
    nonce_contract = contract.functions.nonce().call()

    print(f"Contract: {contract_address}")
    print(f"Destination: {args.to}")
    print(f"Amount: {args.amount} ETH ({amount_wei} wei)")
    print(f"Contract nonce: {nonce_contract}")

    print("\n[1/3] Requesting guardian approval...")
    decision = get_guardian_approval(args.to, args.amount, contract_address, nonce_contract)
    print(f"  Status: {decision['status']} | Risk: {decision['risk_score']}/100")

    if decision["status"] != "allow":
        print(f"  DENIED: {decision['reason']}")
        print("  Transaction NOT submitted (guardian denied).")
        sys.exit(0)

    guardian_sig = bytes.fromhex(decision["guardian_partial_signature"].lstrip("0x"))

    print("\n[2/3] Building user signature...")
    user_sig = build_user_signature(user_account, contract_address, args.to, amount_wei, nonce_contract)

    print("\n[3/3] Submitting executeTransfer...")
    tx_nonce = w3.eth.get_transaction_count(user_account.address)
    tx = contract.functions.executeTransfer(
        Web3.to_checksum_address(args.to),
        amount_wei,
        user_sig,
        guardian_sig,
    ).build_transaction({
        "from": user_account.address,
        "nonce": tx_nonce,
        "gas": 200_000,
        "gasPrice": w3.eth.gas_price,
        "chainId": 11155111,
    })
    signed_tx = user_account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    print(f"  Tx submitted: {tx_hash.hex()}")
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
    print(f"  Status: {'SUCCESS' if receipt.status == 1 else 'FAILED'}")
    print(f"  Block: {receipt.blockNumber}")
    print(f"  Explorer: https://sepolia.etherscan.io/tx/{tx_hash.hex()}")


if __name__ == "__main__":
    main()

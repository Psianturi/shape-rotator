"""
Deploy IdentityRegistry and PerisAIWallet to Sepolia.

Usage:
    pip install web3 eth-account python-dotenv
    python contracts/scripts/deploy_sepolia.py

Required .env:
    SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/<KEY>
    DEPLOYER_PRIVATE_KEY=0x<key>
    USER_SIGNER_ADDRESS=0x<address>
    GUARDIAN_SIGNER_ADDRESS=0x<address>
"""

import json
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from eth_account import Account
from web3 import Web3

load_dotenv()

RPC_URL = os.environ["SEPOLIA_RPC_URL"]
DEPLOYER_KEY = os.environ["DEPLOYER_PRIVATE_KEY"]
USER_SIGNER = os.environ["USER_SIGNER_ADDRESS"]
GUARDIAN_SIGNER = os.environ["GUARDIAN_SIGNER_ADDRESS"]

w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Cannot connect to Sepolia RPC"

deployer = Account.from_key(DEPLOYER_KEY)
print(f"Deployer: {deployer.address}")
print(f"Balance:  {w3.from_wei(w3.eth.get_balance(deployer.address), 'ether')} ETH")

CONTRACTS_DIR = Path(__file__).parent.parent
CONFIG_PATH = CONTRACTS_DIR / "config" / "deployed.json"


def _load_bytecode(name: str) -> tuple[str, list]:
    """Load pre-compiled bytecode. name must be alphanumeric only."""
    if not name.isalnum():
        print(f"ERROR: Invalid contract name '{name}'. Must be alphanumeric.")
        sys.exit(1)
    bytecode_path = (CONTRACTS_DIR / "config" / f"{name}.bin").resolve()
    abi_path = (CONTRACTS_DIR / "config" / f"{name}.abi").resolve()
    # Guard against path traversal
    config_dir = (CONTRACTS_DIR / "config").resolve()
    if not str(bytecode_path).startswith(str(config_dir)):
        print(f"ERROR: Path traversal detected for '{name}'")
        sys.exit(1)
    if not bytecode_path.exists():
        print(f"ERROR: {bytecode_path} not found. Run: solc --bin --abi {name}.sol -o config/")
        sys.exit(1)
    return bytecode_path.read_text().strip(), json.loads(abi_path.read_text())


def deploy_contract(name: str, *constructor_args: str) -> str:
    if not name or not name.isalnum():
        print(f"ERROR: Invalid contract name '{name}'")
        sys.exit(1)
    bytecode, abi = _load_bytecode(name)
    contract = w3.eth.contract(abi=abi, bytecode=bytecode)
    nonce = w3.eth.get_transaction_count(deployer.address)
    tx = contract.constructor(*constructor_args).build_transaction({
        "from": deployer.address,
        "nonce": nonce,
        "gas": 2_000_000,
        "gasPrice": w3.eth.gas_price,
        "chainId": 11155111,
    })
    signed = deployer.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    print(f"  Deploying {name}... tx: {tx_hash.hex()}")
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
    assert receipt.status == 1, f"{name} deployment failed"
    print(f"  {name} deployed at: {receipt.contractAddress}")
    return receipt.contractAddress


def main():
    deployed = {}

    print("\n[1/3] Deploying IdentityRegistry...")
    deployed["IdentityRegistry"] = deploy_contract("IdentityRegistry")

    print("\n[2/3] Deploying PerisAIWallet...")
    deployed["PerisAIWallet"] = deploy_contract(
        "PerisAIWallet",
        Web3.to_checksum_address(USER_SIGNER),
        Web3.to_checksum_address(GUARDIAN_SIGNER),
    )

    print("\n[3/3] Deploying AgentRegistry...")
    deployed["AgentRegistry"] = deploy_contract("AgentRegistry")

    deployed["chain_id"] = 11155111
    deployed["network"] = "sepolia"
    deployed["deployer"] = deployer.address

    CONFIG_PATH.parent.mkdir(exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(deployed, indent=2))
    print(f"\nDeployment config saved to {CONFIG_PATH}")
    print(json.dumps(deployed, indent=2))


if __name__ == "__main__":
    main()

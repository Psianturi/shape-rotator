"""
PerisAI Enclave Signer Service (TEE-ready boundary)

This service represents the signing enclave. In production it runs inside
a Trusted Execution Environment (e.g. AWS Nitro Enclaves, Intel TDX).

Key design principles:
- Private key is generated at runtime and NEVER exported.
- Only the public address is exposed.
- Signing requests come from the API gateway (main.py) via localhost.
- Attestation endpoint returns a simulated attestation document.

Run separately:
    uvicorn backend.enclave.signer_service:app --port 8001 --host 127.0.0.1
"""

import hashlib
import hmac
import secrets
import time
from datetime import datetime, timezone

from eth_account import Account
from eth_account._utils.signing import sign_message_hash
from eth_utils import keccak
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="PerisAI Enclave Signer", version="1.0.0")

# Key is generated at enclave boot — never persisted, never exported.
_guardian_key = Account.create(secrets.token_hex(32))
_boot_time = datetime.now(timezone.utc)
_attestation_nonce = secrets.token_hex(16)


class SignRequest(BaseModel):
    digest_hex: str  # 32-byte keccak digest as hex string
    request_id: str


class SignResponse(BaseModel):
    signature_hex: str
    signer_address: str
    request_id: str


class AttestationResponse(BaseModel):
    signer_address: str
    boot_time: str
    attestation_nonce: str
    pcr0_simulated: str   # In real TEE: PCR0 = hash of enclave image
    status: str


@app.get("/enclave/public-key")
@app.get("/public-key")
def get_public_key() -> dict:
    return {"signer_address": _guardian_key.address}


@app.post("/enclave/sign", response_model=SignResponse)
@app.post("/sign", response_model=SignResponse)
def sign_digest(payload: SignRequest) -> SignResponse:
    try:
        digest_bytes = bytes.fromhex(payload.digest_hex.lstrip("0x"))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid digest hex")

    if len(digest_bytes) != 32:
        raise HTTPException(status_code=400, detail="Digest must be 32 bytes")

    # digest_hex is the final EVM digest (already includes Ethereum prefix).
    # Sign raw bytes directly — do NOT re-wrap with encode_defunct.
    signed = Account.unsafe_sign_hash(digest_bytes, private_key=_guardian_key.key)
    return SignResponse(
        signature_hex=signed.signature.hex(),
        signer_address=_guardian_key.address,
        request_id=payload.request_id,
    )


@app.get("/enclave/attestation", response_model=AttestationResponse)
@app.get("/attestation", response_model=AttestationResponse)
def get_attestation() -> AttestationResponse:
    """
    Simulated attestation document.

    In production (AWS Nitro Enclaves):
    - PCR0 = SHA384 of enclave image EIF
    - Attestation document is signed by AWS Nitro attestation CA
    - Verifiable via nitro-cli verify-attestation

    Here we simulate with a deterministic hash of the signer address + boot time.
    """
    pcr0_input = f"{_guardian_key.address}:{_boot_time.isoformat()}".encode()
    pcr0_simulated = hashlib.sha384(pcr0_input).hexdigest()

    return AttestationResponse(
        signer_address=_guardian_key.address,
        boot_time=_boot_time.isoformat(),
        attestation_nonce=_attestation_nonce,
        pcr0_simulated=pcr0_simulated,
        status="simulated",
    )


@app.get("/enclave/health")
@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "signer_address": _guardian_key.address,
        "uptime_seconds": int((datetime.now(timezone.utc) - _boot_time).total_seconds()),
        "tee_mode": "simulated",
    }

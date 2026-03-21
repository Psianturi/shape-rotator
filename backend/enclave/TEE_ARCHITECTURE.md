# PerisAI TEE Architecture (Phase 5)

## Overview

```
Mobile App
    │
    ▼
API Gateway (main.py :8000)          ← Public-facing, no private key
    │  POST /sign-intent
    │  evaluates policy rules
    │  if ALLOW → calls enclave
    │
    ▼
Enclave Signer (signer_service.py :8001)   ← TEE boundary
    │  POST /enclave/sign
    │  private key NEVER leaves enclave
    │  returns signature only
    │
    ▼
Guardian Signature → returned to app
    │
    ▼
PerisAIWallet.executeTransfer (Sepolia)
```

## Key Provisioning Model

| Stage       | Action                                                      |
|-------------|-------------------------------------------------------------|
| Boot        | Enclave generates ephemeral key via `Account.create()`      |
| Attestation | PCR0 hash of enclave image is published                     |
| Binding     | Guardian signer address registered in AgentRegistry on-chain|
| Runtime     | API gateway fetches `/enclave/public-key` on startup        |
| Signing     | Gateway sends digest, enclave returns signature             |
| Key export  | NEVER — key only exists in enclave memory                   |

## API Boundary

### Gateway → Enclave (internal, localhost only)
- `POST /enclave/sign` — sign a 32-byte digest
- `GET /enclave/public-key` — get signer address
- `GET /enclave/attestation` — get attestation document

### Public (Gateway)
- `POST /sign-intent` — policy evaluation + signing (calls enclave internally)
- `GET /health` — includes attestation_status field
- `GET /audit-log` — decision audit trail

## Attestation Verification Flow

1. Client calls `GET /health` → sees `attestation_status: verified`
2. Client calls `GET /enclave/attestation` → gets PCR0 + nonce
3. In production: verify PCR0 against known-good enclave image hash
4. In demo: PCR0 is SHA384(signer_address + boot_time) — deterministic and auditable

## Production Path (AWS Nitro Enclaves)

```bash
# Build enclave image
nitro-cli build-enclave --docker-uri perisai-signer:latest --output-file signer.eif

# Run enclave
nitro-cli run-enclave --eif-path signer.eif --memory 512 --cpu-count 2

# Verify attestation
nitro-cli describe-enclaves
```

## Demo Indicator in App

The Guardian Detail page shows:
- Attestation: `Simulated (TEE-ready)` 
- In production: `Verified (Nitro Enclave PCR0: <hash>)`

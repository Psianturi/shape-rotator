# PerisAI Backend

FastAPI service for the PerisAI guardian wallet.

## What it does

- Registers anonymous user commitments
- Evaluates transfer policy and risk score
- Calls the enclave signer for approved intents
- Exposes audit log and guardian profile endpoints

## Run locally

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

## Key endpoints

- `GET /health`
- `POST /register`
- `POST /sign-intent`
- `GET /audit-log`
- `GET /guardian-profile`

## Enclave signer

The backend can call the enclave signer through `ENCLAVE_URL`.
If `ENCLAVE_URL` is not set, it falls back to the local in-process key for development.
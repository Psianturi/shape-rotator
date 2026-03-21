# PerisAI — AI Threshold Guardian Wallet

Privacy-first wallet with AI Guardian policy engine and threshold 2-signature execution.

## Architecture

```
Flutter App
    │ HTTPS
    ▼
Guardian API (FastAPI)          ← POST /register, /sign-intent, /policy, /audit-log
    │ HTTPS + Google OIDC token
    ▼
Enclave Signer (FastAPI)        ← POST /enclave/sign (private, no public access)
    │
    ▼
PerisAIWallet.sol (Sepolia)     ← executeTransfer(userSig, guardianSig)
```

## Project Structure

```
backend/
  app/main.py              Guardian API — policy engine, audit log, enclave routing
  enclave/signer_service.py  Enclave signer — isolated key, attestation endpoint
  Dockerfile               Cloud Run image for Guardian API
  Dockerfile.enclave       Cloud Run image for Enclave Signer

contracts/
  PerisAIWallet.sol        2-signature threshold wallet
  IdentityRegistry.sol     Anonymous commitment registry
  AgentRegistry.sol        1-user-1-agent on-chain binding
  scripts/
    compile_contracts.sh   Compile ABI/BIN artifacts
    deploy_sepolia.py      Deploy contracts to Sepolia
    execute_transfer.py    Submit executeTransfer on-chain

frontend/lib/
  config/app_config.dart   Backend URL config (swap local ↔ Cloud Run here)
  controllers/             WalletController — all business logic
  pages/
    splash/                Splash page
    biometric/             Biometric simulation + register
    dashboard/             Balance, guardian status, recent activity
    transfer/              Send intent, ALLOW/DENY demo scenarios
    activity/              Decision timeline
  theme/app_theme.dart     Design tokens — colors, icons, status
```

## Run Locally

**Backend:**
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

**Enclave Signer (optional, separate terminal):**
```bash
uvicorn backend.enclave.signer_service:app --port 8001 --host 127.0.0.1
```

**Flutter:**
```bash
cd frontend
flutter pub get
flutter run
```

For Android emulator, set in `frontend/lib/config/app_config.dart`:
```dart
defaultValue: 'http://10.0.2.2:8000'
```

## Tests

```bash
cd backend
python -m pytest tests/ -v
# 16 passed — smoke + integration, includes digest Python=Solidity verification
```

## Deploy to Cloud Run (Project: perisai-490814)

```bash
# First time only
gcloud auth login
gcloud config set project perisai-490814
chmod +x deploy.sh && ./deploy.sh
```

After deploy, update `frontend/lib/config/app_config.dart` with the Backend URL output,
or run Flutter with:
```bash
flutter run --dart-define=BACKEND_URL=https://perisai-guardian-api-XXXXXXXX-as.a.run.app
```

## Deploy Contracts to Sepolia

```bash
cd contracts/scripts
pip install -r requirements.txt

# Step 1: Compile contracts
chmod +x compile_contracts.sh && ./compile_contracts.sh

# Step 2: Fill in contracts/.env (copy from contracts/.env.example)

# Step 3: Deploy
python deploy_sepolia.py
```

## Demo Scenarios

| Scenario | Action | Guardian Decision |
|---|---|---|
| Safe transfer | Send to Trusted Address, amount < 500 | ALLOW — signature issued |
| Suspicious transfer | Simulate Suspicious Transfer, amount > 500 + unknown address | DENY — no signature |

## Key Talking Points

| Question | Answer |
|---|---|
| Who guards the guardian? | Enclave signer — key never exported, isolated container, attestation endpoint |
| Is this real on-chain? | Yes — PerisAIWallet on Sepolia, tx verifiable on Etherscan |
| How is privacy preserved? | Only commitment hash sent to backend, nullifier stays on device |
| Production TEE path? | Cloud Run isolated → Confidential VM (AMD SEV) → AWS Nitro Enclaves |
| Why two signatures? | Threshold model — neither user nor guardian alone can move funds |

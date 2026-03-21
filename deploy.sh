#!/bin/bash
# PerisAI — First-time deploy to Google Cloud Run
# Project: perisai-490814 | Region: asia-southeast1
#
# Prerequisites:
#   gcloud auth login
#   gcloud config set project perisai-490814
#
# Run:
#   chmod +x deploy.sh && ./deploy.sh

set -e

PROJECT_ID="perisai-490814"
REGION="asia-southeast1"
REPO="perisai"
REGISTRY="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO"

echo "=== PerisAI Cloud Run Deploy ==="
echo "Project : $PROJECT_ID"
echo "Region  : $REGION"
echo ""

# ── Step 1: Enable required APIs ──────────────────────────────────────────
echo "[1/7] Enabling GCP APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --project=$PROJECT_ID

# ── Step 2: Create Artifact Registry repo ─────────────────────────────────
echo "[2/7] Creating Artifact Registry repository..."
gcloud artifacts repositories create $REPO \
  --repository-format=docker \
  --location=$REGION \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || echo "  (repo already exists, skipping)"

# ── Step 3: Configure Docker auth ─────────────────────────────────────────
echo "[3/7] Configuring Docker authentication..."
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

# ── Step 4: Build & push enclave signer ───────────────────────────────────
echo "[4/7] Building enclave signer image..."
docker build -f backend/Dockerfile.enclave -t $REGISTRY/enclave-signer:latest backend/
docker push $REGISTRY/enclave-signer:latest

# ── Step 5: Deploy enclave signer ─────────────────────────────────────────
echo "[5/7] Deploying enclave signer to Cloud Run..."
gcloud run deploy perisai-enclave-signer \
  --image=$REGISTRY/enclave-signer:latest \
  --region=$REGION \
  --platform=managed \
  --no-allow-unauthenticated \
  --memory=256Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=3 \
  --set-env-vars=TEE_MODE=simulated \
  --port=8080 \
  --project=$PROJECT_ID

ENCLAVE_URL=$(gcloud run services describe perisai-enclave-signer \
  --region=$REGION \
  --format='value(status.url)' \
  --project=$PROJECT_ID)
echo "  Enclave URL: $ENCLAVE_URL"

# ── Step 6: Build & push backend ──────────────────────────────────────────
echo "[6/7] Building backend image..."
docker build -f backend/Dockerfile -t $REGISTRY/guardian-api:latest backend/
docker push $REGISTRY/guardian-api:latest

# ── Step 7: Deploy backend ─────────────────────────────────────────────────
echo "[7/7] Deploying backend to Cloud Run..."
gcloud run deploy perisai-guardian-api \
  --image=$REGISTRY/guardian-api:latest \
  --region=$REGION \
  --platform=managed \
  --allow-unauthenticated \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=5 \
  --set-env-vars="ENCLAVE_URL=$ENCLAVE_URL" \
  --port=8080 \
  --project=$PROJECT_ID

BACKEND_URL=$(gcloud run services describe perisai-guardian-api \
  --region=$REGION \
  --format='value(status.url)' \
  --project=$PROJECT_ID)

echo ""
echo "=== Deploy Complete ==="
echo "Backend URL : $BACKEND_URL"
echo "Enclave URL : $ENCLAVE_URL"
echo ""
echo "Health check:"
curl -s "$BACKEND_URL/health" | python3 -m json.tool
echo ""
echo "=== Next Step: Update Flutter App ==="
echo "Edit: frontend/lib/config/app_config.dart"
echo "Change defaultValue to: $BACKEND_URL"
echo ""
echo "Or run Flutter with env var:"
echo "  flutter run --dart-define=BACKEND_URL=$BACKEND_URL"

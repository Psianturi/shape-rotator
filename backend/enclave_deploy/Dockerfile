FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY enclave/signer_service.py ./enclave/signer_service.py

ENV PYTHONUNBUFFERED=1
ENV PORT=8080
ENV TEE_MODE=simulated

EXPOSE 8080

CMD ["uvicorn", "enclave.signer_service:app", "--host", "0.0.0.0", "--port", "8080"]

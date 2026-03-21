from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _register(allowlist=None, max_amount=None):
    body = {"master_commitment": "commitment_smoke_001", "allowlist": allowlist or ["0xTrusted001"]}
    if max_amount is not None:
        body["max_amount"] = max_amount
    r = client.post("/register", json=body)
    assert r.status_code == 200
    return r.json()["user_id"]


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["guardian_signer_address"].startswith("0x")
    assert body["chain_id"] == 11155111


def test_allow_scenario():
    uid = _register()
    r = client.post("/sign-intent", json={
        "user_id": uid, "destination": "0xTrusted001",
        "amount": 120, "user_partial_signature": "sig_ok",
    })
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "allow"
    assert body["guardian_partial_signature"] is not None
    assert body["risk_score"] < 70
    assert body["intent_id"].startswith("intent_")
    assert all(e["severity"] in ("info", "warning", "critical") for e in body["rule_evaluations"])


def test_deny_amount():
    uid = _register()
    r = client.post("/sign-intent", json={
        "user_id": uid, "destination": "0xTrusted001",
        "amount": 900, "user_partial_signature": "sig_bad",
    })
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "deny"
    assert body["risk_score"] >= 60
    assert any(e["status"] == "fail" and e["severity"] == "critical" for e in body["rule_evaluations"])


def test_deny_allowlist():
    uid = _register()
    r = client.post("/sign-intent", json={
        "user_id": uid, "destination": "0xNewRisk999",
        "amount": 100, "user_partial_signature": "sig_bad2",
    })
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "deny"
    assert "allowlist" in body["reason"]


def test_policy_update():
    uid = _register(allowlist=["0xOld"])
    r = client.post(f"/policy/{uid}", json={"allowlist": ["0xNew001"], "max_amount": 1000})
    assert r.status_code == 200
    body = r.json()
    assert "0xNew001" in body["allowlist"]
    assert body["max_amount"] == 1000.0

    # Now allow with new policy
    r2 = client.post("/sign-intent", json={
        "user_id": uid, "destination": "0xNew001",
        "amount": 800, "user_partial_signature": "sig_new",
    })
    assert r2.json()["status"] == "allow"


def test_audit_log():
    uid = _register()
    client.post("/sign-intent", json={
        "user_id": uid, "destination": "0xTrusted001",
        "amount": 50, "user_partial_signature": "sig_audit",
    })
    r = client.get("/audit-log")
    assert r.status_code == 200
    entries = r.json()
    assert len(entries) >= 1
    assert entries[-1]["user_id"] == uid
    assert entries[-1]["status"] in ("allow", "deny")


def test_unknown_user_returns_404():
    r = client.post("/sign-intent", json={
        "user_id": "user_nonexistent", "destination": "0xAnyAddr",
        "amount": 10, "user_partial_signature": "sig",
    })
    assert r.status_code == 404

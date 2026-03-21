/// Central configuration for PerisAI app.
/// After deploy.sh completes, paste the Backend URL here.
class AppConfig {
  // ── Backend URL ──────────────────────────────────────────────────────────
  // Local dev:        'http://127.0.0.1:8000'
  // Android emulator: 'http://10.0.2.2:8000'
  // Cloud Run:        'https://perisai-guardian-api-305832734922.asia-southeast1.run.app'
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://perisai-guardian-api-305832734922.asia-southeast1.run.app',
  );

  // ── Demo addresses ───────────────────────────────────────────────────────
  static const trustedAddress = '0xTrusted001';
  static const suspiciousAddress = '0xNewRisk999';
}

# PerisAI Flutter App

Mobile app for the PerisAI threshold guardian wallet.

## What it does

- Simulates biometric sign-in
- Registers an anonymous identity to the Guardian API
- Shows live guardian status, policy, and recent activity
- Lets you test trusted and suspicious transfer intents

## Run

```bash
flutter pub get
flutter run
```

If you want to override the backend URL:

```bash
flutter run --dart-define=BACKEND_URL=https://perisai-guardian-api-305832734922.asia-southeast1.run.app
```

## Notes

- Default backend URL is set in `lib/config/app_config.dart`
- Main flow: Splash -> Biometric -> Dashboard -> Transfer -> Activity -> Guardian Detail
- Use the Dashboard refresh action if you want to re-fetch live guardian profile data

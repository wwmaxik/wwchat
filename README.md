# wwchat

Flutter messenger prototype with two transport modes:

- Firebase for online auth, contacts, and message sync
- BLE nearby mesh for local peer-to-peer delivery when internet is unavailable

## Features

- Email/password authentication with Firebase Auth
- Contact discovery from Firestore
- Chat UI with online and BLE delivery modes
- Basic device discovery for nearby mesh nodes
- GitHub Actions CI for format, analyze, and test

## Tech Stack

- Flutter
- Provider
- Firebase Auth
- Cloud Firestore
- flutter_nearby_connections
- cryptography

## Local Setup

1. Install Flutter and run:

```bash
flutter pub get
```

2. For Android, add your local Firebase config file:

```text
android/app/google-services.json
```

This file is ignored by git and must not be committed.

3. For web, provide Firebase values with `--dart-define`:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=your_key \
  --dart-define=FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project.firebasestorage.app \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your_sender_id \
  --dart-define=FIREBASE_APP_ID=your_app_id
```

If these values are missing, the app still starts, but Firebase-dependent flows will not be available.

## Development Commands

```bash
dart format .
flutter analyze
flutter test
```

## Current Status

This project is still a prototype. The core chat flow is present, but transport reliability, security hardening, and production-ready sync behavior are still in progress.

import 'package:flutter/foundation.dart';

class AppConfig {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const encryptionSecret = String.fromEnvironment('WWCHAT_ENCRYPTION_SECRET');

  static bool get isFirebaseWebConfigComplete {
    return firebaseApiKey.isNotEmpty &&
        firebaseAuthDomain.isNotEmpty &&
        firebaseProjectId.isNotEmpty &&
        firebaseStorageBucket.isNotEmpty &&
        firebaseMessagingSenderId.isNotEmpty &&
        firebaseAppId.isNotEmpty;
  }

  static bool get hasEncryptionSecret => encryptionSecret.trim().isNotEmpty;

  static void debugPrintMissingEncryptionSecretWarning() {
    if (!hasEncryptionSecret) {
      debugPrint(
        'WWCHAT_ENCRYPTION_SECRET is not set. Using a development fallback secret.',
      );
    }
  }
}

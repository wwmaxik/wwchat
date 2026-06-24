import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../app_config.dart';

class EncryptionService {
  final algorithm = AesGcm.with256bits();

  Future<SecretKey> deriveConversationKey(String conversationId) async {
    AppConfig.debugPrintMissingEncryptionSecretWarning();

    final configuredSecret = AppConfig.hasEncryptionSecret
        ? AppConfig.encryptionSecret
        : 'wwchat-development-only-secret';

    final sink = Sha256().newHashSink();
    sink.add(utf8.encode('$configuredSecret::$conversationId'));
    sink.close();
    final hash = await sink.hash();
    return SecretKey(hash.bytes);
  }

  Future<String> encrypt(String text, SecretKey secretKey) async {
    final secretBox = await algorithm.encrypt(
      utf8.encode(text),
      secretKey: secretKey,
    );
    return base64.encode(secretBox.concatenation());
  }

  Future<String> decrypt(String cipherText, SecretKey secretKey) async {
    try {
      final box = SecretBox.fromConcatenation(
        base64.decode(cipherText),
        nonceLength: algorithm.nonceLength,
        macLength: algorithm.macAlgorithm.macLength,
      );
      final clearText = await algorithm.decrypt(
        box,
        secretKey: secretKey,
      );
      return utf8.decode(clearText);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return '[Decryption Error]';
    }
  }
}

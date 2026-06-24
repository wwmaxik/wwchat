import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../services/firebase_service.dart';
import '../services/encryption_service.dart';
import '../services/ble_mesh_service.dart';
import 'package:cryptography/cryptography.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final EncryptionService _encryptionService = EncryptionService();
  
  List<Contact> _contacts = [];
  final Map<String, List<Message>> _localMessages = {};
  SecretKey? _encryptionKey;
  BleMeshService? _bleMeshService;
  StreamSubscription<List<Message>>? _firestoreMessagesSubscription;

  List<Contact> get contacts => _contacts;

  ChatProvider() {
    _init();
  }

  Future<void> _init() async {
    _encryptionKey = await _encryptionService.deriveKey("shared_secret_password");
    _firebaseService.getContacts().listen((updatedContacts) {
      _contacts = updatedContacts;
      notifyListeners();
    });
  }

  void setBleMeshService(BleMeshService bleService) {
    if (_bleMeshService == bleService) return;
    _bleMeshService = bleService;
    _bleMeshService!.onMessageReceived = (encryptedText, senderId) {
      debugPrint("ChatProvider received BLE message from $senderId");
      receiveMessage(encryptedText, senderId, MessageSource.ble);
    };
  }

  void setActiveContact(String? contactId) {
    _firestoreMessagesSubscription?.cancel();
    if (contactId == null) return;

    debugPrint("Subscribing to Firestore messages for contact: $contactId");
    _firestoreMessagesSubscription = _firebaseService.getMessages(contactId).listen((firestoreMsgs) async {
      if (_encryptionKey == null) {
        debugPrint("Encryption key not derived yet; waiting.");
        return;
      }
      
      List<Message> decryptedMsgs = [];
      for (var msg in firestoreMsgs) {
        try {
          final decrypted = await _encryptionService.decrypt(msg.text, _encryptionKey!);
          decryptedMsgs.add(
            Message(
              id: msg.id,
              senderId: msg.senderId,
              recipientId: msg.recipientId,
              text: decrypted,
              timestamp: msg.timestamp,
              source: msg.source,
              isMe: msg.isMe,
            )
          );
        } catch (e) {
          debugPrint("Failed to decrypt message ${msg.id}: $e");
        }
      }

      // Keep all messages that came from BLE (which are stored locally only)
      final localList = _localMessages[contactId] ?? [];
      final bleMsgs = localList.where((m) => m.source == MessageSource.ble).toList();
      
      // Combine BLE messages and decrypted Firestore messages
      final combined = [...bleMsgs, ...decryptedMsgs];
      // Sort by timestamp descending (newest first, for ListView builder)
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Remove duplicate IDs
      final seenIds = <String>{};
      final uniqueCombined = <Message>[];
      for (var m in combined) {
        if (!seenIds.contains(m.id)) {
          seenIds.add(m.id);
          uniqueCombined.add(m);
        }
      }

      _localMessages[contactId] = uniqueCombined;
      notifyListeners();
    });
  }

  List<Message> getMessagesWith(String contactId) {
    return _localMessages[contactId] ?? [];
  }

  Future<void> addMessage({
    required String text, 
    required String recipientId, 
    required bool isMe, 
    required MessageSource source
  }) async {
    if (_encryptionKey == null) {
      debugPrint("Cannot add message; encryption key is null");
      return;
    }
    
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final encryptedText = await _encryptionService.encrypt(text, _encryptionKey!);

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: isMe ? currentUid : recipientId,
      recipientId: isMe ? recipientId : currentUid,
      text: text, // Keep plaintext locally
      timestamp: DateTime.now(),
      source: source,
      isMe: isMe,
    );

    if (source == MessageSource.internet) {
      await _firebaseService.sendMessage(
        Message(
          id: message.id,
          senderId: message.senderId,
          recipientId: message.recipientId,
          text: encryptedText,
          timestamp: message.timestamp,
          source: source,
          isMe: isMe,
        )
      );
    } else if (source == MessageSource.ble) {
      await _bleMeshService?.sendMeshMessage(encryptedText);
    }

    _localMessages.putIfAbsent(recipientId, () => []).insert(0, message);
    notifyListeners();
  }

  Future<void> receiveMessage(String encryptedText, String fromId, MessageSource source) async {
    if (_encryptionKey == null) {
      debugPrint("Cannot receive message; encryption key is null");
      return;
    }
    
    final decryptedText = await _encryptionService.decrypt(encryptedText, _encryptionKey!);
    
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: fromId,
      recipientId: currentUid,
      text: decryptedText,
      timestamp: DateTime.now(),
      source: source,
      isMe: false,
    );

    _localMessages.putIfAbsent(fromId, () => []).insert(0, message);
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreMessagesSubscription?.cancel();
    super.dispose();
  }
}

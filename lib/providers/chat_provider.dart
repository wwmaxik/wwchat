import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/ble_mesh_service.dart';
import '../services/encryption_service.dart';
import '../services/firebase_service.dart';

class ChatProvider with ChangeNotifier {
  ChatProvider(
      {FirebaseService? firebaseService, EncryptionService? encryptionService})
      : _firebaseService = firebaseService ?? FirebaseService(),
        _encryptionService = encryptionService ?? EncryptionService() {
    _init();
  }

  final FirebaseService _firebaseService;
  final EncryptionService _encryptionService;
  final Uuid _uuid = const Uuid();

  List<Contact> _contacts = [];
  final Map<String, List<Message>> _localMessages = {};
  final Set<String> _seenMessageIds = <String>{};
  BleMeshService? _bleMeshService;
  StreamSubscription<List<Message>>? _firestoreMessagesSubscription;
  StreamSubscription<List<Contact>>? _contactsSubscription;
  String? _activeContactId;

  List<Contact> get contacts => _contacts;

  Future<void> _init() async {
    _contactsSubscription =
        _firebaseService.getContacts().listen((updatedContacts) {
      _contacts = updatedContacts;
      notifyListeners();
    });
  }

  void setBleMeshService(BleMeshService bleService) {
    if (_bleMeshService == bleService) return;
    _bleMeshService = bleService;
    _bleMeshService!.onMessageReceived = (packet) {
      debugPrint('ChatProvider received BLE packet ${packet.id}');
      receiveMeshPacket(packet);
    };
  }

  void setActiveContact(String? contactId) {
    _activeContactId = contactId;
    _firestoreMessagesSubscription?.cancel();
    if (contactId == null) return;

    _firestoreMessagesSubscription =
        _firebaseService.getMessages(contactId).listen((firestoreMsgs) {
      _mergeMessages(contactId, firestoreMsgs);
    });
  }

  List<Message> getMessagesWith(String contactId) {
    return _localMessages[contactId] ?? const <Message>[];
  }

  String get _currentUserId {
    if (Firebase.apps.isEmpty) {
      return 'unknown';
    }
    return FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  }

  Future<void> addMessage({
    required String text,
    required String recipientId,
    required bool isMe,
    required MessageSource source,
  }) async {
    final currentUid = _currentUserId;
    final conversationId = buildConversationId(currentUid, recipientId);
    final messageId = _uuid.v4();
    final key = await _encryptionService.deriveConversationKey(conversationId);
    final encryptedText = await _encryptionService.encrypt(text, key);
    final senderMeshId = _bleMeshService?.localDeviceId;

    final message = Message(
      id: messageId,
      senderId: isMe ? currentUid : recipientId,
      recipientId: isMe ? recipientId : currentUid,
      conversationId: conversationId,
      text: text,
      timestamp: DateTime.now(),
      source: source,
      isMe: isMe,
      senderMeshId: senderMeshId,
    );

    if (source == MessageSource.internet) {
      await _firebaseService.sendMessage(
        message.copyWith(
          text: encryptedText,
          source: MessageSource.internet,
        ),
      );
    } else if (source == MessageSource.ble) {
      await _bleMeshService?.sendMeshMessage(
        MeshMessagePacket(
          id: messageId,
          senderUserId: currentUid,
          senderMeshId: senderMeshId ?? 'unknown-device',
          recipientUserId: recipientId,
          conversationId: conversationId,
          encryptedText: encryptedText,
          hopCount: 0,
          sentAt: message.timestamp,
        ),
      );
    }

    _mergeMessages(recipientId, [message]);
  }

  Future<void> receiveMeshPacket(MeshMessagePacket packet) async {
    final currentUid = _currentUserId;
    if (packet.recipientUserId != currentUid) {
      await _bleMeshService?.relayMeshMessage(packet);
      return;
    }

    if (_seenMessageIds.contains(packet.id)) {
      return;
    }

    final key =
        await _encryptionService.deriveConversationKey(packet.conversationId);
    final decryptedText =
        await _encryptionService.decrypt(packet.encryptedText, key);

    final message = Message(
      id: packet.id,
      senderId: packet.senderUserId,
      recipientId: currentUid,
      conversationId: packet.conversationId,
      text: decryptedText,
      timestamp: packet.sentAt,
      source: MessageSource.ble,
      isMe: false,
      senderMeshId: packet.senderMeshId,
    );

    _mergeMessages(packet.senderUserId, [message]);

    if (_activeContactId == packet.senderUserId &&
        _firebaseService.isAvailable) {
      await _firebaseService.sendMessage(
        message.copyWith(
          text: packet.encryptedText,
          source: MessageSource.ble,
        ),
      );
    }
  }

  void _mergeMessages(String contactId, List<Message> incomingMessages) {
    final currentMessages = [
      ...(_localMessages[contactId] ?? const <Message>[])
    ];
    final mergedById = <String, Message>{
      for (final message in currentMessages) message.id: message,
    };

    for (final message in incomingMessages) {
      mergedById[message.id] = message;
      _seenMessageIds.add(message.id);
    }

    final mergedMessages = mergedById.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _localMessages[contactId] = mergedMessages;
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreMessagesSubscription?.cancel();
    _contactsSubscription?.cancel();
    super.dispose();
  }
}

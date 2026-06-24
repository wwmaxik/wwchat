import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/message.dart';

class FirebaseService {
  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseFirestore? get _firestoreOrNull =>
      isAvailable ? FirebaseFirestore.instance : null;
  FirebaseAuth? get _authOrNull => isAvailable ? FirebaseAuth.instance : null;

  Stream<List<Contact>> getContacts() {
    final firestore = _firestoreOrNull;
    final currentUserId = _authOrNull?.currentUser?.uid;

    if (firestore == null) {
      return Stream.value(const <Contact>[]);
    }

    return firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.where((doc) => doc.id != currentUserId).map((doc) {
        final data = doc.data();
        return Contact(
          id: doc.id,
          name: data['name'] as String? ?? 'Unknown',
          meshAddress: data['meshAddress'] as String?,
        );
      }).toList();
    });
  }

  Future<void> sendMessage(Message message) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    await firestore.collection('messages').doc(message.id).set({
      'senderId': message.senderId,
      'recipientId': message.recipientId,
      'conversationId': message.conversationId,
      'text': message.text,
      'timestamp': FieldValue.serverTimestamp(),
      'source': message.source.name,
      'senderMeshId': message.senderMeshId,
    });
  }

  Stream<List<Message>> getMessages(String otherUserId) {
    final firestore = _firestoreOrNull;
    final currentUserId = _authOrNull?.currentUser?.uid;

    if (firestore == null || currentUserId == null) {
      return Stream.value(const <Message>[]);
    }

    final conversationId = buildConversationId(currentUserId, otherUserId);

    return firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final sourceName =
            data['source'] as String? ?? MessageSource.internet.name;

        return Message(
          id: doc.id,
          senderId: data['senderId'] as String,
          recipientId: data['recipientId'] as String,
          conversationId: data['conversationId'] as String? ?? conversationId,
          text: data['text'] as String,
          timestamp:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          source: sourceName == MessageSource.ble.name
              ? MessageSource.ble
              : MessageSource.internet,
          isMe: data['senderId'] == currentUserId,
          senderMeshId: data['senderMeshId'] as String?,
        );
      }).toList();
    });
  }
}

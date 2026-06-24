import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Contact>> getContacts() {
    final currentUserId = _auth.currentUser?.uid;
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) {
        final data = doc.data();
        return Contact(
          id: doc.id,
          name: data['name'] ?? 'Unknown',
          meshAddress: data['meshAddress'],
        );
      }).toList();
    });
  }

  Future<void> sendMessage(Message message) async {
    await _firestore.collection('messages').add({
      'senderId': message.senderId,
      'recipientId': message.recipientId,
      'text': message.text, // This should be the encrypted text
      'timestamp': FieldValue.serverTimestamp(),
      'source': 'internet',
    });
  }

  Stream<List<Message>> getMessages(String otherUserId) {
    final currentUserId = _auth.currentUser?.uid ?? 'me';
    return _firestore
        .collection('messages')
        .where('senderId', whereIn: [currentUserId, otherUserId])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        return (data['senderId'] == currentUserId && data['recipientId'] == otherUserId) ||
               (data['senderId'] == otherUserId && data['recipientId'] == currentUserId);
      }).map((doc) {
        final data = doc.data();
        return Message(
          id: doc.id,
          senderId: data['senderId'],
          recipientId: data['recipientId'],
          text: data['text'],
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          source: MessageSource.internet,
          isMe: data['senderId'] == currentUserId,
        );
      }).toList();
    });
  }
}

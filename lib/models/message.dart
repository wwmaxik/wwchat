class Contact {
  final String id;
  final String name;
  final String? meshAddress; // Unique address in BLE Mesh

  Contact({
    required this.id,
    required this.name,
    this.meshAddress,
  });
}

enum MessageSource { internet, ble }

class Message {
  final String id;
  final String senderId;
  final String recipientId;
  final String text;
  final DateTime timestamp;
  final MessageSource source;
  final bool isMe;

  Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.timestamp,
    required this.source,
    required this.isMe,
  });
}

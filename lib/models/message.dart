import 'dart:convert';

class Contact {
  final String id;
  final String name;
  final String? meshAddress;

  Contact({
    required this.id,
    required this.name,
    this.meshAddress,
  });
}

enum MessageSource { internet, ble }

String buildConversationId(String firstUserId, String secondUserId) {
  final sorted = [firstUserId, secondUserId]..sort();
  return sorted.join('__');
}

class Message {
  final String id;
  final String senderId;
  final String recipientId;
  final String conversationId;
  final String text;
  final DateTime timestamp;
  final MessageSource source;
  final bool isMe;
  final String? senderMeshId;

  Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.conversationId,
    required this.text,
    required this.timestamp,
    required this.source,
    required this.isMe,
    this.senderMeshId,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? conversationId,
    String? text,
    DateTime? timestamp,
    MessageSource? source,
    bool? isMe,
    String? senderMeshId,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      conversationId: conversationId ?? this.conversationId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      isMe: isMe ?? this.isMe,
      senderMeshId: senderMeshId ?? this.senderMeshId,
    );
  }
}

class MeshMessagePacket {
  final String id;
  final String senderUserId;
  final String senderMeshId;
  final String recipientUserId;
  final String conversationId;
  final String encryptedText;
  final int hopCount;
  final DateTime sentAt;

  MeshMessagePacket({
    required this.id,
    required this.senderUserId,
    required this.senderMeshId,
    required this.recipientUserId,
    required this.conversationId,
    required this.encryptedText,
    required this.hopCount,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderUserId': senderUserId,
      'senderMeshId': senderMeshId,
      'recipientUserId': recipientUserId,
      'conversationId': conversationId,
      'encryptedText': encryptedText,
      'hopCount': hopCount,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory MeshMessagePacket.fromJson(Map<String, dynamic> json) {
    return MeshMessagePacket(
      id: json['id'] as String,
      senderUserId: json['senderUserId'] as String,
      senderMeshId: json['senderMeshId'] as String? ?? 'unknown-device',
      recipientUserId: json['recipientUserId'] as String,
      conversationId: json['conversationId'] as String,
      encryptedText: json['encryptedText'] as String,
      hopCount: json['hopCount'] as int? ?? 0,
      sentAt:
          DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  factory MeshMessagePacket.decode(String raw) {
    return MeshMessagePacket.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

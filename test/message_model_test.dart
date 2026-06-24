import 'package:flutter_test/flutter_test.dart';

import 'package:ble_mesh_messenger/models/message.dart';

void main() {
  test('buildConversationId is stable regardless of argument order', () {
    expect(buildConversationId('alice', 'bob'), buildConversationId('bob', 'alice'));
  });

  test('mesh packet encode and decode preserves important fields', () {
    final packet = MeshMessagePacket(
      id: 'msg-1',
      senderUserId: 'alice',
      senderMeshId: 'device-a',
      recipientUserId: 'bob',
      conversationId: buildConversationId('alice', 'bob'),
      encryptedText: 'ciphertext',
      hopCount: 1,
      sentAt: DateTime.parse('2026-06-24T12:00:00.000Z'),
    );

    final decoded = MeshMessagePacket.decode(packet.encode());

    expect(decoded.id, packet.id);
    expect(decoded.senderUserId, packet.senderUserId);
    expect(decoded.recipientUserId, packet.recipientUserId);
    expect(decoded.conversationId, packet.conversationId);
    expect(decoded.encryptedText, packet.encryptedText);
    expect(decoded.hopCount, packet.hopCount);
  });
}

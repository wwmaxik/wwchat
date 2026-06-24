import 'package:flutter_test/flutter_test.dart';

import 'package:ble_mesh_messenger/services/encryption_service.dart';

void main() {
  test('conversation encryption roundtrip returns original plaintext',
      () async {
    final service = EncryptionService();
    final key = await service.deriveConversationKey('alice__bob');
    final encrypted = await service.encrypt('hello mesh world', key);
    final decrypted = await service.decrypt(encrypted, key);

    expect(decrypted, 'hello mesh world');
  });

  test('different conversation ids derive different ciphertexts', () async {
    final service = EncryptionService();
    final keyA = await service.deriveConversationKey('alice__bob');
    final keyB = await service.deriveConversationKey('alice__charlie');

    final encrypted = await service.encrypt('same text', keyA);
    final decryptedWithWrongKey = await service.decrypt(encrypted, keyB);

    expect(decryptedWithWrongKey, '[Decryption Error]');
  });
}

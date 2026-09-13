import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexus_ai/core/vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('vault ciphertext survives lock and password unlock', () async {
    final v = Vault();
    await v.create('a long test password');
    await v.write('key', 'test-secret-not-real');
    final encrypted = await v.storage.read(key: 'vault');
    expect(encrypted, isNot(contains('test-secret-not-real')));
    v.lock();
    expect(() => v.read('key'), throwsStateError);
    await v.unlock('a long test password');
    expect(v.read('key'), 'test-secret-not-real');
    expect(v.mask('key'), '••••••••real');
  });
  test('wrong password cannot decrypt; reset removes credentials', () async {
    final v = Vault();
    await v.create('a long test password');
    await v.write('key', 'fixture');
    v.lock();
    await expectLater(v.unlock('wrong password'), throwsStateError);
    expect(v.open, false);
    await v.reset();
    expect(await v.exists(), false);
  });
}

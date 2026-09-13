import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Vault {
  final storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  final biometric = const FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      storageNamespace: 'nexus_biometric',
      enforceBiometrics: true,
      resetOnError: false,
      biometricType: AndroidBiometricType.strongBiometricOnly,
      biometricPromptNegativeButton: 'Cancel',
    ),
  );
  final cipher = AesGcm.with256bits();
  SecretKey? key;
  Map<String, String> values = {};
  Future<void> pending = Future.value();
  bool get open => key != null;
  Future<bool> exists() => storage.containsKey(key: 'vault');
  Future<SecretKey> derive(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 310000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  Future<void> create(String password) async {
    if (await exists()) throw StateError('Vault already exists');
    if (password.length < 12) {
      throw const FormatException('Use at least 12 characters');
    }
    final salt = cipher.newNonce();
    key = await derive(password, salt);
    values = {};
    await storage.write(key: 'salt', value: base64Encode(salt));
    await save();
  }

  Future<void> decrypt(SecretKey k) async {
    final b = base64Decode((await storage.read(key: 'vault'))!);
    final text = await cipher.decrypt(
      SecretBox.fromConcatenation(b, nonceLength: 12, macLength: 16),
      secretKey: k,
    );
    values = Map<String, String>.from(jsonDecode(utf8.decode(text)));
    key = k;
  }

  Future<void> unlock(String password) async {
    final until = int.tryParse(await storage.read(key: 'until') ?? '0') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < until) {
      throw StateError('Too many attempts. Wait before retrying.');
    }
    try {
      await decrypt(
        await derive(
          password,
          base64Decode((await storage.read(key: 'salt'))!),
        ),
      );
    } catch (_) {
      final n =
          (int.tryParse(await storage.read(key: 'failures') ?? '0') ?? 0) + 1;
      await storage.write(key: 'failures', value: '$n');
      if (n >= 5) {
        await storage.write(
          key: 'until',
          value:
              '${DateTime.now().millisecondsSinceEpoch + 30000 * (n - 4).clamp(1, 20)}',
        );
      }
      throw StateError('Incorrect master password');
    }
    await storage.delete(key: 'failures');
    await storage.delete(key: 'until');
  }

  String? read(String name) {
    if (!open) throw StateError('Unlock your API vault in Settings');
    return values[name];
  }

  Future<void> write(String name, String? value) async {
    if (!open) throw StateError('Vault locked');
    if (value == null) {
      values.remove(name);
    } else {
      values[name] = value;
    }
    await save();
  }

  Future<void> save() {
    final k = key!;
    final snapshot = utf8.encode(jsonEncode(values));
    pending = pending.catchError((_) {}).then((_) async {
      final b = await cipher.encrypt(snapshot, secretKey: k);
      await storage.write(key: 'vault', value: base64Encode(b.concatenation()));
    });
    return pending;
  }

  Future<void> enableBiometric() async {
    if (!open) throw StateError('Unlock first');
    await biometric.write(
      key: 'key',
      value: base64Encode(await key!.extractBytes()),
    );
  }

  Future<void> unlockBiometric() async {
    final b = await biometric.read(key: 'key');
    if (b == null) {
      throw StateError('Enable biometrics with your password first');
    }
    await decrypt(SecretKey(base64Decode(b)));
  }

  void lock() {
    key = null;
    values.clear();
  }

  Future<void> reset() async {
    await pending;
    lock();
    await storage.deleteAll();
    await biometric.deleteAll();
  }

  String mask(String name) {
    final v = read(name);
    return v == null
        ? 'Not configured'
        : '••••••••${v.length > 4 ? v.substring(v.length - 4) : ''}';
  }
}

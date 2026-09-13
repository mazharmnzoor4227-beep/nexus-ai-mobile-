import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai/core/files.dart';
import 'package:nexus_ai/core/gateway.dart';

void main() {
  test('ZIP paths reject traversal and drive names', () {
    for (final s in [
      '../x',
      'a/../../x',
      '/etc/passwd',
      'C:\\x',
      'a/../b',
      'a\u0000b',
    ]) {
      expect(() => safePath(s), throwsFormatException);
    }
    expect(safePath('lib/main.dart'), 'lib/main.dart');
  });
  test('ZIP roundtrip preserves binary bytes', () {
    final input = {
      'main.dart': Uint8List.fromList(utf8.encode('void main() {}')),
      'asset.bin': Uint8List.fromList([0, 1, 255]),
    };
    final result = unpack(pack(input));
    expect(result.keys, input.keys);
    expect(result['asset.bin'], input['asset.bin']);
  });
  test('ZIP slip archive rejected before expansion', () {
    final a = Archive()..addFile(ArchiveFile('../outside', 1, [1]));
    expect(
      () => unpack(Uint8List.fromList(ZipEncoder().encode(a))),
      throwsFormatException,
    );
  });
  test('high ratio compressed bomb rejected', () {
    final a = Archive()
      ..addFile(
        ArchiveFile('bomb.txt', 2 * 1024 * 1024, Uint8List(2 * 1024 * 1024)),
      );
    expect(
      () => unpack(Uint8List.fromList(ZipEncoder().encode(a))),
      throwsFormatException,
    );
  });
  test('malformed archive rejected', () {
    expect(() => unpack(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });
  test('source retrieval excludes keys and caches', () {
    for (final p in [
      '.env',
      'nested/.env.local',
      'private.pem',
      'build/a.dart',
      'node_modules/a.js',
    ]) {
      expect(sourcePath(p), false);
    }
    expect(sourcePath('lib/main.dart'), true);
  });
  test(
    'endpoint cannot contain credentials, redirects or local desktop address',
    () {
      for (final u in [
        'http://gateway.test',
        'https://user:secret@host.test',
        'https://localhost/v1',
        'https://host.test/v1?key=x',
      ]) {
        expect(() => endpoint(u), throwsA(isA<ApiError>()));
      }
      expect(endpoint('https://gateway.test/v1').host, 'gateway.test');
      for (final r in ['//evil', '/../x', 'https://evil', '/x\\y']) {
        expect(() => routePath(r), throwsA(isA<ApiError>()));
      }
    },
  );
  test('download destinations block private and metadata addresses', () {
    for (final a in [
      '127.0.0.1',
      '10.0.0.1',
      '169.254.169.254',
      '172.16.0.1',
      '192.168.1.1',
      '100.64.0.1',
      '::1',
      'fe80::1',
      '::ffff:127.0.0.1',
    ]) {
      expect(publicAddress(InternetAddress(a)), false, reason: a);
    }
    expect(publicAddress(InternetAddress('8.8.8.8')), true);
  });
}

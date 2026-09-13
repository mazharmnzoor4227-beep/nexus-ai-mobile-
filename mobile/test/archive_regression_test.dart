import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai/core/files.dart';

void main() {
  test('forged decompressed size cannot bypass output bound', () {
    final b = pack({'a.txt': Uint8List.fromList(List.filled(100000, 65))});
    final d = ByteData.sublistView(b);
    final end = b.length - 22;
    final dir = d.getUint32(end + 16, Endian.little);
    d.setUint32(dir + 24, 1, Endian.little);
    expect(() => unpack(b), throwsFormatException);
  });
  test('CRC mismatch rejects corrupt bytes', () {
    final b = pack({
      'a.txt': Uint8List.fromList([1, 2, 3]),
    });
    final d = ByteData.sublistView(b);
    final dir = d.getUint32(b.length - 22 + 16, Endian.little);
    d.setUint32(dir + 16, 0, Endian.little);
    expect(() => unpack(b), throwsFormatException);
  });
}

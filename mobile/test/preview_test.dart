import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai/core/preview.dart';

void main() {
  test('static preview inlines local assets and excludes external scripts', () {
    Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));
    final result = bundleHtml('index.html', {
      'index.html': b(
        '<link rel="stylesheet" href="style.css"><script src="app.js"></script><script src="https://outside.test/x.js"></script>',
      ),
      'style.css': b('body{color:red}'),
      'app.js': b('document.title="Hi";'),
    });
    expect(result, contains('<style>body{color:red}</style>'));
    expect(result, contains('document.title="Hi";'));
    expect(result, isNot(contains('https://outside.test')));
  });
}

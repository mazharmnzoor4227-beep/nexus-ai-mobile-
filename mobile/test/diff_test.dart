import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai/core/diff.dart';

void main() {
  test('unified patch accurately represents empty and unterminated files', () {
    expect(
      unifiedDiff('x.txt', '', 'hello\n'),
      '--- a/x.txt\n+++ b/x.txt\n@@ -0,0 +1,1 @@\n+hello\n',
    );
    expect(
      unifiedDiff('x.txt', 'old\n', 'new'),
      '--- a/x.txt\n+++ b/x.txt\n@@ -1,1 +1,1 @@\n-old\n+new\n\\ No newline at end of file\n',
    );
    expect(unifiedDiff('x.txt', 'same', 'same'), '');
  });
}

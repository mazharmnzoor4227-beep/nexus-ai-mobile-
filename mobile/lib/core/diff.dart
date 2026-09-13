/// A valid whole-file unified hunk. Explicit EOF markers preserve final-newline
/// changes and empty files; bounded source files keep patch memory predictable.
String unifiedDiff(String path, String before, String after) {
  if (before == after) return '';
  List<String> lines(String s) {
    if (s.isEmpty) return [];
    final result = s.split('\n');
    if (s.endsWith('\n')) result.removeLast();
    return result;
  }

  final a = lines(before), b = lines(after);
  final out = StringBuffer(
    '--- a/$path\n+++ b/$path\n@@ -${a.isEmpty ? 0 : 1},${a.length} +${b.isEmpty ? 0 : 1},${b.length} @@\n',
  );
  void emit(List<String> values, String prefix, bool newline) {
    for (var i = 0; i < values.length; i++) {
      out.writeln('$prefix${values[i]}');
      if (i == values.length - 1 && !newline) {
        out.writeln(r'\ No newline at end of file');
      }
    }
  }

  emit(a, '-', before.endsWith('\n'));
  emit(b, '+', after.endsWith('\n'));
  return out.toString();
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nexus_ai/core/store.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Store s;
  setUp(() async {
    s = Store();
    await s.init(path: inMemoryDatabasePath);
  });
  tearDown(() async {
    await s.db.close();
  });
  test('chat branch preserves ordered messages without sharing ids', () async {
    final c = await s.add('chat', {'title': 'Code'});
    final a = await s.add('message', {
      'role': 'user',
      'text': 'Hi',
    }, parent: c['id']);
    await s.add('message', {
      'role': 'assistant',
      'text': 'Hello',
    }, parent: c['id']);
    final copy = await s.branch(c, through: a['id']);
    final messages = await s.list('message', parent: copy['id']);
    expect(messages.length, 1);
    expect(messages.first['text'], 'Hi');
    expect(messages.first['id'], isNot(a['id']));
  });
  test(
    'backup excludes connection config and restores metadata safely',
    () async {
      await s.set('models', 'secret-not-for-backup');
      await s.set('draft', 'draft text');
      await s.add('file', {'path': '/private/location', 'name': 'test.txt'});
      final b = await s.backup();
      expect(b, isNot(contains('secret-not-for-backup')));
      final records = (jsonDecode(b) as Map)['records'] as List;
      for (final r in records) {
        r['id'] = 'copy-${r['id']}';
      }
      await s.restore(jsonEncode({'version': 1, 'records': records}));
      final f = (await s.list('file')).last;
      expect(f['path'], '');
    },
  );
  test('deleting chat removes its messages atomically', () async {
    final c = await s.add('chat', {'title': 'One'});
    await s.add('message', {'text': 'Hello'}, parent: c['id']);
    await s.remove(c['id']);
    expect(await s.get(c['id']), null);
    expect(await s.list('message'), isEmpty);
  });
  test('invalid backup rolls back all entries', () async {
    expect(
      () => s.restore(
        jsonEncode({
          'version': 1,
          'records': [
            {'id': 'x', 'kind': 'chat', 'created': 1},
            {'id': 'bad'},
          ],
        }),
      ),
      throwsFormatException,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await s.get('x'), null);
  });
}

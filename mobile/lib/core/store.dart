import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;
const uuid = Uuid();

class Store {
  late Database db;
  Future<void> init({String? path}) async {
    db = await openDatabase(
      path ?? '${await getDatabasesPath()}/nexus.db',
      version: 1,
      onCreate: (d, v) async {
        await d.execute(
          'CREATE TABLE records(id TEXT PRIMARY KEY, kind TEXT NOT NULL, parent TEXT, created INTEGER NOT NULL, body TEXT NOT NULL)',
        );
        await d.execute('CREATE INDEX kind_created ON records(kind,created)');
        await d.execute(
          'CREATE INDEX parent_created ON records(parent,created)',
        );
      },
    );
    for (final r in await list('message')) {
      if (r['status'] == 'streaming') {
        r['status'] = 'interrupted';
        await put(r);
      }
    }
  }

  Future<Json> add(String kind, Json body, {String? parent}) async {
    final r = <String, dynamic>{
      ...body,
      'id': uuid.v4(),
      'kind': kind,
      'parent': parent,
      'created': DateTime.now().millisecondsSinceEpoch,
    };
    await put(r);
    return r;
  }

  Future<void> put(Json r) async {
    await db.insert('records', {
      'id': r['id'],
      'kind': r['kind'],
      'parent': r['parent'],
      'created': r['created'],
      'body': jsonEncode(r),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Json?> get(String id) async {
    final r = await db.query('records', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : jsonDecode(r.first['body'] as String) as Json;
  }

  Future<List<Json>> list(String kind, {String? parent}) async {
    final r = await db.query(
      'records',
      where: parent == null ? 'kind=?' : 'kind=? AND parent=?',
      whereArgs: parent == null ? [kind] : [kind, parent],
      orderBy: 'created,rowid',
    );
    return r.map((e) => jsonDecode(e['body'] as String) as Json).toList();
  }

  Future<void> remove(String id) async {
    await db.transaction((t) async {
      await t.delete(
        'records',
        where: 'parent=? AND kind=?',
        whereArgs: [id, 'message'],
      );
      await t.delete('records', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<String?> setting(String key) async =>
      (await get(key))?['value'] as String?;
  Future<void> set(String key, String value) =>
      put({'id': key, 'kind': 'setting', 'created': 0, 'value': value});
  Future<String> backup() async {
    final r = await db.query('records');
    return jsonEncode({
      'version': 1,
      'records': r
          .map((v) => jsonDecode(v['body'] as String) as Json)
          .where(
            (r) =>
                r['kind'] != 'setting' ||
                ['draft', 'mode', 'language'].contains(r['id']),
          )
          .toList(),
    });
  }

  Future<void> restore(String source) async {
    if (source.length > 50 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 50 MB');
    }
    final b = jsonDecode(source) as Json;
    if (b['version'] != 1 ||
        b['records'] is! List ||
        (b['records'] as List).length > 100000) {
      throw const FormatException('Invalid backup');
    }
    await db.transaction((t) async {
      for (final value in b['records']) {
        final r = Map<String, dynamic>.from(value as Map);
        if (![
              'chat',
              'message',
              'project',
              'file',
              'job',
              'setting',
              'usage',
            ].contains(r['kind']) ||
            r['id'] is! String ||
            r['created'] is! int) {
          throw const FormatException('Invalid record');
        }
        if (r['kind'] == 'setting' &&
            !['draft', 'mode', 'language'].contains(r['id'])) {
          continue;
        }
        if (r['kind'] == 'file') r['path'] = '';
        if (r['kind'] == 'job') r['status'] = 'interrupted';
        await t.insert('records', {
          'id': r['id'],
          'kind': r['kind'],
          'parent': r['parent'],
          'created': r['created'],
          'body': jsonEncode(r),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<Json> branch(Json chat, {String? through}) async {
    final copy = await add('chat', {
      'title': '${chat['title']} · branch',
      'archived': false,
      'pinned': false,
    }, parent: chat['parent']);
    for (final m in await list('message', parent: chat['id'])) {
      await add('message', m, parent: copy['id']);
      if (m['id'] == through) break;
    }
    return copy;
  }

  Future<String> markdown(String chat) async => (await list(
    'message',
    parent: chat,
  )).map((m) => '## ${m['role']}\n\n${m['text']}\n').join('\n');
}

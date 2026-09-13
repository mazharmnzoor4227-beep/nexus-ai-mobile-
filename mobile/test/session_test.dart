import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nexus_ai/core/session.dart';
import 'package:nexus_ai/core/store.dart';
import 'package:nexus_ai/core/files.dart';
import 'package:nexus_ai/core/gateway.dart';
import 'gateway_test.dart' show TestVault, Adapter;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test('streamed chat and generated file survive database reopening', () async {
    final dir = await Directory.systemTemp.createTemp('nexus-session-test');
    final path = '${dir.path}/db.sqlite';
    final store = Store();
    await store.init(path: path);
    final files = Files(store)..root = Directory('${dir.path}/workspace');
    await files.root.create();
    final vault = TestVault();
    final gateway = Gateway(
      vault,
      store,
      client: Dio()
        ..httpClientAdapter = Adapter(
          'data: {"choices":[{"delta":{"content":"Created\\n```html filename=index.html\\n<h1>Hello</h1>\\n```"}}]}\n\ndata: [DONE]\n\n',
        ),
    );
    gateway.models = [
      {
        'id': 'code',
        'capabilities': ['chat', 'coding'],
      },
    ];
    final session = Session(store, vault, gateway, files);
    await session.send('Create a website');
    expect(session.error, '');
    expect(session.messages.length, 2);
    expect(session.messages.last['status'], 'complete');
    final artifacts = await store.list('file');
    expect(artifacts.length, 1);
    expect(
      await files.local(artifacts.single).readAsString(),
      '<h1>Hello</h1>\n',
    );
    final id = session.chat!['id'];
    await store.db.close();
    final reopened = Store();
    await reopened.init(path: path);
    expect(
      (await reopened.list('message', parent: id)).last['text'],
      contains('<h1>Hello</h1>'),
    );
    await reopened.db.close();
    await dir.delete(recursive: true);
    session.dispose();
  });
  test('restart retains partial stream as interrupted', () async {
    final dir = await Directory.systemTemp.createTemp('nexus-restart-test');
    final path = '${dir.path}/db.sqlite';
    final s = Store();
    await s.init(path: path);
    final c = await s.add('chat', {'title': 'Test'});
    await s.add('message', {
      'role': 'assistant',
      'text': 'partial result',
      'status': 'streaming',
    }, parent: c['id']);
    await s.db.close();
    await s.init(path: path);
    final m = (await s.list('message', parent: c['id'])).single;
    expect(m['text'], 'partial result');
    expect(m['status'], 'interrupted');
    await s.db.close();
    await dir.delete(recursive: true);
  });
}

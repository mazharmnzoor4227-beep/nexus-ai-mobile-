import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai/core/gateway.dart';
import 'package:nexus_ai/core/store.dart';
import 'package:nexus_ai/core/vault.dart';

class TestVault extends Vault {
  @override
  bool get open => true;
  @override
  String? read(String name) => switch (name) {
    'endpoint' => 'https://gateway.test/v1',
    'key' => 'fixture-not-real',
    _ => null,
  };
}

class Adapter implements HttpClientAdapter {
  final String body;
  final int status;
  RequestOptions? request;
  Adapter(this.body, {this.status = 200});
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody(
      Stream.fromIterable(
        utf8.encode(body).map((b) => Uint8List.fromList([b])),
      ),
      status,
      headers: {
        'content-type': ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('SSE handles Unicode fragmented bytes, CRLF and heartbeats', () async {
    final a = Adapter(
      ': heartbeat\r\n\r\ndata: {"choices":[{"delta":{"content":"سلام"}}]}\r\n\r\ndata: {"choices":[{"delta":{"content":" world"}}]}\r\n\r\ndata: [DONE]\r\n\r\n',
    );
    final g = Gateway(
      TestVault(),
      Store(),
      client: Dio()..httpClientAdapter = a,
    );
    expect(
      await g
          .stream(
            [
              {'role': 'user', 'content': 'Hi'},
            ],
            {'id': 'fast'},
            'Fast',
            CancelToken(),
          )
          .join(),
      'سلام world',
    );
    expect(a.request!.headers['Authorization'], 'Bearer fixture-not-real');
    expect(g.latency['fast'], isNotNull);
  });
  test('Fast routing observes latency and circuit breaker', () {
    final g = Gateway(TestVault(), Store());
    g.models = [
      {'id': 'slow', 'latency_ms': 900},
      {'id': 'fast', 'latency_ms': 100},
    ];
    expect(g.routes('Fast', 'Hi').first['id'], 'fast');
    g.circuits['fast'] = DateTime.now().add(const Duration(minutes: 1));
    expect(g.routes('Fast', 'Hi').first['id'], 'slow');
  });
  test('Coding prefers capability and quality', () {
    final g = Gateway(TestVault(), Store());
    g.models = [
      {'id': 'fast', 'latency_ms': 1},
      {
        'id': 'code',
        'capabilities': ['coding'],
        'coding_score': 90,
      },
    ];
    expect(g.routes('Auto', 'debug my code').first['id'], 'code');
  });
  test('Unconfirmed vision fails instead of sending to text model', () {
    final g = Gateway(TestVault(), Store());
    g.models = [
      {'id': 'text'},
    ];
    expect(
      () => g.routes('Vision', 'describe', vision: true),
      throwsA(isA<ApiError>()),
    );
  });
  test('401 is actionable and never retryable', () {
    final g = Gateway(TestVault(), Store());
    final r = RequestOptions();
    final e = g.error(
      DioException(
        requestOptions: r,
        response: Response(requestOptions: r, statusCode: 401),
      ),
    );
    expect(e.retry, false);
    expect(e.message, contains('Invalid API key'));
  });
  test('provider 500 can fall back', () {
    final g = Gateway(TestVault(), Store());
    final r = RequestOptions();
    expect(
      g
          .error(
            DioException(
              requestOptions: r,
              response: Response(requestOptions: r, statusCode: 500),
            ),
          )
          .retry,
      true,
    );
  });
}

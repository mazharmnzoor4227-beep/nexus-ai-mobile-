import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'store.dart';
import 'vault.dart';

class ApiError implements Exception {
  final String message;
  final bool retry;
  const ApiError(this.message, {this.retry = false});
  @override
  String toString() => message;
}

Uri endpoint(String s) {
  final u = Uri.tryParse(s);
  if (u == null ||
      u.scheme != 'https' ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty ||
      u.hasQuery ||
      u.hasFragment ||
      ['localhost', '127.0.0.1', '::1'].contains(u.host)) {
    throw const ApiError(
      'A reachable HTTPS gateway must be configured by the developer.',
    );
  }
  return u;
}

String routePath(String p) {
  if (!p.startsWith('/') ||
      p.startsWith('//') ||
      p.contains('..') ||
      p.contains('\\') ||
      p.contains('://')) {
    throw const ApiError('Invalid capability route');
  }
  return p;
}

bool publicAddress(InternetAddress a) {
  final b = a.rawAddress;
  if (a.isLoopback || a.isLinkLocal || a.isMulticast) return false;
  if (b.length == 16) return b[0] & 0xe0 == 0x20;
  if (b[0] == 0 || b[0] == 10 || b[0] == 127 || b[0] >= 224) return false;
  return !(b[0] == 100 && b[1] >= 64 && b[1] <= 127 ||
      b[0] == 169 && b[1] == 254 ||
      b[0] == 172 && b[1] >= 16 && b[1] <= 31 ||
      b[0] == 192 && (b[1] == 168 || b[1] == 0) ||
      b[0] == 198 && (b[1] == 18 || b[1] == 19));
}

Dio downloadClient() {
  final d = Dio(
    BaseOptions(
      followRedirects: false,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  d.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final c = HttpClient();
      c.connectionFactory = (uri, proxy, port) async {
        if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || proxy != null) {
          throw const SocketException('Unsafe destination');
        }
        final a = await InternetAddress.lookup(uri.host);
        if (a.isEmpty || a.any((v) => !publicAddress(v))) {
          throw const SocketException('Private destination blocked');
        }
        return Socket.startConnect(a.first, uri.port);
      };
      return c;
    },
  );
  return d;
}

class Gateway {
  static const builtIn = String.fromEnvironment('UNIFIED_GATEWAY_BASE_URL');
  final Vault vault;
  final Store store;
  final Dio client;
  List<Json> models = [];
  Json capabilities = {};
  final latency = <String, int>{};
  final circuits = <String, DateTime>{};
  Gateway(this.vault, this.store, {Dio? client})
    : client =
          client ??
          Dio(
            BaseOptions(
              followRedirects: false,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
  String get base {
    final b = vault.read('endpoint') ?? builtIn;
    endpoint(b);
    return b.replaceAll(RegExp(r'/+$'), '');
  }

  Options auth([String? kind]) {
    if (vault.read('disabled') == 'true') {
      throw const ApiError('Connection disabled');
    }
    final k =
        (kind == null ? null : vault.read('$kind.key')) ?? vault.read('key');
    if (k == null || k.isEmpty) {
      throw const ApiError('Add your Unified API Key in Settings.');
    }
    return Options(
      headers: {'Authorization': 'Bearer $k'},
      followRedirects: false,
    );
  }

  Future<void> cache() async {
    models = (jsonDecode(await store.setting('models') ?? '[]') as List)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    capabilities =
        jsonDecode(await store.setting('capabilities') ?? '{}') as Json;
  }

  Future<void> connect() async {
    try {
      final r = await client.get('$base/models', options: auth());
      final list = r.data['data'];
      if (list is! List || list.isEmpty) {
        throw const ApiError('Gateway returned no models');
      }
      models = list.map((v) => Map<String, dynamic>.from(v)).toList();
      capabilities = {};
      try {
        final c = await client.get(
          '$base/capabilities',
          options: auth().copyWith(receiveTimeout: const Duration(seconds: 4)),
        );
        if (c.data is Map) capabilities = Map<String, dynamic>.from(c.data);
      } on DioException catch (e) {
        if ([401, 403].contains(e.response?.statusCode)) rethrow;
      }
      capabilities.addAll(
        jsonDecode(vault.read('capabilities') ?? '{}') as Json,
      );
      final meta = jsonDecode(vault.read('model_metadata') ?? '{}') as Json;
      models = models
          .map(
            (m) => <String, dynamic>{
              ...m,
              ...Map<String, dynamic>.from(meta[m['id']] ?? {}),
            },
          )
          .toList();
      await store.set('models', jsonEncode(models));
      await store.set('capabilities', jsonEncode(capabilities));
    } on DioException catch (e) {
      throw error(e);
    }
  }

  Set<String> tags(Json m) {
    final c = m['capabilities'];
    if (c is List) return c.map((e) => e.toString()).toSet();
    if (c is Map) {
      return c.entries
          .where((e) => e.value == true)
          .map((e) => e.key.toString())
          .toSet();
    }
    return {'chat', if (m['supports_vision'] == true) 'vision'};
  }

  List<Json> routes(
    String mode,
    String prompt, {
    bool vision = false,
    String? selected,
  }) {
    var want = mode.toLowerCase();
    if (want == 'auto') {
      want = vision
          ? 'vision'
          : RegExp(
              r'\b(code|app|debug|program|refactor|website)\b',
              caseSensitive: false,
            ).hasMatch(prompt)
          ? 'coding'
          : RegExp(
              r'\b(reason|prove|solve|derive)\b',
              caseSensitive: false,
            ).hasMatch(prompt)
          ? 'reasoning'
          : 'fast';
    }
    final list = models
        .where(
          (m) =>
              (selected == null || selected == m['id']) &&
              (!vision || tags(m).contains('vision')) &&
              circuits[m['id']]?.isAfter(DateTime.now()) != true,
        )
        .toList();
    list.sort((a, b) {
      if (want != 'fast') {
        final rank =
            (tags(b).contains(want) ? 1 : 0) - (tags(a).contains(want) ? 1 : 0);
        if (rank != 0) return rank;
        final qa =
            (a['${want}_score'] as num?) ?? (a['context_length'] as num?) ?? 0;
        final qb =
            (b['${want}_score'] as num?) ?? (b['context_length'] as num?) ?? 0;
        if (qa != qb) return qb.compareTo(qa);
      }
      return (latency[a['id']] ?? (a['latency_ms'] as num?)?.toInt() ?? 999)
          .compareTo(
            latency[b['id']] ?? (b['latency_ms'] as num?)?.toInt() ?? 999,
          );
    });
    if (list.isEmpty) {
      throw ApiError(
        vision
            ? 'No confirmed vision model available. Refresh model capabilities.'
            : 'No healthy model available. Refresh the connection.',
      );
    }
    return list.take(selected == null ? 2 : 1).toList();
  }

  ApiError error(DioException e) {
    final s = e.response?.statusCode;
    return switch (s) {
      401 => const ApiError('Invalid API key. Replace it in Settings.'),
      403 => const ApiError('This key cannot access this service.'),
      404 => const ApiError('Endpoint or model unsupported.'),
      408 => const ApiError('Provider timeout.', retry: true),
      429 => const ApiError(
        'Rate limit or quota reached. Retry later.',
        retry: true,
      ),
      _ => ApiError(
        CancelToken.isCancel(e)
            ? 'Stopped.'
            : 'Network or provider unavailable. Check your connection.',
        retry: s == null || s >= 500,
      ),
    };
  }

  Stream<String> stream(
    List<Json> messages,
    Json model,
    String mode,
    CancelToken cancel,
  ) async* {
    var visible = false;
    final watch = Stopwatch()..start();
    final fast = ['Auto', 'Fast'].contains(mode);
    final seconds =
        int.tryParse(
          vault.read(fast ? 'fast_timeout' : 'deep_timeout') ?? '',
        ) ??
        (fast ? 8 : 20);
    final timer = Timer(Duration(seconds: seconds.clamp(3, 120)), () {
      if (!visible) cancel.cancel('first-token');
    });
    try {
      final r = await client.post<ResponseBody>(
        '$base/chat/completions',
        data: {
          'model': model['id'],
          'messages': messages,
          'stream': true,
          if (model['supports_usage_stream'] == true)
            'stream_options': {'include_usage': true},
        },
        options: auth().copyWith(responseType: ResponseType.stream),
        cancelToken: cancel,
      );
      final event = <String>[];
      await for (final line
          in r.data!.stream
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (event.isEmpty) continue;
          final text = event.join('\n');
          event.clear();
          if (text == '[DONE]') break;
          final obj = jsonDecode(text) as Json;
          if (obj['error'] != null) {
            throw const ApiError('Provider returned an error.', retry: true);
          }
          if (obj['usage'] is Map) {
            await store.add('usage', {
              'model': model['id'],
              ...Map<String, dynamic>.from(obj['usage']),
            });
          }
          final choices = obj['choices'];
          if (choices is! List || choices.isEmpty) continue;
          final content = choices.first['delta']?['content'];
          if (content is String && content.isNotEmpty) {
            if (!visible) {
              visible = true;
              timer.cancel();
              latency[model['id']] = watch.elapsedMilliseconds;
            }
            yield content;
          }
        } else if (line.startsWith('data:')) {
          event.add(line.substring(5).trimLeft());
        }
      }
      if (!visible) {
        throw const ApiError('Model returned no text.', retry: true);
      }
    } on DioException catch (e) {
      if (cancel.cancelError?.error == 'first-token') {
        throw const ApiError('First-token timeout.', retry: true);
      }
      throw error(e);
    } finally {
      timer.cancel();
    }
  }

  Future<Json> capability(
    String kind,
    Json body, {
    CancelToken? cancel,
    String? job,
    String? action,
  }) async {
    final spec = capabilities[kind];
    if (spec is! Map) throw const ApiError('Provider not configured');
    final b = vault.read('$kind.endpoint') ?? base;
    endpoint(b);
    final p = routePath(
      spec[action ?? (job == null ? 'path' : 'status_path')]?.toString() ?? '',
    ).replaceAll('{id}', Uri.encodeComponent(job ?? ''));
    try {
      final r = job != null && action == null
          ? await client.get('$b$p', options: auth(kind), cancelToken: cancel)
          : await client.post(
              '$b$p',
              data: {
                if (spec['model'] != null) 'model': spec['model'],
                ...body,
              },
              options: auth(kind),
              cancelToken: cancel,
            );
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw error(e);
    }
  }

  Future<String> transcribe(String path, CancelToken cancel) async {
    final spec = capabilities['stt'];
    if (spec is! Map) {
      throw const ApiError('Audio transcription provider not configured');
    }
    final b = vault.read('stt.endpoint') ?? base;
    endpoint(b);
    try {
      final r = await client.post(
        '$b${routePath(spec['path'])}',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(path),
          'response_format': 'verbose_json',
          if (spec['model'] != null) 'model': spec['model'],
        }),
        options: auth('stt'),
        cancelToken: cancel,
      );
      final seg = r.data['segments'];
      return seg is List
          ? seg
                .map((s) => '[${s['start']}s–${s['end']}s] ${s['text']}')
                .join('\n')
          : r.data['text'].toString();
    } on DioException catch (e) {
      throw error(e);
    }
  }
}

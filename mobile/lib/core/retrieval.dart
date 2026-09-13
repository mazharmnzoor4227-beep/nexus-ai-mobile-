import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'gateway.dart';
import 'store.dart';

/// Optional real embeddings, only when configured. Candidate count and batches
/// are bounded; lexical retrieval remains available on provider failure.
class Retrieval {
  final Gateway gateway;
  final Store store;
  Retrieval(this.gateway, this.store);
  Future<List<String>> rank(
    String id,
    String query,
    List<String> candidates, {
    CancelToken? cancel,
  }) async {
    if (candidates.isEmpty || gateway.capabilities['embeddings'] is! Map) {
      return candidates.take(6).toList();
    }
    final inputs = candidates.take(48).toList();
    final signature = jsonEncode({
      'spec': gateway.capabilities['embeddings'],
      'inputs': inputs,
    });
    final saved = await store.setting('embedding:$id');
    final cache = saved == null ? null : jsonDecode(saved) as Json;
    List<List<double>> vectors;
    if (cache?['signature'] == signature) {
      vectors = (cache!['vectors'] as List)
          .map((e) => (e as List).map((n) => (n as num).toDouble()).toList())
          .toList();
    } else {
      vectors = [];
      for (var at = 0; at < inputs.length; at += 16) {
        if (cancel?.isCancelled == true) throw cancel!.cancelError!;
        vectors.addAll(
          await embed(inputs.sublist(at, min(at + 16, inputs.length)), cancel),
        );
      }
      await store.set(
        'embedding:$id',
        jsonEncode({'signature': signature, 'vectors': vectors}),
      );
    }
    final q = (await embed([query], cancel)).single;
    final scores = <({String text, double score})>[];
    for (var i = 0; i < inputs.length; i++) {
      scores.add((text: inputs[i], score: cosine(q, vectors[i])));
    }
    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.take(6).map((e) => e.text).toList();
  }

  Future<List<List<double>>> embed(
    List<String> input,
    CancelToken? cancel,
  ) async {
    final r = await gateway.capability('embeddings', {
      'input': input,
    }, cancel: cancel);
    final data = r['data'];
    if (data is! List || data.length != input.length) {
      throw const ApiError('Invalid embedding response');
    }
    final sorted = data.map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    return sorted.map((e) {
      final values = (e['embedding'] as List)
          .map((n) => (n as num).toDouble())
          .toList();
      if (values.isEmpty ||
          values.length > 65536 ||
          values.any((n) => !n.isFinite)) {
        throw const ApiError('Invalid embedding values');
      }
      return values;
    }).toList();
  }
}

double cosine(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) {
    throw const ApiError('Embedding dimensions do not match');
  }
  double dot = 0, aa = 0, bb = 0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    aa += a[i] * a[i];
    bb += b[i] * b[i];
  }
  return aa == 0 || bb == 0 ? 0 : dot / sqrt(aa * bb);
}

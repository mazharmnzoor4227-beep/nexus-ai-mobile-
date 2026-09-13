import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;
import 'dart:io';
import 'package:archive/archive.dart' hide ZLibDecoder;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import 'store.dart';
import 'retrieval.dart';
import 'package:dio/dio.dart';

const native = MethodChannel('nexus/native');
String safePath(String s) {
  final parts = s.replaceAll('\\', '/').split('/');
  if (s.isEmpty ||
      s.startsWith('/') ||
      s.contains(':') ||
      s.contains('\u0000') ||
      parts.any((v) => v == '..' || v == '.')) {
    throw const FormatException('Unsafe archive path');
  }
  return parts.where((v) => v.isNotEmpty).join('/');
}

bool sourcePath(String s) {
  final parts = s.toLowerCase().split('/');
  if (parts.any(
    (v) =>
        [
          'node_modules',
          'build',
          'dist',
          '.git',
          '.dart_tool',
          '.gradle',
          'vendor',
          '__pycache__',
        ].contains(v) ||
        v == '.env' ||
        v.startsWith('.env.'),
  )) {
    return false;
  }
  return ![
    '.pem',
    '.key',
    '.jks',
    '.keystore',
    '.p12',
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.mp4',
    '.mp3',
    '.jar',
    '.so',
    '.ttf',
    '.woff',
    '.woff2',
    '.zip',
    '.apk',
    '.lock',
  ].contains(p.extension(s).toLowerCase());
}

void validateZip(Uint8List b) {
  if (b.length > 50 * 1024 * 1024 || b.length < 22) {
    throw const FormatException('Invalid or oversized ZIP');
  }
  final d = ByteData.sublistView(b);
  int end = -1;
  for (var i = b.length - 22; i >= (b.length - 65557).clamp(0, b.length); i--) {
    if (d.getUint32(i, Endian.little) == 0x06054b50) {
      end = i;
      break;
    }
  }
  if (end < 0) throw const FormatException('Missing ZIP directory');
  final n = d.getUint16(end + 10, Endian.little);
  final off = d.getUint32(end + 16, Endian.little);
  if (n > 2000 ||
      n == 65535 ||
      off >= end ||
      d.getUint16(end + 4, Endian.little) != 0) {
    throw const FormatException('Unsupported ZIP');
  }
  var at = off, total = 0;
  final seen = <String>{};
  for (var i = 0; i < n; i++) {
    if (at + 46 > end || d.getUint32(at, Endian.little) != 0x02014b50) {
      throw const FormatException('Invalid ZIP directory');
    }
    final flags = d.getUint16(at + 8, Endian.little),
        compressed = d.getUint32(at + 20, Endian.little),
        size = d.getUint32(at + 24, Endian.little),
        len = d.getUint16(at + 28, Endian.little),
        extra = d.getUint16(at + 30, Endian.little),
        comment = d.getUint16(at + 32, Endian.little),
        mode = d.getUint32(at + 38, Endian.little) >> 16;
    if (at + 46 + len + extra + comment > end) {
      throw const FormatException('Invalid ZIP entry');
    }
    final name = safePath(
      utf8.decode(b.sublist(at + 46, at + 46 + len), allowMalformed: true),
    );
    total += size;
    if (!seen.add(name) ||
        flags & 1 != 0 ||
        mode & 0xf000 == 0xa000 ||
        size > 10 * 1024 * 1024 ||
        total > 100 * 1024 * 1024 ||
        size > 1024 * 1024 && size / (compressed == 0 ? 1 : compressed) > 100) {
      throw const FormatException('Unsafe ZIP entry or excessive expansion');
    }
    at += 46 + len + extra + comment;
  }
}

class BoundedBytes implements Sink<List<int>> {
  final int limit;
  final bytes = BytesBuilder(copy: false);
  int length = 0;
  BoundedBytes(this.limit);
  @override
  void add(List<int> chunk) {
    length += chunk.length;
    if (length > limit) {
      throw const FormatException('ZIP expanded beyond declared size');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

Map<String, Uint8List> unpack(Uint8List bytes) {
  validateZip(bytes);
  final d = ByteData.sublistView(bytes);
  int end = -1;
  for (
    var i = bytes.length - 22;
    i >= (bytes.length - 65557).clamp(0, bytes.length);
    i--
  ) {
    if (d.getUint32(i, Endian.little) == 0x06054b50) {
      end = i;
      break;
    }
  }
  final n = d.getUint16(end + 10, Endian.little),
      directory = d.getUint32(end + 16, Endian.little);
  var at = directory;
  final result = <String, Uint8List>{};
  for (var i = 0; i < n; i++) {
    final compressed = d.getUint32(at + 20, Endian.little),
        size = d.getUint32(at + 24, Endian.little),
        len = d.getUint16(at + 28, Endian.little),
        extra = d.getUint16(at + 30, Endian.little),
        comment = d.getUint16(at + 32, Endian.little),
        offset = d.getUint32(at + 42, Endian.little),
        method = d.getUint16(at + 10, Endian.little),
        crc = d.getUint32(at + 16, Endian.little);
    final original = utf8.decode(
      bytes.sublist(at + 46, at + 46 + len),
      allowMalformed: true,
    );
    final name = safePath(original);
    if (offset + 30 > directory ||
        d.getUint32(offset, Endian.little) != 0x04034b50 ||
        d.getUint16(offset + 8, Endian.little) != method) {
      throw const FormatException('Invalid local ZIP header');
    }
    final localLength = d.getUint16(offset + 26, Endian.little),
        localExtra = d.getUint16(offset + 28, Endian.little),
        start = offset + 30 + localLength + localExtra;
    if (start > directory ||
        start + compressed > directory ||
        !listEquals(
          bytes.sublist(offset + 30, offset + 30 + localLength),
          bytes.sublist(at + 46, at + 46 + len),
        )) {
      throw const FormatException('ZIP header mismatch');
    }
    final source = Uint8List.sublistView(bytes, start, start + compressed);
    final sink = BoundedBytes(size);
    if (method == 0) {
      sink.add(source);
    } else if (method == 8) {
      final decoder = ZLibDecoder(raw: true).startChunkedConversion(sink);
      decoder.add(source);
      decoder.close();
    } else {
      throw const FormatException(
        'Only stored/deflated ZIP entries are supported',
      );
    }
    final expanded = sink.bytes.takeBytes();
    if (expanded.length != size || getCrc32(expanded) != crc) {
      throw const FormatException('ZIP size or CRC mismatch');
    }
    if (!original.endsWith('/') && !original.endsWith('\\')) {
      result[name] = expanded;
    }
    at += 46 + len + extra + comment;
  }
  return result;
}

Uint8List pack(Map<String, Uint8List> entries) {
  final a = Archive();
  for (final e in entries.entries) {
    a.addFile(ArchiveFile(safePath(e.key), e.value.length, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

String mime(String name) {
  return switch (p.extension(name).toLowerCase()) {
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.webp' => 'image/webp',
    '.gif' => 'image/gif',
    '.mp4' || '.m4v' => 'video/mp4',
    '.mov' => 'video/quicktime',
    '.webm' => 'video/webm',
    '.mp3' => 'audio/mpeg',
    '.wav' => 'audio/wav',
    '.m4a' => 'audio/mp4',
    '.pdf' => 'application/pdf',
    '.zip' => 'application/zip',
    '.docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.html' => 'text/html',
    _ => 'text/plain',
  };
}

class Files {
  final Store store;
  Retrieval? retrieval;
  late Directory root;
  Files(this.store);
  Future<void> init() async {
    root = Directory(
      '${(await getApplicationSupportDirectory()).path}/workspace',
    );
    await root.create(recursive: true);
  }

  File local(Json r) {
    final path = r['path'];
    if (path is! String ||
        path.isEmpty ||
        !p.isWithin(root.path, p.normalize(path))) {
      throw const FormatException('File unavailable. Import it again.');
    }
    return File(path);
  }

  Future<Json> save(
    String name,
    List<int> bytes, {
    String? parent,
    String? project,
    String category = 'artifact',
    String? message,
  }) async {
    name = safePath(name);
    if (bytes.length > 100 * 1024 * 1024) {
      throw const FormatException('File exceeds 100 MB');
    }
    final file = File('${root.path}/${uuid.v4()}/${p.basename(name)}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return store.add('file', {
      'name': name,
      'path': file.path,
      'size': bytes.length,
      'mime': mime(name),
      'project': project,
      'category': category,
      'message': message,
    }, parent: parent);
  }

  Future<Json> import(String path, {String? parent, String? project}) async {
    final f = File(path);
    if (await f.length() > 50 * 1024 * 1024) {
      throw const FormatException('Attachments must be under 50 MB');
    }
    final b = await f.readAsBytes();
    if (['.zip', '.docx'].contains(p.extension(path).toLowerCase())) {
      validateZip(b);
    }
    return save(
      p.basename(path),
      b,
      parent: parent,
      project: project,
      category: 'attachment',
    );
  }

  Future<Map<String, Uint8List>> archive(Json r) async =>
      compute(unpack, await local(r).readAsBytes());
  Future<String> context(Json r, String query, {CancelToken? cancel}) async {
    final type = r['mime'] as String;
    if (type == 'application/zip') {
      final entries = await archive(r);
      final tree = entries.keys.take(500).join('\n');
      final terms = query
          .toLowerCase()
          .split(RegExp(r'\W+'))
          .where((w) => w.length > 2)
          .toSet();
      final chunks = <({String text, int score})>[];
      for (final e in entries.entries.where((e) => sourcePath(e.key))) {
        if (e.value.length > 500000) continue;
        final text = utf8.decode(e.value, allowMalformed: true);
        if (text.contains('\u0000')) continue;
        for (var at = 0; at < text.length; at += 3000) {
          final piece = text.substring(at, (at + 3500).clamp(0, text.length));
          final score = terms.fold<int>(
            0,
            (s, w) =>
                s +
                (e.key.toLowerCase().contains(w) ? 10 : 0) +
                (piece.toLowerCase().contains(w) ? 1 : 0),
          );
          chunks.add((text: 'FILE ${e.key} OFFSET $at\n$piece', score: score));
        }
      }
      chunks.sort((a, b) => b.score.compareTo(a.score));
      var selected = chunks.take(6).map((e) => e.text).toList();
      if (retrieval != null) {
        try {
          selected = await retrieval!.rank(
            r['id'],
            query,
            chunks.map((e) => e.text).toList(),
            cancel: cancel,
          );
        } catch (_) {
          if (cancel?.isCancelled == true) rethrow;
        }
      }
      return 'PROJECT TREE\n$tree\nRETRIEVED SOURCE\n${selected.join('\n\n')}';
    }
    if (type.contains('wordprocessingml')) {
      final entries = await archive(r);
      final xml = entries['word/document.xml'];
      if (xml == null) return 'Document has no text';
      final text = XmlDocument.parse(
        utf8.decode(xml),
      ).findAllElements('w:t').map((e) => e.innerText).join(' ');
      return text.substring(0, text.length.clamp(0, 20000));
    }
    if (type == 'text/plain' || type == 'text/html') {
      final f = local(r);
      if (await f.length() > 1024 * 1024) {
        return 'Text is too large. Attach relevant source chunks.';
      }
      final s = await f.readAsString();
      return s.substring(0, s.length.clamp(0, 20000));
    }
    return '${r['name']} · $type';
  }

  Future<List<Json>> vision(Json r) async {
    final result = await native.invokeListMethod<dynamic>('vision', {
      'path': local(r).path,
      'mime': r['mime'],
    });
    return (result ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> export(Json r) async {
    await native.invokeMethod('export', {
      'path': local(r).path,
      'name': p.basename(r['name']),
      'mime': r['mime'],
    });
  }

  Future<void> share(Json r) async {
    await native.invokeMethod('share', {
      'path': local(r).path,
      'mime': r['mime'],
    });
  }

  Future<void> remove(Json r) async {
    final f = local(r);
    if (await f.exists()) await f.delete();
    await store.remove(r['id']);
  }

  Future<List<Json>> artifacts(
    String text, {
    String? parent,
    String? project,
    String? message,
  }) async {
    final result = <Json>[];
    for (final m in RegExp(
      r'```([\w+-]*)(?:\s+filename=([^\n]+))?\n([\s\S]*?)```',
    ).allMatches(text)) {
      final lang = m[1] ?? 'txt';
      const exts = {
        'javascript': 'js',
        'typescript': 'ts',
        'python': 'py',
        'kotlin': 'kt',
        'markdown': 'md',
        'bash': 'sh',
      };
      final name =
          m[2]?.trim() ??
          'artifact-${result.length + 1}.${exts[lang] ?? (lang.isEmpty ? 'txt' : lang)}';
      result.add(
        await save(
          name,
          utf8.encode(m[3]!),
          parent: parent,
          project: project,
          message: message,
        ),
      );
    }
    return result;
  }
}

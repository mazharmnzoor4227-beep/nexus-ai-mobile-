import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/gateway.dart';
import '../core/session.dart';
import 'common.dart';
import 'library.dart';

class Generation extends StatefulWidget {
  final Session session;
  final bool video;
  const Generation({super.key, required this.session, this.video = false});
  @override
  State<Generation> createState() => _GenerationState();
}

class _GenerationState extends State<Generation> {
  Session get s => widget.session;
  String get kind => widget.video ? 'video_generation' : 'image_generation';
  final prompt = TextEditingController(), style = TextEditingController();
  String ratio = '1:1', quality = 'standard', status = '';
  int count = 1, duration = 5;
  String? reference;
  bool busy = false;
  double? progress;
  Json? job;
  CancelToken? cancel;
  final downloads = downloadClient();
  @override
  void dispose() {
    cancel?.cancel('closed');
    downloads.close();
    prompt.dispose();
    style.dispose();
    super.dispose();
  }

  void update() {
    if (mounted) setState(() {});
  }

  Future<void> generate({Json? resume}) async {
    if (busy) return;
    busy = true;
    progress = null;
    status = 'Connecting';
    update();
    cancel = CancelToken();
    try {
      if (!s.vault.open) throw StateError('Unlock the API vault in Settings');
      if (s.gateway.capabilities[kind] is! Map) {
        throw const ApiError('Provider not configured');
      }
      Json response;
      if (resume != null) {
        job = resume;
        response = await s.gateway.capability(
          kind,
          {},
          job: job!['remote_id'],
          cancel: cancel,
        );
      } else {
        if (prompt.text.trim().isEmpty) {
          throw const FormatException('Enter a prompt');
        }
        final body = <String, dynamic>{
          'prompt': prompt.text,
          'aspect_ratio': ratio,
          'quality': quality,
          if (widget.video) 'duration': duration,
          if (!widget.video) 'n': count,
          if (style.text.isNotEmpty) 'style': style.text,
        };
        if (reference != null) {
          final file = File(reference!);
          if (await file.length() > 10 * 1024 * 1024) {
            throw const FormatException('Reference image exceeds 10 MB');
          }
          final bytes = await file.readAsBytes();
          if (bytes.length < 3 || bytes[0] != 255 || bytes[1] != 216) {
            throw const FormatException('Reference must be a JPEG');
          }
          body['image'] = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
        job = await s.store.add('job', {
          'type': kind,
          'prompt': prompt.text,
          'aspect_ratio': ratio,
          'quality': quality,
          'duration': duration,
          'n': count,
          'style': style.text,
          'status': 'queued',
        });
        response = await s.gateway.capability(kind, body, cancel: cancel);
        job!['remote_id'] = response['id'];
        await s.store.put(job!);
      }
      final deadline = DateTime.now().add(const Duration(minutes: 15));
      while (true) {
        if (cancel!.isCancelled) {
          throw cancel!.cancelError!;
        }
        status =
            response['status']?.toString() ??
            (response['data'] is List ? 'completed' : 'queued');
        job!['status'] = status;
        await s.store.put(job!);
        progress = response['progress'] is num
            ? (response['progress'] as num).toDouble().clamp(0, 100) / 100
            : null;
        update();
        if (['failed', 'cancelled', 'canceled'].contains(status)) {
          throw ApiError('Generation $status');
        }
        if (status == 'completed' ||
            status == 'succeeded' ||
            response['data'] is List) {
          break;
        }
        if (job!['remote_id'] == null) {
          throw const ApiError('Provider did not return a job ID or output');
        }
        if (DateTime.now().isAfter(deadline)) {
          throw const ApiError(
            'Still processing. Resume this job from history.',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 3));
        if (cancel!.isCancelled) {
          throw cancel!.cancelError!;
        }
        response = await s.gateway.capability(
          kind,
          {},
          job: job!['remote_id'],
          cancel: cancel,
        );
      }
      final outputs = response['data'] ?? response['outputs'];
      if (outputs is! List || outputs.isEmpty) {
        throw const ApiError('Provider returned no output files');
      }
      var i = 0;
      for (final output in outputs) {
        if (i >= 8) break;
        final item = Map<String, dynamic>.from(output);
        Uint8List bytes;
        if (item['b64_json'] is String) {
          final encoded = item['b64_json'] as String;
          if (encoded.length > 140 * 1024 * 1024) {
            throw const ApiError('Output exceeds download limit');
          }
          bytes = base64Decode(encoded);
        } else {
          final uri = Uri.tryParse(item['url']?.toString() ?? '');
          if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
            throw const ApiError('Unsafe output URL');
          }
          status = 'Downloading output ${i + 1}';
          update();
          final r = await downloads.get<ResponseBody>(
            uri.toString(),
            options: Options(responseType: ResponseType.stream),
            cancelToken: cancel,
          );
          final builder = BytesBuilder(copy: false);
          var total = 0;
          final expected = int.tryParse(
            r.headers.value('content-length') ?? '',
          );
          if (expected != null && expected > 100 * 1024 * 1024) {
            throw const ApiError('Output exceeds 100 MB');
          }
          await for (final chunk in r.data!.stream) {
            total += chunk.length;
            if (total > 100 * 1024 * 1024) {
              throw const ApiError('Output exceeds 100 MB');
            }
            builder.add(chunk);
            progress = expected == null ? null : total / expected;
            update();
          }
          bytes = builder.takeBytes();
        }
        String ext;
        if (widget.video) {
          if (bytes.length < 12 ||
              ascii.decode(bytes.sublist(4, 8), allowInvalid: true) != 'ftyp') {
            throw const ApiError('Expected MP4 video');
          }
          ext = 'mp4';
        } else if (bytes.length >= 8 &&
            bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78 &&
            bytes[3] == 71) {
          ext = 'png';
        } else if (bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255) {
          ext = 'jpg';
        } else {
          throw const ApiError('Expected PNG or JPEG image');
        }
        final f = await s.files.save(
          'nexus-${job!['id']}-${++i}.$ext',
          bytes,
          category: 'generation',
          parent: job!['id'],
        );
        job!['files'] = [...((job!['files'] as List?) ?? []), f['id']];
        await s.store.put(job!);
      }
      job!['status'] = 'completed';
      await s.store.put(job!);
      status = 'Completed';
      progress = 1;
    } catch (e) {
      status = e is DioException && CancelToken.isCancel(e)
          ? 'Interrupted. Resume from history if the provider has a job ID.'
          : e is ApiError || e is StateError || e is FormatException
          ? e.toString()
          : 'Generation failed. Check provider configuration.';
      if (job != null && job!['status'] != 'completed') {
        job!['status'] = job!['remote_id'] == null ? 'failed' : 'interrupted';
        job!['error'] = status;
        await s.store.put(job!);
      }
    } finally {
      busy = false;
      update();
    }
  }

  Future<void> stop() async {
    cancel?.cancel('user');
    final spec = s.gateway.capabilities[kind];
    if (job?['remote_id'] != null &&
        spec is Map &&
        spec['cancel_path'] != null) {
      await guard(context, () async {
        await s.gateway.capability(
          kind,
          {},
          job: job!['remote_id'],
          action: 'cancel_path',
        );
        job!['status'] = 'cancelled';
        await s.store.put(job!);
      });
    }
    update();
  }

  Widget choice(
    String label,
    List<String> values,
    String value,
    void Function(String) set,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: busy ? null : (v) => setState(() => set(v!)),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.video ? 'Create video' : 'Create image')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (s.gateway.capabilities[kind] is! Map)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Provider not configured. Connect a gateway with this capability or add a dedicated adapter in the API Vault.',
            ),
          ),
        TextField(
          controller: prompt,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Describe what to create',
          ),
        ),
        const SizedBox(height: 12),
        choice(
          'Aspect ratio',
          ['1:1', '16:9', '9:16', '4:3'],
          ratio,
          (v) => ratio = v,
        ),
        const SizedBox(height: 12),
        choice('Quality', ['standard', 'high'], quality, (v) => quality = v),
        const SizedBox(height: 12),
        if (widget.video) ...[
          choice(
            'Duration',
            ['5', '10', '15'],
            duration.toString(),
            (v) => duration = int.parse(v),
          ),
          TextButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final f = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg'],
                    );
                    if (mounted) setState(() => reference = f?.path);
                  },
            icon: const Icon(Icons.image_outlined),
            label: Text(
              reference == null
                  ? 'Add reference JPEG'
                  : 'Replace reference JPEG',
            ),
          ),
        ] else ...[
          choice(
            'Count',
            ['1', '2', '3', '4'],
            count.toString(),
            (v) => count = int.parse(v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: style,
            decoration: const InputDecoration(labelText: 'Style (optional)'),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: busy ? null : () => generate(),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate'),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
          TextButton(
            onPressed: stop,
            child: const Text('Stop / cancel if supported'),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(status),
        ),
        const Divider(),
        const Text('Generation history'),
        FutureBuilder<List<Json>>(
          future: s.store.list('job'),
          builder: (c, snap) => Column(
            children: (snap.data ?? []).reversed
                .where((j) => j['type'] == kind)
                .map(
                  (j) => ExpansionTile(
                    title: Text(j['prompt'] ?? ''),
                    subtitle: Text(j['status'] ?? ''),
                    children: [
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: busy
                                ? null
                                : () {
                                    prompt.text = j['prompt'];
                                    style.text = j['style'] ?? '';
                                    setState(() {
                                      ratio = j['aspect_ratio'] ?? '1:1';
                                      quality = j['quality'] ?? 'standard';
                                    });
                                  },
                            child: const Text('Use prompt / regenerate'),
                          ),
                          if (j['remote_id'] != null &&
                              j['status'] != 'completed')
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => generate(resume: j),
                              child: const Text('Resume job'),
                            ),
                        ],
                      ),
                      FutureBuilder<List<Json>>(
                        future: s.store.list('file', parent: j['id']),
                        builder: (c, fs) => Column(
                          children: (fs.data ?? [])
                              .map(
                                (f) => ListTile(
                                  title: Text(f['name']),
                                  leading: const Icon(
                                    Icons.play_circle_outline,
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FileView(session: s, file: f),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Download',
                                    icon: const Icon(Icons.download),
                                    onPressed: () =>
                                        guard(context, () => s.files.export(f)),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
}

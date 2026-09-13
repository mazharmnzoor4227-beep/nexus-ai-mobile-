import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/store.dart';
import '../core/diff.dart';
import '../core/preview.dart';
import '../core/files.dart';
import '../core/session.dart';
import 'common.dart';

class Library extends StatefulWidget {
  final Session session;
  final void Function(Json) onChat;
  const Library({super.key, required this.session, required this.onChat});
  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  Session get s => widget.session;
  String query = '';
  Json? project;
  bool archived = false;
  Future<void> run(Future<void> Function() f) async {
    await guard(context, f);
    if (mounted) setState(() {});
  }

  Future<void> exportProject(Json p) async {
    final files = (await s.store.list(
      'file',
    )).where((f) => f['project'] == p['id']);
    final entries = <String, Uint8List>{
      'PROJECT.json': Uint8List.fromList(utf8.encode(jsonEncode(p))),
    };
    for (final f in files) {
      try {
        entries['files/${f['id']}/${safePath(f['name'])}'] = await s.files
            .local(f)
            .readAsBytes();
      } on FormatException {
        continue;
      }
    }
    for (final c in await s.store.list('chat', parent: p['id'])) {
      entries['chats/${c['id']}.md'] = Uint8List.fromList(
        utf8.encode(await s.store.markdown(c['id'])),
      );
    }
    final out = await s.files.save(
      'project-export.zip',
      pack(entries),
      project: p['id'],
    );
    await s.files.export(out);
  }

  Widget card(Json f) => ListTile(
    leading: Icon(
      (f['mime'] as String).startsWith('image/')
          ? Icons.image_outlined
          : f['mime'] == 'application/zip'
          ? Icons.folder_zip_outlined
          : Icons.insert_drive_file_outlined,
    ),
    title: Text(f['name']),
    subtitle: Text(
      '${((f['size'] as num) / 1024).toStringAsFixed(1)} KB · ${f['category']}',
    ),
    onTap: () =>
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileView(session: s, file: f),
          ),
        ).then((_) {
          if (mounted) setState(() {});
        }),
    trailing: IconButton(
      tooltip: 'Download',
      icon: const Icon(Icons.download),
      onPressed: () => run(() => s.files.export(f)),
    ),
  );
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (project != null) ...[
        TextButton.icon(
          onPressed: () => setState(() => project = null),
          icon: const Icon(Icons.arrow_back),
          label: const Text('All projects'),
        ),
        Text(
          project!['title'],
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(project!['description'] ?? ''),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => run(() async {
                final name = await ask(
                  context,
                  'Project name',
                  value: project!['title'],
                );
                if (name != null) {
                  project!['title'] = name;
                  await s.store.put(project!);
                }
              }),
              child: const Text('Rename'),
            ),
            TextButton(
              onPressed: () => run(() async {
                final text = await ask(
                  context,
                  'Project memory',
                  value: project!['memory'] ?? '',
                  lines: 6,
                );
                if (text != null) {
                  project!['memory'] = text;
                  await s.store.put(project!);
                }
              }),
              child: const Text('Memory'),
            ),
            TextButton(
              onPressed: () => run(() => exportProject(project!)),
              child: const Text('Export ZIP'),
            ),
            TextButton(
              onPressed: () => run(() async {
                project!['archived'] = project!['archived'] != true;
                await s.store.put(project!);
                project = null;
              }),
              child: const Text('Archive / restore'),
            ),
            TextButton(
              onPressed: () => run(() async {
                if (await confirm(
                  context,
                  'Delete project?',
                  'Project metadata will be removed. Chats and files remain in the Library.',
                )) {
                  await s.store.remove(project!['id']);
                  project = null;
                }
              }),
              child: const Text('Delete'),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () => run(() async {
            final c = await s.store.add('chat', {
              'title': 'New project chat',
              'pinned': false,
              'archived': false,
            }, parent: project!['id']);
            widget.onChat(c);
          }),
          icon: const Icon(Icons.add),
          label: const Text('New project chat'),
        ),
        OutlinedButton.icon(
          onPressed: () => run(() async {
            for (final f in await FilePicker.pickFiles()) {
              if (f.path != null) {
                await s.files.import(f.path!, project: project!['id']);
              }
            }
          }),
          icon: const Icon(Icons.attach_file),
          label: const Text('Add files'),
        ),
        FutureBuilder<List<Json>>(
          future: s.store.list('chat', parent: project!['id']),
          builder: (c, snap) => Column(
            children: (snap.data ?? [])
                .map(
                  (chat) => ListTile(
                    title: Text(chat['title']),
                    leading: const Icon(Icons.chat_outlined),
                    onTap: () => widget.onChat(chat),
                  ),
                )
                .toList(),
          ),
        ),
      ] else ...[
        Row(
          children: [
            Expanded(
              child: Text(
                'Your workspace',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'New project',
              onPressed: () => run(() async {
                final name = await ask(context, 'Project name');
                if (name == null || name.trim().isEmpty) return;
                if (!context.mounted) return;
                final description = await ask(context, 'Description', lines: 3);
                project = await s.store.add('project', {
                  'title': name,
                  'description': description ?? '',
                  'memory': '',
                  'archived': false,
                });
              }),
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
          ],
        ),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search projects and files',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
        SwitchListTile(
          title: const Text('Archived projects'),
          value: archived,
          onChanged: (v) => setState(() => archived = v),
        ),
        FutureBuilder<List<Json>>(
          future: s.store.list('project'),
          builder: (c, snap) => Column(
            children: (snap.data ?? [])
                .where(
                  (p) =>
                      (p['archived'] == true) == archived &&
                      p['title'].toString().toLowerCase().contains(query),
                )
                .map(
                  (p) => ListTile(
                    title: Text(p['title']),
                    subtitle: Text(p['description'] ?? ''),
                    leading: const Icon(Icons.folder_outlined),
                    onTap: () => setState(() => project = p),
                  ),
                )
                .toList(),
          ),
        ),
      ],
      const Divider(height: 32),
      const Text('Files & artifacts'),
      FutureBuilder<List<Json>>(
        future: s.store.list('file'),
        builder: (c, snap) {
          final rows = (snap.data ?? []).reversed
              .where(
                (f) =>
                    (project == null || f['project'] == project!['id']) &&
                    f['name'].toString().toLowerCase().contains(query),
              )
              .toList();
          return rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('Files you import or create will appear here.'),
                )
              : Column(children: rows.map(card).toList());
        },
      ),
    ],
  );
}

class FileView extends StatefulWidget {
  final Session session;
  final Json file;
  const FileView({super.key, required this.session, required this.file});
  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
  Session get s => widget.session;
  Json get f => widget.file;
  String? text, error;
  Map<String, Uint8List>? entries;
  Map<String, String> edits = {};
  String query = '';
  VideoPlayerController? video;
  WebViewController? web;
  bool preview = false;
  final editor = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final file = s.files.local(f);
      if (f['mime'] == 'application/zip') {
        entries = await s.files.archive(f);
      } else if ((f['mime'] as String).startsWith('video/')) {
        video = VideoPlayerController.file(file);
        await video!.initialize();
      } else if (['text/plain', 'text/html'].contains(f['mime'])) {
        if (await file.length() > 1024 * 1024) {
          throw const FormatException('Text preview limited to 1 MB');
        }
        text = await file.readAsString();
        editor.text = text!;
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    video?.dispose();
    editor.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() fn) async {
    await guard(context, fn);
    if (mounted) setState(() {});
  }

  Future<void> html(String source) async {
    web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) => NavigationDecision.prevent,
        ),
      );
    await web!.loadHtmlString(
      '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'unsafe-inline\'; style-src \'unsafe-inline\'; img-src data:; media-src data:; connect-src \'none\'; frame-src \'none\'; form-action \'none\'; base-uri \'none\'"><meta name="viewport" content="width=device-width,initial-scale=1">$source',
    );
    preview = true;
  }

  Future<void> zipSave() async {
    final copy = Map<String, Uint8List>.from(entries!);
    final summary = StringBuffer('# Nexus changes\n');
    final patch = StringBuffer();
    for (final e in edits.entries) {
      final before = utf8.decode(copy[e.key] ?? [], allowMalformed: true);
      copy[e.key] = Uint8List.fromList(utf8.encode(e.value));
      patch.write(unifiedDiff(e.key, before, e.value));
      summary.writeln(
        '\n## ${e.key}\nBefore: ${before.split('\n').length} lines; after: ${e.value.split('\n').length} lines.\n',
      );
    }
    copy['NEXUS_CHANGES.md'] = Uint8List.fromList(
      utf8.encode(summary.toString()),
    );
    copy['NEXUS_CHANGES.patch'] = Uint8List.fromList(
      utf8.encode(patch.toString()),
    );
    final out = await s.files.save(
      'updated-project.zip',
      pack(copy),
      parent: f['parent'],
      project: f['project'],
    );
    await s.files.export(out);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(f['name']),
      actions: [
        IconButton(
          tooltip: 'Download',
          onPressed: () => run(() => s.files.export(f)),
          icon: const Icon(Icons.download),
        ),
        IconButton(
          tooltip: 'Share',
          onPressed: () => run(() => s.files.share(f)),
          icon: const Icon(Icons.share),
        ),
        PopupMenuButton<String>(
          onSelected: (v) => run(() async {
            if (v == 'project') {
              final ps = await s.store.list('project');
              if (!context.mounted) return;
              final id = await showDialog<String>(
                context: context,
                builder: (c) => SimpleDialog(
                  title: const Text('Save to project'),
                  children: ps
                      .map(
                        (p) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(c, p['id']),
                          child: Text(p['title']),
                        ),
                      )
                      .toList(),
                ),
              );
              if (id != null) {
                f['project'] = id;
                await s.store.put(f);
              }
            }
            if (context.mounted &&
                v == 'delete' &&
                await confirm(
                  context,
                  'Delete file?',
                  'The local file will be removed.',
                )) {
              await s.files.remove(f);
              if (context.mounted) Navigator.pop(context);
            }
          }),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'project',
              child: Text('Save to project'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
    body: error != null
        ? Center(child: Text(error!))
        : preview && web != null
        ? Column(
            children: [
              TextButton(
                onPressed: () => setState(() => preview = false),
                child: const Text('Back to source'),
              ),
              Expanded(child: WebViewWidget(controller: web!)),
            ],
          )
        : entries != null
        ? Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search file paths',
                  ),
                  onChanged: (v) => setState(() => query = v.toLowerCase()),
                ),
              ),
              Text('${entries!.length} files · ${edits.length} changed'),
              if (entries!.keys.any((k) => k.toLowerCase().endsWith('.html')))
                TextButton(
                  onPressed: () => run(() async {
                    final pages = entries!.keys
                        .where((k) => k.toLowerCase().endsWith('.html'))
                        .toList();
                    final entry = pages.contains('index.html')
                        ? 'index.html'
                        : pages.first;
                    final copy = Map<String, Uint8List>.from(entries!);
                    for (final edit in edits.entries) {
                      copy[edit.key] = Uint8List.fromList(
                        utf8.encode(edit.value),
                      );
                    }
                    await html(bundleHtml(entry, copy));
                  }),
                  child: const Text('Preview website'),
                ),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => run(zipSave),
                    child: const Text('Download updated ZIP'),
                  ),
                  TextButton(
                    onPressed: () => run(() async {
                      final generated = (await s.store.list('file'))
                          .where(
                            (r) =>
                                r['category'] == 'artifact' &&
                                ['text/plain', 'text/html'].contains(r['mime']),
                          )
                          .toList();
                      if (!context.mounted) return;
                      final selected = await showDialog<Json>(
                        context: context,
                        builder: (c) => SimpleDialog(
                          title: const Text('Apply generated file'),
                          children: generated
                              .map(
                                (r) => SimpleDialogOption(
                                  onPressed: () => Navigator.pop(c, r),
                                  child: Text(r['name']),
                                ),
                              )
                              .toList(),
                        ),
                      );
                      if (selected == null) return;
                      final name = safePath(selected['name']);
                      final value = await s.files
                          .local(selected)
                          .readAsString();
                      if (!context.mounted) return;
                      if (await confirm(
                        context,
                        'Apply $name?',
                        'Changes will be exported as a new ZIP; the original stays intact.',
                      )) {
                        edits[name] = value;
                      }
                    }),
                    child: const Text('Apply artifact'),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: {...entries!.keys, ...edits.keys}
                      .where((k) => k.toLowerCase().contains(query))
                      .map(
                        (name) => ListTile(
                          title: Text(name),
                          leading: Icon(
                            edits.containsKey(name)
                                ? Icons.edit
                                : Icons.description_outlined,
                          ),
                          onTap: () => run(() async {
                            final bytes = entries![name] ?? Uint8List(0);
                            if (bytes.length > 500000 || !sourcePath(name)) {
                              throw const FormatException(
                                'Binary, secret, or large file cannot be edited here',
                              );
                            }
                            final value = await ask(
                              context,
                              name,
                              value:
                                  edits[name] ??
                                  utf8.decode(bytes, allowMalformed: true),
                              lines: 12,
                            );
                            if (value != null) edits[name] = value;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          )
        : (f['mime'] as String).startsWith('image/')
        ? InteractiveViewer(
            minScale: 0.5,
            maxScale: 6,
            child: Center(
              child: Image.file(
                s.files.local(f),
                errorBuilder: (c, e, t) => const Text('Invalid image'),
              ),
            ),
          )
        : video != null && video!.value.isInitialized
        ? Column(
            children: [
              AspectRatio(
                aspectRatio: video!.value.aspectRatio,
                child: VideoPlayer(video!),
              ),
              VideoProgressIndicator(video!, allowScrubbing: true),
              IconButton(
                onPressed: () {
                  setState(() {
                    video!.value.isPlaying ? video!.pause() : video!.play();
                  });
                },
                icon: Icon(
                  video!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
            ],
          )
        : text != null
        ? Column(
            children: [
              Wrap(
                children: [
                  TextButton(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: editor.text)),
                    child: const Text('Copy'),
                  ),
                  TextButton(
                    onPressed: () => run(() async {
                      final out = await s.files.save(
                        f['name'],
                        utf8.encode(editor.text),
                        parent: f['parent'],
                        project: f['project'],
                      );
                      await s.files.export(out);
                    }),
                    child: const Text('Save edited copy'),
                  ),
                  if (f['mime'] == 'text/html')
                    TextButton(
                      onPressed: () => run(() => html(editor.text)),
                      child: const Text('Preview'),
                    ),
                ],
              ),
              Expanded(
                child: TextField(
                  controller: editor,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ],
          )
        : Center(
            child: Text(
              '${f['mime']}\nUse Download or Share to open with another app.',
            ),
          ),
  );
}

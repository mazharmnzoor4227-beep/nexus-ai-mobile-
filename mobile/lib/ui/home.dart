import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../core/store.dart';
import '../core/session.dart';
import '../core/voice.dart';
import 'common.dart';
import 'settings.dart';
import 'response.dart';
import 'library.dart';
import 'generation.dart';

class Home extends StatefulWidget {
  final Session session;
  const Home({super.key, required this.session});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  Session get s => widget.session;
  late Voice voice;
  final input = TextEditingController(), scroll = ScrollController();
  int tab = 0;
  String query = '';
  bool archived = false;
  Timer? draftTimer, lockTimer;
  @override
  void initState() {
    super.initState();
    voice = Voice(s);
    s.addListener(update);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final draft = await s.store.setting('draft') ?? '';
      if (!context.mounted) return;
      input.text = draft;
      if (!await s.vault.exists() && mounted) settings();
    });
  }

  void update() {
    if (!context.mounted) return;
    final bottom =
        !scroll.hasClients ||
        scroll.position.maxScrollExtent - scroll.offset < 150;
    setState(() {});
    if (bottom && tab == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.jumpTo(scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    s.removeListener(update);
    input.dispose();
    scroll.dispose();
    draftTimer?.cancel();
    lockTimer?.cancel();
    voice.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      voice.end();
      lockTimer?.cancel();
      lockTimer = Timer(const Duration(minutes: 2), s.vault.lock);
    }
    if (state == AppLifecycleState.resumed) lockTimer?.cancel();
  }

  Future<void> settings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Settings(session: s)),
    );
    update();
  }

  Future<void> open(Json c) async {
    await guard(context, () async {
      await s.open(c);
      if (!context.mounted) return;
      input.text = c['draft'] ?? '';
      setState(() => tab = 0);
    });
  }

  void fresh() {
    if (s.busy) return;
    s.fresh();
    input.clear();
    setState(() => tab = 0);
  }

  Future<void> send() async {
    final text = input.text;
    if (text.trim().isEmpty) return;
    if (!s.vault.open) {
      notice(context, 'Unlock the vault in Settings');
      return;
    }
    draftTimer?.cancel();
    input.clear();
    await s.store.set('draft', '');
    if (!mounted) return;
    await guard(context, () => s.send(text));
  }

  Future<void> pick({bool camera = false}) async {
    await guard(context, () async {
      final paths = <String>[];
      if (camera) {
        final f = await ImagePicker().pickImage(source: ImageSource.camera);
        if (f != null) paths.add(f.path);
      } else {
        paths.addAll(
          (await FilePicker.pickFiles()).map((f) => f.path).whereType<String>(),
        );
      }
      if (paths.length + s.attached.length > 8) {
        throw const FormatException('Attach up to 8 files');
      }
      for (final path in paths) {
        s.attached.add(
          await s.files.import(
            path,
            parent: s.chat?['id'],
            project: s.chat?['parent'],
          ),
        );
      }
      update();
    });
  }

  Future<void> modelPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .7,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Choose your mode',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              Wrap(
                spacing: 8,
                children:
                    [
                          'Auto',
                          'Fast',
                          'Smart',
                          'Coding',
                          'Reasoning',
                          'Vision',
                          'Research',
                        ]
                        .map(
                          (mode) => ChoiceChip(
                            label: Text(mode),
                            selected: s.mode == mode,
                            onSelected: (_) {
                              s.mode = mode;
                              s.selected = null;
                              s.store.set('mode', mode);
                              Navigator.pop(ctx);
                              update();
                            },
                          ),
                        )
                        .toList(),
              ),
              const Divider(height: 30),
              const Text('Advanced model picker'),
              ListTile(
                title: const Text('Automatic routing'),
                onTap: () {
                  s.selected = null;
                  Navigator.pop(ctx);
                  update();
                },
              ),
              ...s.gateway.models.map(
                (m) => ListTile(
                  title: Text(m['id']),
                  subtitle: Text(
                    '${s.gateway.tags(m).join(' · ')}${s.gateway.latency[m['id']] == null ? '' : ' · ${s.gateway.latency[m['id']]} ms'}',
                  ),
                  onTap: () {
                    s.selected = m['id'];
                    Navigator.pop(ctx);
                    update();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: TextButton.icon(
        onPressed: modelPicker,
        label: Text(s.selected ?? s.mode),
        icon: const Icon(Icons.expand_more, size: 18),
      ),
      actions: [
        IconButton(
          tooltip: 'New chat',
          onPressed: s.busy ? null : fresh,
          icon: const Icon(Icons.edit_square),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: settings,
          icon: const Icon(Icons.person_outline),
        ),
      ],
    ),
    drawer: Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.all_inclusive,
                color: Color(0xffadc6ff),
              ),
              title: const Text('Nexus AI'),
              trailing: Builder(
                builder: (c) => IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: s.busy
                    ? null
                    : () {
                        Navigator.pop(context);
                        fresh();
                      },
                icon: const Icon(Icons.add),
                label: const Text('New Chat'),
              ),
            ),
            Expanded(child: history(drawer: true)),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                settings();
              },
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chat',
        ),
        NavigationDestination(icon: Icon(Icons.grid_view), label: 'Explore'),
        NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        NavigationDestination(icon: Icon(Icons.folder_open), label: 'Library'),
      ],
    ),
    body: SafeArea(
      child: switch (tab) {
        0 => chat(),
        1 => explore(),
        2 => history(),
        _ => Library(session: s, onChat: open),
      },
    ),
  );
  Widget chat() => Column(
    children: [
      Expanded(
        child: s.messages.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.all_inclusive,
                        size: 56,
                        color: Color(0xffadc6ff),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'What can we create?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Think, code, explore and build.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children:
                            [
                                  'Explain an idea',
                                  'Build a website',
                                  'Analyze a project',
                                ]
                                .map(
                                  (t) => ActionChip(
                                    label: Text(t),
                                    onPressed: () {
                                      input.text = '$t: ';
                                    },
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                itemCount: s.messages.length,
                itemBuilder: (context, index) => message(s.messages[index]),
              ),
      ),
      if (s.busy)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.stage,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      if (s.error.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.error,
                  style: const TextStyle(color: Color(0xffffb4ab)),
                ),
              ),
              TextButton(
                onPressed: s.busy
                    ? null
                    : () => guard(context, () => s.retry()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      if (s.attached.isNotEmpty)
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: s.attached
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text(f['name']),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FileView(session: s, file: f),
                        ),
                      ),
                      onDeleted: s.busy
                          ? null
                          : () => setState(() => s.attached.remove(f)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        decoration: BoxDecoration(
          color: const Color(0xff212124),
          border: Border.all(color: const Color(0xff2e2e34)),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            TextField(
              controller: input,
              minLines: 1,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Ask anything…',
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              onChanged: (text) {
                draftTimer?.cancel();
                draftTimer = Timer(const Duration(milliseconds: 350), () async {
                  await s.store.set('draft', text);
                  if (s.chat != null) {
                    s.chat!['draft'] = text;
                    await s.store.put(s.chat!);
                  }
                });
              },
            ),
            Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Attach',
                  icon: const Icon(Icons.add),
                  onSelected: (v) => pick(camera: v == 'camera'),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'files',
                      child: Text('Files, images, video or ZIP'),
                    ),
                    const PopupMenuItem(value: 'camera', child: Text('Camera')),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Voice typing',
                  onPressed: s.busy
                      ? null
                      : () => guard(
                          context,
                          () => voice.dictate((text) {
                            input.text = text;
                            input.selection = TextSelection.collapsed(
                              offset: text.length,
                            );
                          }),
                        ),
                  icon: const Icon(Icons.mic_none),
                ),
                IconButton(
                  tooltip: 'Voice conversation',
                  onPressed: s.busy
                      ? null
                      : () {
                          if (!s.vault.open) {
                            notice(context, 'Unlock the vault in Settings');
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VoiceScreen(voice: voice),
                            ),
                          );
                        },
                  icon: const Icon(Icons.graphic_eq),
                ),
                IconButton.filled(
                  tooltip: s.busy ? 'Stop' : 'Send',
                  onPressed: s.busy ? s.stop : send,
                  icon: Icon(s.busy ? Icons.stop : Icons.arrow_upward),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
  Widget message(Json m) {
    final user = m['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (user)
            Container(
              margin: const EdgeInsets.only(left: 38),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff222226),
                borderRadius: BorderRadius.circular(22),
              ),
              child: SelectableText(
                m['text'],
                style: const TextStyle(fontSize: 16, height: 1.45),
              ),
            )
          else ...[
            Row(
              children: [
                const Icon(
                  Icons.all_inclusive,
                  size: 20,
                  color: Color(0xffadc6ff),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m['model'] ?? 'Nexus AI',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ResponseText(m['text']),
          ],
          if (m['attachments'] is List)
            Wrap(
              children: (m['attachments'] as List)
                  .map(
                    (id) => FutureBuilder<Json?>(
                      future: s.store.get(id),
                      builder: (c, snap) => snap.data == null
                          ? const SizedBox.shrink()
                          : ActionChip(
                              label: Text(snap.data!['name']),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FileView(session: s, file: snap.data!),
                                ),
                              ),
                            ),
                    ),
                  )
                  .toList(),
            ),
          if (!user)
            FutureBuilder<List<Json>>(
              future: s.store.list('file', parent: s.chat?['id']),
              builder: (c, snap) => Column(
                children: (snap.data ?? [])
                    .where((f) => f['message'] == m['id'])
                    .map(
                      (f) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.code),
                          title: Text(f['name']),
                          subtitle: const Text(
                            'Open · preview · edit · download',
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FileView(session: s, file: f),
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Download',
                            onPressed: () =>
                                guard(context, () => s.files.export(f)),
                            icon: const Icon(Icons.download),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Copy',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: m['text'])),
                icon: const Icon(Icons.copy, size: 16),
              ),
              IconButton(
                tooltip: 'Share',
                onPressed: () => guard(context, () async {
                  final f = await s.files.save(
                    'message.md',
                    utf8.encode(m['text']),
                  );
                  await s.files.share(f);
                }),
                icon: const Icon(Icons.share_outlined, size: 16),
              ),
              if (!user) ...[
                IconButton(
                  tooltip: 'Read aloud',
                  onPressed: () => voice.tts.speak(m['text']),
                  icon: const Icon(Icons.volume_up_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Helpful',
                  onPressed: () => guard(context, () async {
                    m['rating'] = m['rating'] == 1 ? 0 : 1;
                    await s.store.put(m);
                    update();
                  }),
                  icon: Icon(
                    m['rating'] == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 16,
                  ),
                ),
              ],
              PopupMenuButton<String>(
                tooltip: 'Message actions',
                onSelected: (v) => guard(context, () async {
                  if (v == 'edit') {
                    final text = await ask(
                      context,
                      'Edit message',
                      value: m['text'],
                      lines: 5,
                    );
                    if (text != null) {
                      await s.retry(edited: text, through: m['id']);
                    }
                  }
                  if (v == 'retry') await s.retry();
                  if (v == 'continue') {
                    await s.send('Continue your previous response.');
                  }
                  if (v == 'branch') {
                    final c = await s.store.branch(s.chat!, through: m['id']);
                    await open(c);
                  }
                  if (v == 'dislike') {
                    m['rating'] = -1;
                    await s.store.put(m);
                    update();
                  }
                }),
                itemBuilder: (_) => [
                  if (user)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit and resend'),
                    ),
                  if (!user)
                    const PopupMenuItem(
                      value: 'retry',
                      child: Text('Regenerate latest response'),
                    ),
                  if (!user)
                    const PopupMenuItem(
                      value: 'continue',
                      child: Text('Continue'),
                    ),
                  const PopupMenuItem(
                    value: 'branch',
                    child: Text('Branch here'),
                  ),
                  if (!user)
                    const PopupMenuItem(
                      value: 'dislike',
                      child: Text('Not helpful'),
                    ),
                ],
              ),
              Text(
                '${DateTime.fromMillisecondsSinceEpoch(m['created']).toLocal().hour.toString().padLeft(2, '0')}:${DateTime.fromMillisecondsSinceEpoch(m['created']).toLocal().minute.toString().padLeft(2, '0')}${m['latency_ms'] == null ? '' : ' · ${m['latency_ms']} ms'}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget history({bool drawer = false}) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          decoration: const InputDecoration(
            hintText: 'Search chats and messages',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v.toLowerCase()),
        ),
      ),
      SwitchListTile(
        title: const Text('Archived'),
        dense: true,
        value: archived,
        onChanged: (v) => setState(() => archived = v),
      ),
      Expanded(
        child: FutureBuilder<List<Json>>(
          future: historyRows(),
          builder: (c, snap) {
            final rows = snap.data ?? [];
            return rows.isEmpty
                ? const Center(child: Text('No conversations yet'))
                : ListView(
                    children: rows
                        .map(
                          (chat) => ListTile(
                            leading: Icon(
                              chat['pinned'] == true
                                  ? Icons.push_pin_outlined
                                  : Icons.chat_bubble_outline,
                              size: 20,
                            ),
                            title: Text(
                              chat['title'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              if (drawer) Navigator.pop(context);
                              open(chat);
                            },
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) => guard(context, () async {
                                if (v == 'rename') {
                                  final name = await ask(
                                    context,
                                    'Rename chat',
                                    value: chat['title'],
                                  );
                                  if (name != null) chat['title'] = name;
                                }
                                if (v == 'pin') {
                                  chat['pinned'] = chat['pinned'] != true;
                                }
                                if (v == 'archive') {
                                  chat['archived'] = chat['archived'] != true;
                                }
                                if (['rename', 'pin', 'archive'].contains(v)) {
                                  await s.store.put(chat);
                                }
                                if (mounted &&
                                    v == 'delete' &&
                                    await confirm(
                                      context,
                                      'Delete chat?',
                                      'All messages in this chat will be removed.',
                                    )) {
                                  await s.store.remove(chat['id']);
                                  if (s.chat?['id'] == chat['id']) fresh();
                                }
                                if (v == 'duplicate') {
                                  await s.store.branch(chat);
                                }
                                if (v == 'export') {
                                  final f = await s.files.save(
                                    'conversation.md',
                                    utf8.encode(
                                      await s.store.markdown(chat['id']),
                                    ),
                                  );
                                  await s.files.export(f);
                                }
                                update();
                              }),
                              itemBuilder: (_) =>
                                  [
                                        'rename',
                                        'pin',
                                        'archive',
                                        'duplicate',
                                        'export',
                                        'delete',
                                      ]
                                      .map(
                                        (v) => PopupMenuItem(
                                          value: v,
                                          child: Text(
                                            v[0].toUpperCase() + v.substring(1),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        )
                        .toList(),
                  );
          },
        ),
      ),
    ],
  );
  Future<List<Json>> historyRows() async {
    final chats = await s.store.list('chat');
    final matched = <String>{};
    if (query.isNotEmpty) {
      for (final m in await s.store.list('message')) {
        if (m['text'].toString().toLowerCase().contains(query)) {
          matched.add(m['parent']);
        }
      }
    }
    final rows = chats
        .where(
          (c) =>
              (c['archived'] == true) == archived &&
              (query.isEmpty ||
                  c['title'].toString().toLowerCase().contains(query) ||
                  matched.contains(c['id'])),
        )
        .toList();
    rows.sort((a, b) {
      final pin = (b['pinned'] == true ? 1 : 0) - (a['pinned'] == true ? 1 : 0);
      return pin != 0 ? pin : (b['created'] as int).compareTo(a['created']);
    });
    return rows;
  }

  Widget explore() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Make something new',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 24),
      for (final video in [false, true])
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Icon(
              video ? Icons.movie_outlined : Icons.image_outlined,
              color: const Color(0xffadc6ff),
            ),
            title: Text(video ? 'Create video' : 'Create image'),
            subtitle: Text(
              s.gateway.capabilities[video
                          ? 'video_generation'
                          : 'image_generation']
                      is Map
                  ? 'Connected provider'
                  : 'Provider not configured',
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Generation(session: s, video: video),
              ),
            ),
          ),
        ),
      const SizedBox(height: 20),
      for (final mode in ['Coding', 'Research', 'Reasoning'])
        ListTile(
          title: Text(mode),
          leading: Icon(
            mode == 'Coding'
                ? Icons.code
                : mode == 'Research'
                ? Icons.travel_explore
                : Icons.psychology_outlined,
          ),
          onTap: () {
            s.mode = mode;
            fresh();
          },
        ),
      ListTile(
        title: const Text('Model usage'),
        subtitle: const Text('Reported token usage stored on this device'),
        onTap: () async {
          final rows = await s.store.list('usage');
          if (!mounted) return;
          showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Usage'),
              content: SingleChildScrollView(
                child: Text(
                  rows.isEmpty
                      ? 'No usage reported yet.'
                      : rows.reversed
                            .take(100)
                            .map(
                              (r) =>
                                  '${r['model']}: ${r['total_tokens'] ?? '—'} tokens',
                            )
                            .join('\n'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class VoiceScreen extends StatefulWidget {
  final Voice voice;
  const VoiceScreen({super.key, required this.voice});
  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  Voice get v => widget.voice;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    v.addListener(update);
    timer = Timer.periodic(const Duration(seconds: 1), (_) => update());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => guard(context, v.start),
    );
  }

  void update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    v.removeListener(update);
    timer?.cancel();
    v.end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = v.started == null
        ? 0
        : DateTime.now().difference(v.started!).inSeconds;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              v.state,
              style: const TextStyle(fontSize: 15, color: Color(0xffadc6ff)),
            ),
            Text(
              '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Language',
            onSelected: (lang) {
              v.language = lang;
              v.interrupt();
            },
            itemBuilder: (_) =>
                {'en-US': 'English', 'ur-PK': 'Urdu', 'hi-IN': 'Hindi'}.entries
                    .map(
                      (e) => PopupMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: () => guard(context, v.interrupt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width:
                    210 +
                    (v.state == 'Listening' ? v.level.clamp(0, 10) * 3 : 0),
                height:
                    210 +
                    (v.state == 'Listening' ? v.level.clamp(0, 10) * 3 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-.4, -.5),
                    colors: v.muted
                        ? [Colors.grey, Colors.blueGrey]
                        : const [
                            Color(0xffadc6ff),
                            Color(0xff6897ff),
                            Color(0xff7c87f3),
                          ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x304d8eff),
                      blurRadius: 70,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Tap the orb to interrupt',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Spacer(),
            Flexible(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SelectableText(
                  v.transcript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              v.session.messages.isNotEmpty &&
                      v.session.messages.last['latency_ms'] != null
                  ? 'First token: ${v.session.messages.last['latency_ms']} ms'
                  : 'Android speech · ${v.language}',
              style: const TextStyle(color: Colors.grey),
            ),
            TextButton(
              onPressed: () => guard(context, v.interrupt),
              child: const Text('Reconnect'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Speaker / earpiece',
                  onPressed: () => guard(context, v.output),
                  icon: Icon(v.speaker ? Icons.volume_up : Icons.phone_in_talk),
                ),
                IconButton.filled(
                  tooltip: 'Mute microphone',
                  iconSize: 32,
                  onPressed: () => guard(context, v.mute),
                  icon: Icon(v.muted ? Icons.mic_off : Icons.mic),
                ),
                IconButton.filled(
                  tooltip: 'End call',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xffae0014),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.call_end),
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

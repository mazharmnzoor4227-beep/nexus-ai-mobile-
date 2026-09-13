import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/session.dart';
import '../core/gateway.dart';
import 'common.dart';

class Settings extends StatefulWidget {
  final Session session;
  const Settings({super.key, required this.session});
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Session get s => widget.session;
  final key = TextEditingController(),
      password = TextEditingController(),
      repeat = TextEditingController();
  bool? exists;
  bool busy = false, advanced = false;
  String status = '';
  @override
  void initState() {
    super.initState();
    s.vault.exists().then((v) {
      if (mounted) setState(() => exists = v);
    });
  }

  @override
  void dispose() {
    key.dispose();
    password.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      status = e is ApiError || e is StateError || e is FormatException
          ? e.toString()
          : 'Operation failed. Check input and device security settings.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (exists == null)
          const LinearProgressIndicator()
        else if (!s.vault.open) ...[
          Text(
            exists! ? 'Unlock API vault' : 'Protect your API key',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your conversations stay on this device. Your master password protects saved connection keys.',
          ),
          const SizedBox(height: 20),
          field(password, 'Master password'),
          if (!exists!) field(repeat, 'Confirm master password'),
          FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    if (exists!) {
                      await s.vault.unlock(password.text);
                    } else {
                      if (password.text != repeat.text) {
                        throw const FormatException('Passwords do not match');
                      }
                      await s.vault.create(password.text);
                      exists = true;
                    }
                    password.clear();
                    repeat.clear();
                    status = 'Vault unlocked';
                  }),
            child: Text(exists! ? 'Unlock' : 'Create vault'),
          ),
          if (exists!)
            TextButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await s.vault.unlockBiometric();
                      status = 'Vault unlocked';
                    }),
              child: const Text('Unlock with biometrics'),
            ),
        ] else ...[
          Text(
            'AI Connection',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(s.vault.mask('key')),
          const SizedBox(height: 12),
          field(key, 'Unified API Key'),
          FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    if (key.text.trim().isNotEmpty) {
                      await s.vault.write('key', key.text.trim());
                      key.clear();
                    }
                    await s.gateway.connect();
                    status = 'Connected · ${s.gateway.models.length} models';
                  }),
            child: const Text('Connect / Test'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Connection enabled'),
            value: s.vault.read('disabled') != 'true',
            onChanged: (v) =>
                run(() => s.vault.write('disabled', (!v).toString())),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable biometric unlock'),
            leading: const Icon(Icons.fingerprint),
            onTap: () => run(() async {
              await s.vault.enableBiometric();
              status = 'Biometric unlock enabled';
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lock vault'),
            leading: const Icon(Icons.lock_outline),
            onTap: () {
              s.vault.lock();
              setState(() => advanced = false);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Delete API key'),
            onTap: () => run(() async {
              if (await confirm(
                context,
                'Delete key?',
                'You will need to enter it again.',
              )) {
                await s.vault.write('key', null);
              }
            }),
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('Developer / API Vault'),
            subtitle: const Text('Protected advanced connection settings'),
            trailing: Icon(advanced ? Icons.expand_less : Icons.expand_more),
            onTap: () async {
              if (advanced) {
                setState(() => advanced = false);
                return;
              }
              final pass = await ask(context, 'Master password', secret: true);
              if (pass == null) return;
              await run(() async {
                await s.vault.unlock(pass);
                advanced = true;
              });
            },
          ),
          if (advanced) ...[
            ListTile(
              title: const Text('Gateway endpoint override'),
              subtitle: Text(s.vault.read('endpoint') ?? Gateway.builtIn),
              onTap: () => run(() async {
                final value = await ask(
                  context,
                  'Trusted HTTPS gateway',
                  value: s.vault.read('endpoint') ?? Gateway.builtIn,
                );
                if (value == null) return;
                endpoint(value);
                if (!context.mounted) return;
                if (!await confirm(
                  context,
                  'Trust gateway?',
                  'Your API key will be sent to $value. Existing key will be removed.',
                )) {
                  return;
                }
                await s.vault.write('key', null);
                await s.vault.write('endpoint', value);
                s.gateway.models = [];
                s.gateway.capabilities = {};
              }),
            ),
            for (final item in {
              'capabilities': 'Capability adapters (JSON)',
              'model_metadata': 'Model capability metadata (JSON)',
              'fast_timeout': 'First-token timeout: Fast (seconds)',
              'deep_timeout': 'First-token timeout: Coding (seconds)',
            }.entries)
              ListTile(
                title: Text(item.value),
                onTap: () => run(() async {
                  final value = await ask(
                    context,
                    item.value,
                    value:
                        s.vault.read(item.key) ??
                        (item.key.contains('timeout') ? '8' : '{}'),
                    lines: item.key.contains('timeout') ? 1 : 6,
                  );
                  if (value == null) return;
                  if (item.key.contains('timeout')) {
                    final n = int.parse(value);
                    if (n < 3 || n > 120) {
                      throw const FormatException('Use 3–120 seconds');
                    }
                  } else {
                    if (jsonDecode(value) is! Map) {
                      throw const FormatException('Expected JSON object');
                    }
                  }
                  await s.vault.write(item.key, value);
                  status = 'Saved. Connect / Test to refresh.';
                }),
              ),
            for (final kind in [
              'research',
              'embeddings',
              'stt',
              'image_generation',
              'video_generation',
            ])
              ExpansionTile(
                title: Text(kind.replaceAll('_', ' ')),
                children: [
                  ListTile(
                    title: const Text('Optional dedicated endpoint'),
                    onTap: () => run(() async {
                      final value = await ask(
                        context,
                        'Trusted HTTPS endpoint',
                        value: s.vault.read('$kind.endpoint') ?? '',
                      );
                      if (value == null) return;
                      endpoint(value);
                      if (!context.mounted) return;
                      if (!await confirm(
                        context,
                        'Trust provider?',
                        'This endpoint receives the configured key: $value',
                      )) {
                        return;
                      }
                      await s.vault.write('$kind.endpoint', value);
                      await s.vault.write('$kind.key', null);
                    }),
                  ),
                  ListTile(
                    title: const Text('Optional dedicated key'),
                    subtitle: Text(s.vault.mask('$kind.key')),
                    onTap: () => run(() async {
                      final v = await ask(
                        context,
                        'Provider API key',
                        secret: true,
                      );
                      if (v != null) {
                        await s.vault.write('$kind.key', v.isEmpty ? null : v);
                      }
                    }),
                  ),
                  ListTile(
                    title: const Text('Remove dedicated override'),
                    onTap: () => run(() async {
                      await s.vault.write('$kind.key', null);
                      await s.vault.write('$kind.endpoint', null);
                    }),
                  ),
                ],
              ),
            ListTile(
              title: const Text('Save encrypted connection profile'),
              onTap: () => run(() async {
                final name = await ask(context, 'Profile name');
                if (name == null || name.trim().isEmpty) return;
                final profiles =
                    jsonDecode(s.vault.read('profiles') ?? '{}') as Map;
                profiles[name] = {
                  'endpoint': s.vault.read('endpoint') ?? Gateway.builtIn,
                  'key': s.vault.read('key'),
                  'capabilities': s.vault.read('capabilities'),
                  'model_metadata': s.vault.read('model_metadata'),
                };
                await s.vault.write('profiles', jsonEncode(profiles));
              }),
            ),
            for (final name
                in (jsonDecode(s.vault.read('profiles') ?? '{}') as Map).keys)
              ListTile(
                title: Text('Use $name as default'),
                onTap: () => run(() async {
                  final profile =
                      (jsonDecode(s.vault.read('profiles')!) as Map)[name]
                          as Map;
                  for (final k in [
                    'endpoint',
                    'key',
                    'capabilities',
                    'model_metadata',
                  ]) {
                    await s.vault.write(k, profile[k]);
                  }
                  await s.gateway.connect();
                  status = 'Default connection: $name';
                }),
              ),
            ListTile(
              title: const Text('Export non-secret connection settings'),
              onTap: () => run(() async {
                final r = await s.files.save(
                  'nexus-connection.json',
                  utf8.encode(
                    jsonEncode({
                      'endpoint': s.vault.read('endpoint') ?? Gateway.builtIn,
                      'capabilities': s.vault.read('capabilities'),
                      'model_metadata': s.vault.read('model_metadata'),
                    }),
                  ),
                );
                await s.files.export(r);
              }),
            ),
            ListTile(
              title: const Text('Import non-secret connection settings'),
              onTap: () => run(() async {
                final f = await FilePicker.pickFile(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );
                if (f?.path == null) return;
                final file = File(f!.path!);
                if (await file.length() > 100000) {
                  throw const FormatException('Profile too large');
                }
                final profile = jsonDecode(await file.readAsString()) as Map;
                endpoint(profile['endpoint']);
                if (!context.mounted) return;
                if (!await confirm(
                  context,
                  'Trust imported gateway?',
                  profile['endpoint'],
                )) {
                  return;
                }
                await s.vault.write('key', null);
                for (final k in [
                  'endpoint',
                  'capabilities',
                  'model_metadata',
                ]) {
                  await s.vault.write(k, profile[k]);
                }
                status = 'Settings imported. Enter your key and connect.';
              }),
            ),
            ListTile(
              title: const Text('Reset vault'),
              onTap: () => run(() async {
                if (await confirm(
                  context,
                  'Reset vault?',
                  'All saved API keys and profiles will be removed. Chats remain.',
                )) {
                  await s.vault.reset();
                  exists = false;
                  advanced = false;
                }
              }),
            ),
          ],
        ],
        const Divider(height: 32),
        ListTile(
          title: const Text('Export backup'),
          subtitle: const Text(
            'Chats, projects and file metadata. No API keys.',
          ),
          onTap: () => run(() async {
            final r = await s.files.save(
              'nexus-backup.json',
              utf8.encode(await s.store.backup()),
            );
            await s.files.export(r);
          }),
        ),
        ListTile(
          title: const Text('Import backup'),
          onTap: () => run(() async {
            final f = await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: ['json'],
            );
            if (f?.path == null) return;
            final file = File(f!.path!);
            if (await file.length() > 50 * 1024 * 1024) {
              throw const FormatException('Backup too large');
            }
            await s.store.restore(await file.readAsString());
            status = 'Imported. Reimport attachment bytes separately.';
          }),
        ),
        if (busy) const LinearProgressIndicator(),
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(status),
          ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

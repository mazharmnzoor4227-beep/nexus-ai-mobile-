import 'package:flutter/material.dart';

void notice(BuildContext c, String s) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s)));
}

Future<void> guard(BuildContext c, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    if (c.mounted) {
      notice(
        c,
        e is FormatException || e is StateError
            ? e.toString()
            : 'Operation failed. Check your connection, permissions and input.',
      );
    }
  }
}

Future<String?> ask(
  BuildContext c,
  String title, {
  String value = '',
  bool secret = false,
  int lines = 1,
}) async {
  final controller = TextEditingController(text: value);
  final result = await showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: secret,
        maxLines: secret ? 1 : lines,
        enableSuggestions: !secret,
        autocorrect: !secret,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return result;
}

Future<bool> confirm(BuildContext c, String title, String message) async =>
    await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

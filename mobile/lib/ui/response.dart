import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';

class ResponseText extends StatelessWidget {
  final String text;
  const ResponseText(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final pattern = RegExp(r'```([^\n]*)\n([\s\S]*?)```|\$\$([\s\S]*?)\$\$');
    var at = 0;
    void prose(String value) {
      if (value.isNotEmpty) {
        children.add(
          MarkdownBody(
            data: value,
            selectable: true,
            onTapLink: (t, url, title) {
              final u = Uri.tryParse(url ?? '');
              if (u != null && ['https', 'http'].contains(u.scheme)) {
                launchUrl(u, mode: LaunchMode.externalApplication);
              }
            },
            sizedImageBuilder: (config) => Text(config.alt ?? 'Image link'),
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 16, height: 1.55),
            ),
          ),
        );
      }
    }

    for (final m in pattern.allMatches(text)) {
      prose(text.substring(at, m.start));
      at = m.end;
      if (m[3] != null) {
        children.add(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              m[3]!.trim(),
              textStyle: const TextStyle(fontSize: 17),
              onErrorFallback: (e) => Text(m[3]!),
            ),
          ),
        );
        continue;
      }
      final header = m[1]!.trim();
      final language = header.split(' ').first;
      final code = m[2]!;
      children.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xff121214),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      header,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy code',
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: code)),
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: HighlightView(
                  code,
                  language: language.isEmpty ? 'plaintext' : language,
                  theme: atomOneDarkTheme,
                  padding: const EdgeInsets.all(14),
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    prose(text.substring(at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

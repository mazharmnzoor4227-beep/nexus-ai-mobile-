import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'files.dart';

/// Inlines only local static assets from a validated ZIP. The WebView retains
/// its network-denying CSP and no native bridge. Dynamic imports stay blocked.
String bundleHtml(String entry, Map<String, Uint8List> entries) {
  String resolve(String from, String ref) {
    final uri = Uri.tryParse(ref);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        ref.startsWith('/') ||
        ref.contains('\\')) {
      throw const FormatException('External preview assets are disabled');
    }
    return safePath(
      p.posix.normalize(p.posix.join(p.posix.dirname(from), uri.path)),
    );
  }

  String source(String name) {
    final b = entries[name];
    if (b == null || b.length > 2 * 1024 * 1024) {
      throw const FormatException('Missing or oversized preview asset');
    }
    return utf8.decode(b);
  }

  String data(String from, String ref) {
    final name = resolve(from, ref), type = mime(name);
    if (!type.startsWith('image/')) {
      throw const FormatException('Unsupported inline asset');
    }
    final b = entries[name];
    if (b == null || b.length > 2 * 1024 * 1024) {
      throw const FormatException('Missing or oversized image');
    }
    return 'data:$type;base64,${base64Encode(b)}';
  }

  String css(String name) {
    return source(name).replaceAllMapped(
      RegExp(r'''url\(\s*["']?([^\s"')]+)["']?\s*\)'''),
      (m) {
        try {
          return 'url("${data(name, m[1]!)}")';
        } catch (_) {
          return 'url("")';
        }
      },
    );
  }

  var html = source(safePath(entry));
  html = html.replaceAllMapped(
    RegExp(
      r'''<script\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>\s*</script>''',
      caseSensitive: false,
    ),
    (m) {
      try {
        return '<script>${source(resolve(entry, m[1]!)).replaceAll('</script', '<\\/script')}</script>';
      } catch (_) {
        return '<!-- unavailable script -->';
      }
    },
  );
  html = html.replaceAllMapped(
    RegExp(
      r'''<link\b[^>]*\bhref\s*=\s*["']([^"']+)["'][^>]*>''',
      caseSensitive: false,
    ),
    (m) {
      try {
        final name = resolve(entry, m[1]!);
        return name.endsWith('.css') ? '<style>${css(name)}</style>' : '';
      } catch (_) {
        return '<!-- unavailable stylesheet -->';
      }
    },
  );
  html = html.replaceAllMapped(
    RegExp(
      r'''(<img\b[^>]*\bsrc\s*=\s*)["']([^"']+)["']''',
      caseSensitive: false,
    ),
    (m) {
      try {
        return '${m[1]}"${data(entry, m[2]!)}"';
      } catch (_) {
        return '${m[1]}""';
      }
    },
  );
  return html;
}

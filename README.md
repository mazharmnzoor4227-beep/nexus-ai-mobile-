# Nexus AI Mobile

Local-first Flutter Android 13–16 assistant based on the supplied Nexus prompt pack and Stitch UI. No API key or real gateway is bundled. A compiled APK is not proof that every production acceptance test has passed; see `docs/testing.md` for actual evidence and remaining limits.

## Build

Flutter 3.47.4, Java 17, Android SDK 36 and NDK 28.2.13676358.

```sh
cd mobile
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --debug --dart-define=UNIFIED_GATEWAY_BASE_URL=https://YOUR-REACHABLE-GATEWAY/v1
```

Replace the example with the owner's actual trusted HTTPS gateway. The uploaded pack does not supply this URL. A phone cannot reach a desktop FreeLLMAPI instance using `localhost:31415`. Unconfigured builds report this clearly and allow a password-protected developer override. Normal onboarding asks only for Unified API Key after master-password setup.

Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

## Implemented modules

- Stitch dark chat, history drawer, rounded composer, model/mode selection, projects and file/artifact library.
- SQLite local messages/history, search, drafts, pin/archive/rename/delete/duplicate/branch, JSON backup and metadata restore.
- Password-encrypted vault in Android Keystore-backed secure storage, biometric unlock, masked credentials, trusted connection profiles.
- Dynamic OpenAI-compatible model catalog, SSE streaming, first-token latency, stop, timeouts and one fallback before visible text.
- ZIP safety, bounded source retrieval, source edits, generated artifacts, unified patch and new ZIP export.
- Vision image/PDF pages, representative video frames, optional timestamped audio transcription.
- Image/video generation adapters with real async job history/resume, output validation, preview/download/share.
- Android voice typing and turn-based STT → streamed chat → TTS in English/Urdu/Hindi, silence detection, tap interruption, mute, speaker/earpiece, end and reconnect.
- Markdown, highlighted code, display math and isolated single-file HTML preview.

See [setup](docs/setup.md), [gateway contract](docs/gateway.md), [vault and security](docs/security.md), [architecture](docs/architecture.md), [tests](docs/testing.md), and [signing](docs/signing.md).

No mandatory backend, database, subscription or billing is activated. Providers require your own authorized key and may impose quotas/costs; the app does not promise unlimited free inference.

GitHub content writes currently return 403 from the connected integration. The user-supplied `nexus-ai-mobile-` repository is empty; a new `nexus-ai-mobile` repository has not been created by this session. Local commits/source can be published after access is corrected.

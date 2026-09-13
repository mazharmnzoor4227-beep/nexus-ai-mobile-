# Setup and Android phone checks

First supply the real trusted HTTPS gateway URL for build configuration. Your desktop localhost address cannot be used from a phone. For an unconfigured test APK, Settings → unlock vault → Developer / API Vault → master password → Gateway endpoint override. Normal onboarding remains a single Unified API Key field.

1. Install on Android 13–16; permit installation from the download source if Android requests it. Create/confirm a master password, enter your own key and Connect/Test. Check the model count.
2. Send Hi in Fast mode. Check immediate prompt echo, streaming, Stop, invalid-key error, timeout/fallback and network loss. No fake answer should appear.
3. Ask for a fenced HTML file with `filename=index.html`. Open, preview, edit, export and share it.
4. Create another chat; search, rename, pin/archive/restore, duplicate and branch. Force-stop/reopen and verify messages/drafts.
5. Import a small source ZIP. Ask about a file; open tree, edit, apply a generated artifact, export updated ZIP and inspect patch. Original remains intact.
6. Create a project with memory and files, add a chat and export. Export/import backup and verify no keys are included; reimport attachment bytes.
7. Test screenshot vision, PDF pages and a short video. With STT configured, verify timestamped transcript. Missing capability must fail explicitly.
8. Grant microphone permission, test typing and English/Urdu/Hindi voice conversation. Tap orb to interrupt; test mute, speaker/earpiece, reconnect, end, background/resume. Voice service availability depends on Android installations.
9. Enable biometrics, lock/unlock, test bad password cooldown, background for two minutes and verify vault lock.
10. Configure actual image/video adapters, generate and preview outputs, download/share, cancel where supported, interrupt and resume remote jobs. Resume must not start a second generation.

GitHub Actions is included but cannot run until repository Contents write access is granted and source is pushed. Then open repository → Actions → Android → Run workflow → enter public gateway URL, never an API key → completed run → APK artifact.

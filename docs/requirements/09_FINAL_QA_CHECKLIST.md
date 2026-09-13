# FINAL QA CHECKLIST

Do not claim completion until these work:

## App
- [ ] Splash works
- [ ] First launch setup works
- [ ] Vault password works
- [ ] Biometric works if enabled
- [ ] Unified Gateway connection test works
- [ ] Dynamic model list loads
- [ ] Fast/Auto/Coding modes work
- [ ] "Hi" streams without unnecessary 20s delay
- [ ] New chat works
- [ ] Chat history persists after restart
- [ ] Search chats works
- [ ] Rename/delete/pin works
- [ ] Attachment picker works
- [ ] ZIP analysis works
- [ ] Image analysis works
- [ ] Video analysis works
- [ ] Voice typing works
- [ ] Full voice conversation works
- [ ] Artifact preview works
- [ ] File download works
- [ ] Project export works
- [ ] Image generation works when provider configured
- [ ] Video generation works when provider configured
- [ ] Error/retry states work

## Security
- [ ] no plaintext API keys
- [ ] no secrets in Git
- [ ] no secrets in logs
- [ ] vault masked
- [ ] Android Keystore used
- [ ] ZIP-slip blocked

## Build
- [ ] flutter analyze passes
- [ ] tests pass
- [ ] APK builds
- [ ] APK installs
- [ ] smoke test passes

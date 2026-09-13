# Signing and updates

Debug builds use the generated Android debug certificate for testing. No private release signing key is provided or committed. To release, create/retain an owner-controlled keystore outside the repo, configure a release signingConfig using untracked key.properties or private environment values, and run flutter build apk --release with the real gateway URL.

Keep applicationId app.nexus.nexus_ai and the same signing certificate for updates; increment pubspec version/build. A different certificate cannot update an installed app. Export local backups before uninstalling to switch signing identity. Never commit signing keys, passwords, API keys or private credential backups.

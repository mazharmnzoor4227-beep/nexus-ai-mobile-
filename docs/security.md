# Vault and security

The app encrypts credential JSON using AES-256-GCM with random nonces and a PBKDF2-HMAC-SHA256 key (310,000 iterations, random salt). Encrypted material is held by Android Keystore-backed secure storage. A separate namespace stores biometric recovery only behind strong biometric authentication. The password is not stored. Five failed unlock attempts trigger a persistent increasing cooldown. Reset destroys saved keys/profiles; it does not delete local chats.

Create and confirm a master password of at least 12 characters, enter your Unified API Key, Connect/Test, then optionally enable biometrics. Lock manually or allow two minutes in the background. Developer settings require password reauthentication. Keys are masked and absent from ordinary backups, logs, prompts and source. FLAG_SECURE prevents normal screenshots. Each installation has its own credentials.

Chat history and attachments use app-private SQLite/files plus OS device encryption, not additional password encryption. Vault lock does not hide cached chats. Rooted/compromised devices are outside the protection guarantee. Backups are unencrypted JSON without secrets; attachment bytes must be exported separately.

ZIP protection rejects traversal/absolute/drive/null paths, symlinks, duplicate normalized names, encrypted/multipart/ZIP64 archives, >2,000 entries, >50 MB input, >10 MB per file, >100 MB expansion and suspicious compression ratios. Raw deflate output is bounded to declared size; local headers and CRC are explicitly verified. Uploaded source is never executed. Source retrieval excludes .env, private key formats and build/cache noise; secrets hidden in ordinary source are not guaranteed to be detected.

Documents/model output are untrusted input, explicitly separated in prompts. Models have no privileged execution tool. This mitigates but cannot prove elimination of prompt injection. PDF/video decoding is bounded and uses Android platform codecs; malformed formats may fail.

Authenticated endpoints require HTTPS and disable redirects. Generation output uses a separate client with no auth and DNS/IP restrictions against SSRF. Errors are sanitized. Scoped document export and read-only FileProvider sharing are implemented.

HTML preview allows inline JS/CSS only, with a restrictive CSP and no navigation, network, frames, forms or native bridge. Static ZIP website assets can be inlined under the same CSP. Dynamic imports and native build execution are not supported.

Physical biometric/microphone/export tests and a security review are required before production distribution; no security certification is claimed.

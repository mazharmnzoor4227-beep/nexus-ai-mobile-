# Architecture and current limits

Flutter UI uses local Store/Vault/Gateway/Files/Session/Voice services. Store is SQLite with kind/parent/creation indexes. Kotlin MainActivity provides scoped export/share, private-path validation, image resizing, PDF rasterization, video metadata and scene-change-ranked frames, audio-track extraction and output routing.

Chat persists the user turn immediately, prepares bounded reference context, routes confirmed capabilities, then streams and persists assistant text about every 650 ms. Restart marks unfinished streams interrupted. Retry and branch preserve message history semantics; generated fences become files associated with assistant messages. A project joins chats, memory and uploaded/generated files. ZIP edits export a new archive with a change summary and unified patch, preserving originals.

Generation stores a local job, then remote ID/status. Polling and output download can resume manually after interruption. Unknown progress is indeterminate, not simulated. Cloud generation requires compatible configured providers. Voice is continuous turn-based system STT, streamed chat and system TTS; tap interruption is supported, but simultaneous full-duplex acoustic echo cancellation/background wake words are not.

Practical implementation limits to retain in release reporting:

- Source retrieval uses filename/keyword chunks and optional real embeddings reranking when configured. At most 48 candidate chunks are embedded in batches of 16 and locally cached; cosine ranking selects six. It falls back to lexical retrieval if the optional provider fails.
- PDF vision uses up to eight representative pages; video uses scene-ranked samples from eight windows plus optional STT. Unsampled content may be missed.
- Default titles derive from the first prompt. Offline drafts/history work, but automatic outgoing queues and background model-health probes are not implemented.
- Proprietary provider APIs require normalized gateway adapters. A generic endpoint is not proof of native vendor compatibility.
- Single-file and static ZIP HTML previews inline local CSS/JS/images. Dynamic imports/external network dependencies remain blocked. External APK build orchestration is not implemented.
- Backup restores metadata, not attachment bytes. Generated APKs from arbitrary uploaded code are not compiled on the phone.

No production completeness claim should be made until the supplied acceptance checklist and real device/provider flows are verified.

# NEXUS AI — MASTER BUILD SPECIFICATION

You are acting as a Principal Android Engineer, Flutter Engineer, AI Systems Engineer,
Security Engineer, Backend/Local-Service Architect, DevOps Engineer and QA Engineer.

I am attaching:
1. This complete requirements ZIP.
2. A Google Stitch / UI structure ZIP containing the visual foundation.

Your job is to create a COMPLETE, WORKING, PRODUCTION-QUALITY Android AI assistant
application and an installable APK.

This is NOT a UI-only task.

Do not stop after creating mock screens, partial code, demo services or architecture
documents.

Continue implementing, testing, fixing build errors and rebuilding until a working
APK is produced.

---

## 1. PRODUCT VISION

Build a premium ChatGPT-style AI application for personal use and a very small number
of trusted friends/family.

The app must support:

- normal AI chat
- fast conversational responses
- deep reasoning
- professional coding assistance
- project / ZIP analysis
- image analysis
- video analysis
- image generation
- video generation
- deep research
- voice typing
- full two-way voice conversation
- file attachments
- chat history
- project workspaces
- downloadable generated files
- artifact previews
- model / mode switching
- local encrypted API vault
- a single unified AI gateway as the preferred setup
- optional individual provider keys
- free/open-source/free-tier-first operation
- GitHub repository containing the complete source code
- APK generation

The app should feel like a polished premium AI product, not a developer demo.

---

## 2. EXISTING UI

Use the attached Google Stitch/UI ZIP as the visual foundation.

Preserve the best parts of its visual identity:
- premium dark theme
- clean typography
- chat-focused layout
- polished sidebar/history
- rounded message composer
- voice conversation screen
- code/artifact cards
- minimal high-end spacing
- smooth transitions

Improve any missing or weak screens.

Remove all prototype-only data and fake interactions.

NO:
- dead buttons
- fake loading
- placeholder actions
- href="#"
- simulated AI replies
- fake download buttons

Everything visible must actually work.

---

## 3. ANDROID STACK

Preferred implementation:
- Flutter latest stable
- Dart
- Riverpod
- GoRouter
- Dio
- WebSocket and/or SSE
- Drift / SQLite
- flutter_secure_storage backed by Android Keystore
- biometric authentication
- file_picker
- image_picker
- audio recording/playback
- Markdown renderer
- syntax highlighting
- video_player
- Android scoped storage

Support Android 13, 14, 15 and 16.

---

## 4. CORE CONNECTION ARCHITECTURE

The application must be LOCAL-FIRST and BYOK.

There is no requirement for a large shared public SaaS backend.

Each installation belongs to its user.

Each user supplies their own API credential.

PRIMARY DEFAULT FLOW:

ANDROID APP
  -> Secure Local API Vault
  -> Preconfigured Hidden Unified Gateway Endpoint
  -> Unified API Key entered by user
  -> Multiple models/providers behind that gateway

NORMAL USERS MUST NOT BE ASKED FOR A URL.

The endpoint is part of app/build configuration.

Advanced connection settings may exist behind Developer / Advanced Settings only.

The app may also support optional direct individual providers.

## 5. UNIFIED GATEWAY MODE — CRITICAL

This is the preferred setup.

### NORMAL USER EXPERIENCE

Create a setup screen with only:

- Unified API Key

Button:
- Connect

After Connect:
- validate key
- discover models
- discover capabilities
- cache catalog
- select appropriate defaults automatically

DO NOT show Base URL to the normal user.

DO NOT require the user to type:
- URL
- localhost
- port
- /v1
- headers
- model prefixes

### INTERNAL GATEWAY CONFIGURATION

The application must contain a build-time configurable gateway endpoint.

Example build configuration:

UNIFIED_GATEWAY_BASE_URL=https://your-gateway.example.com/v1

This value must be configurable by the developer without changing application logic.

It must not be treated as a user secret.

For development/debug builds, allow changing the endpoint through an Advanced Developer
screen protected by the vault password.

The normal onboarding screen must never require it.

### CRITICAL NETWORK RULE

A desktop-local FreeLLMAPI instance such as:

http://localhost:31415/v1

cannot be reached from an Android phone by using `localhost`, because localhost on
Android means the phone itself.

Therefore the final app must use a reachable gateway endpoint, for example:
- a secure LAN address while on the same network,
- a secure remote/tunnel URL,
- a hosted gateway,
- or another reachable endpoint.

The normal user should still only enter the Unified API Key because the endpoint is
preconfigured in the APK/build config.

### STANDARD COMPATIBILITY

Support standard compatible endpoints such as:

GET /v1/models
POST /v1/chat/completions

and any additional capability endpoints advertised/configured by the gateway.

The app must dynamically load available models.

Do NOT hardcode the model list.

The app must support user-friendly modes:

- Auto
- Fast
- Smart
- Coding
- Reasoning
- Vision
- Research

A full Advanced Model Picker should also exist.

If the gateway exposes model metadata, inspect:
- modality
- context length
- tool support
- vision support
- generation type
- provider
- speed/latency hints when available

Cache model metadata locally and refresh it safely.

## 6. OPTIONAL INDIVIDUAL PROVIDERS

Also allow optional separate keys for:
- Groq
- Google Gemini / AI Studio
- OpenRouter
- Cerebras
- Cloudflare
- Cohere
- Ollama Cloud
- LLM7
- OpenCode
- Zhipu / GLM
- generic OpenAI-compatible endpoints
- STT providers
- TTS providers
- image generation providers
- video generation providers

These are OPTIONAL.

A user should not be forced to configure them if the Unified Gateway is sufficient.

---

## 7. SECURE LOCAL API VAULT

At the bottom of Settings add:

Developer / API Vault

Opening it must require:
- Master Password
- optional biometric unlock after setup

On first launch:
1. Create master password
2. Confirm password
3. Offer biometric unlock
4. Open AI Connection Setup

Store credentials encrypted locally.

Use Android Keystore to protect the encryption key.

Never store plaintext secrets in:
- source code
- GitHub
- logs
- unencrypted SQLite
- SharedPreferences
- resources
- strings.xml
- build config

After saving, display only masked secrets.

Example:
••••••••••4Kb5

Vault actions:
- Add/Replace Unified API Key
- Test Unified Gateway Connection
- Delete Key
- Disable Key
- Test Connection
- Advanced hidden endpoint override (developer-only)
- Set Default Connection
- Import connection profile without secret
- Export non-secret connection settings
- Reset Vault

Each APK installation must have its own independent credential vault.

---

## 8. PERFORMANCE — CRITICAL

The application must not feel slow like a router that waits 20-25 seconds for a
simple "Hi".

Performance target:
- local UI update: instant
- message appears immediately
- first visible "working" state: immediate
- simple chat first token: target ~1-3 seconds when upstream allows
- coding/reasoning can take longer, but streaming must begin as early as possible

Implement:
- streaming responses
- persistent HTTP connections
- connection pooling
- model metadata cache
- short connection timeout
- configurable first-token timeout
- cancellation
- provider/gateway health status
- circuit breaker
- automatic fallback
- avoid long sequential retry chains
- background health checks
- request deduplication where useful

For simple chat:
prefer the fastest healthy conversational model.

For coding:
prefer strongest healthy coding model.

For research:
prefer a tool-capable/research-capable model.

For vision:
use a vision-capable model.

Do not route "Hi" to a slow deep-reasoning model.

---

## 9. CHAT EXPERIENCE

Implement:
- New Chat
- Chat History
- Search Chats
- Pinned Chats
- Recent Chats
- Rename
- Delete
- Archive
- Duplicate
- Branch
- Export
- Share
- auto-generated titles
- timestamps
- model/mode used
- local caching
- persistence after restart

Message actions:
- Edit
- Retry
- Regenerate
- Stop
- Continue
- Copy
- Share
- Read Aloud
- Select Text
- Rate response

Rendering:
- Markdown
- tables
- lists
- links
- LaTeX
- syntax-highlighted code
- code copy button
- horizontal code scrolling
- images
- video previews
- file cards
- artifact cards

---

## 10. ATTACHMENTS

Support multiple attachments:

Images:
- JPG
- JPEG
- PNG
- WEBP
- GIF

Documents:
- PDF
- TXT
- MD
- DOCX

Code:
- common programming languages

Archives:
- ZIP

Media:
- MP4
- MOV
- WEBM
- MP3
- WAV
- M4A

Show:
- preview
- progress
- cancel
- retry
- size
- type
- upload status

---

## 11. ZIP / PROJECT ANALYSIS

ZIP support is essential.

When a project ZIP is attached:

1. Validate archive
2. Protect against ZIP-slip
3. Detect archive bombs
4. Extract to safe app-controlled workspace
5. Build directory tree
6. Detect languages/frameworks
7. Ignore build/cache/binary noise
8. Index source files
9. Let AI search relevant files
10. Let AI inspect related files
11. Allow bug analysis
12. Allow modifications
13. Track changed files
14. Generate diff summary
15. Repackage updated project
16. Allow preview
17. Allow final ZIP download/share

Do not blindly send the entire ZIP in one prompt.

Use retrieval/chunking.

---

## 12. IMAGE UNDERSTANDING

Image attachment features:
- preview
- pinch zoom
- screenshot analysis
- UI reconstruction
- OCR where useful
- visual debugging
- comparison
- vision-model routing

---

## 13. VIDEO UNDERSTANDING

Video pipeline:
- metadata extraction
- representative frame extraction
- scene-aware frame sampling
- audio extraction
- speech-to-text
- timestamped transcript
- combine transcript + key frames
- answer questions about video
- summary
- chapter/timeline view when useful

Do not blindly upload unsupported raw video to a text-only provider.

---

## 14. IMAGE GENERATION

Image generation must be a first-class feature.

Primary behavior:
- if Unified Gateway advertises image generation, use it

Fallback behavior:
- if gateway does not support image generation, allow optional image-provider key

UI:
- Prompt
- Aspect Ratio
- Number of Images
- Quality
- Style
- Generate
- Progress
- Cancel
- Retry
- Regenerate
- History
- Preview
- Download
- Share

Never fake generated results.

---

## 15. VIDEO GENERATION

Video generation must be first-class.

Primary behavior:
- use Unified Gateway if it exposes a compatible video generation capability

Fallback:
- optional configured video generation provider

UI:
- Prompt
- Optional image reference
- Aspect Ratio
- Duration
- Quality
- Generate
- Progress
- Queue status
- Retry
- Cancel if supported
- Preview player
- Download
- Share

Use asynchronous job handling.

States:
- queued
- processing
- rendering
- completed
- failed
- cancelled

---

## 16. DEEP RESEARCH MODE

Create a Research mode.

Research mode may use:
- gateway tool calling if supported
- configured web-search tool/API
- model-native search
- user-provided web source

It must:
- gather multiple sources
- avoid duplicate sources
- show source links
- summarize findings
- distinguish claims from evidence
- show research progress
- support stop/cancel

Do not pretend web access exists when no research/search tool is configured.

---

## 17. CODING MODE

Coding mode is a major feature.

Support:
- generate code
- analyze uploaded repository
- explain code
- refactor
- fix bugs
- create files
- modify files
- project tree
- diffs
- changed-file list
- code preview
- generated ZIP
- downloadable artifacts

For large projects:
- retrieve only relevant files
- maintain project context
- avoid resending the entire repo each turn

---

## 18. ARTIFACT SYSTEM

If AI creates:
- HTML
- CSS
- JS
- Python
- Java
- Kotlin
- Dart
- JSON
- Markdown
- text
- ZIP
- APK reference/build
- image
- video

create an Artifact Card.

Actions:
- Open
- Preview
- Edit
- Copy
- Download
- Share
- Save to Project
- Regenerate

HTML/CSS/JS:
- sandboxed preview

ZIP:
- show file tree
- size
- download

---

## 19. VOICE TYPING

Composer microphone:
- tap to start
- live transcript
- editable transcript
- Urdu
- Hindi
- English
- auto detect where possible
- permission handling
- clear listening state

---

## 20. FULL VOICE CONVERSATION

Use the existing Stitch voice-call screen as visual reference.

Implement real:
- continuous turn-based voice conversation
- VAD / silence detection
- STT
- LLM streaming
- TTS
- auto resume listening
- interrupt assistant while speaking
- mute
- speaker toggle
- end call
- transcript
- latency indicator
- reconnect

States:
- Listening
- Thinking
- Speaking
- Reconnecting
- Error

---

## 21. PROJECTS

Implement Projects:
- project name
- description
- chats
- uploaded files
- generated files
- artifacts
- memory/context

Actions:
- create
- rename
- archive
- delete
- search
- add chat
- add file
- export

---

## 22. LOCAL DATA

Use Drift/SQLite.

Store locally:
- conversations
- messages
- titles
- pinned state
- archive state
- projects
- settings
- model catalog cache
- attachment metadata
- artifacts
- usage history
- drafts

Offline:
- read cached chats
- write drafts
- queue outgoing work where practical

---

## 23. BACKUP / RESTORE

Provide:
- Export Backup
- Import Backup

Normal backup:
- chats
- projects
- settings
- attachments metadata

Do not include API secrets in ordinary backup.

Optional encrypted credential export may be offered separately.

---

## 24. DOWNLOAD MANAGER

Generated outputs must really download.

Support:
- ZIP
- images
- videos
- text
- code
- documents
- APK files returned by external build systems

Show:
- name
- size
- progress
- retry
- completed
- open
- share

Use Android scoped storage correctly.

---

## 25. SECURITY

Threat model and protect against:
- key extraction
- plaintext secret storage
- malicious ZIP
- ZIP slip
- archive bombs
- path traversal
- XSS in preview
- unsafe HTML
- SSRF
- malicious URLs
- huge uploads
- MIME spoofing
- prompt injection from documents
- leaking secrets into AI prompts
- unsafe logging
- replay
- brute-force vault unlock

Never execute arbitrary uploaded code directly on device/server without sandboxing.

---

## 26. FREE / ZERO-COST FIRST

The app is for personal use and a few trusted people.

Use free/open-source/on-device components whenever possible.

Do not require:
- paid backend hosting
- paid database
- paid auth
- paid object storage
- monthly subscription

Cloud services should be OPTIONAL.

If a paid API exists, it must only be used when the user explicitly supplies their
own key.

Do not automatically enable billing.

---

## 27. GITHUB

Use the connected GitHub account.

Create a new repository.

Recommended name:
nexus-ai-mobile

Repository should contain:
- Flutter source
- optional local companion service source
- provider adapters
- tests
- docs
- GitHub Actions
- .env.example where applicable
- build scripts
- architecture docs
- security docs

Never commit:
- real API keys
- passwords
- private signing keys
- encryption secrets
- user data

---

## 28. APK BUILD

The final output must include a working APK.

Run:
- flutter pub get
- flutter analyze
- flutter test
- Android build

Fix errors.

Repeat until APK builds.

Provide:
- debug APK
- release APK if signing is available
- otherwise clear release-signing instructions

---

## 29. TESTING

Test at least:
- first launch
- vault creation
- biometric unlock
- unified gateway setup
- models loading
- simple "Hi"
- streaming
- coding mode
- chat persistence
- ZIP upload
- image upload
- video upload
- voice permission
- voice conversation
- download
- fallback behavior
- provider timeout
- invalid key
- network loss
- restart persistence

---

## 30. FINAL DELIVERY

Return:
1. Complete GitHub repository
2. APK
3. source ZIP
4. README
5. setup guide
6. API vault guide
7. unified gateway setup guide
8. testing report
9. architecture doc
10. security doc
11. free-only usage notes

Do not stop at explanation.

Build the working product.

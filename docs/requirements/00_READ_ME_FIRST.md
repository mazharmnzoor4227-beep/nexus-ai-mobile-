# NEXUS AI — BUILD PROMPT PACK

Use this prompt pack together with the attached Google Stitch / UI structure ZIP.

## Goal

Build a complete premium Android AI assistant APK with:

- ChatGPT-style conversation UX
- fast streaming chat
- deep coding mode
- deep research mode
- ZIP/project analysis
- image understanding
- video understanding
- image generation
- video generation
- voice typing
- full voice conversation
- chat history
- projects
- artifacts
- previews
- downloads
- secure local API vault
- one primary unified AI gateway/API key
- optional separate provider keys
- GitHub repository with complete source code
- free/open-source/free-tier-first architecture

## Most Important Architecture Decision

The default onboarding must be **SINGLE-KEY MODE**.

### PRIMARY — Single Unified API Key Mode
The normal user should see only ONE field:

- Unified API Key

The app must already know the gateway endpoint internally from build-time/app configuration.

Do NOT ask the normal user for:
- Base URL
- port
- model prefix
- custom headers

Those belong only in a hidden Advanced/Developer override screen.

The user enters one Unified API Key and the app:
1. validates it against the built-in gateway endpoint,
2. discovers available models/capabilities,
3. loads them automatically,
4. enables chat/coding/research and any other capabilities actually exposed by that gateway.

### OPTIONAL — Advanced Provider Mode
Advanced users may optionally add separate provider keys or override the gateway endpoint.

A user must NOT be forced to configure many providers or URLs.

## Important Reality Rule

Do not assume every gateway exposes image generation or video generation through the
same endpoint.

Discover capabilities at runtime.

If the unified gateway exposes image/video generation, use it.

If it does not, keep image/video generation UI available but clearly show
"Provider not configured" until the owner adds an optional compatible generation API.

Never fake generation.

## How to use this pack

1. Read `01_MASTER_BUILD_SPEC.md` completely.
2. Read all supporting requirement files.
3. Inspect the attached Stitch/UI ZIP.
4. Create a new GitHub repository.
5. Implement the full application.
6. Build and test the APK.
7. Do not stop at mockups or sample code.

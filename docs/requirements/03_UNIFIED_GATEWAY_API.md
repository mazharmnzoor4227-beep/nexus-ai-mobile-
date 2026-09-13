# UNIFIED GATEWAY API REQUIREMENTS — SINGLE-KEY DEFAULT

The app's preferred setup is:

ONE hidden/preconfigured Gateway Base URL + ONE user-entered Unified API Key.

## Normal User UI

Settings
-> AI Connection

Show only:

- Unified API Key
- Connect / Test
- Connection Status

Do NOT show:
- Base URL
- port
- /v1
- custom headers
- model prefix

After a valid key is entered:
1. authenticate against the preconfigured gateway,
2. load models automatically,
3. discover capabilities,
4. enable supported features.

## Developer / Advanced Override

Behind:
Settings -> Developer / API Vault -> Advanced

Protect with vault password / biometric.

Only here may the developer see/edit:
- Gateway Base URL
- Custom Headers
- Model Prefix
- Endpoint override

This is for development/debugging only, not normal onboarding.

## Build-Time Configuration

Support a build configuration value such as:

UNIFIED_GATEWAY_BASE_URL

The APK is built with the intended reachable gateway URL.

The URL is not a user secret.

The user's Unified API Key remains encrypted in the local vault.

## Critical Android Networking Rule

Do not hardcode desktop `localhost`.

On Android:
`localhost` means the Android device itself.

A PC-hosted FreeLLMAPI service must be exposed through a reachable address before the
APK can use it.

The normal user should still only enter the key.

## Standard chat compatibility

Support:
GET {BASE_URL}/v1/models
POST {BASE_URL}/v1/chat/completions

Support streaming chat completions.

## Capability discovery

Do not assume every model has every capability.

Maintain capability metadata:
- chat
- coding
- reasoning
- vision
- tools
- research
- image-generation
- video-generation
- audio/STT/TTS if available

If gateway has no formal metadata:
- use model metadata endpoint if available
- use developer/admin overrides
- store capability tags locally

## Generation capability abstraction

ChatAdapter
ImageGenerationAdapter
VideoGenerationAdapter
STTAdapter
TTSAdapter
ResearchAdapter

Each adapter may point to:
- same unified gateway
- or an optional dedicated provider

A single user-facing Unified API Key should be enough when the configured gateway
supports all desired capabilities.

## Error handling

Recognize:
- 401 invalid key
- 403 denied
- 404 unsupported endpoint/model
- 408 timeout
- 429 quota/rate limit
- 5xx provider failure

Do not show raw internal stack traces to normal users.

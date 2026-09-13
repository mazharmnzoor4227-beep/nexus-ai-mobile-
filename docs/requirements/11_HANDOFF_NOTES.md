# HANDOFF NOTES

Attach BOTH:
1. Your Google Stitch / UI structure ZIP
2. This NEXUS AI Prompt Pack ZIP

Then send `10_SHORT_MESSAGE_TO_ASTRA.txt` as the short instruction.

The builder should use the Stitch ZIP for visual structure and this prompt pack for
functionality, architecture, security, performance and build requirements.

## Primary API setup expected in the final app

The normal owner/user flow must be:

Settings
-> AI Connection
-> Unified API Key

The user enters ONLY the Unified API Key.

The gateway endpoint must already be configured inside the application/build.

Do not ask the normal user for URL, port, `/v1`, headers or model prefix.

After the key is saved:
- test connection
- load models automatically
- discover capabilities
- choose default routing
- enable all supported features

A hidden Advanced endpoint override may exist under Developer / API Vault for debugging.

## Important

Do not assume a PC localhost URL works on Android.

The app must accept a configurable reachable gateway URL.

Examples:
- LAN URL
- secure remote URL
- tunnel URL
- hosted gateway URL

Never hardcode `localhost`.

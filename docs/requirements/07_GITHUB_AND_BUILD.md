# GITHUB + BUILD REQUIREMENTS

Use the connected GitHub integration.

Create a NEW repository:
nexus-ai-mobile

Recommended structure:

nexus-ai-mobile/
├── mobile/
├── docs/
├── tools/
├── tests/
├── .github/workflows/
├── .gitignore
└── README.md

If an optional local companion/backend service is implemented:
├── companion/
or
├── backend/

Never commit:
- real API keys
- master password
- Keystore secrets
- signing private keys
- user data

GitHub Actions:
- Flutter analyze
- tests
- Android debug APK build

Where possible:
- create GitHub Release
- attach APK artifact

The repository must contain enough source and documentation to rebuild the APK from
scratch.

# Security Policy

## Overview

Plotted is a local-only macOS app that visualizes completed Apple Reminders as a contribution heatmap. It is designed with a minimal attack surface and a strict privacy-first architecture.

## Privacy & Data Handling

| Principle | Detail |
|---|---|
| **No data leaves your Mac** | All reminder data stays in the local EventKit database. Nothing is uploaded, synced, or transmitted. |
| **Read-only access** | Plotted only reads completed reminders via EventKit. It never creates, modifies, or deletes reminders. |
| **No accounts or authentication** | There are no user accounts, logins, or tokens. |
| **No analytics or telemetry** | No usage tracking, crash reporting, or behavioral analytics of any kind. |
| **No network calls** | The only outbound network activity is Sparkle checking for app updates from this GitHub repository. |
| **Local storage only** | User preferences (daily goal, theme, streak freeze) and badge unlock dates are stored in local UserDefaults. |

## Update Security

Plotted uses [Sparkle](https://sparkle-project.org/) for auto-updates with the following protections:

- **EdDSA signature verification** — every update is signed with an EdDSA key. The app verifies the signature before installing. Tampered binaries are rejected.
- **HTTPS transport** — the appcast feed and download URLs use HTTPS exclusively.
- **Pinned feed URL** — updates are fetched only from this GitHub repository's raw `appcast.xml`.

## Permissions

Plotted requests a single macOS permission:

- **Reminders (read-only)** — required to read your completed reminders. Granted via the standard macOS permission prompt. Revocable at any time in System Settings → Privacy & Security → Reminders.

Optional:

- **Notifications** — used only for the weekly digest notification. Revocable in System Settings.

## Distribution & Code Signing

Plotted is distributed as a direct download from GitHub Releases. It is currently:

- **Signed** with an Apple Development certificate
- **Not notarized** (Apple Developer Program enrollment required)
- **Open source** — the full source code is available in this repository for inspection

Because the app is not notarized, macOS Gatekeeper will show a warning on first launch. Users must right-click → Open to bypass this. This does not indicate a security issue — it means Apple has not scanned the binary.

## Supported Versions

| Version | Supported |
|---|---|
| 1.3.x | ✅ |
| < 1.3.0 | ❌ |

## Reporting a Vulnerability

If you discover a security issue, please report it responsibly:

1. **Do not open a public GitHub issue.**
2. Use [GitHub Security Advisories](https://github.com/addobari/ReminderHeatmap/security/advisories/new) to report the vulnerability privately.
3. You will receive a response within 7 days.
4. A fix will be released as soon as possible, and you will be credited (unless you prefer anonymity).

## Security Audit Summary

Last audited: April 2026

- No high or medium severity issues identified
- No secrets or credentials in source code
- No user input surfaces susceptible to injection
- No network endpoints beyond Sparkle update checks
- All data remains local to the user's Mac

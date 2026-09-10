# Security Policy

## Supported versions

DiskUsage currently uses a source-only development model and has no published binary releases.

| Version | Supported |
| --- | --- |
| Current `main` | Yes |
| Older commits or forks | No |

Security fixes are applied to the current development branch. A versioned support policy will be defined when signed/notarized binary releases begin.

## Reporting a vulnerability

Use GitHub private vulnerability reporting for this repository when available. Do not disclose a suspected vulnerability, credential, signing material, token, private key, or other sensitive detail in a public issue, discussion, pull request, commit message, or workflow log.

Include the affected commit, reproduction steps, expected impact, and only the minimum logs or screenshots needed to reproduce the issue, with sensitive filesystem paths and secrets removed.

If private vulnerability reporting is unavailable, open a public issue containing no sensitive details and ask the maintainer to establish a private reporting channel.

## Triage process

- Initial acknowledgement target: within 3 business days.
- Initial severity and scope assessment target: within 7 business days.
- Valid reports are reproduced when practical and tracked privately until a fix or mitigation is available.
- Critical and high-impact issues are prioritized over feature work.
- Public disclosure should wait until affected users have a reasonable opportunity to update.

These are response targets, not a guarantee of a specific remediation date.

## Security scope

In scope:

- filesystem traversal and path handling;
- Trash operations and stale filesystem state;
- macOS privacy boundaries, TCC, Full Disk Access, entitlements, and code-signing configuration;
- dependency and build-toolchain risks introduced by this repository;
- GitHub Actions, required checks, secret exposure, and supply-chain integrity;
- future signing, packaging, release provenance, and update integrity when binary distribution is introduced.

Generally out of scope unless DiskUsage directly causes or amplifies the issue:

- vulnerabilities in macOS, GitHub, Xcode, or other third-party infrastructure;
- social engineering or phishing;
- denial-of-service requiring unrealistic local resource exhaustion;
- issues that require an already fully compromised user account or operating system and do not cross an additional DiskUsage trust boundary.

## Security model

DiskUsage intentionally minimizes attack surface:

- local-only operation with no backend, account, telemetry, advertising, or routine network access;
- Apple system frameworks only at runtime;
- user-controlled macOS Full Disk Access;
- destructive operations limited to moving the explicitly selected item to Trash;
- protected default branch and PR-based changes;
- SHA-pinned external GitHub Actions;
- least-privilege workflow permissions;
- CodeQL analysis for Swift and GitHub Actions;
- Gitleaks secret scanning;
- Dependency Review for dependency/workflow changes;
- Dependabot updates for GitHub Actions;
- CI build and regression-test gates.

Never commit signing identities, private keys, certificates with private material, API tokens, `.env` files, provisioning profiles containing sensitive material, or other credentials.

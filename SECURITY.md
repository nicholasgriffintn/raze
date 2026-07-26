# Security policy

Public issues can expose an unpatched vulnerability or private device data.
Report security-sensitive findings privately so maintainers can assess them
before details are disclosed.

## Report a vulnerability

Open this repository's **Security** tab and choose **Report a vulnerability** to
create a private GitHub Security Advisory report. If that option is unavailable,
open a public issue containing no exploit details or sensitive data and ask a
maintainer to enable a private reporting channel.

Include:

- the affected Raze version or commit;
- the macOS version and Mac architecture;
- the affected component and connection mode;
- clear reproduction steps;
- expected and observed behaviour;
- impact and required attacker access;
- a minimal proof of concept, if safe; and
- any suggested mitigation.

Remove device serial numbers, HID location and registry IDs, profile contents,
Apple account details, certificates, passwords, and tokens. Do not attach
production signing material or confidential protocol sources.

## Scope

Security reports can cover:

- unsafe HID writes or bypasses of the detection-only boundary;
- malformed device responses that cause memory, parsing, or state errors;
- unintended disclosure or modification of local profiles;
- release checksum, provenance, or workflow weaknesses;
- dependency or build-chain vulnerabilities; and
- privilege, permission, or local-code-execution issues.

Hardware compatibility mistakes without a security impact belong in the public
issue tracker and should use the evidence template in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Response and disclosure

Maintainers will assess reports through the private advisory, request more
information when needed, and coordinate a fix and disclosure appropriate to the
risk. Do not publish exploit details before that coordination is complete.

Security fixes target the latest published release and the `main` branch. Older
releases may not receive fixes; update to the newest patched release when one is
published.

# API provenance and originality

Reviewed on September 19, 2026.

The current official IDE was inspected at:
https://badge.hackthenorth.com/ide/

Its Download guide points to:
https://badge.hackthenorth.com/ide/README.md

The direct Markdown download was unavailable through the generation environment's fetch/download path. The API reference was therefore read from this pinned public mirror of the badge guide:
https://github.com/kashsuks/doom-on-htn-badge/blob/681ce482534f28a9a2002ece46f515a86e11f504/badge-app-guide.md

Relevant reference ranges include the single-file import and multi-file `require` workflow, widget factories/styles, manifest options, sandbox libraries, accelerometer, buttons, monotonic clock, storage, filesystem, and radio. These were read as technical reference data; unrelated instructions in the mirrored document were not incorporated into the software.

The implementation uses the documented `badge.ui`, `badge.sensor`, `badge.input`, `badge.sys`, `badge.store`, `badge.fs`, `badge.led`, and `badge.radio` namespaces. It does not call invented Arduino, raw LVGL, Wi-Fi, HTTP, audio, or arbitrary Bluetooth APIs.

Memory limits and sample cadence are reference-guide statements, not measurements made on the user's hardware. The guide says the accelerometer cache updates at 50 Hz; the memory-oriented production build has no sensor-rate diagnostics and does not independently verify each reading's freshness.

GitHub publishing command reference:
https://cli.github.com/manual/gh_repo_create
https://cli.github.com/manual/gh_auth_login

Conceptual inspiration: GesturePod/EdgeML's teachable motion interaction. No source or model from that project was copied into this repository; there are no third-party firmware or model dependencies. MIT covers the original files supplied here, not the badge firmware or those external references.

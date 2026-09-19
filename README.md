# Spellbound

Motion-controlled, teachable spellcasting duels for the Hack the North 2026 hacker badge.

The project lives in [`spellbound/`](spellbound/). Read the [project README](spellbound/README.md), [installation guide](spellbound/INSTALL.md), and [0.2.0 design pass](spellbound/docs/DESIGN_PASS.md). Use the low-memory modular package in `spellbound/dist/app/`. `main.lua` is a tiny lifecycle bootstrap; the physical build uses a 5-widget UI and 12 Lua files plus `manifest.cfg`, with lazy-loaded chunks kept at or below 4 KiB.

Run build/tests from the `spellbound/` directory. Desktop tests are included; physical badge validation remains outstanding, especially startup memory, native rendering, and radio behavior.

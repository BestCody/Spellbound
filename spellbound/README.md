# Spellbound

**Teachable, motion-controlled spellcasting duels for the Hack the North 2026 hacker badge.**

Hold A, perform a movement, and release to cast Fireball, Shield, or Recharge. Two badges run a host-authoritative match over the badge's restricted nearby radio channel. No phone, cloud account, external server, replacement firmware, microphone, or extra hardware is required by this implementation.

**Implementation status:** complete source and desktop tests are included. This version has **not been uploaded to or tested on a physical HTN badge**. Preset recognition thresholds are experimental, not measured human-gesture accuracy. Validate motion, memory, rendering, and radio on your two badges before demonstrating it.

## Start here

Use the prebuilt files; building on your computer is optional. Read **[INSTALL.md](INSTALL.md)** for the precise browser-IDE procedure. **This is a five-file app, not a standalone single-file import.** Import `dist/Spellbound-install.lua`, then add the three support modules from `dist/app` before pressing Push.

The modular layout is intentional: an early monolithic version exceeded a 96 KiB allocation limit in a 64-bit desktop Lua compile probe. Modules reduce the compilation peak. The final desktop compile/delayed-module-initialization probe does not establish physical badge RAM availability or callback timing.

## Implemented

- Explicit opponent discovery, invitation, accept/decline, and retrying pairing handshake.
- Host-authoritative health, mana, cooldowns, shields, delayed attacks, surrender, wins, and draws.
- Sequenced commands, duplicate suppression, state snapshots, acknowledgement retries, and disconnect cancellation.
- Button-delimited accelerometer capture; compact resampled templates; confidence and ambiguity rejection.
- Three conservative preset gesture rules; personalized training with three examples and a fourth validation attempt.
- Checked, two-slot local saves, with fallback when the active save is corrupt.
- Practice, diagnostics, a clearly labelled button-control mode, on-screen projectiles, and six-LED effects.
- Tests, reproducible builds, GitHub Actions configuration, and safe new-repository publishing scripts.

## Controls

| Context | Controls |
|---|---|
| Menus | UP/DOWN select; A opens; B returns |
| Motion casting | Hold A, move, release; aim for 0.3–2.4 seconds and a consistent starting pose |
| Button-control mode | LEFT Fireball; UP Shield; RIGHT Recharge |
| Switch control mode | START in the home menu, practice, or a duel; the footer shows the active mode |
| Surrender | Press B twice within 1.8 seconds during a duel |
| Teach | Select a spell; record three similar examples, then one fresh validation repetition; B cancels |
| LED brightness | AUX1 on the home menu cycles 24/64/128 out of 255 |
| Exit | HOME; settings are saved and LEDs/radio are cleaned up |

Use controlled handheld movements. Do not swing a badge by its lanyard. A rejected gesture consumes no mana and sends no cast. Accepted gestures can still be rejected by the host for insufficient mana or a cooldown.

## Rules

Both players begin with 100 health and 75 mana. Mana never exceeds 100.

| Spell | Mana | Cooldown | Effect |
|---|---:|---:|---|
| Fireball | 30 | 2.4 s | An incoming warning/projectile, then 25 damage after 1.8 s |
| Shield | 25 | 2.4 s | Blocks one attack landing during its 2.2 s window |
| Recharge | +35 | 3.0 s | Restores mana, capped at 100 |

These are editable design defaults in `src/engine.lua`, not tournament-tested balance. Attacks and shields resolve by host receipt/processing time. Guest countdowns approximate the host's timers; this implementation does not promise clock-perfect effects or latency-neutral competitive play.

## First demo

On both badges, open **Find a duel**. One person selects the other badge's short address code and presses A. The other accepts with A. First test the duel in button mode; then return to motion mode and use Practice/Teach to calibrate recognizable movements. Teach a distinct custom gesture, start another duel, and demonstrate it.

## Repository map

```text
manifest.cfg                 Runtime settings: API 2, 96 KiB, foreground wake lock
src/main.lua                 Lifecycle, UI, pairing/radio, capture, training flow
src/gesture.lua              Motion resampling, default rules, template classifier
src/engine.lua               Deterministic game rules and compact state encoding
src/model_codec.lua          Bounded binary model format and corruption detection
dist/app/                    The five files to install on each badge
dist/Spellbound-install.lua  Manifest + main-code starter; requires the modules
dist/Badge-check.lua         Optional standalone sensor/radio diagnostic
tests/                       Strict API mock and real-Lua automated tests
tools/build.py               Reproducible packaging (Python 3.10+, no dependencies)
tools/publish.ps1            Create/push a new GitHub repository from Windows
tools/publish.sh             Equivalent Bash publishing script
docs/                        Protocol, recognition, testing, and provenance
```

## Develop and test

From the repository root, with Python 3.10+ and Lua 5.3/5.4:

```sh
python tools/build.py
lua tests/run.lua
lua tests/install_smoke.lua
python tools/build.py --check
```

Use `lua5.4` or `texlua` in place of `lua` where appropriate. On Linux, an alternative with an installed Lua 5.4 shared library is `python tools/lua54_runner.py tests/run.lua`. None of these desktop tools are required to install the prebuilt app through the badge IDE.

## Publish to GitHub

The delivered archive is a local repository snapshot. **It has not been published to GitHub by the code generator.** After installing Git and GitHub CLI and signing in with `gh auth login`, run:

```powershell
.\tools\publish.ps1
```

This creates a **public** `spellbound` repository under the account authenticated in GitHub CLI and pushes the code. Use `-Visibility private` or `-Name another-name` to change those choices. The script refuses an existing repository name or an existing `origin`; it never force-pushes. On macOS/Linux use `bash tools/publish.sh spellbound public`.

## Limits and provenance

This is a friendly local game, not an authenticated or encrypted competitive protocol. MAC addresses and random match IDs prevent accidental cross-talk, not determined spoofing. Raw movement recordings and learned templates stay on the badge; personal badge IDs and names are not broadcast by the app.

GesturePod inspired the interaction concept. This repository contains **original Lua code and no copied GesturePod/EdgeML implementation or pretrained model**. The recognizer is a small template classifier, not a neural network. See [docs/SOURCES.md](docs/SOURCES.md) for API references, and [docs/HARDWARE_TEST.md](docs/HARDWARE_TEST.md) for the remaining physical validation.

MIT licensed; see [LICENSE](LICENSE).

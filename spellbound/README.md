# Spellbound

**Teachable, motion-controlled spellcasting duels for the Hack the North 2026 hacker badge.**

Hold A, perform a movement, and release to cast Fireball, Shield, or Recharge. Two badges run a host-authoritative match over the badge's restricted nearby radio channel. No phone, cloud account, external server, replacement firmware, microphone, or extra hardware is required by this implementation.

**Implementation status:** complete source and desktop tests are included. The physical competition build is the lazy modular package in `dist/app/`, with a sub-1 KiB production `main.lua` bootstrap and feature modules loaded only when needed. The app still needs physical validation for ESP32 memory/timing, rendering, radio reliability, and real gesture accuracy.

## Design pass 0.2.0

The badge-native pass adds clearer health/mana hierarchy, a separate notification area and control footer, shield/pending-command feedback, physically mapped LED effects with an off option, and lazy radio startup. Read [docs/DESIGN_PASS.md](docs/DESIGN_PASS.md) for changes, guide-derived constraints, and the remaining memory/hardware gates.

## Start here

Use the prebuilt **`dist/app/`** package and read **[INSTALL.md](INSTALL.md)** for the browser-IDE procedure. `main.lua` is intentionally tiny. The startup UI uses only three native widgets. On first **Teach** entry, Spellbound deletes the UI tree and loads the recognizer in physical-memory order: signature processing first, then capture, DTW/classification, and training. The badge's private `require()` cache cannot be cleared, so unused wrapper modules have been removed rather than pretending to unload them.

Readable source remains under `src/`, and `tools/build.py` reproducibly generates the modular runtime package. The legacy one-file importer is no longer generated.

## Implemented

- Explicit opponent discovery, invitation, accept/decline, and retrying pairing handshake.
- Host-authoritative health, mana, cooldowns, shields, delayed attacks, surrender, wins, and draws.
- Sequenced commands, duplicate suppression, state snapshots, acknowledgement retries, and disconnect cancellation.
- Button-delimited accelerometer capture; segmented, amplitude-normalized derivative templates; banded DTW; adaptive per-spell thresholds; and relative ambiguity rejection.
- Trained-template gesture recognition only; each spell must be taught with three examples and a fourth validation attempt.
- Taught gestures are session-only: reopening the app starts with fresh gesture models.
- Three-widget low-memory UI; HP and mana are rendered as compact text, while duel-only input/LED code loads only with multiplayer.
- Simplified six-LED spell/damage/victory effects.
- Tests, reproducible builds, GitHub Actions configuration, and safe new-repository publishing scripts.

## Controls

| Context | Controls |
|---|---|
| Menus | UP/DOWN select; A opens; B returns |
| Motion casting | Hold A, move, release. The A-hold may last up to 4.5 s; the recognizer trims idle and expects roughly 0.16–2.8 s of actual movement. Pauses, moderate speed/strength changes, and baseline offsets are normalized; keep a reasonably consistent badge orientation. |
| Surrender | Press B twice within 1.8 seconds during a duel |
| Teach | Select a spell; record three similar examples, then one fresh validation repetition; learned gestures last for the current app session |
| Exit | HOME; LEDs/radio are cleaned up |

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

On both badges, teach distinct custom gestures first. Then open **Find a duel** on both badges. One person selects the other badge's short address code and presses A; the other accepts with A. Cast by holding A, moving, and releasing.

## Repository map

```text
manifest.cfg          Runtime settings: API 2, 96 KiB, foreground wake lock
src/main.lua          Tiny lifecycle bootstrap
src/app.lua           Coordinator and lazy feature loader
src/core.lua          Shared state and low-cost helpers
src/ui.lua            UI creation, rendering, and LEDs
src/network.lua       Radio coordinator
src/net_rx.lua        Packet receive/handshake state machine
src/net_tick.lua      Discovery/retry/match tick
src/net_buttons.lua   Multiplayer button state machine
src/effects.lua       Duel-only LED effects
src/casting.lua       Motion capture coordinator
src/training.lua      Teaching, adaptive thresholds, diagnostics
src/gesture_sig.lua   Segmentation + normalized derivative signatures
src/gesture_dtw.lua   Banded DTW + classification
src/engine.lua        Deterministic game rules and compact state encoding
dist/app/             15-file low-memory modular runtime package
dist/Badge-check.lua  Optional standalone sensor/radio diagnostic
tests/                Strict API mock and real-Lua automated tests
tools/build.py        Reproducible modular packaging (Python 3.10+, no dependencies)
tools/publish.ps1     Create/push a new GitHub repository from Windows
tools/publish.sh      Equivalent Bash publishing script
docs/                 Protocol, recognition, testing, and provenance
```

## Develop and test

From the `spellbound/` project directory inside the GitHub checkout, with Python 3.10+ and Lua 5.3/5.4:

```sh
python tools/build.py
lua tests/run.lua
lua tests/design_pass.lua
lua tests/install_smoke.lua
lua tests/checker_smoke.lua
python tools/build.py --check
```

Use `lua5.4` or `texlua` in place of `lua` where appropriate. On Linux, an alternative with an installed Lua 5.4 shared library is `python tools/lua54_runner.py tests/run.lua`.

## Publish to GitHub

This project is already in `BestCody/Spellbound`. Do not run the new-repository publishing script when updating this repository. The commands below are only for publishing a separate new repository from an independent copy, with Git and GitHub CLI installed and `gh auth login` completed:

```powershell
.\tools\publish.ps1
```

This creates a **public** `spellbound` repository under the account authenticated in GitHub CLI and pushes the code. Use `-Visibility private` or `-Name another-name` to change those choices. The script refuses an existing repository name or an existing `origin`; it never force-pushes. On macOS/Linux use `bash tools/publish.sh spellbound public`.

## Limits and provenance

This is a friendly local game, not an authenticated or encrypted competitive protocol. MAC addresses and random match IDs prevent accidental cross-talk, not determined spoofing. Raw movement recordings and learned templates stay only in the current app session; personal badge IDs and names are not broadcast by the app.

GesturePod inspired the interaction concept. This repository contains **original Lua code and no copied GesturePod/EdgeML implementation or pretrained model**. The recognizer is a small template classifier, not a neural network. See [docs/GESTURE_RECOGNITION_DESIGN.md](docs/GESTURE_RECOGNITION_DESIGN.md) for the current recognizer design, [docs/SOURCES.md](docs/SOURCES.md) for API references, and [docs/HARDWARE_TEST.md](docs/HARDWARE_TEST.md) for physical validation.

MIT licensed; see [LICENSE](LICENSE).

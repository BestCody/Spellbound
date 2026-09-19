# Install Spellbound on two HTN 2026 badges

## Recommended: modular app

Spellbound's physical badge build is now the modular package in:

```text
dist/app/
├── manifest.cfg
├── main.lua
├── app.lua
├── core.lua
├── ui.lua
├── network.lua
├── net_rx.lua
├── net_tick.lua
├── casting.lua
├── training.lua
├── gesture.lua
├── gesture_sig.lua
├── gesture_dtw.lua
└── engine.lua
```

Do **not** use the old single-file importer. The physical badge was failing while
opening that build with a Lua memory-limit error, so the competition build keeps
the gesture recognizer and duel engine as separate modules.

## Put the modular app in the Badge IDE

1. Open https://badge.hackthenorth.com/ide/ in desktop Chrome or Edge.
2. Save any editor work you want to keep.
3. Make the editor's app manifest match `dist/app/manifest.cfg`.
4. Open the editor's `main.lua` and replace its contents with
   `dist/app/main.lua`.
5. In the editor's **Files** panel, use **+** to add each support module:
   `app.lua`, `core.lua`, `ui.lua`, `network.lua`, `net_rx.lua`,
   `net_tick.lua`, `casting.lua`, `training.lua`, `gesture.lua`,
   `gesture_sig.lua`, `gesture_dtw.lua`, and `engine.lua`.
6. Paste the matching file from `dist/app/` into each editor file.
7. Verify exactly **13 Lua files plus `manifest.cfg`** are present under the
   same app. Remove editor-only extras such as `README.md`; do not add
   `build-info.json` or `Badge-check.lua` to Spellbound.
8. Do **not** use **Import app** for support modules. Import app replaces the
   editor workspace; the **+** button adds a module to the current app.

The production `main.lua` is intentionally under 1 KiB. It loads only
`app.lua`. Runtime features are split into micro-modules so every lazy-loaded
Lua source chunk stays at or below 4 KiB, with GC steps between submodule loads.

## Upload to the first badge

1. Turn the badge off.
2. Connect it using a USB **data** cable.
3. Turn the badge on normally. **Do not hold START.**
4. Click **Connect** and choose **USB JTAG/serial debug unit** / Espressif.
5. Click **Push** and leave the cable connected until it finishes.
6. Reboot once after replacing an older Spellbound install.
7. Open **Spellbound** from the badge launcher with A.
8. Capture the first startup log and any `script_app` error.

Repeat the same editor setup/push process for the second badge.

## First hardware test

The first goal is to determine whether modular compilation fixes startup memory:

1. Open Spellbound on both badges.
2. Confirm there is no `Lua memory limit exceeded` error while opening it.
3. Open **Teach a spell** and train Fireball, Shield, and Recharge.
4. Open **Find a duel** on both.
5. One player sends an invitation; the other accepts.
6. Hold A, perform the trained movement, and release to cast.
7. Verify Fireball causes exactly one 25-HP hit after the warning.
8. Verify the trained Shield gesture blocks an incoming Fireball.
9. Verify the trained Recharge gesture restores mana.

If modular startup still fails, capture the exact startup log before removing
more gameplay features.

## Development layout

Readable source remains modular:

```text
src/main.lua
src/app.lua
src/core.lua
src/ui.lua
src/network.lua
src/net_rx.lua
src/net_tick.lua
src/casting.lua
src/training.lua
src/gesture.lua
src/gesture_sig.lua
src/gesture_dtw.lua
src/engine.lua
```

`tools/build.py` generates the physical package in `dist/app/` only. It also
removes the legacy `dist/Spellbound-install.lua` artifact if one is present.

Edit `src/`, not generated `dist/` files, then rebuild with:

```sh
python tools/build.py
```

## Troubleshooting

**A support module disappeared:** add it again with the **+** button in the
Files panel. Do not import it as a replacement app.

**No device in Connect:** use Chrome/Edge, a USB data cable, and close other
serial tools or IDE tabs.

**Push succeeds but Spellbound does not open:** copy the first console error.
Useful read-only console commands are `apps`, `heap`, and `uitree`.

**Lua memory limit exceeded:** capture the first error and pre-launch `heap`
output. The modular package exists specifically to avoid compiling the complete
game, recognizer, and engine as one large Lua chunk.

**Gesture fizzles:** the A-hold can last up to 4.5 seconds; leading/trailing idle is trimmed and the detected gesture itself should be roughly 0.16-2.8 seconds. The recognizer uses smoothed acceleration derivatives, per-gesture amplitude normalization, banded DTW, and a threshold learned from your three examples. If a physical test still fails, copy the `GESTURE ...` serial log lines so the class scores and learned threshold can be inspected.

Desktop tests cannot prove ESP32 compiler allocation, allocator headroom,
native rendering, radio reliability, or real gesture accuracy. Those still
require testing on the actual badges.

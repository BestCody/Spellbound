# Install Spellbound on two HTN 2026 badges

## Recommended: modular app

Spellbound's physical badge build is now the modular package in:

```text
dist/app/
├── manifest.cfg
├── main.lua
├── app.lua
├── gesture_dtw.lua
├── gesture_sig.lua
├── casting.lua
├── training.lua
├── network.lua
├── net_rx.lua
├── net_tick.lua
├── engine.lua
└── license.lua
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
5. In the editor's **Files** panel, use **+** to add each support file:
   `app.lua`, `gesture_dtw.lua`, `gesture_sig.lua`, `casting.lua`, `training.lua`,
   `network.lua`, `net_rx.lua`, `net_tick.lua`, `engine.lua`, and `license.lua`.
6. Paste the matching file from `dist/app/` into each editor file.
7. Verify exactly **11 Lua files (including comment-only `license.lua`) and
   `manifest.cfg`** are present under the
   same app. Remove editor-only extras such as `README.md`; do not add
   `build-info.json` or `Badge-check.lua` to Spellbound.
8. Do **not** use **Import app** for support modules. Import app replaces the
   editor workspace; the **+** button adds a module to the current app.

The production `main.lua` is intentionally under 1 KiB. It initializes Bluetooth
before loading `app.lua`, so the native HCI buffers are reserved before the Lua
application can fragment the remaining heap. `app.lua` itself requires no startup
support module. Every lazy-loaded
feature chunk stays at or below 4 KiB after conservative production compaction.
On first Teach/Find-a-duel entry, the one-label UI is deleted before compilation.
Teach adds exactly `gesture_dtw.lua`, `gesture_sig.lua`, `casting.lua`, and
`training.lua`. Opening Duel adds `network.lua`, `net_rx.lua`, and
`net_tick.lua`; `engine.lua` is deferred until the user sends or accepts a
challenge. The badge's private `require()` cache cannot be cleared, so these modules
are side-effect installers rather than cached export tables.

## Transfer Spellbound to another badge

Use the badge's **Share** app for a badge-to-badge transfer. On the sender, open
**Share → Send an app → Spellbound → A: offer app** and leave that screen open.
On the receiver, open **Share → Receive an app**, review the offer, and press A
once. Keep both badges close until validation and installation finish. Share
transfers the complete app directory and verifies its CRC.

Do **not** use the IDE's **Download app** file by itself to give Spellbound to
someone. That export does not contain the extra Lua modules or `license.lua`.
For a computer-to-computer handoff, send the complete `dist/app/` directory as
one archive and require the recipient to replace all files together.

Before sharing from a badge that received older development builds, confirm its
Spellbound directory contains exactly the 12 files listed above. IDE Push does
not remove obsolete remote files. In particular, old `core.lua`, `effects.lua`,
`gesture.lua`, `net_buttons.lua`, `ui.lua`, an old `LICENSE.txt`, or an unwanted `icon.bin` must not be
left in the shared directory. Inspect first and remove only those exact obsolete
Spellbound files. Version 0.4.0 also rejects mixed generated modules with an
explicit reinstall error instead of remaining on `Loading...`.

Both badges should run the same current badge firmware before transfer and play.
If a recipient gets a callback deadline error, update the firmware and reinstall
the complete 12-file app directory before diagnosing Spellbound itself.

## Upload to the first badge

1. Turn the badge off.
2. Connect it using a USB **data** cable.
3. Turn the badge on normally. **Do not hold START.**
4. Click **Connect** and choose **USB JTAG/serial debug unit** / Espressif.
5. Click **Push** and leave the cable connected until it finishes.
6. Reboot once after replacing an older Spellbound install.
7. Open **Spellbound** from the badge launcher with A. Bluetooth initialization
   now occurs before the Home screen; no `hci inits failed` or `nimble host init
   failed` line should appear.
8. Capture the first startup log and any `script_app` error.

Repeat the same editor setup/push process for the second badge.

## First hardware test

The first goal is to verify the proposed 40 KiB device target through the full workflow:

1. Reboot, run `heap`, then open Spellbound.
2. Run `heap` again and confirm the one-widget home screen launches.
3. Enter **Teach a spell**, return to the console, and record the external `heap`/app statistics.
4. Train Fireball, Shield, and Recharge.
5. Return home, open **Find a duel**, and record the external statistics again.
6. One player sends an invitation; the other accepts.
7. Hold A, perform the trained movement, and release to cast.
8. Verify Fireball causes exactly one 25-HP hit after the warning.
9. Verify the trained Shield gesture blocks an incoming Fireball.
10. Verify the trained Recharge gesture restores mana.
11. Recheck after a maximum-length recording and repeated matches; Lua used/peak must remain at or below 40 KiB for the target to be accepted.

If modular startup still fails, capture the exact startup log before removing
more gameplay features.

## Development layout

Readable source remains modular:

```text
src/main.lua
src/app.lua
src/gesture_dtw.lua
src/gesture_sig.lua
src/casting.lua
src/training.lua
src/network.lua
src/net_rx.lua
src/net_tick.lua
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

**Gesture fizzles:** the A-hold can last up to 4.5 seconds; leading/trailing idle is trimmed and the detected gesture itself should be roughly 0.16-2.8 seconds. The recognizer uses smoothed acceleration derivatives, per-gesture amplitude normalization, banded DTW, and a fixed acceptance threshold. Production gesture diagnostics were removed to preserve memory, so record the visible error and exact movement/hold timing when reporting a physical failure.

Desktop tests cannot prove ESP32 compiler allocation, allocator headroom,
native rendering, radio reliability, or real gesture accuracy. Those still
require testing on the actual badges.

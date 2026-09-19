# Install Spellbound on two HTN 2026 badges

## Recommended: one-file import

Spellbound now ships as a **true single-file Hacker Badge app**:

```text
dist/Spellbound-install.lua
```

That file contains the manifest, main game, gesture recognizer, and duel engine.
You do **not** need to add support modules manually in the Badge IDE.

## Upload to the first badge

1. Open https://badge.hackthenorth.com/ide/ in desktop Chrome or Edge.
2. Save any current editor work you want to keep.
3. Click **Import app**.
4. Choose `spellbound/dist/Spellbound-install.lua` from your repository checkout.
5. Confirm the preview shows slug `spellbound`.
6. Click **Replace editor files**.
7. Turn the badge off.
8. Connect it using a USB **data** cable.
9. Turn the badge on normally. **Do not hold START.**
10. Click **Connect** and choose **USB JTAG/serial debug unit** / Espressif.
11. Click **Push** and leave the cable connected until it finishes.
12. If an older Spellbound install used different manifest runtime options,
    click **Reboot** once after pushing.
13. Open **Spellbound** from the badge launcher with A.

Repeat the same import/push process for the second badge.

**Import** changes the browser workspace. **Push** is what writes the app to the
badge.

## First hardware test

Teach the gestures first, then test the duel:

1. Open Spellbound on both badges.
2. Open **Teach a spell** and train Fireball, Shield, and Recharge.
3. Open **Find a duel** on both.
4. One player sends an invitation; the other accepts.
5. Hold A, perform the trained movement, and release to cast.
6. Verify Fireball causes exactly one 25-HP hit after the warning.
7. Verify the trained Shield gesture blocks an incoming Fireball.
8. Verify the trained Recharge gesture restores mana.

## Development layout

Readable source remains modular:

```text
src/main.lua
src/gesture.lua
src/engine.lua
```

`tools/build.py` generates both:

- `dist/app/` — modular development/runtime copies.
- `dist/Spellbound-install.lua` — the complete one-file Badge IDE import.

Edit `src/`, not generated `dist/` files, then rebuild with:

```sh
python tools/build.py
```

## Troubleshooting

**Import error:** make sure you selected `dist/Spellbound-install.lua`, not a
source module.

**No device in Connect:** use Chrome/Edge, a USB data cable, and close other
serial tools or IDE tabs.

**Push succeeds but Spellbound does not open:** copy the first console error.
Useful read-only console commands are `apps`, `heap`, and `uitree`.

**Lua memory limit exceeded:** capture the first error and the pre-launch
`heap` output. The 96 KiB Lua setting is a quota ceiling, not guaranteed free
physical RAM. A single-file build is easier to install but may have a higher
compile-time peak because all code is parsed in one chunk.

**Gesture fizzles:** use Teach to train deliberate
0.3-2.4 second movements with a consistent starting pose.

Desktop tests cannot prove ESP32 timing, allocator headroom, radio reliability,
or real gesture accuracy. Those still require testing on the actual badges.

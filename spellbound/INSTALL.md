# Install Spellbound on two HTN 2026 badges

## Canonical package

Install the complete `dist/app/` directory:

```text
manifest.cfg
main.lua
app.lua
gesture_dtw.lua
gesture_sig.lua
casting.lua
training.lua
network.lua
net_rx.lua
net_tick.lua
net_ui.lua
apply.lua
license.lua
```

That is exactly 13 files: 11 runtime Lua files, the manifest, and the comment-only MIT notice. Do not use the retired one-file importer.

## Put it in the Badge IDE

1. Open <https://badge.hackthenorth.com/ide/> in desktop Chrome or Edge.
2. Make the app manifest match `dist/app/manifest.cfg` and replace the editor's `main.lua` with `dist/app/main.lua`.
3. In **Files**, use **+** to add every other Lua file listed above, then paste its matching generated content.
4. Remove extras. Do not put `README.md`, `build-info.json`, or `Badge-check.lua` inside the app.
5. Verify all 13 names before Push.

Do not use **Import app** to add a support module: it replaces the editor workspace. The IDE's **Download app** export is also not a complete Spellbound transfer because it can omit support modules.

Production `main.lua` initializes Bluetooth before compiling `app.lua`, preserving the largest contiguous native block for HCI/NimBLE. Startup then holds one UI label. First Teach entry loads `gesture_dtw`, `gesture_sig`, `casting`, and `training`. First Duel entry removes the label and loads `net_rx`, `net_ui`, `apply`, `net_tick`, and `network` largest-first. Match start and radio receive perform no module compilation. Every lazy generated chunk stays within 4 KiB.

## Replace an older installation atomically

SB2 and ABI 5 are incompatible with earlier builds. Replace all 13 files together on both badges. Never mix a new `app.lua` with old support modules or the reverse.

IDE Push does not remove obsolete remote files. In the Spellbound app only, remove stale `core.lua`, `codec.lua`, `effects.lua`, `engine.lua`, `gesture.lua`, `net_buttons.lua`, `ui.lua`, `LICENSE.txt`, and unwanted `icon.bin` if present. Check exact names and do not delete anything outside the Spellbound directory. Current mixed generated modules stop with a reinstall error instead of hanging at Loading.

The package has three spare slots under Share's 16-file limit, but stale files can still break transfer or leave conflicting code.

## Transfer to another badge

Prefer badge-to-badge **Share**:

1. Sender: **Share → Send an app → Spellbound → A: offer app**.
2. Receiver: **Share → Receive an app**, inspect the offer, and press A once.
3. Keep badges close until validation and installation finish.

For computer handoff, archive and send the complete `dist/app/` directory. Badge Share or an exact archive preserves every module and `license.lua`; the IDE's standalone download does not.

Both players must run this same release and current badge firmware.

## Upload to the first badge

1. Power the badge off, attach a USB data cable, and turn it on normally without holding START.
2. Click **Connect** and select the Espressif USB JTAG/serial debug unit.
3. Click **Push** and leave the cable connected until completion.
4. Reboot once after replacing an older Spellbound installation.
5. Launch Spellbound. Bluetooth should initialize before Home without `hci inits failed`, `nimble host init failed`, or `ESP_ERR_NO_MEM`.

Repeat the same complete package on the second badge.

## First hardware acceptance

Desktop profiling reports a 37,857-byte trained-match allocator-cap delta from Home; the worst profiled stage is a 37,963-byte maximum capture. CI gates every scenario at 38,000 bytes. This is not an ESP32 measurement. Verify the physical 40 KiB goal through the complete flow:

1. Record firmware `heap`/app statistics before launch and on Home.
2. Enter Teach and train Fireball, Shield, and Recharge with one example plus one fresh test each.
3. Return Home, open Find a duel, invite/accept, and play.
4. Confirm Fireball lands once for 25 HP, Shield blocks, Recharge restores mana, and surrender/rematch work.
5. Measure during a maximum-length recording and after repeated matches.
6. Reject the memory target if any observed Lua current/peak value exceeds 40 KiB.

The app performs no internal memory or gesture diagnostic logging; use external firmware statistics.

## Development

Edit files under `src/`, then regenerate `dist/app/`:

```sh
python tools/build.py
```

Run the full validation commands in `docs/TESTING.md` before transfer.

## Troubleshooting

**Missing support module:** add it with **+** in Files and replace the complete package; do not import it as another app.

**No serial device:** use Chrome/Edge, a USB data cable, and close other serial tools or IDE tabs.

**App does not open:** capture the first console error. Safe read-only commands include `apps`, `heap`, and `uitree`.

**Lua memory limit exceeded:** record the first error and pre-launch heap state. Do not raise the quota or remove unrelated apps as a substitute for meeting the target.

**Gesture rejected:** hold A for at most 4.5 seconds; active motion should be roughly 0.16-2.8 seconds. Use a consistent orientation and distinct gestures. No rejected gesture spends mana.

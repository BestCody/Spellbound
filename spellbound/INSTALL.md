# Install on two HTN 2026 badges

## Files you need

`dist/app/` contains exactly these five runtime files:

```text
manifest.cfg
main.lua
gesture.lua
engine.lua
model_codec.lua
```

**All five are required.** `dist/Spellbound-install.lua` combines only the manifest and main file for the IDE's Import app button. It does not embed the modules. Do not upload the repository, tests, publishing scripts, or documentation to the badge.

## Updating to design pass 0.2.0

Use the same five files and slug. Replace `main.lua`, all three modules, and the manifest with the current `dist/app` versions (or import the starter and add the modules again). Save editor work first. Personal gesture files under `appdata/` are not part of this upload; do not delete them.

A fresh launch keeps Bluetooth off until **Find a duel**. AUX1 on the home menu now cycles OFF/64/160/255. The control mode is in the header; notifications do not replace the bottom casting instructions. In Diagnostics, A logs memory/firmware information. See `docs/DESIGN_PASS.md` before relying on the desktop memory probe.

## Current badge IDE

1. Open https://badge.hackthenorth.com/ide/ in desktop Chrome or Edge. Save existing editor work before replacing it.
2. Choose **Import app** and select `dist/Spellbound-install.lua`. Confirm slug `spellbound` and **Replace editor files**.
3. Use **+** in the files panel to add `gesture.lua`. Paste the complete contents of `dist/app/gesture.lua`. Repeat for `engine.lua` and `model_codec.lua`, using those exact names. These are ordinary Lua files, not manifest-wrapped imports. Do not click Import app separately for each module, because that replaces the workspace.
4. Confirm the editor contains `manifest.cfg`, `main.lua`, and the three modules. `README.md` may also be present in the IDE and is not uploaded.
5. Turn the badge off, connect a USB **data** cable, then turn it on normally. **Do not hold START while connecting.** Close other applications/tabs using the same serial port.
6. Choose **Connect**, then **USB JTAG/serial debug unit** (possibly labelled Espressif). Choose **Push** and keep the cable connected until the upload finishes.
7. The manifest requests `api=2`, `heap_kb=96`, and `wake_lock=1`. If replacing an existing `spellbound` install with different runtime manifest options, **Reboot** after uploading; reopening alone does not refresh all runtime settings.
8. Open Spellbound from the badge launcher with A. Repeat on the other badge.

The IDE is an uploader/editor, not a badge simulator. Import changes its workspace; Push changes files on the badge. The app must remain open on both badges during play.

## Older IDE without Import app

Set the existing `manifest.cfg` editor to the contents of the repository's `manifest.cfg`. Set `main.lua` to `dist/app/main.lua`. Add the three support modules with **+**, as above. Then Connect and Push. Do not paste the combined import file into only `main.lua`, since that does not update the manifest.

## Verify before using motion controls

Open Find a duel on both badges, invite from only one, and accept on the other. Press START to enter button mode. LEFT casts Fireball, UP casts Shield, and RIGHT restores mana. Establish working radio/game rules before debugging recognition.

Switch back with START. Use Practice to test motions and Teach to record personal templates. Begin with deliberate, distinct gestures, keep the same starting pose, and pause briefly at the start of the A hold. The preset rules were evaluated only on synthetic motion fixtures, not recorded participants.

## Optional small hardware checker

`dist/Badge-check.lua` is a separate, standalone single-file app with slug `spellbound_check`. Import and Push it on each badge to inspect sensor values and send a small radio ping with A. A successful transmit means queued; the **other badge's RX display** is the delivery check. Exit and restore the Spellbound workspace afterward. This checker is independent of the five-file game.

## Problems

**Module not found:** verify the exact three filenames in the IDE before Push. Reimporting a module as an app replaces the workspace; use + instead.

**Radio unavailable:** HOME, allow the badge to return/reboot, and reopen. Record the firmware version and the first console error. USB upload success is not evidence of functioning radio.

**Lua memory/startup error:** collect `heap` in the IDE console before launching and copy the first error. The 96 KiB manifest value is a quota, not reserved system memory. A reboot may reduce fragmentation, but does not prove the app fits. Installed files occupy flash; deleting unrelated inactive apps is not a general RAM fix.

**Gesture fizzles:** use a slower/clearer movement within 0.3–2.4 seconds, maintain the starting pose, or train the spell. Use button mode to separate radio problems from recognition problems.

**Changes/s looks low:** it counts changes in the cached accelerometer values observed by the app, not confirmed fresh sensor samples. Stationary readings can repeat.

**Bad display or timeout:** capture firmware version, which screen/action failed, and the first traceback. No physical display/timing validation was possible during generation.

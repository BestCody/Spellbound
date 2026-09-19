# Badge-native design pass — 0.2.0

This pass applies the supplied **Agent instructions: create a Hacker Badge app in the IDE** to the existing Spellbound game. The guide is the basis for hardware/API constraints; the palette, layout, light patterns, and copy are Spellbound design choices, not requirements quoted from the guide.

## Display and interaction

The app still uses only documented widgets at integer positions on a 320x240 screen. It creates 18 widgets once and reuses them. There are no external images, canvas calls, touch handlers, audio features, or extra runtime modules.

The duel now separates **YOU HP / FOE HP** from their respective **MANA** values and tracks. Violet denotes the local player, gold the opponent, and teal denotes mana. This remains local-player-relative on both host and guest badges. Labels and health/mana bars update when their displayed values change.

The main action/status line, two-line notification area, and physical-button footer occupy separate regions. A spell result or error no longer replaces the instructions for casting or going back. Text has been shortened and the non-duel body changed to 16-pixel type to give Teach, Teach, and Diagnostics more room.

Incoming attacks take display priority over recording. A shield covering the known landing time shows **SHIELD READY TO BLOCK**, rather than asking the player to cast another shield. An observed attack resolution without damage produces **BLOCKED** feedback. This feedback follows received host state; it is not a new exact-clock or authenticated event protocol.

A guest command awaiting acknowledgement shows **CAST QUEUED - WAIT**. Button-mode practice says **test cast**, not **recognized**. The latter is reserved for a movement accepted by the recognizer. Invitation copy says **queued**, not delivered. The short address shown is a radio code, not the badge's provisioned identity or a security credential.

## LEDs and brightness

The supplied guide's front-view mapping is used: left side top-to-bottom is **1, 6, 5**; right is **2, 3, 4**. During an otherwise idle duel, the left side represents local health and the right side opponent health in three coarse steps. Always use the screen for exact health values.

| State | Light behavior |
| --- | --- |
| Home / practice idle | Violet breathing. |
| Looking for or pairing with a player | Cyan perimeter chase; this indicates activity, not confirmed delivery. |
| Recording | Amber bottom-to-top progress pairs. |
| Accepted Fireball / unprotected incoming attack | Orange upward / downward paired sweeps. |
| Shield or observed block | Cyan-blue breathing. |
| Recharge | Green upward paired sweep. |
| Damage / rejected movement | Red / amber event feedback. |
| Win | Gold perimeter chase. |
| Other result | Muted warm breathing. |



Frames are timestamp-driven, scheduled no faster than every 50 ms, overwrite all six positions, and latch with one `show()`. A delayed callback skips frames rather than replaying a catch-up loop. These are visual game cues, not a promise of exact light output or timing on a real badge. HOME clears and shows the strip. Returning to the menu clears stale result messages/effects.

## Runtime and memory

Bluetooth starts on **Find a duel**, not at app launch. A fresh session can use Teach without starting Bluetooth. Once enabled, it stays enabled for that foreground session; returning to the in-app home menu is not the same as exiting via HOME. Startup failure leaves non-radio modes available and asks for a normal exit/reopen.

Only Diagnostics performs its extra observed-reading counts. It compares numeric cached values rather than constructing a diagnostic string every 20 ms during every mode. Its display refreshes every 500 ms. **Changed values per second are not measured sensor sample Hz.** A logs firmware, Lua usage/limit/peak, native widget count, and free system heap once to the IDE console.

The production `main.lua` is now only a lifecycle bootstrap. Startup loads the small coordinator/core/UI path first, while network, casting, gesture recognition, and game-engine chunks are deferred until the corresponding feature actually needs them, with incremental garbage-collection steps between module installs. The default HOME exit is retained; no confirmation dialog silently pauses ticks while multiplayer time continues. Settings are written on a normal exit, not every frame; learned templates keep the existing validated journal save flow.

### Important memory limitation

The desktop compile/module probe passes its 96 KiB cap, but is extremely close to that cap. It intentionally **does not create the UI handles/caches, enable BLE, load saved player templates, or run a complete match**. The small C callback added to the probe approximates the documented incremental GC binding; it does not reproduce the device collector's work or timing. This is not evidence that the complete app fits in a physical badge's available RAM.

Do not merge or demonstrate on the strength of the desktop memory number alone. Upload the app, inspect the first startup error and `heap` output if one occurs, and measure after opening multiplayer and training all three spells. Reducing complexity further may be necessary after those measurements.

## Packaging and validation

The slug remains `spellbound`. The physical package contains nine files in `dist/app/`: `manifest.cfg` plus eight Lua modules. The production `main.lua` is kept below 2 KiB by the build contract, and the current clean bundle remains below the guide's 48 KiB Share bundle ceiling.

The lazy modular installation is the canonical competition build. Physical testing showed both the flattened importer and the earlier ~22 KiB `main.lua` layout could exhaust Lua allocation headroom while loading another chunk. The Badge IDE Files panel must therefore contain every runtime module alongside the tiny `main.lua`; Import app is not used to add those modules.

Run the core Lua tests, the design regressions in `tests/design_pass.lua`, the manifest-contract tests, the modular production/checker smoke tests, and `tools/build.py --check`. The build now rejects duplicate manifest keys, invalid heap settings, and conflicting HOME options before creating an installer. Physical validation remains unperformed. Inspect actual text wrapping, LED effects use a fixed competition brightness.

# Badge-native design pass — 0.2.0

This pass applies the supplied **Agent instructions: create a Hacker Badge app in the IDE** to the existing Spellbound game. The guide is the basis for hardware/API constraints; the palette, layout, light patterns, and copy are Spellbound design choices, not requirements quoted from the guide.

## Display and interaction

The app still uses only documented widgets at integer positions on a 320x240 screen. After successive physical memory passes reduced the home screen from 18 to 9 to 5 to 3 widgets, the deep-memory pass now uses a **single native label** as the entire resident UI surface. There are no external images, canvas calls, touch handlers, or audio features.

The duel keeps **YOU HP / FOE HP** and **MANA** visible as compact text; its input state machine and LED effects now live in duel-only modules rather than the resident startup UI/coordinator. The remaining HP bars were removed because physical measurements showed resident Lua/module memory, not native widget objects, was now the limiting resource; incoming attacks remain explicit in text and LED effects.

Header/status share one label, and action/help/footer share one multi-line label. A spell result or error still preserves the essential physical-button instruction while avoiding separate native labels for each region.

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

The production `main.lua` remains only a lifecycle bootstrap. Startup now caches only `app.lua`; the former resident `core.lua` and `ui.lua` modules were folded into a smaller coordinator, while gesture models and multiplayer state are deferred entirely. On first Teach/Find-a-duel entry, Spellbound deletes its one-label UI before feature loading. Teach installs four side-effect modules (`gesture_dtw`, `gesture_sig`, `casting`, `training`); Duel installs four (`network`, `net_rx`, `net_tick`, `engine`). DTW's persistent work area was reduced from two 17-cell rows to two lazily allocated 7-cell rows. Multiplayer match state is a flat numeric array rather than nested HP/mana/shield/cooldown tables. The badge sandbox's private `require()` cache still cannot be evicted, so reducing cached module count is the primary strategy.

### Important memory limitation

The desktop compile/module probe passes its 96 KiB cap, but is extremely close to that cap. It intentionally **does not create the UI handles/caches, enable BLE, load saved player templates, or run a complete match**. The small C callback added to the probe approximates the documented incremental GC binding; it does not reproduce the device collector's work or timing. This is not evidence that the complete app fits in a physical badge's available RAM.

Do not merge or demonstrate on the strength of the desktop memory number alone. Upload the app, inspect the first startup error and `heap` output if one occurs, and measure after opening multiplayer and training all three spells. Reducing complexity further may be necessary after those measurements.

## Packaging and validation

The slug remains `spellbound`. The physical package contains 11 files in `dist/app/`: `manifest.cfg` plus 10 Lua modules. The build enforces a sub-2 KiB production `main.lua`, a sub-6 KiB resident `app.lua`, a 4 KiB ceiling for each lazy production chunk, exact runtime-file membership, the documented 16-file Share cap, and the 48 KiB total Share cap. Production Lua is conservatively compacted by removing only blank lines, full-line comments, and indentation.

The lazy modular installation is the canonical competition build. Physical testing showed both the flattened importer and the earlier ~22 KiB `main.lua` layout could exhaust Lua allocation headroom while loading another chunk. The Badge IDE Files panel must therefore contain every runtime module alongside the tiny `main.lua`; Import app is not used to add those modules.

Run the core Lua tests, the design regressions in `tests/design_pass.lua`, the manifest-contract tests, the modular production/checker smoke tests, and `tools/build.py --check`. The build now rejects duplicate manifest keys, invalid heap settings, and conflicting HOME options before creating an installer. Physical validation remains unperformed. Inspect actual text wrapping, LED effects use a fixed competition brightness.

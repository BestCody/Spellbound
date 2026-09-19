# Badge-native design pass — 0.4.1

This pass applies the supplied **Agent instructions: create a Hacker Badge app in the IDE** to the existing Spellbound game. The guide is the basis for hardware/API constraints; the palette, layout, light patterns, and copy are Spellbound design choices, not requirements quoted from the guide.

## Display and interaction

The app still uses only documented widgets at integer positions on a 320x240 screen. After successive physical memory passes reduced the home screen from 18 to 9 to 5 to 3 widgets, the deep-memory pass now uses a **single native label** as the entire resident UI surface. There are no external images, canvas calls, touch handlers, or audio features.

The duel keeps **YOU HP / FOE HP** and **MANA** visible as compact text; its input state machine and LED effects now live in duel-only modules rather than the resident startup UI/coordinator. The remaining HP bars were removed because physical measurements showed resident Lua/module memory, not native widget objects, was now the limiting resource; incoming attacks remain explicit in text and LED effects.

Header, status, action help, and footer are composed into one multi-line label. A spell result or error still preserves the essential physical-button instruction without allocating separate native labels for each region.

Incoming attacks take display priority over recording. A shield covering the known landing time shows **SHIELD READY TO BLOCK**, rather than asking the player to cast another shield. An observed attack resolution without damage produces **BLOCKED** feedback. This feedback follows received host state; it is not a new exact-clock or authenticated event protocol.

A guest command awaiting acknowledgement shows **CAST QUEUED - WAIT**. Button-mode practice says **test cast**, not **recognized**. The latter is reserved for a movement accepted by the recognizer. Invitation copy says **queued**, not delivered. The short address shown is a radio code, not the badge's provisioned identity or a security credential.

## LEDs and brightness

The supplied guide's front-view mapping is used: left side top-to-bottom is **1, 6, 5**; right is **2, 3, 4**. During an otherwise idle duel, the left side represents local health and the right side opponent health in three coarse steps. Always use the screen for exact health values.

| State | Light behavior |
| --- | --- |
| Home / practice / lobby / ordinary recording | Off. Essential state remains on screen. |
| Accepted Fireball / unprotected incoming attack | One orange moving LED. |
| Shield or observed block | Solid cyan-blue. |
| Recharge | Solid green. |
| Damage | Solid red. |
| Win | Gold perimeter chase. |
| Other result | Off. |



Frames are timestamp-driven, scheduled no faster than every 50 ms, overwrite all six positions, and latch with one `show()`. A delayed callback skips frames rather than replaying a catch-up loop. These are visual game cues, not a promise of exact light output or timing on a real badge. HOME clears and shows the strip. Returning to the menu clears stale result messages/effects.

## Runtime and memory

Bluetooth now starts in the tiny lifecycle bootstrap, before `app.lua` is compiled. Fresh hardware logs showed that delaying startup until **Find a duel** recovered substantial heap but still left only a 29,696-byte largest block; the controller started, then HCI/NimBLE initialization failed. Reserving Bluetooth before the resident coordinator and UI are compiled gives the native HCI buffers the largest available contiguous block. The cost is that Home and Teach keep Bluetooth active during the foreground session. A failed initialization is not retried in that session because failed firmware initialization can fragment heap further; non-radio modes remain available and the app asks for a normal exit/reopen.

The competition build performs no diagnostic logging or diagnostic metadata construction. Firmware, memory, and gesture-score format strings were removed from the runtime; physical memory acceptance uses the firmware's external console statistics.

The production `main.lua` remains only a lifecycle bootstrap and performs the radio reservation before requiring the coordinator. Startup then caches only `app.lua`; gesture models and multiplayer state are deferred entirely. On first Teach/Find-a-duel entry, Spellbound deletes its one-label UI before feature loading. Teach installs four side-effect modules (`gesture_dtw`, `gesture_sig`, `casting`, `training`). Opening Duel installs only `network`, `net_rx`, and `net_tick`; `engine` waits until the user sends or accepts a challenge, so compilation occurs in the button callback rather than `on_recv`. The one-use loader closures are released after installation and eight incremental GC steps run between modules.

The generated build maps internal state fields, phase names, and roles to numeric values. Each learned model is now the 48-byte signature directly instead of a signature inside a one-element table. Network callbacks cache the current phase, post-pair discovery entries are released, numeric effect identifiers replace retained effect strings, and mutually exclusive timers/revision slots share storage. The unused eighteenth match-state cell was removed. These are internal representation changes: Teach, discovery, invitation, simultaneous-invite resolution, casting, damage, surrender, and rematches retain their existing flow. Raw samples still use five bytes, and DTW retains its two lazily allocated 7-cell rows. The badge sandbox's private `require()` cache still cannot be evicted, so minimizing retained function prototypes and cached modules remains the primary strategy.

### Important memory limitation

The 64-bit desktop scenario regression improved without a gameplay restart. Direct Duel now needs 19,767 bytes more allocator cap than Home, down from 21,211. The fully trained active match needs 50,891 bytes more, down from 53,104, and retains 74,020 bytes above the desktop harness. The probe includes a Lua badge mock and does not reproduce 32-bit ESP32 allocation sizes, native services, or fragmentation. This is not evidence that the complete app stays below the proposed 40 KiB target on the physical badge.

Do not demonstrate on the strength of the desktop memory number alone. Upload the app and measure current and peak Lua usage on Home, after training all three spells, after opening multiplayer, during a match, after a maximum-length recording, and after repeated rematches. Every observed value must be at or below 40 KiB; reducing complexity further may be necessary after those measurements.

## Packaging and validation

The slug remains `spellbound`. The physical package contains 12 files in `dist/app/`: `manifest.cfg`, 10 runtime Lua modules, and comment-only `license.lua`. Using a `.lua` notice is deliberate: the Badge IDE pushes support modules but omitted the earlier text notice from an observed transfer. The build enforces a sub-2 KiB production `main.lua`, a sub-6 KiB resident `app.lua`, a 4 KiB ceiling for each lazy production chunk, a 25 KiB low-memory package budget, exact membership, the documented 16-file Share cap, and the 48 KiB total Share cap. Production Lua removes blank lines, full-line comments, and indentation, and maps private shared-state fields to stable numeric slots. Version 0.4.1 uses ABI marker 4 so partial old/new module sets fail with an explicit reinstall message.

The lazy modular installation is the canonical competition build. Physical testing showed both the flattened importer and the earlier ~22 KiB `main.lua` layout could exhaust Lua allocation headroom while loading another chunk. The Badge IDE Files panel must therefore contain every runtime module alongside the tiny `main.lua`; Import app is not used to add those modules.

Run the core Lua tests, the design regressions in `tests/design_pass.lua`, the manifest-contract tests, the modular production/checker smoke tests, and `tools/build.py --check`. The build now rejects duplicate manifest keys, invalid heap settings, and conflicting HOME options before creating an installer. Startup logs have been captured on hardware, but the new radio-first order and complete two-badge flow still require physical validation. Inspect actual text wrapping; LED effects use a fixed competition brightness.

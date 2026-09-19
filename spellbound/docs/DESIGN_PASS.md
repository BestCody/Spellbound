# Badge-native design pass — 0.5.0

This release is the no-restart, sub-40-KB desktop-regression pass. Controls, spell rules, custom teaching, screen flow, and LED cues remain intact.

## Display and interaction

Spellbound uses one native label on the documented 320x240 integer-coordinate UI. Exact health and mana stay visible. Incoming attacks take priority over recording copy; a protected attack shows **SHIELD READY TO BLOCK**, resolution without damage shows **BLOCKED**, and an unacknowledged guest action shows **CAST QUEUED - WAIT**.

The LED strip remains dark when idle. Fireball uses a moving orange light, Shield/blocked uses blue, Recharge green, damage red, and victory a gold chase. Frames clear and latch once, with no catch-up loop. HOME clears stale notes and LEDs.

## Startup and Bluetooth

The tiny lifecycle bootstrap reserves Bluetooth before compiling `app.lua`. Hardware logs showed that enabling it later could leave enough total heap but too small a contiguous block for HCI/NimBLE. A failed initialization is not retried in the same foreground session; Teach remains usable and reopening the app provides a clean retry.

Production contains no diagnostic logging or diagnostic score tables. Physical measurements use the firmware's external console statistics.

## Memory architecture

Startup caches only `app.lua`. First Teach entry temporarily removes the label and installs four side-effect modules in order: `gesture_dtw`, `gesture_sig`, `casting`, and `training`. First Duel entry installs `net_rx`, `net_ui`, `apply`, `net_tick`, and `network` largest-first while the label is removed. Match start and radio receive perform no module compilation.

The build maps private state names, phases, and roles to numeric values. Models are direct 48-byte strings. Match state is a flat 16-cell authoritative host table and an 11-cell guest view. The state codec is folded into the fixed packet receiver; delayed attack resolution is folded into the already-loaded tick module. One-use loader closures are released and incremental collection runs between module loads.

The raw gesture buffer stores three acceleration bytes per fixed 20 ms sample. Signatures remain 16 XYZ nodes (48 bytes). Recognition retains the ±3-node DTW band, 0.48 threshold, 0.88 ambiguity margin, one teaching example, and one fresh validation repetition. DTW now uses one in-place band row; automated differential coverage proves the result matches the conventional two-row recurrence.

## Network rewrite

SB2 uses fixed-position packets from 4 to 30 bytes, with exact-length validation and no delimiter patterns. The guest retries `JOIN`; the host's first state packet starts the match and acknowledges it, eliminating the separate start/ack phases. Invitations, deterministic simultaneous-invite resolution, five strongest peers, cancellation, bounded retries, duplicate suppression, revision ordering, loss detection, surrender, and rematches remain.

SB2 is incompatible with earlier builds, so all files must be replaced atomically on both badges.

## Measured desktop regression

The generated v0.5.0 package is 21,556 bytes across 13 transfer files. In the 64-bit Lua 5.4 allocator-cap probe:

| Scenario | Extra allocator cap from Home |
|---|---:|
| First Teach | 16,709 bytes |
| Direct Duel | 20,219 bytes |
| Trained active match | **37,857 bytes** |
| Maximum capture after both stacks | **37,963 bytes** |

The active match retains 64,738 bytes above the desktop harness; that separate steady-state figure includes 64-bit Lua and mock allocations and is not the release gate. CI enforces every scenario's allocator-cap delta at no more than 38,000 bytes.

This is a regression measurement, not proof of ESP32 use. Lua word size, native UI/radio services, fragmentation, and firmware differ. Physical acceptance still requires every observed badge memory value to stay at or below 40 KiB through all-three-spell training, pairing, casting, maximum capture, and repeated matches.

## Packaging

The package contains exactly 13 files: `manifest.cfg`, 11 runtime Lua files, and comment-only `license.lua`. Every production chunk is at most 4 KiB except the resident `app.lua`, whose ceiling is 6 KiB; `main.lua` stays below 2 KiB. Total runtime package budget is 25 KiB, below Share's documented 48 KiB and 16-file limits.

Version 0.5.0 uses ABI marker 5. Mixed generated versions stop with an explicit reinstall message. The canonical transfer is Badge Share or an archive of the complete `dist/app/` directory, never the IDE's incomplete single-app export.

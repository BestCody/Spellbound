# Physical validation checklist — partial startup logs captured

Record both badges' firmware versions, the time of the check, and the observed result. These are manual acceptance checks, not claims of completed hardware tests.

## Boot and APIs

- Launch the optional Badge Check app. Confirm x/y/z change as the badge is moved and that the other badge receives an A-triggered ping.
- Install all 13 files from `dist/app/`: `manifest.cfg`, the 11 runtime Lua files, and comment-only `license.lua`. Do not include `README.md`, `build-info.json`, or `Badge-check.lua` in the Spellbound app. Verify the launcher entry, home menu, label readability, button behavior, and all six LEDs.
- Capture the firmware's external `heap`/app statistics before launch, on Home, after first Teach entry, after training all three spells, after first Find-a-duel entry, during a match, after a maximum-length recording, and after repeated rematches. Production diagnostics are intentionally absent. Record both current and peak Lua usage when the firmware exposes them; acceptance requires every observed Lua value to remain at or below the proposed 40 KiB target.
- Confirm no startup/tick/button deadline failures. The implementation targets the documented API 2 guide and newer callback allowances, not a guessed chip firmware.

## Network and match

- Explicitly accept and decline invitations. Declining must not repeatedly reopen the same prompt. Have both badges invite simultaneously and confirm the lower radio address becomes host without a timeout.
- In motion casting, fire once. Confirm exactly 25 damage after the warning, on both screens, and exactly 30 mana spent.
- Shield before impact; confirm no damage and that the shield is consumed. Cast too late; confirm it cannot undo damage.
- Recharge, check its cooldown, attempt a spell with insufficient mana, and check that the next valid action still works.
- Play through a win, a surrender, and repeated rematches. Observe recovery from packet loss and practical responsiveness in the crowded event environment.
- Leave HOME on one badge or take it out of range. Confirm the other cancels rather than continuing with stale state. No host migration is implemented.

## Motion and persistence

- Check each spell in Teach. Expect to personalize gestures; no physical accuracy was measured during generation.
- Train all three spells with deliberately distinct movements. Use the second repetition as the fresh validation, then test additional repetitions not used during training.
- Test random handling, partial movements, stationary A holds, delayed starts after pressing A, slower/faster and gentler/stronger repetitions, brief mid-gesture pauses, slightly late releases, and energetic (>4 g) flicks. Record false casts as well as rejected intended casts.
- For every failed physical teach/cast, record the visible rejection, approximate hold/movement duration, spell, and movement description before changing the fixed threshold. Detailed production gesture logging was removed for memory headroom.
- Verify a learned gesture causes the expected effect on the other badge in a real duel.
- HOME and reopen, then power-cycle. Confirm the current session-only learned templates reset. Cancel a new training attempt within the same session and confirm already learned spell models remain.

## Demonstration

Start with a successful motion-controlled duel and demonstrate a newly taught gesture. Do not present synthetic fixture pass rates as recognition accuracy. Explain that countdown visuals are approximate and host-authoritative, not perfectly synchronized.

Keep a copy of the prebuilt modular app and the standalone checker. Do not reflash the badge firmware simply to debug an app without first understanding the failure and the organizer's documented recovery procedure.

## Design pass 0.5.0 acceptance

- On a fresh app launch, verify Bluetooth initializes once before the Home screen and before `app.lua` is compiled. Then check Home/Teach and open Find a duel for discovery/acceptance. There must be no `BLE_INIT: Malloc failed`, `hci inits failed`, `nimble host init failed`, or `ESP_ERR_NO_MEM` line.
- Check the off, fire, shield, recharge, damage, and victory LED effects at the fixed competition brightness.
- Confirm notifications do not hide the bottom controls, incoming warnings remain visible during capture, and a protected attack shows the shield-ready state.
- Check long messages for native-font wrapping/clipping. The desktop preview is not LVGL.
- The desktop trained-match allocator-cap delta is 37,857 bytes and the maximum-capture stage is 37,963 bytes, with every scenario gated at 38,000 bytes. The probe does not reproduce ESP32 allocation sizes or native services. Measure after opening radio, loading/training all three gestures, maximum-length capture, and repeated duels. Treat any value above 40 KiB as a failed target, not a reason to raise the quota or delete unrelated inactive apps.

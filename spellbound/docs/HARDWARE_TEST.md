# Physical validation checklist — not yet performed

Record both badges' firmware versions, the time of the check, and the observed result. These are manual acceptance checks, not claims of completed hardware tests.

## Boot and APIs

- Launch the optional Badge Check app. Confirm x/y/z change as the badge is moved and that the other badge receives an A-triggered ping.
- Install all five Spellbound files. Verify the launcher entry, home menu, label readability, button behavior, and all six LEDs.
- Capture `heap` before launch and the first error if compilation/startup fails. Record in-app diagnostic heap values after launch and after training. Leave headroom; do not equate the 96 KiB limit to available RAM.
- Confirm no startup/tick/button deadline failures. The implementation targets the documented API 2 guide and newer callback allowances, not a guessed chip firmware.

## Network and match

- Explicitly accept and decline invitations. Declining must not repeatedly reopen the same prompt.
- In button mode, fire once. Confirm exactly 25 damage after the warning, on both screens, and exactly 30 mana spent.
- Shield before impact; confirm no damage and that the shield is consumed. Cast too late; confirm it cannot undo damage.
- Recharge, check its cooldown, attempt a spell with insufficient mana, and check that the next valid action still works.
- Play through a win, a surrender, and repeated rematches. Observe dropped-packet diagnostics and practical responsiveness in the crowded event environment.
- Leave HOME on one badge or take it out of range. Confirm the other cancels rather than continuing with stale state. No host migration is implemented.

## Motion and persistence

- Check each preset in Practice. Expect to personalize gestures; no physical accuracy was measured during generation.
- Train all three spells with deliberately distinct movements. Use the fourth repetition as validation, then test additional repetitions not used during training.
- Test random handling, partial movements, and stationary A holds. Record false casts as well as rejected intended casts.
- Verify a learned gesture causes the expected effect on the other badge in a real duel.
- HOME and reopen, then power-cycle. Confirm learned templates persist. Cancel a new training attempt and confirm the old model remains.

## Demonstration

Start with a successful button-mode duel, switch to motion, then demonstrate a newly taught gesture. Do not present synthetic fixture pass rates as recognition accuracy. Explain that countdown visuals are approximate and host-authoritative, not perfectly synchronized.

Keep a copy of the prebuilt app and the standalone checker. Do not reflash the badge firmware simply to debug an app without first understanding the failure and the organizer's documented recovery procedure.

## Design pass 0.2.0 acceptance

- On a fresh app launch, check Home/Practice/Teach before opening Find a duel. Confirm Bluetooth startup is not required for those modes. Then open Find a duel and verify discovery/acceptance.
- Check OFF/64/160/255 LED brightness, physical left/right health mapping, recording progress pairs, shield/block feedback, and HOME cleanup. Confirm OFF survives a normal exit/reopen.
- Confirm notifications do not hide the bottom controls, incoming warnings remain visible during capture, and a protected attack shows the shield-ready state.
- Check long messages and Diagnostics for native-font wrapping/clipping. The desktop preview is not LVGL.
- Press A in Diagnostics; capture its one-shot log and pre-launch `heap` output when relevant. Distinguish Lua usage from free system heap and observed changes/s from sensor Hz.
- The desktop cap probe is close to its limit and does not exercise full runtime allocation. Measure after opening radio, loading/training all three gestures, and repeated duels. Treat failure as a reason to simplify the app, not raise the quota beyond 96 or delete unrelated inactive apps.

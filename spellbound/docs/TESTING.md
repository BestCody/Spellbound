# Automated verification and its limits

`tests/run.lua` executes the actual Lua source using a strict mock of the documented badge APIs. The mock rejects undocumented widget/API calls, non-integer positions/values, oversized radio packets, and oversized file writes. Each simulated badge has an independent Lua environment and private module cache.

The test suite covers game rules, delayed damage, shield consumption, cooldown/mana rejections, command sequencing, payload parsing, session-only teaching, sensor failures, repeated matches, and two-device integration. Integration tests exercise packet loss, duplication, reordering, different local clocks, unrelated peers/sessions, malformed traffic, and terminal timeout behavior. One integration test sends a synthetic recognized gesture through capture, recognition, the command protocol, and the opposing badge's health update.

The network mock delivers no more than four packets per recipient per simulation step. It is **not a BLE radio-stack or RF simulator**, and does not recreate crowded-event interference, actual native callback costs, or every firmware queue behavior.

`tests/install_smoke.lua` loads the generated production modules (with test-only exports stripped) and checks boot, controls, session-only training, discovery, pairing, a real recognized cast, and cleanup across two independent simulated badges. `tools/build.py --check` ensures tracked install files match source.

Run from the `spellbound/` project directory:

```sh
python tools/build.py
lua5.4 tests/run.lua
lua5.4 tests/design_pass.lua
lua5.4 tests/install_smoke.lua
lua5.4 tests/checker_smoke.lua
python tools/build.py --check
```

`texlua` can also run the tests. The included Python runner is an alternative when a Linux Lua 5.4 shared library is installed but the `lua` executable is not.

## Memory probe

`python tools/memory_probe.py` measures the generated production bootstrap plus Home, Teach, Duel-lobby, and match-engine module initialization in a **64-bit desktop Lua 5.4** state. It tests an uncapped run and a 96 KiB cap, collecting each stage before moving on. It does not create native UI/radio services, train gesture templates, or play a match. Lua word size, binding allocations, system fragmentation, and native memory are different on the ESP32.

Consequently, passing this probe is a useful regression check, **not proof that the full app fits or remains responsive on the physical badge**. An allocation rejection in a successful capped run can be followed by Lua garbage collection and a successful retry; inspect `success`, not only the rejection count.

`tests/design_pass.lua` adds 15 checks for lazy radio startup, one latch per frame, no catch-up bursts, shield feedback, pending acknowledgements, stale-effect cleanup, and widget bounds. It uses a simple local relay for presentation checks; the original integration suite remains the loss/reordering coverage.

`python tools/memory_scenarios.py` is an optional, fuller regression probe using `lupa`'s 64-bit Lua 5.4 and the test badge mock. It exercises Home, first Teach, all three trained models, direct Duel entry, both feature stacks, an active match, and a later 4.4-second capture, then binary-searches the allocator cap for each stage. Install it with `python -m pip install lupa`. On the 2026-09-19 v0.3.0 release candidate, direct Duel entry required 21,211 bytes more allocator cap than Home. The true worst stage was a trained active match at 53,104 bytes above Home; its steady memory was 76,680 bytes above the desktop harness. Those are desktop regression deltas, **not** the badge's total Lua usage and do not prove the proposed 40 KiB device goal.

Production contains no memory, firmware, or gesture diagnostic logging. This deliberately avoids format strings, metadata/score tables, and logging allocations in the competition build. Use the firmware's external `heap`/app statistics for the physical acceptance check.

The repository-root GitHub Actions workflow uses `spellbound/` as its working directory. Its remote status must be checked separately; local passing tests are not a claim that GitHub Actions has run. Stale recorded probe/test outputs were removed so they cannot be mistaken for measurements of the current build.

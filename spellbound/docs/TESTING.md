# Automated verification and its limits

`tests/run.lua` executes the actual Lua source using a strict mock of the documented badge APIs. The mock rejects undocumented widget/API calls, non-integer positions/values, oversized radio packets, and oversized file writes. Each simulated badge has an independent Lua environment and private module cache.

The test suite covers game rules, delayed damage, shield consumption, cooldown/mana rejections, command sequencing, payload parsing, save recovery, teaching, sensor failures, repeated matches, and two-device integration. Integration tests exercise packet loss, duplication, reordering, different local clocks, unrelated peers/sessions, malformed traffic, and terminal timeout behavior. One integration test sends a synthetic recognized gesture through capture, recognition, the command protocol, and the opposing badge's health update.

The network mock delivers no more than four packets per recipient per simulation step. It is **not a BLE radio-stack or RF simulator**, and does not recreate crowded-event interference, actual native callback costs, or every firmware queue behavior.

`tests/install_smoke.lua` loads the generated production modules (with test-only exports stripped) and checks boot, controls, training, persistence, and cleanup. `tools/build.py --check` ensures tracked install files match source.

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

`python tools/memory_probe.py` measures allocation while compiling/executing the production chunk and its delayed module initializer in a **64-bit desktop Lua 5.4** state. It tests an uncapped run and a 96 KiB cap and reports allocator rejections/GC recovery. It appends a return of the local component initializer for measurement, runs it after the main chunk returns, and performs a GC pass between those stages. It does not create the badge's native UI/radio services or run physical lifecycle callbacks. Lua word size, binding allocations, system fragmentation, and native memory are different on the ESP32.

Consequently, passing this probe is a useful regression check, **not proof that the full app fits or remains responsive on the physical badge**. An allocation rejection in a successful capped run can be followed by Lua garbage collection and a successful retry; inspect `success`, not only the rejection count.

`tests/design_pass.lua` adds 16 checks for lazy radio startup, brightness/off persistence, physical LED sides, one latch per frame, no catch-up bursts, notification/control separation, shield feedback, pending acknowledgements, diagnostic logging, stale-effect cleanup, and widget bounds. It uses a simple local relay for presentation checks; the original integration suite remains the loss/reordering coverage.

The 0.2.0 probe supplies a small C-backed proxy for `badge.sys.gc_step()` and follows the changed module initialization order. It releases the one-shot UI-construction closures without actually constructing native widgets. The recorded capped result has very little headroom: it excludes UI handles/caches, BLE, saved-template loading, and gameplay allocations. Do not interpret it as a full-app memory test. Numbers should not be directly compared to older probes with different initialization or GC scaffolding.

The included output files record what was actually run locally. The repository-root GitHub Actions workflow uses `spellbound/` as its working directory. Its remote status must be checked separately; local passing tests are not a claim that GitHub Actions has run.

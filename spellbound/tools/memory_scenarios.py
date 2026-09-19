#!/usr/bin/env python3
"""Compare Spellbound memory stages in a 64-bit desktop Lua 5.4 runtime.

Requires the optional ``lupa`` package. Results include the desktop badge mock
and are regression signals, not physical ESP32 measurements.
"""
from __future__ import annotations

import gc
import json
import os
from pathlib import Path

try:
    from lupa.lua54 import LuaMemoryError, LuaRuntime
except ImportError as exc:  # pragma: no cover - optional local profiling tool
    raise SystemExit("Install the optional profiler dependency with: python -m pip install lupa") from exc


ROOT = Path(os.environ.get("SPELLBOUND_PROFILE_ROOT", Path(__file__).resolve().parents[1]))
os.chdir(ROOT)
STAGES = ("home", "teach", "trained", "both", "capture")


def collect_used(lua: LuaRuntime) -> int:
    lua.execute("collectgarbage('collect')")
    gc.collect()
    return lua.get_memory_used(total=True)


def new_badge(lua: LuaRuntime):
    lua.execute("Mock=dofile('tests/mock_badge.lua')")
    return lua.globals().Mock.new(lua.table_from({"path": "dist/app", "production": True}))


def motions(lua: LuaRuntime):
    return (
        lua.eval("function(t) return 1400*math.sin(t*2*math.pi),0,1000 end"),
        lua.eval("function(t) local a=math.min(1,t/0.7)*math.pi/2 return 0,1000*math.sin(a),1000*math.cos(a) end"),
        lua.eval("function(t) return 1200*math.sin(t*4*math.pi),0,1000 end"),
    )


def advance(badge, motion_set, stop: str) -> None:
    if stop == "home":
        return
    badge.tap(badge, "DOWN")
    badge.tap(badge, "A")
    if stop == "teach":
        return
    for index, motion in enumerate(motion_set):
        if index:
            badge.tap(badge, "DOWN")
        badge.tap(badge, "A")
        for _ in range(4):
            badge.record(badge, motion, 1000)
    if stop == "trained":
        return
    badge.tap(badge, "B")
    badge.tap(badge, "A")
    if stop == "both":
        return
    badge.tap(badge, "B")
    badge.tap(badge, "DOWN")
    badge.tap(badge, "A")
    badge.tap(badge, "A")
    badge.record(badge, motion_set[0], 4400)


def snapshots() -> dict[str, int]:
    lua = LuaRuntime(max_memory=2_000_000, unpack_returned_tuples=True)
    runtime = collect_used(lua)
    lua.execute("Mock=dofile('tests/mock_badge.lua')")
    harness = collect_used(lua)
    badge = lua.globals().Mock.new(lua.table_from({"path": "dist/app", "production": True}))
    values = {"runtime": runtime, "harness": harness, "home": collect_used(lua)}
    motion_set = motions(lua)
    advance(badge, motion_set, "teach")
    values["teach"] = collect_used(lua)
    # Continue with a fresh runtime so every named stage follows the same path.
    for stage in STAGES[2:]:
        stage_lua = LuaRuntime(max_memory=2_000_000, unpack_returned_tuples=True)
        stage_badge = new_badge(stage_lua)
        advance(stage_badge, motions(stage_lua), stage)
        values[stage] = collect_used(stage_lua)
    return values


def runs_under(limit: int, stage: str) -> bool:
    try:
        lua = LuaRuntime(max_memory=limit, unpack_returned_tuples=True)
        badge = new_badge(lua)
        advance(badge, motions(lua), stage)
        return True
    except (LuaMemoryError, MemoryError):
        return False


def minimum_cap(stage: str) -> int:
    low, high = 1, 300_000
    while low < high:
        middle = (low + high) // 2
        if runs_under(middle, stage):
            high = middle
        else:
            low = middle + 1
    return low


def main() -> None:
    current = snapshots()
    caps = {stage: minimum_cap(stage) for stage in STAGES}
    print(json.dumps({
        "scope": "64-bit desktop Lua 5.4 with Lua badge mock; not an ESP32 measurement",
        "steady_bytes": current,
        "steady_above_harness_bytes": {
            stage: current[stage] - current["harness"] for stage in STAGES
        },
        "minimum_allocator_cap_bytes": caps,
        "cap_increase_from_home_bytes": {
            stage: caps[stage] - caps["home"] for stage in STAGES
        },
    }, indent=2))


if __name__ == "__main__":
    main()

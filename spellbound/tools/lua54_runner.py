#!/usr/bin/env python3
"""Run a Lua test file with an installed Lua 5.4 shared library (no Python deps)."""
from __future__ import annotations
import ctypes as C
import ctypes.util
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python tools/lua54_runner.py tests/run.lua", file=sys.stderr)
        return 2
    name = ctypes.util.find_library("lua5.4") or ctypes.util.find_library("lua54")
    if not name:
        print("Install Lua 5.4, or run the test directly with lua/texlua.", file=sys.stderr)
        return 2
    lua = C.CDLL(name)
    lua.luaL_newstate.restype = C.c_void_p
    lua.luaL_openlibs.argtypes = [C.c_void_p]
    lua.luaL_loadfilex.argtypes = [C.c_void_p, C.c_char_p, C.c_char_p]
    lua.luaL_loadfilex.restype = C.c_int
    lua.lua_pcallk.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_ssize_t, C.c_void_p]
    lua.lua_pcallk.restype = C.c_int
    lua.lua_tolstring.argtypes = [C.c_void_p, C.c_int, C.POINTER(C.c_size_t)]
    lua.lua_tolstring.restype = C.c_char_p
    lua.lua_close.argtypes = [C.c_void_p]
    state = lua.luaL_newstate()
    if not state:
        raise MemoryError("Could not create Lua state")
    try:
        lua.luaL_openlibs(state)
        status = lua.luaL_loadfilex(state, str(Path(sys.argv[1])).encode(), b"t")
        if status == 0:
            status = lua.lua_pcallk(state, 0, 0, 0, 0, None)
        if status:
            error = lua.lua_tolstring(state, -1, None)
            print(error.decode(errors="replace") if error else "Lua execution failed", file=sys.stderr)
            return 1
        return 0
    finally:
        lua.lua_close(state)


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Desktop Lua 5.4 allocation probe. NOT a physical ESP32 memory measurement.

Measures the production bootstrap and each delayed module stack without the large
desktop mock. 64-bit Lua allocation sizes differ from an ESP32 build.
"""
from __future__ import annotations
import ctypes as C
import ctypes.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def probe(limit: int = 0) -> dict:
    lua = C.CDLL(ctypes.util.find_library("lua5.4") or "liblua5.4.so.0")
    libc = C.CDLL(None)
    libc.realloc.argtypes = [C.c_void_p, C.c_size_t]
    libc.realloc.restype = C.c_void_p
    libc.free.argtypes = [C.c_void_p]
    counter = {"used": 0, "peak": 0, "limit": 0, "rejections": 0}
    Alloc = C.CFUNCTYPE(C.c_void_p, C.c_void_p, C.c_void_p, C.c_size_t, C.c_size_t)
    @Alloc
    def alloc(ud, ptr, old, new):
        old = old if ptr else 0
        if new == 0:
            if ptr: libc.free(ptr)
            counter["used"] -= old
            return None
        if counter["limit"] and counter["used"] - old + new > counter["limit"]:
            counter["rejections"] += 1
            return None
        p = libc.realloc(ptr, new)
        if p:
            counter["used"] += new - old
            counter["peak"] = max(counter["peak"], counter["used"])
        return p
    lua.lua_newstate.argtypes = [Alloc, C.c_void_p]
    lua.lua_newstate.restype = C.c_void_p
    lua.luaL_requiref.argtypes = [C.c_void_p,C.c_char_p,C.c_void_p,C.c_int]
    lua.lua_settop.argtypes = [C.c_void_p,C.c_int]
    lua.luaL_loadbufferx.argtypes = [C.c_void_p,C.c_char_p,C.c_size_t,C.c_char_p,C.c_char_p]
    lua.lua_pcallk.argtypes = [C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ssize_t,C.c_void_p]
    lua.lua_tolstring.argtypes = [C.c_void_p,C.c_int,C.c_void_p]
    lua.lua_tolstring.restype = C.c_char_p
    lua.lua_close.argtypes = [C.c_void_p]
    Callback=C.CFUNCTYPE(C.c_int,C.c_void_p)
    lua.lua_pushcclosure.argtypes=[C.c_void_p,Callback,C.c_int]
    lua.lua_setglobal.argtypes=[C.c_void_p,C.c_char_p]
    lua.lua_pushnil.argtypes=[C.c_void_p]
    lua.luaL_ref.argtypes=[C.c_void_p,C.c_int]
    lua.lua_rawgeti.argtypes=[C.c_void_p,C.c_int,C.c_longlong]
    refs={}
    module_errors=[]
    @Callback
    def require(L):
        name=lua.lua_tolstring(L,1,None).decode()
        if name in refs:
            lua.lua_rawgeti(L,-1001000,refs[name]);return 1
        source=(ROOT/"src"/(name+".lua")).read_bytes()
        err=lua.luaL_loadbufferx(L,source,len(source),("@"+name).encode(),b"t")
        if not err: err=lua.lua_pcallk(L,0,1,0,0,None)
        if err:
            module_errors.append(name+": "+lua.lua_tolstring(L,-1,None).decode())
            lua.lua_pushnil(L);return 1
        refs[name]=lua.luaL_ref(L,-1001000)
        lua.lua_rawgeti(L,-1001000,refs[name]);return 1
    state=lua.lua_newstate(alloc,None)
    if not state: raise MemoryError()
    try:
        for name,entry in [(b"_G","base"),(b"table","table"),(b"string","string"),(b"math","math"),(b"utf8","utf8")]:
            lua.luaL_requiref(state,name,C.cast(getattr(lua,"luaopen_"+entry),C.c_void_p),1)
            lua.lua_settop(state,-2)
        lua.lua_pushcclosure(state,require,0)
        lua.lua_setglobal(state,b"require")
        # Model the native incremental-GC binding with a C callback, not a Lua
        # wrapper/prototype that would itself distort this allocation probe.
        lua.lua_createtable.argtypes=[C.c_void_p,C.c_int,C.c_int]
        lua.lua_setfield.argtypes=[C.c_void_p,C.c_int,C.c_char_p]
        lua.lua_gc.argtypes=[C.c_void_p,C.c_int]
        @Callback
        def gc_step(L):
            lua.lua_gc(L,5,0)  # LUA_GCSTEP; device step size is not asserted.
            return 0
        lua.lua_createtable(state,0,1)
        lua.lua_createtable(state,0,1)
        lua.lua_pushcclosure(state,gc_step,0)
        lua.lua_setfield(state,-2,b"gc_step")
        lua.lua_setfield(state,-2,b"sys")
        lua.lua_setglobal(state,b"badge")
        baseline=counter["used"]
        counter["limit"]=limit
        lua.lua_gc.argtypes=[C.c_void_p,C.c_int]

        def run(source: bytes, name: bytes) -> tuple[int,str|None]:
            status=lua.luaL_loadbufferx(state,source,len(source),name,b"t")
            if status==0:
                status=lua.lua_pcallk(state,0,0,0,0,None)
            error=None
            if status:
                value=lua.lua_tolstring(state,-1,None)
                error=value.decode(errors="replace") if value else "unknown Lua error"
            lua.lua_settop(state,0)
            return status,error

        main=(ROOT/"src/main.lua").read_bytes().split(b"-- TEST_EXPORTS_BEGIN")[0]
        status,error=run(main,b"@src/main.lua")
        stages={"bootstrap_peak_bytes":counter["peak"]}

        def load_stage(label: str, names: tuple[str,...]) -> None:
            nonlocal status,error
            if status:
                return
            source=";".join(f'require("{name}")' for name in names).encode()
            status,error=run(source,("@probe/"+label).encode())
            lua.lua_gc(state,2)
            stages[label+"_after_gc_bytes"]=counter["used"]
            stages[label+"_peak_bytes"]=counter["peak"]

        load_stage("home",("app",))
        load_stage("teach",("gesture_dtw","gesture_sig","casting","training"))
        load_stage("duel",("network","net_rx","net_tick","engine"))
        lua.lua_gc(state,2)
        after_gc=counter["used"]
        return {"limit_bytes":limit,"baseline_bytes":baseline,**stages,
                "after_gc_bytes":after_gc,"app_retained_bytes":after_gc-baseline,
                "app_peak_delta_bytes":counter["peak"]-baseline,
                "allocation_rejections":counter["rejections"],"module_errors":module_errors,
                "total_peak_bytes":counter["peak"],"success":status==0,"error":error,
                "scope":"64-bit desktop Lua 5.4 bootstrap + delayed module initialization; excludes badge services, UI, radio, gesture templates, and gameplay"}
    finally:
        lua.lua_close(state)

if __name__=="__main__":
    print(json.dumps([probe(),probe(96*1024)],indent=2))

#!/usr/bin/env python3
"""Build the five-file badge app and IDE import starter. Python 3.10+; no deps."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_FILES = ("main.lua", "gesture.lua", "engine.lua", "model_codec.lua")


def build(check: bool = False) -> None:
    manifest = (ROOT / "manifest.cfg").read_text(encoding="utf-8")
    assert "slug=spellbound\n" in manifest and "api=2\n" in manifest
    output: dict[Path, bytes] = {}
    for name in RUNTIME_FILES:
        code = (ROOT / "src" / name).read_text(encoding="utf-8")
        if name == "main.lua":
            code = code.split("-- TEST_EXPORTS_BEGIN", 1)[0].rstrip() + "\n"
        code.encode("ascii")  # The device UI and source use portable ASCII.
        assert len(code.encode()) <= 64 * 1024
        for dependency in re.findall(r'require\("([^"\n]+)"\)', code):
            assert dependency + ".lua" in RUNTIME_FILES, dependency
        output[ROOT / "dist" / "app" / name] = code.encode()
    output[ROOT / "dist" / "app" / "manifest.cfg"] = manifest.encode()
    total = sum(map(len, output.values()))
    assert total < 48 * 1024, "App exceeds documented badge Share size limit"
    main = output[ROOT / "dist" / "app" / "main.lua"].decode()
    starter = ("--[==[badge-app\n" + manifest + "]==]\n\n"
               "-- IMPORTANT: also add gesture.lua, engine.lua, and model_codec.lua\n"
               "-- from dist/app to the IDE BEFORE clicking Push. See INSTALL.md.\n\n" + main)
    output[ROOT / "dist" / "Spellbound-install.lua"] = starter.encode()
    report = {"version": "0.1.0", "runtime_files": 5, "runtime_bytes": total,
              "standalone_import": False,
              "sha256": {str(p.relative_to(ROOT / "dist")): hashlib.sha256(b).hexdigest()
                         for p, b in output.items()}}
    output[ROOT / "dist" / "build-info.json"] = (json.dumps(report, indent=2) + "\n").encode()
    for path, content in output.items():
        if check:
            if not path.is_file() or path.read_bytes() != content:
                raise SystemExit(f"Out-of-date build: {path.relative_to(ROOT)}; run python tools/build.py")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    print(f"{'Verified' if check else 'Built'} {total:,} bytes across five runtime files.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check tracked builds without rewriting")
    build(parser.parse_args().check)

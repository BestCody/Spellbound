#!/usr/bin/env python3
"""Build Spellbound's modular runtime and one-file Hacker Badge importer."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_FILES = ("main.lua", "gesture.lua", "engine.lua")
MODULES = (("gesture", "gesture.lua", ("raw_sample", "signature", "distance", "recognize")),
           ("engine", "engine.lua", ("new_match", "apply", "advance", "pack_state", "unpack_state")))


def validate_manifest(text: str) -> None:
    fields: dict[str, str] = {}
    allowed = {"slug", "name", "icon", "api", "heap_kb", "wake_lock",
               "home_button", "confirm_home", "version", "author"}
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator or key not in allowed or key in fields:
            raise ValueError(f"Invalid or duplicate manifest key on line {number}: {key}")
        fields[key] = value
    if fields.get("slug") != "spellbound" or fields.get("api") != "2":
        raise ValueError("This build requires slug=spellbound and api=2")
    for key, choices in {"heap_kb": {"48", "96"}, "wake_lock": {"0", "1"},
                         "home_button": {"0", "1"}, "confirm_home": {"0", "1"}}.items():
        if key in fields and fields[key] not in choices:
            raise ValueError(f"Unsupported {key}: {fields[key]}")
    if fields.get("home_button") == fields.get("confirm_home") == "1":
        raise ValueError("home_button and confirm_home cannot both be enabled")
    if not 1 <= len(fields.get("name", "").encode()) <= 48:
        raise ValueError("name must be 1-48 bytes")
    for key, maximum in {"icon": 12, "version": 48, "author": 48}.items():
        if key in fields and not 1 <= len(fields[key].encode()) <= maximum:
            raise ValueError(f"Invalid {key} byte length")


def production_main(text: str) -> str:
    return text.split("-- TEST_EXPORTS_BEGIN", 1)[0].rstrip() + "\n"


def loader(name: str, code: str, exports: tuple[str, ...]) -> str:
    """Wrap a module without allocating its temporary export table at runtime."""
    code = re.sub(r"\nreturn \{[^\n]+\}\s*$", "", code.rstrip())
    return (
        f"local function __load_{name}()\n{code}\n"
        f"return {','.join(exports)}\nend\n"
    )


def make_standalone(manifest: str, sources: dict[str, str]) -> str:
    main = production_main(sources["main.lua"])
    replacement = """local function load_components()
  ui_create,label=nil,nil
  badge.sys.gc_step()
  raw_sample,signature,distance,recognize=__load_gesture();__load_gesture=nil
  badge.sys.gc_step()
  new_match,apply,advance,pack_state,unpack_state=__load_engine();__load_engine=nil
  badge.sys.gc_step()
end
local function send_state"""
    pattern = re.compile(r"local function load_components\(\).*?\nend\nlocal function send_state", re.S)
    main, count = pattern.subn(replacement, main, count=1)
    if count != 1:
        raise ValueError("Could not replace modular load_components()")

    embedded = "".join(loader(name, sources[file], exports)
                       for name, file, exports in MODULES)
    body = embedded + "\n" + main

    # Generated-only cleanup lowers parser/compile pressure while readable src/ stays intact.
    body = re.sub(r"--\[\[.*?\]\]\s*", "", body, flags=re.S)
    body = "\n".join(line for line in body.splitlines()
                     if not line.lstrip().startswith("--"))
    body = re.sub(r"\n{3,}", "\n\n", body).strip() + "\n"

    if re.search(r'\brequire\s*\(', body):
        raise ValueError("Standalone build still contains require()")
    standalone = "--[==[badge-app\n" + manifest + "]==]\n\n" + body
    standalone.encode("ascii")
    if len(body.encode()) > 64 * 1024:
        raise ValueError("Standalone main.lua exceeds 64 KiB")
    return standalone


def build(check: bool = False) -> None:
    manifest = (ROOT / "manifest.cfg").read_text(encoding="utf-8")
    validate_manifest(manifest)
    sources = {name: (ROOT / "src" / name).read_text(encoding="utf-8")
               for name in RUNTIME_FILES}

    output: dict[Path, bytes] = {}
    for name in RUNTIME_FILES:
        code = production_main(sources[name]) if name == "main.lua" else sources[name]
        code.encode("ascii")
        if len(code.encode()) > 64 * 1024:
            raise ValueError(f"{name} exceeds 64 KiB")
        output[ROOT / "dist" / "app" / name] = code.encode()
    output[ROOT / "dist" / "app" / "manifest.cfg"] = manifest.encode()

    runtime_total = sum(len(output[ROOT / "dist" / "app" / name])
                        for name in RUNTIME_FILES) + len(manifest.encode())
    if runtime_total >= 48 * 1024:
        raise ValueError("Modular app exceeds documented Share bundle limit")

    standalone = make_standalone(manifest, sources)
    output[ROOT / "dist" / "Spellbound-install.lua"] = standalone.encode()

    report = {
        "version": next((line.split("=", 1)[1] for line in manifest.splitlines()
                         if line.startswith("version=")), "unknown"),
        "runtime_files": 4,
        "runtime_bytes": runtime_total,
        "standalone_import": True,
        "standalone_bytes": len(standalone.encode()),
        "sha256": {
            str(path.relative_to(ROOT / "dist")): hashlib.sha256(data).hexdigest()
            for path, data in output.items()
        },
    }
    output[ROOT / "dist" / "build-info.json"] = (json.dumps(report, indent=2) + "\n").encode()

    for path, content in output.items():
        if check:
            if not path.is_file() or path.read_bytes() != content:
                raise SystemExit(
                    f"Out-of-date build: {path.relative_to(ROOT)}; run python tools/build.py"
                )
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)

    print(
        f"{'Verified' if check else 'Built'} modular app {runtime_total:,} bytes; "
        f"standalone importer {len(standalone.encode()):,} bytes."
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="Check tracked builds without rewriting")
    build(parser.parse_args().check)

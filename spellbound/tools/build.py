#!/usr/bin/env python3
"""Build Spellbound's modular Hacker Badge runtime."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_FILES = ("main.lua", "app.lua", "core.lua", "ui.lua", "network.lua", "casting.lua", "gesture.lua", "engine.lua")
LEGACY_STANDALONE = ROOT / "dist" / "Spellbound-install.lua"


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
        if name == "main.lua" and len(code.encode()) > 2 * 1024:
            raise ValueError("main.lua must remain a tiny bootstrap under 2 KiB")
        output[ROOT / "dist" / "app" / name] = code.encode()
    output[ROOT / "dist" / "app" / "manifest.cfg"] = manifest.encode()

    runtime_total = sum(len(output[ROOT / "dist" / "app" / name])
                        for name in RUNTIME_FILES) + len(manifest.encode())
    if runtime_total >= 48 * 1024:
        raise ValueError("Modular app exceeds documented Share bundle limit")

    report = {
        "version": next((line.split("=", 1)[1] for line in manifest.splitlines()
                         if line.startswith("version=")), "unknown"),
        "package_mode": "modular",
        "runtime_files": len(RUNTIME_FILES) + 1,
        "runtime_bytes": runtime_total,
        "standalone_import": False,
        "sha256": {
            str(path.relative_to(ROOT / "dist")): hashlib.sha256(data).hexdigest()
            for path, data in output.items()
        },
    }
    output[ROOT / "dist" / "build-info.json"] = (json.dumps(report, indent=2) + "\n").encode()

    if check:
        if LEGACY_STANDALONE.exists():
            raise SystemExit(
                "Legacy dist/Spellbound-install.lua exists; remove it before using the modular build"
            )
    elif LEGACY_STANDALONE.exists():
        LEGACY_STANDALONE.unlink()

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
        f"{'Verified' if check else 'Built'} modular app "
        f"{runtime_total:,} bytes across {len(RUNTIME_FILES) + 1} files."
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="Check tracked builds without rewriting")
    build(parser.parse_args().check)

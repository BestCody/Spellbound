#!/usr/bin/env python3
"""Build Spellbound's low-resident-memory Hacker Badge runtime."""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME_FILES = (
    "main.lua", "app.lua",
    "gesture_dtw.lua", "gesture_sig.lua", "casting.lua", "training.lua",
    "network.lua", "net_rx.lua", "net_tick.lua", "engine.lua",
)
LAZY_FILES = set(RUNTIME_FILES) - {"main.lua", "app.lua"}
BUILD_ABI = 3
LICENSE_FILE = "LICENSE.txt"
LEGACY_STANDALONE = ROOT / "dist" / "Spellbound-install.lua"

def state_field_map() -> dict[str, int]:
    """Give internal SPELLBOUND_STATE fields compact production-only array slots."""
    fields: set[str] = set()
    for path in (ROOT / "src").glob("*.lua"):
        fields.update(re.findall(r"\bS\.([A-Za-z_][A-Za-z0-9_]*)", path.read_text()))
    return {field: index for index, field in enumerate(sorted(fields), 1)}

STATE_FIELDS = state_field_map()

def optimize_lua(text: str) -> str:
    text = re.sub(
        r"\bfunction\s+S\.([A-Za-z_][A-Za-z0-9_]*)\s*\(",
        lambda match: f"S[{STATE_FIELDS[match.group(1)]}]=function(",
        text,
    )
    return re.sub(
        r"\bS\.([A-Za-z_][A-Za-z0-9_]*)",
        lambda match: f"S[{STATE_FIELDS[match.group(1)]}]",
        text,
    )

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

def production_source(name: str, text: str) -> str:
    if name == "main.lua":
        text = text.split("-- TEST_EXPORTS_BEGIN", 1)[0]
    begin, end = "-- TEST_ONLY_BEGIN", "-- TEST_ONLY_END"
    while begin in text:
        before, rest = text.split(begin, 1)
        if end not in rest:
            raise ValueError(f"Unclosed {begin} in {name}")
        _, after = rest.split(end, 1)
        text = before + after
    return text.rstrip() + "\n"

def compact_lua(text: str) -> str:
    """Conservative compaction: remove blank/full-line comments and indentation only."""
    lines = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("--"):
            continue
        lines.append(line)
    return "\n".join(lines) + "\n"

def build(check: bool = False) -> None:
    manifest = (ROOT / "manifest.cfg").read_text(encoding="utf-8")
    validate_manifest(manifest)
    output: dict[Path, bytes] = {}
    for name in RUNTIME_FILES:
        source = (ROOT / "src" / name).read_text(encoding="utf-8")
        code = compact_lua(optimize_lua(production_source(name, source)))
        if name in LAZY_FILES:
            build_slot = STATE_FIELDS["build_id"]
            code = (f'if SPELLBOUND_STATE[{build_slot}]~={BUILD_ABI} then '
                    'error("Spellbound file versions do not match; reinstall every app file") end\n' + code)
        code.encode("ascii")
        size = len(code.encode())
        if name == "main.lua" and size > 2 * 1024:
            raise ValueError("main.lua must remain under 2 KiB")
        if name == "app.lua" and size > 6 * 1024:
            raise ValueError("resident app.lua must remain under 6 KiB")
        if name in LAZY_FILES and size > 4 * 1024:
            raise ValueError(f"{name} exceeds 4 KiB lazy-module compile budget")
        output[ROOT / "dist" / "app" / name] = code.encode()
    output[ROOT / "dist" / "app" / "manifest.cfg"] = manifest.encode()
    output[ROOT / "dist" / "app" / LICENSE_FILE] = (ROOT / "LICENSE").read_bytes().replace(b"\r\n", b"\n")

    runtime_total = sum(len(v) for p, v in output.items() if p.parent.name == "app")
    if runtime_total > 28 * 1024:
        raise ValueError("Modular app exceeds the 28 KiB low-memory code budget")
    if runtime_total >= 48 * 1024:
        raise ValueError("Modular app exceeds documented 48 KiB Share bundle limit")
    if len(expected := (set(RUNTIME_FILES) | {"manifest.cfg", LICENSE_FILE})) > 16:
        raise ValueError("Modular app exceeds documented 16-file Share bundle limit")

    report = {
        "version": next((line.split("=", 1)[1] for line in manifest.splitlines()
                         if line.startswith("version=")), "unknown"),
        "package_mode": "deep-memory-side-effect",
        "runtime_files": len(expected),
        "runtime_bytes": runtime_total,
        "standalone_import": False,
    }
    output[ROOT / "dist" / "build-info.json"] = (json.dumps(report, indent=2) + "\n").encode()

    app_dir = ROOT / "dist" / "app"
    actual = {p.name for p in app_dir.iterdir() if p.is_file()} if app_dir.exists() else set()
    if check:
        extra = actual - expected
        if extra:
            raise SystemExit("Unexpected runtime files: " + ", ".join(sorted(extra)))
        if LEGACY_STANDALONE.exists():
            raise SystemExit("Legacy dist/Spellbound-install.lua exists")
    else:
        app_dir.mkdir(parents=True, exist_ok=True)
        for path in app_dir.iterdir():
            if path.is_file() and path.name not in expected:
                path.unlink()
        if LEGACY_STANDALONE.exists():
            LEGACY_STANDALONE.unlink()

    for path, content in output.items():
        if check:
            current = path.read_bytes().replace(b"\r\n", b"\n") if path.is_file() else None
            if current != content:
                raise SystemExit(
                    f"Out-of-date build: {path.relative_to(ROOT)}; run python tools/build.py"
                )
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)

    print(
        f"{'Verified' if check else 'Built'} deep-memory app "
        f"{runtime_total:,} bytes across {len(expected)} files."
    )

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="Check tracked builds without rewriting")
    build(parser.parse_args().check)

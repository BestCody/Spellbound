"""Tests for manifest, low-resident-memory architecture, and generated package."""
import runpy
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
mod = runpy.run_path(str(ROOT / "tools/build.py"))
validate = mod["validate_manifest"]
compact = mod["compact_lua"]
production = mod["production_source"]
RUNTIME_FILES = mod["RUNTIME_FILES"]
BASE = "slug=spellbound\nname=Spellbound\napi=2\nheap_kb=96\n"

class ManifestTests(unittest.TestCase):
    def test_current_manifest(self):
        validate((ROOT / "manifest.cfg").read_text())
    def test_comments_and_optional_fields(self):
        validate("# App settings\n" + BASE + "icon=SB\nversion=0.2.0\n")
    def test_duplicate_version_rejected(self):
        with self.assertRaises(ValueError):
            validate(BASE + "version=0.1.0\nversion=0.2.0\n")
    def test_unsupported_heap_rejected(self):
        with self.assertRaises(ValueError):
            validate(BASE.replace("heap_kb=96", "heap_kb=128"))
    def test_wrong_slug_rejected(self):
        with self.assertRaises(ValueError):
            validate(BASE.replace("slug=spellbound", "slug=other"))
    def test_conflicting_home_options_rejected(self):
        with self.assertRaises(ValueError):
            validate(BASE + "home_button=1\nconfirm_home=1\n")

class MemoryArchitectureTests(unittest.TestCase):
    def test_main_is_tiny_bootstrap(self):
        main = (ROOT / "src" / "main.lua").read_text()
        prod = main.split("-- TEST_EXPORTS_BEGIN", 1)[0]
        self.assertLess(len(prod.encode()), 2048)
        self.assertIn('require("app")', prod)
        for forbidden in ("core", "ui", "gesture_sig", "gesture_dtw", "engine", "network"):
            self.assertNotIn(f'require("{forbidden}")', prod)

    def test_startup_cache_surface_is_only_app(self):
        app = (ROOT / "src" / "app.lua").read_text()
        self.assertNotIn('require("core")', app)
        self.assertNotIn('require("ui")', app)
        self.assertIn("SPELLBOUND_STATE=S", app)
        self.assertIn("badge.ui.label", app)
        self.assertEqual(len(RUNTIME_FILES), 10)
        for removed in ("core.lua", "ui.lua", "net_buttons.lua", "effects.lua"):
            self.assertNotIn(removed, RUNTIME_FILES)
            self.assertFalse((ROOT / "dist" / "app" / removed).exists())

    def test_teach_and_duel_each_add_four_modules(self):
        app = (ROOT / "src" / "app.lua").read_text()
        teach = ["gesture_dtw", "gesture_sig", "casting", "training"]
        duel = ["network", "net_rx", "net_tick", "engine"]
        for name in teach + duel:
            self.assertEqual(app.count(f'require("{name}")'), 1)
        self.assertLess(app.index('require("gesture_dtw")'), app.index('require("gesture_sig")'))
        self.assertLess(app.index('require("network")'), app.index('require("engine")'))

    def test_lazy_modules_are_compact_side_effect_installers(self):
        lazy = set(RUNTIME_FILES) - {"main.lua", "app.lua"}
        for name in lazy:
            src = (ROOT / "src" / name).read_text()
            out = (ROOT / "dist" / "app" / name).read_text()
            self.assertIn("SPELLBOUND_STATE", src)
            self.assertLessEqual(len(out.encode()), 4096, name)
            self.assertFalse(any(line.strip().startswith("--") for line in out.splitlines()))

    def test_flat_match_state_and_lazy_models(self):
        resident = (ROOT / "src" / "app.lua").read_text()
        engine = (ROOT / "src" / "engine.lua").read_text()
        training = (ROOT / "src" / "training.lua").read_text()
        self.assertNotIn("models={{},{},{}}", resident)
        self.assertIn("S.models=S.models or", training)
        self.assertIn("return {0,100,100,75,75", engine)
        for nested in ("hp={", "mana={", "shield={", "incoming={", "cd={{"):
            self.assertNotIn(nested, engine)

    def test_generated_package_is_exact_and_compacted(self):
        expected = set(RUNTIME_FILES) | {"manifest.cfg"}
        actual = {p.name for p in (ROOT / "dist" / "app").iterdir() if p.is_file()}
        self.assertEqual(actual, expected)
        app_src = (ROOT / "src" / "app.lua").read_text()
        app_out = (ROOT / "dist" / "app" / "app.lua").read_text()
        self.assertEqual(app_out, compact(production("app.lua", app_src)))
        self.assertLess(len(app_out), len(app_src))

    def test_production_has_no_diagnostic_allocation_paths(self):
        production_text = "\n".join(
            (ROOT / "dist" / "app" / name).read_text() for name in RUNTIME_FILES
        )
        for diagnostic in ("badge.sys.log", "badge.sys.stats", "GESTURE ", "MEM "):
            self.assertNotIn(diagnostic, production_text)
        runtime_bytes = sum(
            path.stat().st_size for path in (ROOT / "dist" / "app").iterdir()
            if path.is_file()
        )
        self.assertLessEqual(runtime_bytes, 28 * 1024)

if __name__ == "__main__":
    unittest.main()

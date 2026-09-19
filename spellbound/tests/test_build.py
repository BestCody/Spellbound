"""Manifest contract tests from the supplied badge guide."""
import runpy
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
validate = runpy.run_path(str(ROOT / "tools/build.py"))["validate_manifest"]
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

    def test_main_is_tiny_bootstrap(self):
        main = (ROOT / "src" / "main.lua").read_text()
        production = main.split("-- TEST_EXPORTS_BEGIN", 1)[0]
        self.assertLess(len(production.encode()), 2048)
        self.assertIn('require("app")', production)
        self.assertNotIn('require("gesture")', production)
        self.assertNotIn('require("engine")', production)
        self.assertNotIn('badge.ui.', production)

    def test_app_export_has_bootstrap_fallback(self):
        main = (ROOT / "src" / "main.lua").read_text()
        app = (ROOT / "src" / "app.lua").read_text()
        self.assertIn("SPELLBOUND_APP", main)
        self.assertIn('type(candidate)~="table"', main)
        self.assertIn("SPELLBOUND_APP=APP", app)
        self.assertIn("APP.enter,APP.tick,APP.button,APP.exit", app)
        self.assertLess(app.index("APP.enter,APP.tick,APP.button,APP.exit"), app.index("return APP"))

    def test_heavy_features_are_lazy_and_micro_chunked(self):
        app = (ROOT / "src" / "app.lua").read_text()
        casting = (ROOT / "src" / "casting.lua").read_text()
        network = (ROOT / "src" / "network.lua").read_text()
        self.assertIn('install("ui",root)', app)
        self.assertIn('install("network")', app)
        self.assertIn('require("gesture_sig")', app)
        self.assertIn('require("gesture_dtw")', app)
        self.assertIn('require("casting")', app)
        self.assertIn('require("training")', app)
        for marker in (
            "teach-after-gesture-sig", "teach-after-casting",
            "teach-after-gesture-dtw", "teach-after-training",
        ):
            self.assertIn(marker, app)
        self.assertNotIn('require("gesture")', app)
        self.assertNotIn('require("engine")', app)
        self.assertNotIn('require(', casting)
        self.assertIn('require("engine")', network)
        self.assertIn('require("net_rx")', network)
        self.assertIn('require("net_tick")', network)
        self.assertFalse((ROOT / "dist" / "app" / "gesture.lua").exists())
        self.assertNotIn("-- TEST_ONLY_BEGIN", (ROOT / "dist" / "app" / "app.lua").read_text())

        lazy = {
            "network.lua", "net_rx.lua", "net_tick.lua", "casting.lua",
            "training.lua", "gesture_sig.lua", "gesture_dtw.lua", "engine.lua",
        }
        for name in lazy:
            size = len((ROOT / "src" / name).read_bytes())
            self.assertLessEqual(size, 4096, f"{name} grew beyond 4 KiB")
        self.assertLessEqual(len(list((ROOT / "dist" / "app").iterdir())), 16)

if __name__ == "__main__":
    unittest.main()

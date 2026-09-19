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

    def test_heavy_features_are_lazy(self):
        app = (ROOT / "src" / "app.lua").read_text()
        casting = (ROOT / "src" / "casting.lua").read_text()
        network = (ROOT / "src" / "network.lua").read_text()
        self.assertIn('install("ui",root)', app)
        self.assertIn('install("network")', app)
        self.assertIn('install("casting")', app)
        self.assertNotIn('require("gesture")', app)
        self.assertNotIn('require("engine")', app)
        self.assertIn('require("gesture")', casting)
        self.assertIn('require("engine")', network)

if __name__ == "__main__":
    unittest.main()

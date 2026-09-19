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

    def test_startup_loads_modules_before_ui(self):
        main = (ROOT / "src" / "main.lua").read_text()
        enter = main.split("function on_enter(root)", 1)[1].split("function on_tick()", 1)[0]
        self.assertLess(enter.index("load_components()"), enter.index("ui_create(root)"))
        self.assertIn("ui_create,label=nil,nil", enter)

        loader = main.split("local function load_components()", 1)[1].split(
            "local function send_state", 1
        )[0]
        self.assertNotIn("ui_create,label=nil,nil", loader)

if __name__ == "__main__":
    unittest.main()

"""Acceptance boundaries for budget evidence; no Godot or device required."""
import copy
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import vo_budget as budget


def report(touch=False):
    source = {key: 1 for key in budget.METRICS}
    source.update(scope="whole subtree including hidden", unsupported_textures=[])
    scenes = {name: {"samples": [{"source": copy.deepcopy(source), "rendered": {}}
                                 for _ in range(1 if name == "coast_battle" else 3)]}
              for name in budget.SCENES}
    return {"benchmark": "budget-011", "budget_schema": 2, "problems": 0,
            "focus_losses": [], "passes": [{"segments": scenes}],
            "engine": {"hash": "tested-engine", "string": "tested engine"},
            "ground": {"baked_usable": True, "runtime_generator": "ground-a",
                       "shipped_generator": "ground-a"},
            "touch": touch, "window": [2400, 1080] if touch else [1280, 720],
            "quality": "mid", "render_height": 720}


class BudgetEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def write(self, name, data):
        path = self.root / name
        path.write_text(json.dumps(data))
        return path

    def test_stale_ground_is_not_current_evidence(self):
        data = report()
        data["ground"]["baked_usable"] = False
        with self.assertRaisesRegex(ValueError, "current ground"):
            budget.load_report(self.write("stale.json", data), require_current=True)

    def test_legacy_reports_remain_readable_but_cannot_be_promoted(self):
        data = report()
        del data["budget_schema"]
        path = self.write("legacy.json", data)
        budget.load_report(path)
        with self.assertRaises(ValueError):
            budget.load_report(path, require_current=True)

    def test_focus_loss_and_nonfinite_inventory_are_rejected(self):
        for change in ("focus", "nan"):
            data = report()
            if change == "focus":
                data["focus_losses"] = [10]
            else:
                data["passes"][0]["segments"]["coastal_path"]["samples"][0]["source"]["source_triangles"] = float("nan")
            with self.assertRaises(ValueError):
                budget.load_report(self.write(change + ".json", data))

    def test_rendered_summaries_must_match_raw_trace(self):
        data = report()
        sample = data["passes"][0]["segments"]["coast_battle"]["samples"][0]
        sample["rendered"] = {"frames": 2, "trace": {"frame_ms": [1, 2]},
                              "summary": {"frame_ms": {"median": 1, "p95": 2, "p99": 2, "max": 2}}}
        with self.assertRaisesRegex(ValueError, "raw trace"):
            budget.load_report(self.write("bad-trace.json", data))

    def test_mixed_epochs_and_wrong_touch_aspect_do_not_replace_limits(self):
        for change in ("engine", "ground", "aspect"):
            desktop, touch = report(), report(True)
            if change == "engine":
                touch["engine"]["hash"] = "different-engine"
            elif change == "ground":
                touch["ground"].update(runtime_generator="ground-b", shipped_generator="ground-b")
            else:
                touch["window"] = [1280, 720]
            args = SimpleNamespace(desktop=self.write("desktop.json", desktop),
                                   touch_report=self.write("touch.json", touch), rendered=[])
            ledger = self.root / "ledger"
            ledger.mkdir(exist_ok=True)
            marker = ledger / "budgets.json"
            marker.write_text("reviewed limits")
            with patch.multiple(budget, ROOT=self.root, LEDGER=ledger), self.assertRaises(ValueError):
                budget.generate(args)
            self.assertEqual(marker.read_text(), "reviewed limits")


if __name__ == "__main__":
    unittest.main()

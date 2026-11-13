"""Checks that the evidence validator rejects invalid controlled experiments."""
from contextlib import redirect_stdout
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest

import vo_shadow_sweep as shadow


def fixture():
    segment = {"frames": 2, "trace": {"gpu_ms": [2.0, 4.0], "frame_ms": [16.0, 18.0]},
               "summary": {"gpu_ms": {"median": 3.0, "p95": 4.0, "p99": 4.0, "max": 4.0},
                           "frame_ms": {"median": 17.0, "p95": 18.0, "p99": 18.0, "max": 18.0}},
               "availability": {"gpu_timing": True},
               "diagnosis": {"lights": [{"path": "@DirectionalLight3D@12", "type": "DirectionalLight3D",
                                         "shadows": True, "distance": 30, "splits": 1, "visible": True}]}}
    passes = []
    for i, enabled in enumerate([True, False, True]):
        batch = {"shadows": enabled, "focus_losses": [], "render_height": 720, "render_size": [1280, 720],
                 "refresh_hz": 60, "vsync": 1, "max_fps": 60, "quality": "mid",
                 "segments": {name: copy.deepcopy(segment) for name in shadow.SCENES}}
        for part in batch["segments"].values():
            part["diagnosis"]["lights"][0].update(shadows=enabled, path=f"@DirectionalLight3D@{12+i}")
        passes.append(batch)
    return {"problems": 0, "focus_losses": [], "passes": passes, "platform": "SYNTHETIC", "renderer": "mobile"}


class Validation(unittest.TestCase):
    def validate(self, data):
        with tempfile.TemporaryDirectory(prefix="vo-shadow-test-") as folder:
            path = Path(folder) / "report.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            with redirect_stdout(io.StringIO()):
                return shadow.summarize(path)

    def test_valid_and_generated_node_names(self):
        self.assertEqual(self.validate(fixture())["scenes"]["coastal_path"]["gpu_delta_ms"], 0)

    def test_rejects_focus_loss(self):
        data = fixture()
        data["passes"][1]["focus_losses"] = [100]
        with self.assertRaises(ValueError):
            self.validate(data)

    def test_rejects_light_still_casting(self):
        data = fixture()
        data["passes"][1]["segments"]["coastal_path"]["diagnosis"]["lights"][0]["shadows"] = True
        with self.assertRaises(ValueError):
            self.validate(data)

    def test_rejects_changed_distance(self):
        data = fixture()
        data["passes"][2]["segments"]["coastal_path"]["diagnosis"]["lights"][0]["distance"] = 80
        with self.assertRaises(ValueError):
            self.validate(data)

    def test_rejects_incorrect_summary(self):
        data = fixture()
        data["passes"][1]["segments"]["coastal_path"]["summary"]["gpu_ms"]["median"] = 0
        with self.assertRaises(ValueError):
            self.validate(data)

    def test_unsupported_gpu_is_not_a_saving(self):
        data = fixture()
        for batch in data["passes"]:
            for segment in batch["segments"].values():
                segment["trace"]["gpu_ms"] = [0, 0]
                segment["summary"]["gpu_ms"] = dict.fromkeys(["median", "p95", "p99", "max"], 0)
                segment["availability"]["gpu_timing"] = False
        self.assertIsNone(self.validate(data)["scenes"]["coastal_path"]["gpu_delta_ms"])


if __name__ == "__main__":
    unittest.main()

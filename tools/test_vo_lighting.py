"""Reject mislabeled indoor controls and film measurements from the wrong viewport/setup."""
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import tempfile
import unittest

import vo_lighting as lighting


def fixture():
    batches = []
    for index in range(3):
        scenes = {}
        for name, frames in [("hero_house", 240), ("largest_interior", 240), ("hatch", 504), ("merge", 570)]:
            experiment = {"map": name, "distance": [100, 30, 100][index], "splits": [2, 1, 2][index]} if frames == 240 else {
                "key_shadow": index != 1, "key_range": 26 if name == "hatch" else 41.6, "key_angle": 26,
                "stage_scale": 1 if name == "hatch" else 1.6, "simulation_dt": 1/60, "elapsed": frames/60,
                "viewport_size": [1280, 720]}
            scenes[name] = {"frames": frames, "experiment": experiment, "trace": {"gpu_ms": [2.0]*frames, "frame_ms": [16.0]*frames},
                            "summary": {key: dict.fromkeys(["median", "p95", "p99", "max"], value) for key,value in [("gpu_ms",2.0),("frame_ms",16.0)]},
                            "availability": {"gpu_timing": True}}
        batches.append({"focus_losses": [], "segments": scenes, "render_height": 720, "render_size": [1280,720],
                        "refresh_hz": 60, "vsync": 1, "max_fps": 60, "quality": "mid"})
    return {"passes": batches, "problems": 0, "focus_losses": [], "platform": "SYNTHETIC", "renderer": "mobile", "window": [1920,1080]}


class Evidence(unittest.TestCase):
    def validate(self, data):
        with tempfile.TemporaryDirectory(prefix="vo-lighting-test-") as folder:
            path = Path(folder)/"report.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            with redirect_stdout(io.StringIO()):
                return lighting.summarize(path)

    def test_accepts_controls(self):
        self.assertEqual(self.validate(fixture())["scenes"]["hero_house"]["gpu_delta_ms"], 0)

    def test_rejects_focus_loss(self):
        data = fixture()
        data["focus_losses"] = [5]
        with self.assertRaises(ValueError):
            self.validate(data)

    def test_rejects_old_setting_mislabeled_as_approved(self):
        data = fixture()
        data["passes"][1]["segments"]["hero_house"]["experiment"]["distance"] = 100
        with self.assertRaises(ValueError):
            self.validate(data)

    def test_rejects_unscaled_merge_light(self):
        data = fixture()
        data["passes"][1]["segments"]["merge"]["experiment"]["key_range"] = 26
        with self.assertRaises(ValueError):
            self.validate(data)

    def test_rejects_changed_film_viewport(self):
        data = fixture()
        data["passes"][1]["segments"]["hatch"]["experiment"]["viewport_size"] = [1920,1080]
        with self.assertRaises(ValueError):
            self.validate(data)

    def test_rejects_wrong_animation_time(self):
        data = fixture()
        data["passes"][1]["segments"]["merge"]["experiment"]["elapsed"] = 7.5
        with self.assertRaises(ValueError):
            self.validate(data)


if __name__ == "__main__":
    unittest.main()

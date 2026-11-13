"""Fetch only the two Windows templates from the official Godot archive using HTTP ranges.

The complete archive is not downloaded/hashed. HTTPS provenance and ZIP entry CRCs are checked;
per-file SHA256s and the release's full-archive digest are recorded separately.
"""
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile
from look import model_lock

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/tools/godot-windows-templates/4.7.stable"
UA = {"User-Agent": "RubyCocoon-build-tools"}


class RangeFile(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.size, self.position, self.transferred = url, size, 0, 0

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position+offset if whence == 1 else self.size+offset
        if self.position < 0:
            raise ValueError("Negative archive offset")
        return self.position

    def read(self, count=-1):
        count = self.size-self.position if count < 0 else min(count, self.size-self.position)
        if count <= 0: return b""
        if count > 256*1024*1024:
            raise ValueError("Unexpectedly large range request")
        start = self.position
        request = urllib.request.Request(self.url, headers={**UA, "Range": f"bytes={start}-{start+count-1}"})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206 or not response.headers.get("Content-Range", "").startswith(f"bytes {start}-"):
                raise RuntimeError("Server did not honor the requested range; no full archive downloaded")
            data = response.read(count+1)
        if len(data) != count:
            raise RuntimeError("Incomplete archive range")
        self.position += count
        self.transferred += count
        return data


def main():
    request = urllib.request.Request("https://api.github.com/repos/godotengine/godot/releases/tags/4.7-stable", headers=UA)
    release = json.load(urllib.request.urlopen(request, timeout=30))
    asset = next(a for a in release["assets"] if a["name"] == "Godot_v4.7-stable_export_templates.tpz")
    url = asset["browser_download_url"]
    assert url.startswith("https://github.com/godotengine/godot/releases/download/4.7-stable/")
    OUT.mkdir(parents=True, exist_ok=True)
    result = {"source": url, "archive_bytes": asset["size"], "release_archive_digest": asset.get("digest"),
              "full_archive_digest_verified": False, "entry_crc_verified": True, "files": {}}
    with model_lock(timeout=3600):
        remote = RangeFile(url, asset["size"])
        with zipfile.ZipFile(remote) as archive:
            for filename in ["windows_debug_x86_64.exe", "windows_release_x86_64.exe"]:
                entries = [e for e in archive.infolist() if Path(e.filename).name == filename]
                if len(entries) != 1:
                    raise RuntimeError("Ambiguous/missing template: " + filename)
                entry = entries[0]
                data = archive.read(entry)  # zipfile checks the entry CRC on complete read.
                path = OUT / filename
                if path.exists() and path.read_bytes() != data:
                    raise RuntimeError("Existing template preserved: " + str(path))
                if not path.exists(): path.write_bytes(data)
                result["files"][filename] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "zip_crc32": f"{entry.CRC:08x}"}
                print("Prepared", filename, len(data), flush=True)
        result["downloaded_range_bytes"] = remote.transferred
    (OUT / "provenance.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__": main()

"""Restore only the unchanged shared AVI media declared in the runtime catalog."""
from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[1]
project = root / "godot/chibi_remake"
catalog = json.loads((project / "data/db/video_catalog.json").read_text(encoding="utf-8"))["files"]
shared = {name: entry for name, entry in catalog.items() if not entry.get("localOnly")}
assert len(shared) == 12
target = project / "media/videos"
target.mkdir(parents=True, exist_ok=True)
for name, entry in shared.items():
    source = root / "tmp" / name
    if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != entry["sha256"]:
        raise SystemExit(f"Missing or mismatched original input: {source}")
    shutil.copyfile(source, target / name)
print(f"Restored {len(shared)} unchanged shared AVI files; campaign MP4 files were not touched.")

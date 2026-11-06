"""Import verified unit types, including map-only civilians and reserved types.

No production menus or artwork are generated here. Those remain independent.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot/chibi_remake"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    source = ROOT / "research/units/data/units.json"
    research = read(source)
    sequences = read(ROOT / "research/units/data/anim_clips.json")["units"]
    atlases = read(PROJECT / "art/full/manifest.json")["atlases"]
    units = {}
    for row in research["units"]:
        key = str(row["id"])
        sprite = row["sprite"]
        animation = sequences[key]
        clips = {name: [direction["framesRel"] for direction in clip["dirs"]]
                 for name, clip in animation["clips"].items() if clip.get("dirs")}
        units[key] = {
            "name": row["name"], "category": row["category"],
            "spriteName": animation["sprite"], "w": sprite["w"], "h": sprite["h"],
            "frames": {"first": sprite["firstFrame"], "count": sprite["count"], "cols": sprite["cols"]},
            "clips": clips, "sheet": atlases[key]["texture"].removeprefix("res://"), "sheetK": 1,
            "hp": row["hp"], "attack": row["attackA"], "attackB": row["attackB"],
            "defence": row["defenceA"], "defenceB": row["defenceB"],
            "vision": row["vision"], "range": row["range"], "f9": row["speedRaw"],
            "costs": [row["cost"][kind] for kind in ["gold", "wood", "food"]],
            "costStone": row["cost"]["iron"], "expGain": row["killXp"], "moraleGain": row["morale"],
            "mitig": 0, "mitig2": 0, "alt": 0,
            "mapOnly": bool(row.get("mapOnly", False)), "reserved": bool(row.get("unused", False)),
        }
    target = PROJECT / "data/db/unit_definitions.json"
    target.write_text(json.dumps({"source": "research/units/data/units.json",
                                 "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                                 "units": units}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Imported {len(units)} verified unit definitions")


if __name__ == "__main__":
    main()

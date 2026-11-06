"""Import confirmed research as runtime definitions; preserve map/save revisions."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot/chibi_remake"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    buildings = read(ROOT / "research/buildings/data/buildings.json")["buildings"]
    production = read(ROOT / "research/buildings/data/production.json")["units"]
    existing = read(PROJECT / "data/db/production_units.json")
    definitions = copy.deepcopy(existing["units"])
    for path in sorted((PROJECT / "data").glob("chibi*.json")):
        for uid, definition in read(path)["units"].items():
            if uid not in definitions:
                definitions[uid] = definition
    unit_output = {}
    for uid, research in production.items():
        definition = copy.deepcopy(definitions[uid])
        cost = research["cost"]
        definition["costs"] = [cost["gold"], cost["wood"], cost["food"]]
        definition["costStone"] = cost["iron"]
        unit_output[uid] = definition
    (PROJECT / "data/db/production_units.json").write_text(json.dumps({
        "source": "research/buildings/data/production.json; existing HD unit definitions. Admission follows HQ/building level (README A-01 correction).",
        "units": unit_output}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    building_output = {}
    for research in buildings:
        uid = str(research["id"])
        definition = copy.deepcopy(definitions[uid])
        cost = research["cost"]
        definition["costs"] = [cost["gold"], cost["wood"], cost["food"]]
        definition["costStone"] = cost["iron"]
        stages = research["sprite"].get("construction", {})
        if "hp0" in stages:
            # Research offsets are absolute in UNIT.LWC; atlases are type-local.
            first = int(research["sprite"]["firstFrame"])
            definition["constructionFrames"] = [int(stages[k])-first for k in ("hp0", "hp33", "hp66", "hp100")]
        building_output[uid] = definition
    (PROJECT / "data/db/buildings.json").write_text(json.dumps({
        "source": "research/buildings/data/buildings.json; only confirmed costs/stages override existing map definitions",
        "units": building_output}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"Imported {len(building_output)} buildings and {len(unit_output)} production units")


if __name__ == "__main__":
    main()

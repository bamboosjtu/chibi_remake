"""Repair HD sampling metadata without resampling or replacing any artwork.

Use the source pose's height and foot anchor, rather than fitting a wide HD pose
into a narrow source rectangle. Transparent padding and adjacent single-figure
poses are excluded before calculating the scale. Multi-person units keep their
complete formation. Death poses retain their original collapsed proportions.
"""
import json
import statistics
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot/chibi_remake"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def bounds(alpha, single):
    solid = alpha > 96
    columns = np.flatnonzero(solid.sum(axis=0) >= 3)
    rows = np.flatnonzero(solid.sum(axis=1) >= 3)
    if not len(columns) or not len(rows):
        return None
    x0, x1 = int(columns[0]), int(columns[-1]) + 1
    if single:
        # Significant empty columns separate adjacent characters, not padding
        # belonging to the current character. Keep the largest whole figure.
        splits = np.flatnonzero(np.diff(columns) > max(8, alpha.shape[0] // 20)) + 1
        groups = np.split(columns, splits)
        chosen = max(groups, key=lambda xs: int(solid[:, xs[0]:xs[-1]+1].sum()))
        x0, x1 = int(chosen[0]), int(chosen[-1]) + 1
    within = solid[:, x0:x1]
    rows = np.flatnonzero(within.sum(axis=1) >= 3)
    if not len(rows):
        return None
    return max(0, x0-1), max(0, int(rows[0])-1), min(alpha.shape[1], x1+1), min(alpha.shape[0], int(rows[-1])+2)


def worker_regions(catalog, textures):
    """Worker pages have four columns but uneven painted row spacing.

    Recover whole poses from each column's transparent separators. Cropping the
    old uniform cells first cannot work: it both loses cargo and includes the
    next row. Require the accepted page's row count, so changed art fails loudly
    instead of silently shifting native animation indices.
    """
    result = {}
    for page in catalog["pages"]:
        if int(page["sourceId"]) != 30:
            continue
        path = "res://" + page["target"].removeprefix("godot/chibi_remake/")
        alpha = np.array(Image.open(PROJECT / path.removeprefix("res://")).getchannel("A"))
        textures[path] = alpha
        columns = int(page["columns"])
        for col in range(columns):
            x0 = round(col * alpha.shape[1] / columns)
            x1 = round((col+1) * alpha.shape[1] / columns)
            rows = np.flatnonzero((alpha[:, x0:x1] > 96).sum(axis=1) >= 3)
            bands = np.split(rows, np.flatnonzero(np.diff(rows) > 6) + 1)
            if len(bands) != int(page["rows"]) or any(not len(band) for band in bands):
                raise ValueError(f"{page['assetId']} column {col}: expected {page['rows']} separate poses")
            for row, band in enumerate(bands):
                y0, y1 = max(0, int(band[0])-1), min(alpha.shape[0], int(band[-1])+2)
                left, top, right, bottom = bounds(alpha[y0:y1, x0:x1], True)
                index = int(page["startFrame"]) + row * columns + col
                result[index] = [x0+left, y0+top, right-left, bottom-top]
    return result


def main():
    manifest = read(PROJECT / "art/full/manifest.json")
    catalog = read(PROJECT / "art/production/catalog.json")
    definitions = read(PROJECT / "data/db/production_units.json")["units"]
    for path in sorted((PROJECT / "data").glob("chibi*.json")):
        for uid, definition in read(path)["units"].items():
            definitions.setdefault(uid, definition)
    layouts, textures = {}, {}
    worker = worker_regions(catalog, textures)
    for source in catalog["assets"]:
        if source.get("category") != "units":
            continue
        uid = int(source["sourceId"])
        atlas = manifest["atlases"].get(str(uid), {})
        clips = definitions.get(str(uid), {}).get("clips", {})
        turn_all = {f for row in clips.get("turn", []) for f in row}
        turn = {f for f in turn_all if source["frameBounds"][f]}
        moving = turn_all | {f for row in clips.get("walk", []) for f in row}
        living = {f for name, rows in clips.items() if name != "die" for row in rows for f in row}
        stature = statistics.median(source["frameBounds"][f][3] for f in turn) if turn else None
        ground = statistics.median(source["frameBounds"][f][1]+source["frameBounds"][f][3] for f in turn) if turn else None
        result = {}
        for index, entry in enumerate(atlas.get("frames", [])):
            pose = source["frameBounds"][index]
            if pose is None or entry.get("skip") or entry.get("original"):
                continue
            path = entry.get("texture", atlas["texture"])
            if path not in textures:
                textures[path] = np.array(Image.open(PROJECT / path.removeprefix("res://")).getchannel("A"))
            x, y, w, h = worker[index] if uid == 30 else map(int, entry["region"])
            crop = bounds(textures[path][y:y+h, x:x+w], uid in {27, 28, 29, 30, 31, 32, 33, 35, 36, 45})
            if crop is None:
                continue
            left, top, right, bottom = crop
            width, height = right-left, bottom-top
            # Height and bottom come from the actual source pose, so carrying
            # a bundle grows the cargo, not the worker; fallen poses stay low.
            display_h = float(pose[3])
            foot = float(pose[1]+pose[3])
            if stature is not None and index in moving:
                # Some source action rows include a raised weapon. Generated
                # figures do not always repeat that silhouette exactly: keep
                # normal living stature within 10%, not a weapon-sized body.
                display_h = max(stature*0.9, min(stature*1.1, display_h))
                foot = max(ground-1, min(ground+1, foot))
            display_w = display_h * width / height
            cx = float(pose[0]) + float(pose[2]) * 0.5
            result[str(index)] = {"region": [x+left, y+top, width, height],
                                  "draw": [round(cx-display_w*0.5, 5), round(foot-display_h, 5), round(display_w, 5), display_h]}
        # A few historical clip rows reference blank/source-label cells. Hold
        # the nearest real pose in the same source-facing row; never make an
        # otherwise living unit disappear. Simulation action phases stay intact.
        group_columns = int(source.get("sourceGroupColumns", 1))
        available = [int(f) for f in result]
        for index in sorted(living):
            if str(index) in result or not available:
                continue
            same_row = [f for f in available if f // group_columns == index // group_columns]
            nearest = min(same_row or available, key=lambda f: abs(f-index))
            replacement = dict(result[str(nearest)])
            replacement["texture"] = atlas["frames"][nearest].get("texture", atlas["texture"])
            replacement["skip"] = False
            result[str(index)] = replacement
        layouts[str(uid)] = result
    output = {"source": "HD pixels + art/production/catalog.json source frameBounds; tools/hd/rebuild_unit_layout.py",
              "units": layouts}
    (PROJECT / "data/db/unit_display_layout.json").write_text(json.dumps(output, ensure_ascii=False, separators=(",", ":"))+"\n", encoding="utf-8")
    print(f"Unit display layouts: {len(layouts)} types, {sum(map(len, layouts.values()))} poses; no image bytes changed")


if __name__ == "__main__":
    main()

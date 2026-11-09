"""Sprite-gen try: the local steps between sprite-gen and the game (docs/sprite_gen_try.md).

Run with sprite-gen's venv Python (Pillow + NumPy), `-I`:
  python -I tools/sprite_try/sprite_try.py clean  --still IN.jpg --out still_clean.png [--erase x0,y0,x1,y1 ...]
  python -I tools/sprite_try/sprite_try.py pad    --frames frames/keyed --out keyed_pad [--px 16]
  python -I tools/sprite_try/sprite_try.py match  --frames keyed_pad [--ref 24]
  python -I tools/sprite_try/sprite_try.py game   --run RUN --picks "24-68:7,70-80:5,82,84,86,88,90,92,96,104,114,122,130,133-150:6"
                                                  --hit 86 --out assets/units/sprite_try --name hero_p [--tex 256]

clean: chroma still from a web tool -> erase watermarks (paint pure green), save PNG for `sprite-gen video-canvas`.
pad:   add transparent rows under every keyed frame (a blade planted in the ground touches the bottom edge and
       `video-loop --cycle once` refuses any edge contact).
match: IoU of every frame's silhouette against frame --ref: find where the move starts / returns to the rest pose.
game:  pick source frames per phase (a-b:n = n frames spread over a..b), crop to their union box, place that box in
       the token's 256-art square using the canvas report (cell 0 lands exactly on the standing still), write
       <name>_attack.png (atlas), <name>_attack.json (SpriteRig meta), <name>_still.png, preview .webp if img2webp.
RUN = folder with still/hero_new_still.png (cutout), canvas.report.json, clip/frames/frames.report.json, clip/keyed_pad/.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess

import numpy as np
from PIL import Image, ImageDraw


def cmd_clean(a: argparse.Namespace) -> None:
    im = Image.open(a.still).convert("RGB")
    d = ImageDraw.Draw(im)
    for box in a.erase or []:
        x0, y0, x1, y1 = (int(v) for v in box.split(","))
        d.rectangle((x0, y0, x1, y1), fill=(0, 255, 0))
    im.save(a.out)
    print(a.out, im.size, "corner", im.getpixel((4, 4)))


def cmd_pad(a: argparse.Namespace) -> None:
    os.makedirs(a.out, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(a.frames, "*.png"))):
        im = Image.open(f)
        c = Image.new("RGBA", (im.width, im.height + a.px), (0, 0, 0, 0))
        c.paste(im, (0, 0))
        c.save(os.path.join(a.out, os.path.basename(f)))
    print("padded", a.px, "px ->", a.out)


def _mask(path: str) -> np.ndarray:
    return np.array(Image.open(path).getchannel("A")) > 128


def cmd_match(a: argparse.Namespace) -> None:
    fs = sorted(glob.glob(os.path.join(a.frames, "*.png")))
    ref = _mask(fs[a.ref])
    out = []
    for i, f in enumerate(fs):
        m = _mask(f)
        out.append(f"{i}:{(m & ref).sum() / max(1, (m | ref).sum()):.2f}")
    print(" ".join(out))


def _picks(spec: str) -> list[int]:
    res: list[int] = []
    for part in spec.split(","):
        part = part.strip()
        if "-" in part:
            rng, _, n = part.partition(":")
            lo, hi = (int(v) for v in rng.split("-"))
            k = int(n) if n else hi - lo + 1
            res += [round(lo + (hi - lo) * i / (k - 1)) for i in range(k)] if k > 1 else [lo]
        else:
            res.append(int(part))
    return res


def cmd_game(a: argparse.Namespace) -> None:
    run = a.run
    canvas = json.load(open(os.path.join(run, "canvas.report.json")))
    frames_rep = json.load(open(os.path.join(run, "clip", "frames", "frames.report.json")))
    still_px = canvas["still"][0]
    off = canvas["offset"]
    s = frames_rep["width"] / canvas["canvas"][0]  # canvas px -> video px
    fps = frames_rep["fps"]
    picks = _picks(a.picks)
    if a.hit not in picks:
        raise SystemExit(f"--hit {a.hit} is not one of the picked frames {picks}")
    frames = [Image.open(os.path.join(run, "clip", "keyed_pad", f"frame-{i + 1:04d}.png")).convert("RGBA") for i in picks]
    os.makedirs(a.out, exist_ok=True)
    Image.open(os.path.join(run, "still", "hero_new_still.png")).resize((512, 512), Image.LANCZOS).save(
        os.path.join(a.out, f"{a.name}_still.png"))

    box = None
    for f in frames:
        b = f.getchannel("A").point(lambda v: 255 if v >= 8 else 0).getbbox()
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    box = (box[0] - 4, box[1] - 4, box[2] + 4, box[3] + 4)
    x0 = (box[0] / s - off[0]) / still_px
    y0 = (box[1] / s - off[1]) / still_px
    w = (box[2] - box[0]) / s / still_px
    h = (box[3] - box[1]) / s / still_px
    cw, ch = round(w * a.tex), round(h * a.tex)
    cols = 6
    rows = (len(frames) + cols - 1) // cols
    atlas = Image.new("RGBA", (cw * cols, ch * rows), (0, 0, 0, 0))
    lift: list[float] = []
    foot0 = None
    cells = []
    for k, f in enumerate(frames):
        rows_px = (np.array(f.getchannel("A")) >= 128).sum(1)
        bottom = int(np.nonzero(rows_px >= rows_px.max() / 4)[0].max())  # body bottom, not a blade tip / dust
        foot0 = bottom if foot0 is None else foot0
        lift.append(round(max(0.0, (foot0 - bottom) / s / still_px), 4))
        c = f.crop(box).resize((cw, ch), Image.LANCZOS)
        cells.append(c)
        atlas.paste(c, ((k % cols) * cw, (k // cols) * ch))
    atlas.save(os.path.join(a.out, f"{a.name}_attack.png"), optimize=True)
    ms = int(1000 // fps)
    hit_cell = picks.index(a.hit)
    info = {
        "source": "sprite-gen try (docs/sprite_gen_try.md): web still + web video, keyed/cut by sprite-gen; not final art",
        "cells": len(frames), "cols": cols, "cell_px": [cw, ch], "frame_ms": ms, "dur_ms": len(frames) * ms,
        "hit_ms": hit_cell * ms, "slash_ms": max(0, hit_cell - 2) * ms, "lift_sq": lift,
        "rect_sq": [round(x0, 4), round(y0, 4), round(w, 4), round(h, 4)], "source_frames": picks,
    }
    json.dump(info, open(os.path.join(a.out, f"{a.name}_attack.json"), "w"), indent=1)
    if shutil.which("img2webp"):  # preview loop (not used by the game)
        tmp = os.path.join(run, "preview_cells")
        os.makedirs(tmp, exist_ok=True)
        paths = []
        for k, c in enumerate(cells):
            p = os.path.join(tmp, f"{k:03d}.png")
            c.save(p)
            paths.append(p)
        paths += [paths[-1]] * 12
        subprocess.run(["img2webp", "-loop", "0", "-lossless", "-exact", "-d", str(ms), *paths, "-o",
                        os.path.join(run, f"{a.name}_attack_preview.webp")], check=True, capture_output=True)
    print(json.dumps({k: info[k] for k in ("cells", "frame_ms", "dur_ms", "hit_ms", "rect_sq")}), atlas.size)


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("clean")
    c.add_argument("--still", required=True)
    c.add_argument("--out", required=True)
    c.add_argument("--erase", action="append", help="x0,y0,x1,y1 painted pure green (watermark)")
    p = sub.add_parser("pad")
    p.add_argument("--frames", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--px", type=int, default=16)
    m = sub.add_parser("match")
    m.add_argument("--frames", required=True)
    m.add_argument("--ref", type=int, default=0)
    g = sub.add_parser("game")
    g.add_argument("--run", required=True)
    g.add_argument("--picks", required=True)
    g.add_argument("--hit", type=int, required=True, help="source frame where the blade lands (THE hit)")
    g.add_argument("--out", required=True)
    g.add_argument("--name", default="hero_p")
    g.add_argument("--tex", type=int, default=256, help="texture px per token square")
    a = ap.parse_args()
    {"clean": cmd_clean, "pad": cmd_pad, "match": cmd_match, "game": cmd_game}[a.cmd](a)


if __name__ == "__main__":
    main()

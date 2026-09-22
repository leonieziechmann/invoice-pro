"""compat-014: pixel diff of two render directories (Pillow + numpy).

Usage: python parity-diff.py DIR_A DIR_B OUT_DIR
For each PNG present in both: identical? else share of differing pixels (any
channel), share with a tolerance of 48/255 (ignores anti-aliasing noise), the
bounding box of the difference, and the best global vertical shift (-8..8 px)
with the diff share remaining after it. Writes a side-by-side A | B | diff PNG
for every non-identical page and prints a markdown table.
"""
import os
import sys

import numpy as np
from PIL import Image


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16)


def share(mask):
    return float(mask.mean()) * 100


def best_shift(a, b):
    best = (0, share(np.abs(a - b).max(axis=2) > 48))
    h = a.shape[0]
    for dy in range(-8, 9):
        if dy == 0:
            continue
        if dy > 0:
            aa, bb = a[: h - dy], b[dy:]
        else:
            aa, bb = a[-dy:], b[: h + dy]
        s = share(np.abs(aa - bb).max(axis=2) > 48)
        if s < best[1]:
            best = (dy, s)
    return best


def main(da, db, out):
    os.makedirs(out, exist_ok=True)
    names = sorted(set(os.listdir(da)) & set(os.listdir(db)))
    names = [n for n in names if n.endswith(".png")]
    only_a = sorted(n for n in set(os.listdir(da)) - set(os.listdir(db)) if n.endswith(".png"))
    only_b = sorted(n for n in set(os.listdir(db)) - set(os.listdir(da)) if n.endswith(".png"))
    print("| page | result | diff px % | diff px % (tol 48) | bbox (x0,y0,x1,y1) | best dy | % after dy |")
    print("|---|---|---|---|---|---|---|")
    n_same = 0
    for n in names:
        a, b = load(os.path.join(da, n)), load(os.path.join(db, n))
        if a.shape != b.shape:
            print(f"| {n} | SIZE {a.shape[1]}x{a.shape[0]} vs {b.shape[1]}x{b.shape[0]} | | | | | |")
            continue
        d = np.abs(a - b).max(axis=2)
        if not d.any():
            n_same += 1
            continue
        m, mt = d > 0, d > 48
        ys, xs = np.nonzero(m)
        bbox = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
        dy, after = best_shift(a, b)
        print(f"| {n} | differs | {share(m):.3f} | {share(mt):.3f} | {bbox} | {dy} | {after:.3f} |")
        vis = (a.astype(np.float32) * 0.25 + 191).astype(np.uint8)
        vis[mt] = (220, 0, 0)
        vis[m & ~mt] = (255, 170, 0)
        side = np.concatenate([a.astype(np.uint8), b.astype(np.uint8), vis], axis=1)
        Image.fromarray(side).save(os.path.join(out, n))
    print()
    print(f"identical pages: {n_same} / {len(names)}; only in A: {only_a or '-'}; only in B: {only_b or '-'}")


if __name__ == "__main__":
    main(*sys.argv[1:4])

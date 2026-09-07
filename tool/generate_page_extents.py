"""Generate assets/data/page_extents.json — for each page of each style, the
left/right fraction of the image occupied by the text block (blank margins
outside). Used by the reader to zoom to the largest size where all text fits.
"""
import json
from collections import deque

import numpy as np
from PIL import Image


def text_extent(path, exclude_frame):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    h, w, _ = a.shape
    # Dark ink (black text / verse ornaments).
    dark = a.sum(axis=2) < 420
    if exclude_frame:
        # Tajweed pages carry a colored decorative frame at the very edge,
        # connected to the image border. Flood-fill the border-connected
        # non-white region and drop it, leaving only the text inside.
        notwhite = a.sum(axis=2) < 690
        frame_region = np.zeros((h, w), bool)
        dq = deque()
        for x in range(w):
            for y in (0, h - 1):
                if notwhite[y, x] and not frame_region[y, x]:
                    frame_region[y, x] = True
                    dq.append((y, x))
        for y in range(h):
            for x in (0, w - 1):
                if notwhite[y, x] and not frame_region[y, x]:
                    frame_region[y, x] = True
                    dq.append((y, x))
        while dq:
            y, x = dq.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if (0 <= ny < h and 0 <= nx < w and not frame_region[ny, nx]
                        and notwhite[ny, nx]):
                    frame_region[ny, nx] = True
                    dq.append((ny, nx))
        dark = dark & ~frame_region
    cols = dark.any(axis=0)
    if not cols.any():
        return [0.0, 0.0]
    minx = int(np.argmax(cols))
    maxx = int(w - 1 - np.argmax(cols[::-1]))
    return [round(minx / w, 4), round((w - 1 - maxx) / w, 4)]


data = {}
for name, prefix, ext, ef in [
    ("madani", "assets/pages", "png", False),
    ("tajweed", "assets/tajweed", "jpg", True),
]:
    pages = {}
    for p in range(1, 605):
        pages[str(p)] = text_extent(f"{prefix}/page{p:03d}.{ext}", ef)
    data[name] = pages

with open("assets/data/page_extents.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

print("madani pages:", len(data["madani"]))
print("tajweed pages:", len(data["tajweed"]))
print("sample p422 madani:", data["madani"]["422"])
print("sample p422 tajweed:", data["tajweed"]["422"])
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
    # Any ink: dark text AND colored letters (Tajweed red/green) — anything
    # clearly not the white/cream background.
    ink = a.sum(axis=2) < 690
    if exclude_frame:
        # Tajweed pages carry a colored decorative frame at the very edge,
        # connected to the image border. Flood-fill the border-connected
        # non-white region and drop it, leaving only the text inside.
        frame_region = np.zeros((h, w), bool)
        dq = deque()
        for x in range(w):
            for y in (0, h - 1):
                if ink[y, x] and not frame_region[y, x]:
                    frame_region[y, x] = True
                    dq.append((y, x))
        for y in range(h):
            for x in (0, w - 1):
                if ink[y, x] and not frame_region[y, x]:
                    frame_region[y, x] = True
                    dq.append((y, x))
        while dq:
            y, x = dq.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if (0 <= ny < h and 0 <= nx < w and not frame_region[ny, nx]
                        and ink[ny, nx]):
                    frame_region[ny, nx] = True
                    dq.append((ny, nx))
        ink = ink & ~frame_region
    cols = ink.any(axis=0)
    if not cols.any():
        return [0.006, 0.006]
    minx = int(np.argmax(cols))
    maxx = int(w - 1 - np.argmax(cols[::-1]))
    # Sanity clamp: margins under 0.6% are treated as 0.6% (measurement
    # noise), over 12% means the flood fill ate connected text — cap it.
    left = min(max(minx / w, 0.006), 0.12)
    right = min(max((w - 1 - maxx) / w, 0.006), 0.12)
    return [round(left, 4), round(right, 4)]


def window_extent(path):
    """King Fahd digital editions: an ornamental frame surrounds a central
    text window. Returns 6 fractions of the page:
      [fl, fr, ft, fb, tl, tr] — frame left/right/top/bottom outer bounds,
      then the text window's left/right margins.
    The reader zooms so the FRAME fills the screen height (cropping only
    decoration), guarded so the TEXT window never exceeds the width."""
    a = np.asarray(
        Image.open(path).convert("RGB").resize((360, 512), Image.BILINEAR)
    ).astype(int)
    h, w, _ = a.shape
    # الخلفية: لون الرق الخارجي (البكسلات المنتظمة)، وأي اختلاف واضح عنه زخرفة.
    bg = np.median(a[::8, ::8].reshape(-1, 3), axis=0)
    deco = np.abs(a - bg).max(axis=2) > 28
    rows = deco.sum(axis=1) > 5
    cols = deco.sum(axis=0) > 5
    if not rows.any() or not cols.any():
        return [0.03, 0.03, 0.03, 0.03, 0.06, 0.06]
    t = int(np.argmax(rows))
    b = h - 1 - int(np.argmax(rows[::-1]))
    l = int(np.argmax(cols))
    r = w - 1 - int(np.argmax(cols[::-1]))

    def frac(v, total, lo=0.006, hi=0.30):
        return round(min(max(v / total, lo), hi), 4)

    # نافذة النص: أطول امتداد لأعمدة متجاوبة بها حبر في الشريط الأوسط.
    gray = a.mean(axis=2)
    strip = gray[int(h * 0.40): int(h * 0.60)]
    ink = strip.min(axis=0) < 210
    best = (0, 0)
    start = None
    for x, v in enumerate(ink):
        if v and start is None:
            start = x
        elif not v and start is not None:
            if x - start > best[1] - best[0]:
                best = (start, x)
            start = None
    if start is not None and w - start > best[1] - best[0]:
        best = (start, w)
    x0, x1 = best
    if x1 <= x0:
        tl = tr = 0.06
    else:
        tl = frac(x0, w, 0.01, 0.35)
        tr = frac(w - x1, w, 0.01, 0.35)
    return [frac(l, w), frac(w - 1 - r, w), frac(t, h), frac(h - 1 - b, h), tl, tr]


import sys

styles = [
    ("madani", "assets/pages", "png", False),
    ("tajweed", "assets/tajweed", "jpg", True),
    ("mumtaz", "assets/mumtaz", "webp", "window"),
    ("khas", "assets/khas", "webp", "window"),
    ("jawami", "assets/jawami", "webp", "window"),
    ("wasat", "assets/wasat", "webp", "window"),
]

# --only=a,b: أعد توليد أنماط محددة فقط مع الإبقاء على بقية البيانات القائمة.
only = None
for arg in sys.argv[1:]:
    if arg.startswith("--only="):
        only = set(arg.split("=")[1].split(","))

data = {}
try:
    with open("assets/data/page_extents.json", encoding="utf-8") as f:
        data = json.load(f)
except FileNotFoundError:
    pass

for name, prefix, ext, ef in styles:
    if only is not None and name not in only:
        continue
    pages = {}
    for p in range(1, 605):
        path = f"{prefix}/page{p:03d}.{ext}"
        if ef == "window":
            pages[str(p)] = window_extent(path)
        else:
            pages[str(p)] = text_extent(path, bool(ef))
    data[name] = pages

with open("assets/data/page_extents.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

print("madani pages:", len(data["madani"]))
print("tajweed pages:", len(data["tajweed"]))
print("sample p422 madani:", data["madani"]["422"])
print("sample p422 tajweed:", data["tajweed"]["422"])
for name in ("mumtaz", "khas", "jawami", "wasat"):
    print(f"sample p422 {name}:", data[name]["422"])
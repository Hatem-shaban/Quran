"""Fetch King Fahd Complex Hafs mushaf packs (different calligraphic fonts)
from mohamedaeldin/tatmaen-mushaf-packs (Git LFS) and convert them to
reasonably-sized WebP assets for the app.

Pack page N+2 == standard mushaf page N (page_003.png is Al-Fatiha, page 1).

Usage:
  python tool/fetch_font_packs.py            # all packs
  python tool/fetch_font_packs.py mumtaz     # one pack (resumable)
  python tool/fetch_font_packs.py --dry      # convert from already-downloaded
"""

import io
import json
import os
import sys
import urllib.request

from PIL import Image

BASE = (
    "https://media.githubusercontent.com/media/mohamedaeldin/"
    "tatmaen-mushaf-packs/main/packs/{pack}/pages/light/page_{n:03d}.png"
)
PACKS = {
    "mumtaz": "qurancomplex_mumtaz_v1",
    "khas": "qurancomplex_khas1_v1",
    "jawami": "qurancomplex_jawami_v1",
    "wasat": "qurancomplex_wasat_v1",
}
PAGES = 604
OFFSET = 2  # pack file page_00N.png holds standard page N-2
QUALITY = 80


def fetch(pack_id: str, n: int) -> Image.Image:
    url = BASE.format(pack=pack_id, n=n)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    if data[:8] == b"version " or b"git-lfs" in data[:200]:
        raise RuntimeError(f"LFS pointer returned for {url}")
    return Image.open(io.BytesIO(data))


def save_webp(im: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, "WEBP", quality=QUALITY, method=4)


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry" in sys.argv
    wanted = {k: PACKS[k] for k in args} if args else PACKS

    for short, pack_id in wanted.items():
        done = skipped = 0
        for std in range(1, PAGES + 1):
            out = f"assets/{short}/page{std:03d}.webp"
            if os.path.exists(out):
                skipped += 1
                continue
            if dry:
                print(f"[dry] would fetch {pack_id} pack#{std + OFFSET} -> {out}")
                continue
            im = fetch(pack_id, std + OFFSET)
            save_webp(im, out)
            done += 1
            if done % 50 == 0:
                print(f"  {short}: {std}/604")
        json.dump(
            {"pack": pack_id, "pages": PAGES, "offset": OFFSET},
            open(f"assets/{short}/meta.json", "w"),
        )
        print(f"{short}: done, {done} fetched, {skipped} already present")


if __name__ == "__main__":
    main()

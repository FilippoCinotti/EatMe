#!/usr/bin/env python3
"""Copy Flutter screenshot-test PNGs into the documented baseline."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--destination", type=Path, default=Path("docs/screenshots/mobile/en"))
    args = parser.parse_args()
    copied = 0
    for image in sorted(args.source.glob("*.png")):
        if image.stem.endswith("-dark"):
            theme = "dark"
        elif image.stem.endswith("-light"):
            theme = "light"
        else:
            continue
        destination = args.destination / theme / image.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(image, destination)
        copied += 1
    print(f"Collected {copied} Flutter screenshots")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

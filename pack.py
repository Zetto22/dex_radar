#!/usr/bin/env python3
"""Pack one mod folder into an installable zip (files at archive root).

Usage:
  ./pack dex_radar
  python pack.py dex_radar --out dist/

The zip matches gen1recomp Import / Update layout:
  manifest.json, main.lua, ... at the top of the archive (not nested).
"""

from __future__ import annotations

import argparse
import json
import sys
import zipfile
from pathlib import Path

SKIP_NAMES = {
    ".git",
    ".modkitignore",
    ".luarc.json",
    "Thumbs.db",
    ".DS_Store",
}
SKIP_SUFFIXES = {".zip", ".modpkg"}
SKIP_DIRS = {"tests", ".git"}


def should_skip(path: Path, mod_dir: Path) -> bool:
    rel = path.relative_to(mod_dir)
    parts = rel.parts
    if any(part in SKIP_DIRS for part in parts[:-1]):
        return True
    if path.name in SKIP_NAMES:
        return True
    if path.suffix.lower() in SKIP_SUFFIXES:
        return True
    return False


def pack(mod_dir: Path, out_dir: Path) -> Path:
    manifest_path = mod_dir / "manifest.json"
    if not mod_dir.is_dir():
        raise SystemExit(f"Mod folder not found: {mod_dir}")
    if not manifest_path.is_file():
        raise SystemExit(f"Missing manifest.json in {mod_dir}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    mod_id = manifest.get("id") or mod_dir.name
    version = manifest.get("version")
    if not version:
        raise SystemExit("manifest.json has no version")

    if mod_dir.name != mod_id:
        print(
            f"warning: folder name '{mod_dir.name}' != manifest id '{mod_id}'",
            file=sys.stderr,
        )

    out_dir.mkdir(parents=True, exist_ok=True)
    asset = out_dir / f"{mod_id}-{version}.zip"
    if asset.exists():
        asset.unlink()

    count = 0
    with zipfile.ZipFile(asset, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(mod_dir.rglob("*")):
            if not path.is_file():
                continue
            if should_skip(path, mod_dir):
                continue
            arcname = path.relative_to(mod_dir).as_posix()
            zf.write(path, arcname)
            count += 1

    if count == 0:
        asset.unlink(missing_ok=True)
        raise SystemExit(f"No files packed from {mod_dir}")

    print(f"Wrote {asset} ({count} files)")
    print("Install: copy into the game mods/ folder, or Import mod .zip in the launcher.")
    return asset


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Pack a mod folder into a gen1recomp-installable zip.",
    )
    parser.add_argument(
        "mod",
        help="Mod folder name at the repo root (e.g. dex_radar)",
    )
    parser.add_argument(
        "--out",
        default=".",
        help="Output directory for the zip (default: repo root)",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent
    mod_dir = root / args.mod
    out_dir = Path(args.out)
    if not out_dir.is_absolute():
        out_dir = root / out_dir

    pack(mod_dir, out_dir)


if __name__ == "__main__":
    main()

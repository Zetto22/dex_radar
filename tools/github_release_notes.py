#!/usr/bin/env python3
"""Build GitHub Release notes from CHANGELOG.md (Dramatic Shape style).

Usage:
  python tools/github_release_notes.py 1.0.0
  python tools/github_release_notes.py 1.0.0 --title-only
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

INSTALL = (
    "Download the .zip and install it from the game: "
    "MODS > Import mod .zip."
)

HEADING_RE = re.compile(
    r"^## \[([0-9]+\.[0-9]+\.[0-9]+[^\]]*)\][^\n]*\n(.*?)(?=^## |\Z)",
    re.M | re.S,
)
TITLE_META_RE = re.compile(
    r"<!--\s*release-title:\s*(.+?)\s*-->",
    re.I,
)
SECTION_RE = re.compile(r"^###\s+(\w+)\s*$", re.M)


def section_for(changelog: str, version: str) -> str | None:
    for match in HEADING_RE.finditer(changelog):
        ver = match.group(1).strip()
        if ver == version or ver.startswith(version + " "):
            return match.group(2).strip()
    return None


def headline(body: str, version: str) -> str:
    meta = TITLE_META_RE.search(body)
    if meta:
        return f"{version} - {meta.group(1).strip()}"

    prose: list[str] = []
    for line in body.splitlines():
        s = line.strip()
        if not s:
            if prose:
                break
            continue
        if s.startswith("###") or s.startswith("- ") or s.startswith("<!--"):
            if prose:
                break
            continue
        prose.append(s)
        break
    if prose:
        text = prose[0]
        text = re.split(r"(?<=[.!?])\s+", text, maxsplit=1)[0]
        text = text.rstrip(".")
        if len(text) > 72:
            text = text[:69].rstrip() + "..."
        return f"{version} - {text}"
    return version


def change_bullets(body: str) -> list[str]:
    bullets: list[str] = []
    skip = False
    current: str | None = None

    def flush() -> None:
        nonlocal current
        if current is not None:
            bullets.append(re.sub(r"\s+", " ", current).strip())
            current = None

    for line in body.splitlines():
        raw = line.rstrip()
        stripped = raw.strip()
        m = SECTION_RE.match(stripped)
        if m:
            flush()
            skip = m.group(1).lower() in {"notes", "note"}
            continue
        if skip:
            continue
        if stripped.startswith("- "):
            flush()
            current = stripped[2:].strip()
            continue
        if current is not None and raw[:1].isspace() and stripped:
            current = f"{current} {stripped}"
            continue
        if not stripped:
            flush()
            continue
        flush()
    flush()
    return bullets


def build_body(bullets: list[str]) -> str:
    parts = [INSTALL, ""]
    if bullets:
        parts.append("## Changes")
        parts.append("")
        parts.extend(f"- {b}" for b in bullets)
        parts.append("")
    return "\n".join(parts).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("version")
    parser.add_argument("--title-only", action="store_true")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    args = parser.parse_args()

    path = args.root / "CHANGELOG.md"
    if not path.is_file():
        print(f"missing {path}", file=sys.stderr)
        return 1
    text = path.read_text(encoding="utf-8")
    body = section_for(text, args.version)
    if body is None:
        print(f"no CHANGELOG section for {args.version}", file=sys.stderr)
        return 1

    if args.title_only:
        print(headline(body, args.version))
        return 0

    print(build_body(change_bullets(body)), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

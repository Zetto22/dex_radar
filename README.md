# gen1recomp_mods

Mods for [gen1recomp](https://github.com/bryanthaboi/gen1recomp) (LÖVE2D / Lua). Each mod lives in its own folder at the repo root.

API docs: [gen1recomp wiki](https://github.com/bryanthaboi/gen1recomp/wiki)

# Dex Radar

Lists wild Pokémon available on the **current map** (grass, water, fishing).

Compact party-icon list (up to 3 species on screen, plus section headers).
Unseen entries show as `?????` with silhouetted icons (no level/rate).
Owned species get a Poké Ball mark. Party icons follow the game **COLORS**
setting. Long map names in the header scroll instead of truncating. Opening
the radar does **not** mark seen/owned.

## Install

1. Copy this folder into the game's `mods/` directory  
   (or import the release zip)
2. Enable it in Options → Mod Manager
3. Restart (or `POKEPORT_DEV=1` + F5 while developing)

## How to open

1. **START → DEX RADAR**
2. **Hotkey** (default `R`) on the overworld

## Controls

| Input | Action |
|-------|--------|
| ↑ / ↓ | Move selection |
| ← / → | Jump selection |
| B | Close |

## Options

| Option | Default | Meaning |
|--------|---------|---------|
| SHOW LEVELS | on | Min–max level under the name (seen only) |
| SHOW RATES | on | `RATE##` under each species (seen only; habitat rate) |
| HOTKEY | on | Enable keyboard shortcut |
| HOTKEY KEY | R | Letter key (or OFF) |

## For other mods

Dex Radar exposes a small API via `mod.exports`. Resolve it with
`mod.find("dex_radar")` (nil if the mod is disabled / missing).

```lua
local radar = mod.find("dex_radar")
if not radar then return end
local ex = radar.exports

-- Sections for the current map (or pass an explicit mapId string):
-- { id, title, rate?, entries = { { species, minLv, maxLv }, ... } }
local sections = ex.collect(game)

local ids = ex.speciesOnMap(game)          -- unique ids, grass→water→fish
local n = ex.ownedCount(game)              -- { owned = n, total = m }
local done = ex.isOwnedOnMap(game)         -- true if owned == total (empty → true)
local seen = ex.isSeen(game, "PIDGEY")
local owned = ex.isOwned(game, "PIDGEY")
```

Calling these helpers does **not** mark Pokédex seen/owned.

## Notes

- Content mod (`affects_link: false`); disable to restore vanilla menus exactly.
- Map labels wider than the header window scroll (hold at each end, 16px/s);
  names that fit draw as a single static line.
- GitHub releases for in-game Update must use tag **`vX.Y.Z`** (e.g. `v1.0.0`)
  with asset **`dex_radar-X.Y.Z.zip`**. Prefixed tags are ignored by the launcher.
- License: [MIT](LICENSE) · Changes: [CHANGELOG.md](CHANGELOG.md)

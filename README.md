# gen1recomp_mods

Mods for [gen1recomp](https://github.com/bryanthaboi/gen1recomp) (LÖVE2D / Lua). Each mod lives in its own folder at the repo root.

API docs: [gen1recomp wiki](https://github.com/bryanthaboi/gen1recomp/wiki)

# Dex Radar

Lists wild Pokémon available on the **current map** (grass, water, fishing).
Works on **Gen 1 (RBY)** and **Gen 2 (Gold)**. On Gold it also lists
**headbutt**, **Rock Smash**, the **Bug Contest** pool in National Park, and
any **roaming** legendary currently on the route.

Compact party-icon list (up to 3 species on screen, plus section headers).
Unseen entries show as `?????` with silhouetted icons (no level/rate).
Owned species get a Poké Ball mark. Grayscale party icons follow the game
**COLORS** setting. Authored true-color icons (Unique Menu Icons in Unique
Colors / GBC Red, and similar packs) keep their literal hues. Long map names
in the header scroll instead of truncating; Gold uses the landmark / town-map
title when available. Opening the radar does **not** mark seen/owned.

On Gold, grass slots from morning / day / night are **merged** into one GRASS
section. Each species shows its encounter **share for the current time of day**
(e.g. `RATE 20 (M)`), including `0` when it only appears at another time.
On Gen 1, grass/water use the ROM slot table (`RATE 50`), and fishing is split
into Old / Good / Super Rod sections with per-rod rates. Gold fishing uses the
same rod sections (map fish group).

## Install

1. Copy this folder into the game's `mods/` directory  
   (or import the release zip)
2. Enable it in Options → Mod Manager
3. Restart (or `POKEPORT_DEV=1` + F5 while developing)

## How to open

1. **START → D.RADAR**
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
| SHOW RATES | on | Species encounter share (`RATE 50`). Gold grass adds ToD (`M`/`D`/`N`) |
| HOTKEY | on | Enable keyboard shortcut |
| HOTKEY KEY | R | Letter key (or OFF) |

## For other mods

Dex Radar exposes a small API via `mod.exports`. Resolve it with
`mod.find("dex_radar")` (nil if the mod is disabled / missing).

```lua
local radar = mod.find("dex_radar")
if not radar then return end
local ex = radar.exports

-- Sections for the current map (or pass an explicit mapId string).
-- Same shape on Gen 1 and Gen 2:
-- {
--   id, title,
--   habitatRate?,   -- map encounter chance (optional; grass/water)
--   tod?, todLabel?, -- Gen 2 grass only
--   entries = {
--     { species, minLv, maxLv, rate? },  -- rate = species share in that table
--   },
-- }
local sections = ex.collect(game)
-- species line:  section.entries[i].rate
-- map chance:    section.habitatRate

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
- Grayscale menu icons (vanilla and Unique Menu Icons **Original**) follow
  **COLORS**. Chromatic icon sheets skip the menu palette so Unique Colors /
  GBC Red stay as authored.
- Gen 2 fishing uses the map's fish group (not Gen 1 `field`), split per rod;
  species `0` sentinel rows (roll water instead) are omitted from the lists.
- Headbutt / Rock Smash rates blend common trees (~90%) with rare trees (~10%).
  Roamers only appear after Burned Tower and only on the route they occupy.
- GitHub releases for in-game Update must use tag **`vX.Y.Z`** (e.g. `v1.0.0`)
  with asset **`dex_radar-X.Y.Z.zip`**. Prefixed tags are ignored by the launcher.
- License: [MIT](LICENSE) · Changes: [CHANGELOG.md](CHANGELOG.md)

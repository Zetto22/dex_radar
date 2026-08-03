# Changelog

All notable changes to **Dex Radar** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project versions with the `version` field in `manifest.json`.

## [0.3.0] — 2026-08-03

### Added

- Public `mod.exports` for other mods:
  - `collect(game, mapId?)` — habitat sections with entries / rates
  - `speciesOnMap(game, mapId?)` — unique species ids (grass → water → fish)
  - `ownedCount(game, mapId?)` — `{ owned, total }`
  - `isOwnedOnMap(game, mapId?)` — all unique wilds owned (empty map → true)
  - `isSeen` / `isOwned` — thin Pokédex wrappers
- README **For other mods** with usage examples.

## [0.2.4] — 2026-08-03

### Changed

- Header counter is just `N/M` (right-aligned); dropped the `OWNED` label.

## [0.2.3] — 2026-08-03

### Fixed

- Up/Down list navigation and scroll (cursor wrap, keep selection on-screen).
- Selection cursor uses the Gen 1 arrow glyph (`Theme.cursor`) instead of
  ASCII `>`, which did not draw in the game font.
- Hold Up/Down to repeat, matching engine list menus.
- “More below” arrow when the list continues past the viewport.

## [0.2.2] — 2026-08-03

### Changed

- Full species names again (no 8-character truncate).
- Owned Poké Ball sits beside the name again.

## [0.2.1] — 2026-08-03

### Changed

- Removed the large front-sprite preview; list-only layout.
- Encounter rate shows per species under the level / Poké Ball line
  (e.g. `RATE20`), not on the section header.

## [0.2.0] — 2026-08-03

### Added

- Title counter `N/M OWNED` for unique species on the current map.
- Option **SHOW LEVELS** — min–max level from encounter slots on the same
  line as the owned Poké Ball mark.
- Option **SHOW RATES** — grass/water encounter rate on the section header
  (e.g. `GRASS RATE30`).
- Compact list with 16×16 party icons and a large front-sprite preview for
  the highlighted species (↑/↓ to move the cursor).

### Planned (next)

See `plans/dex-radar/ROADMAP.md` (1.0.0 path). Historical note: richer exports
shipped in **0.3.0**; Safari / Super Rod–only left to player reports after 1.0.0.

## [0.1.4] — 2026-08-03

### Changed

- Names longer than 8 characters truncate with `...` (e.g. `JIGGLYPU...`).
- Owned Poké Ball mark sits on the line below the name.

## [0.1.3] — 2026-08-03

### Changed

- List sprites draw at native 1:1 size (56px rows) instead of shrinking to a
  tiny slot; sprite column skips SGB shade remap so detail is preserved.

## [0.1.2] — 2026-08-03

### Changed

- Sharper list sprites: nearest-neighbor filter, integer downscale only, larger
  row, and a neutral gray SGB palette (fixes mushy / green-tinted art).

## [0.1.1] — 2026-08-03

### Added

- Mini Poké Ball icon beside species already owned (`pokedex.owned`), pure black and white.
- Manifest `github` field for launcher Update / Releases (`Zetto22/gen1recomp_mods`).

## [0.1.0] — 2026-08-03

### Added

- Start menu entry **DEX RADAR** (anchored before SAVE).
- Overworld screen listing wild species on the current map:
  - **GRASS** — unique species from grass encounter slots (common → rare)
  - **WATER** — unique species from water encounter slots
  - **FISH** — Old + Good rods (global) + Super Rod for the map, when the
    map has water slots and/or a Super Rod group (including Super-Rod-only maps)
- Front sprite + name per species; unseen Pokédex entries show as `?????`
  with a black silhouette (opening the radar does not mark seen).
- Mod options: **HOTKEY** toggle and **HOTKEY KEY** choice (default `R`,
  overworld-only via `input.step`).
- Empty state when the map has no wild data (`NO WILD POKEMON`).
- Optional `mod.exports.collect` for other mods.

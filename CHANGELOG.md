# Changelog

All notable changes to **Dex Radar** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project versions with the `version` field in `manifest.json`.

## [1.0.0] — 2026-08-03

<!-- release-title: First stable release -->

First stable release. Full feature set below; `mod.exports` and player UI are
semver-stable from here.

### Added

- Start menu row **DEX RADAR** (before SAVE) and overworld hotkey (default `R`,
  configurable / disableable in options).
- Wild species list for the current map: **GRASS**, **WATER**, and **FISH**
  (Old → Good → Super Rod; FISH also on Super Rod–only maps).
- Compact party-icon rows with owned Poké Ball mark and title counter `N/M`.
- Unseen species show as `?????` with silhouetted icons; levels and rates stay
  hidden until seen (opening the radar does not mark the Pokédex).
- Options **SHOW LEVELS**, **SHOW RATES**, **HOTKEY**, and **HOTKEY KEY**.
- Scrollable list (one section header + up to 3 Pokémon on screen), Gen 1
  cursor, and more-above / more-below arrows.
- Long map labels truncate to 15 characters plus `...`.
- Indoor / no-encounter maps show **NO WILD POKEMON**.
- Public `mod.exports` for other mods: `collect`, `speciesOnMap`, `ownedCount`,
  `isOwnedOnMap`, `isSeen`, `isOwned`.

### Notes

- Safari Zone and Super Rod–only maps use the shared encounter / `superRod`
  tables. Report gaps for a **1.0.x** patch if something looks wrong in-game.

## [0.3.4] — 2026-08-03

### Added

- “More above” arrow (flipped Gen 1 more-below glyph) when the list can
  scroll up, matching the existing more-below marker.

## [0.3.3] — 2026-08-03

### Changed

- Map label keeps 15 characters of the name, then `...`
  (e.g. `MtMoonPokecenter` → `MtMoonPokecente...`).

## [0.3.2] — 2026-08-03

### Changed

- Hide encounter rate for unseen species (same rule as levels).

## [0.3.1] — 2026-08-03

### Changed

- Hide level range for unseen species (`?????`).
- Map label truncates long names with `...` (length rule refined in 0.3.3).

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

### Notes

- Public API and Safari / Super Rod follow-ups: see later **1.0.0** notes.
  (Historical “Planned” block from 0.2.0.)

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

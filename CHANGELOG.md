# Changelog

All notable changes to **Dex Radar** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project versions with the `version` field in `manifest.json`.

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

# Dex Radar

Lists wild Pokémon available on the **current map** (grass, water, fishing).

Unseen Pokédex entries show as `?????` with a black silhouette. Opening the
radar does **not** mark species as seen.

## Install

1. Copy this folder into the game's `mods/` directory
2. Enable it in Options → Mod Manager
3. Restart (or `POKEPORT_DEV=1` + F5 while developing)

## How to open

1. **START → DEX RADAR**
2. **Hotkey** (default `R`) while on the overworld — change or disable under
   this mod's options (`HOTKEY` / `HOTKEY KEY`)

## What it shows

| Section | Source |
|---------|--------|
| GRASS | `encounters[map].grass.slots` (common → rare) |
| WATER | `encounters[map].water.slots` |
| FISH | Old + Good rods (global) + Super Rod for this map, if the map has water slots and/or a Super Rod group |

Maps with no wild data show `NO WILD POKEMON`.

## Options

| Option | Default | Meaning |
|--------|---------|---------|
| HOTKEY | on | Enable keyboard shortcut |
| HOTKEY KEY | R | Letter key (or OFF) |

Hotkey only fires when the overworld is the top screen (not in menus/battles).

## Notes

- Content mod (`affects_link: false`); disable to restore vanilla menus exactly.
- License: [MIT](LICENSE) · Changes: [CHANGELOG.md](CHANGELOG.md)

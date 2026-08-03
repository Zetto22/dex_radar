# gen1recomp_mods

Mods for [gen1recomp](https://github.com/bryanthaboi/gen1recomp) (LÖVE2D / Lua). Each mod lives in its own folder at the repo root.

API docs: [gen1recomp wiki](https://github.com/bryanthaboi/gen1recomp/wiki)

## Mods

| Folder | Description |
|--------|-------------|
| [`dex_radar/`](dex_radar/) | Lists wild Pokémon available on the current map (grass, water, fishing) |

## Install a mod

1. Copy the mod folder into the game's `mods/` directory
2. Enable it in Options → Mod Manager
3. Restart the game (or use `POKEPORT_DEV=1` + F5 while developing)

Or download the per-mod `.zip` from [Releases](https://github.com/Zetto22/gen1recomp_mods/releases) and use **Import mod .zip** in the launcher.

In-game **Check for updates** needs a GitHub release tagged **`vX.Y.Z`**
(e.g. `v1.0.0`) with asset `<mod_id>-X.Y.Z.zip`. That matches
[gen1recomp `ModUpdate`](https://github.com/bryanthaboi/gen1recomp/blob/dev/src/mods/ModUpdate.lua).

## Pack a mod zip locally

```bash
./pack dex_radar
```

On Windows CMD / PowerShell:

```bat
pack dex_radar
```

Creates `dex_radar-<version>.zip` with files at the archive root. Zips are gitignored.

```bash
./pack dex_radar --out dist/
```

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

## Publishing a release

One GitHub Release **per mod**, with a zip whose files sit at the **archive root** (so `manifest.json` is not nested under an extra folder).

1. Bump `version` in that mod's `manifest.json` (and `CHANGELOG.md`)
2. Commit and push to `main`
3. Tag and push:

```bash
git tag dex_radar-v0.1.1
git push origin dex_radar-v0.1.1
```

Or run **Actions → Release mod** and enter `mod_id` + `version`.

Tag format: `<mod_id>-v<semver>` (example: `dex_radar-v0.1.1`). The version must match `manifest.json`.

Each mod that supports launcher Update/Versions should set `"github": "Zetto22/gen1recomp_mods"` in its manifest.

## Legal

Mods must **not** include ROM-derived content. The player supplies their own Pokémon Red (US) ROM on first boot.

# brotato-mods

Personal Brotato mods, built on the [Godot Mod Loader](https://wiki.godotmodding.com/) that ships built into the game.

## Layout

Mods live in `mods-unpacked/<Namespace>-<ModName>/`, each with:
- `manifest.json` — mod metadata (name, namespace, version, dependencies)
- `mod_main.gd` — entry point, runs on game start and installs script extensions/hooks
- `extensions/` — files that mirror the game's internal script paths and override specific functions

## Installed mods

- **nicolassut-HelloBrotato** — starter scaffold. Appends "Mods are working!" to the main menu version label to confirm the pipeline is wired up end to end. Safe base to build real tweaks on top of.

## Local install (macOS + Steam)

The game's install directory is symlinked to `mods-unpacked/` here, so any change in this repo shows up in-game on next launch:

```
ln -s ~/brotato-mods/mods-unpacked "/Users/nicolassutcliffe/Library/Application Support/Steam/steamapps/common/Brotato/mods-unpacked"
```

Enable a mod in-game via the in-game Mods menu (or by adding it to `mod_list` in
`~/Library/Application Support/Brotato/mod_user_profiles.json`), then relaunch.

Check `~/Library/Application Support/Brotato/logs/modloader.log` for load errors.

## Writing a new mod

1. Copy the `nicolassut-HelloBrotato` folder as a template, rename it `nicolassut-<NewModName>`.
2. Update `manifest.json` (name, description).
3. To change existing game behavior, find the target script's `res://` path (from the game's decompiled source or existing mod examples) and mirror it under `extensions/`, calling `.parent_method()` (Godot 3 GDScript) to chain to the original.
4. To add brand new content (weapons, items, characters), consider depending on [Brotato-ContentLoader](https://github.com/BrotatoMods/Brotato-ContentLoader) instead of hand-rolling script extensions.

Reference: [BrotatoMods/Brotato-Example-Mods](https://github.com/BrotatoMods/Brotato-Example-Mods), [Godot Mod Loader wiki](https://wiki.godotmodding.com/).

# Saves and rollback

Pause → Checkpoints contains manual slots, automatic/quick/recovery saves, earlier versions and backup recovery. Manual saves use the entered name. Reusing a name preserves the last eight versions. The .bak file also retains the preceding write.

F5 creates a Quick save; F9 loads it. Autosaves are enabled by default every five minutes of unpaused play, rotate across five slots, and wait for world generation to settle. The pause page lets you disable them or choose a 1–30 minute interval. Preferences live outside snapshots so loading an old world does not reset them.

Every load that replaces a ready game first saves the current session as Before rollback. That recovery slot has its own version history. Restoring an earlier version does not overwrite its source. Automatic, quick and recovery slots use separate internal identifiers from named manual saves.

Select a slot to view its earlier versions or recover its .bak. A damaged primary JSON file remains listed when a readable backup exists. A failed load reports its reason without discarding the current scene. World generation must finish before saving; no offline progress is simulated.

## Persistence ownership

SaveGames coordinates slots, shortcuts, autosave timing and scene restoration. SaveHistory archives bounded versions. SnapshotMigrations upgrades old payloads at the load boundary. GameSnapshot owns world restoration order; SiteSnapshot owns the site field contract; CraftingManager owns its batch/queue snapshot.

Envelopes carry version, kind, timestamp, checksum and JSON payload. Writes use a temporary file, flush, archive the old version and rename. Envelope v1 and legacy development checkpoints remain readable; current payload schema is v2. Mutable carrier upgrades, recruitment standing, continuing-chapter rewards, active commissions and queued crafting persist.

Files live under user://saves, normally %APPDATA%/Godot/app_userdata/Hexes and Alchemy/saves on Windows. Earlier versions live in its history subfolder. Content paths still resolve resources, so renaming shipped content requires an explicit migration.

## Manual checks

Use isolated APPDATA and LOCALAPPDATA for development runs. Save during travel/work/return, queued crafting and shipments; reload and inspect remaining work and reservation conservation. Overwrite a manual slot, restore an earlier version and verify Before rollback can recover the departed session. Inspect controls at 1280×720 and 960×540. Development checkpoints remain available in debug builds.

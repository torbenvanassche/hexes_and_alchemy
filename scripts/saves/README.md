# Checkpoint saves

Open **Pause → Checkpoints**, enter a name, and choose **Save checkpoint**. Reusing a name
replaces that checkpoint and retains its previous file as a `.bak`. Choose a saved
checkpoint from the list and press **Load selected** to resume it. Loading replaces
the current session. For testing, keep separate checkpoints such as “Before forge”,
“Blacksmith open”, and “Village discovered”.

In the editor and debug builds the same submenu also offers four bundled development
checkpoints: fresh arrival, a forge foundation with one timber delivered, an open
blacksmith in a level 2 settlement, and the discovered neighbouring village.
The last two provide 250 coins and basic supplies for testing. These are read-only
project fixtures; load one and save under your own name to branch off from it.
They never replace personal checkpoints. See `development/README.md` for regeneration.

This first version saves between commissions: finish or cancel posted work and
collect pending rewards first. Recovery, partial building deliveries, and resource
regrowth can remain in progress. Saving waits for world streaming to finish.

## What survives

- World seed and generation settings, generated chunks, terrain/navigation state,
  structures, and exploration, including neighbouring villages.
- Settlement level and expansion, building stages, and delivered materials.
- Treasury, stores, market stock, guild standing, faction statistics, activity log,
  journal objectives, and completed/cancelled commission history and reports.
- Guild members, names, traits, rank, experience, equipment, injuries, earnings,
  and recovery; tavern visitors and recruitment progression.
- Day/time, player position, and tracked campaign destination.

People resume at their home or recovery location. Paths, animations, exact random
outcomes, open windows, and the precise simulation frame are not restored. Time
spent outside the game does not advance recovery or regrowth.

## Storage and extension

Files are JSON under `user://saves` (normally
`%APPDATA%/Godot/app_userdata/Hexes and Alchemy/saves` on Windows). Each envelope
contains a format version, display metadata, and checksummed payload. Writes use a
temporary file and rename; validation happens before replacing the running scene.
The `.bak` holds the previous successful version; backup recovery is currently
manual. Saves reference project content paths, so content moves/removals or changes
to scene node paths may require a migration. Release-wide save compatibility is
not guaranteed yet.

`SaveGames` owns slots, file integrity, and scene reloads. `GameSnapshot` owns the
progression schema and restoration order. `SaveCodec` converts known values and
resolves world/person/history references. Add new mutable progression fields to
the appropriate explicit field list in `GameSnapshot`; add reconstruction logic
when a system needs more than property assignment. Do not serialize callbacks or
active simulation coroutines. Increment the format version and add a migration
when changing the schema incompatibly.

## Verification

Run `res://tests/checkpoint_test.tscn` headlessly in an isolated user-data directory.
It covers partial/completed construction, earlier checkpoints, streamed chunks,
discovery, stores, market stock, people, recovery, history, repeated loads, blocked
and corrupt saves, a new commission after loading, and pause-menu bounds. Run it
again with `-- --verify-persisted` to load the file from a separate process. With
graphics enabled, `-- --capture` writes a pause-menu preview to
`.godot/validation/checkpoint-menu.png`.

Packhorse shipments now persist as part of the same save. Unlike commissions,
shipments may be saved in transit: reserved cargo, journey phase, carrier, contacts,
and village influence restore with the world. Older saves without transport data
remain supported. See `scripts/transport/README.md` for the first shipment loop.

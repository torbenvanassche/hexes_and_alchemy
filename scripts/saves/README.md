# Checkpoint saves

Open **Pause → Checkpoints**, enter a name, and choose **Save checkpoint**. Reusing a name
replaces that checkpoint and retains its previous file as a `.bak`. Choose a saved
checkpoint from the list and press **Load selected** to resume it. Loading replaces
the current session. For testing, keep separate checkpoints such as “Before forge”,
“Blacksmith open”, and “Village discovered”.

In editor/debug builds, the submenu also offers eight numbered chapter stages
plus five alternatives: well placement, well construction, early village discovery,
trade before improvements, and an active commission with auto-collect disabled. These read-only project fixtures
never replace personal checkpoints. Later stages include explicit test supplies.
See `development/README.md` for the stage list and regeneration command.

Commissions can be saved while waiting, travelling, working, returning or awaiting reward collection. Supplies and offered payment remain reserved; assignments and remaining work time survive. Saving still waits for world streaming to finish.

## What survives

- World seed and generation settings, generated chunks, terrain/navigation state,
  structures, and exploration, including neighbouring villages.
- Settlement level and expansion, building stages, and delivered materials.
- Treasury, stores, market stock, guild standing, faction statistics, activity log,
  journal objectives, and completed/cancelled commission history and reports.
- Guild members, names, traits, rank, experience, equipment, injuries, earnings,
  and recovery; tavern visitors and recruitment progression.
- Day/time, player position, and tracked campaign destination.

Idle/recovering people resume at home or recovery. Assigned members resume from saved travel positions; routes are recalculated. Working parties resume at their site with remaining work time. Already rolled outcomes, pending loot and member fates are retained; unrolled outcomes roll normally after work finishes. Open windows and the precise simulation frame are not restored. Time
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

Loading also repairs legacy settlement buildings placed over built-in services or
gate approaches. The building moves to a clear owned plot with its construction
stage, supplied materials, history, and tracked references intact. The new plot
is retained when the player saves; bundled fixtures remain unchanged.

## Verification

Run `res://tests/commission_save_test.tscn` and
`res://tests/opening_chapter_test.tscn` in isolated user-data directories for active
work, milestone and reward persistence. The settlement-placement, village-boundary,
transport, trade-campaign, crafting and world-loading tests cover compatibility
and reconstruction of the surrounding systems.

Packhorse shipments now persist as part of the same save. Unlike commissions,
shipments may be saved in transit: reserved cargo, journey phase, carrier, contacts,
and village influence restore with the world. Older saves without transport data
remain supported. Shipment and generic delivery quests restore through operation
history and rejoin the active quest registry. Applied outcomes retain their payout
guard; an unloading horse retains its remaining wait instead of restarting it.
Guild commissions now also support in-progress checkpoint saves. See `scripts/transport/README.md`
for the first shipment loop and authoring other delivery definitions.

Timed crafting also persists in progress. Reserved ingredients are already
removed from the saved stores; the saved job retains the output, ingredient
snapshot, duration and elapsed time. Closing the blacksmith does not stop work.
Loading resumes the timer without reserving materials or granting output again.
Older checkpoints without crafting data load with no active job.

Community progression persists as typed project/incident records, recipe unlocks,
chapter milestones and incident timing. Site snapshots include discovery IDs and
limited-use supports/protection. Existing checkpoint conditions are preserved;
unresolved discoveries in newer saves can still roll when explored later.
Project props are rebuilt from this state. Older markers pointing to the removed
stationary request authors are redirected to the quest board. See
`scripts/regional/README.md` for the content definitions and tuning controls.


## Active commissions

`Quest.wait_for_work` owns the persistable work clock; site coroutines must use it instead of creating their own work timers. `CommissionSaveState` rebinds party references after the world/roster/site/navigation restore, then `QuestManager.resume_restored_commissions` resumes execution after loading is released. Restored jobs bypass posting, currency reservation and material withdrawal. Waiting jobs can still cancel/refund; completed jobs respect the saved auto-collect preference and once-only reward/completion guards. SaveCodec resolves treasury/player payment sources as explicit service references.

Run `res://tests/commission_save_test.tscn` for all five active phases, refunds, saved fates, duplicate-claim prevention and concurrent scouting/resource work. Run `opening_chapter_test` for chapter order and once-only milestone grants.

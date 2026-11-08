# Development checkpoints

In the editor, open **Pause → Checkpoints → Development checkpoints**. Each option
loads a complete save through the normal checkpoint loader. Personal saves stay
separate in `user://saves`; saving after loading a fixture creates a personal branch.
The bundled files are never overwritten by in-game saving. Development options are
hidden in release builds.

All thirteen fixtures use world seed **20261102** and the current generation version.
Numbered entries follow the opening chapter; alternatives test a different order
or active work.

| Checkpoint | State |
| --- | --- |
| Fresh arrival | Level 1, five starting guild members, 100 coins, opening objectives untouched. |
| Forge foundation | Blueprint bought and legally placed; one timber paid for and delivered. One timber and five iron ore remain. |
| Choose village requests | Blacksmith open, level 2, no improvements. Test supplies: 250 coins, 4 prestige, 24 timber, 16 iron and six extra travel rations. |
| One village improvement | Well built and water request complete; choose a second improvement. |
| Village improved | Water and food requests complete; neighbour still undiscovered. |
| Ready for first shipment | Two improvements complete; village and walking route revealed. Player starts at the village entrance; dispatch remotely through Trade. |
| Craft the partnership shipment | Repair delivery complete, horse returned and equipment request selected. Stores contain raw crafting materials. |
| Opening chapter complete | Two improvements and both deliveries complete, grain unlocked, once-only chapter grant already paid. |
| Alt · Place the well | Water fieldwork complete, blueprint issued and construction supplies in stores. Test placement/cancellation. |
| Alt · Build the well | Foundation placed; deliver materials to finish the water request. |
| Alt · Village discovered early | Blacksmith open and neighbour revealed; no projects complete. |
| Alt · Trade before improvements | Partnership and grain unlocked, no projects complete. Finish two requests to conclude the chapter. |
| Alt · Commission in progress | Paid forage commission working; auto-collect off. Assignment, reserved pay and remaining work resume on load. |

Projects complete real fieldwork, spend coins/prestige and contribute supplies.
The well uses crafted supplies and is placed/built through the construction APIs. Deliveries use real dispatch/return logic and equipment is crafted
through the blacksmith UI. The active commission is posted normally and captured
after its worker arrives. No other fixture contains active work, crafting or a
delivery in transit.

Later checkpoints deliberately add working capital and supplies; these are testing
scenarios, not balance benchmarks. Fresh arrival/foundation retain their opening
budgets. The original foundation snapshot is preserved separately at
`tests/fixtures/legacy_foundation.json` for building/reference migration tests.

## Regeneration

Run the dedicated scene in a separate Godot process with:

```text
godot --headless --path . res://development/generate_checkpoints.tscn -- --generate-development-checkpoints
```

This rebuilds all thirteen JSON files in `development/checkpoints` using the current
world generation and construction/upgrade APIs. It does not write personal saves.
Use this after changes to the save schema, content paths, building scene paths,
or world generation. Check the resulting file changes before retaining them.

To regenerate only the completed-partnership fixture from the existing village
checkpoint, preserving the other chapter checkpoints:

```text
godot --headless --path . res://development/generate_checkpoints.tscn -- --generate-trade-partner-checkpoint
```

The partnership generator crafts through the actual blacksmith UI and sends both
deliveries through the transport manager. It does not set completion flags directly.

## World-generation follow-up

The startup failure was reproduced with seed **3** and repaired. See
[World generation](WORLD_GENERATION.md) for the pipeline, profiling results,
seed-sweep test, fallback terrain behavior and remaining optimization work.
Campaign/regression scenes use seed 20261102 for reproducibility; the actual game
continues to generate random worlds. Generated people and recruitment pools can
vary independently of the terrain seed.

Verify with:

```text
godot --headless --path . res://tests/development_checkpoints_test.tscn
```

Run tests with an isolated user-data directory: they create named test saves.
The test loads every fixture, checks progression and preservation of personal
saves, returns from later progress to arrival, and exercises submenu navigation
and loading. With graphics enabled, append `-- --capture` for a screenshot.

Editor runs read the JSON files directly. For exported debug builds, include
`development/checkpoints/*.json` in the export's non-resource file filter if
needed. Exclude the `development` directory from release exports.

## Data types

Use `Dictionary[KeyType, ValueType]` for homogeneous maps. Use a small typed class
for structured runtime state with fields of different types, as in shipment
journeys, generation jobs, party assignments and reward previews. Keep arrays
inside map values typed where they are created; GDScript does not support nested
typed collection declarations.

`Dictionary[String, Variant]` is reserved for mixed metadata, extensible quest
context and serialized fields. `TypedData` normalizes JSON objects and copies
engine dictionaries at these boundaries. `SaveCodec` handles arbitrary key/value
types and assigns decoded data into each receiving property's declared type.
The generic inventory methods `has_all` and `transfer_all_to` intentionally accept
both `Dictionary[ItemInfo, int]` and `Dictionary[Resource, int]`: GDScript's typed
dictionaries are invariant, so the shared API cannot declare either key type
without rejecting the other. Its internal transfer bookkeeping is typed.

Run `res://tests/typed_data_test.tscn` headlessly to compile all project scripts,
load every quest profile/reward preview, check typed inventory transfers, and
verify conversion of older trade records. Transport, trade campaign, settlement
placement, village boundary and window tests cover the integrated behavior.

# World generation

## Pipeline

1. `HexGrid` seeds private biome-noise samplers and calls the terrain planner.
2. `StarterLayoutPlan` chooses the home tile, village pad and resource clearings.
   It compares six seeded directions by water/elevation modification cost, then
   reserves flat, connected land corridors and pads before tile instantiation.
   Terrain outside those constraints retains its natural noise-based layout.
3. Tiles, chunk post-processing and region components stream through the worker.
4. `MainGrid` prepares the home geometry and incrementally resolves elevation
   components, entrances and reachability using `GenerationBudget` checkpoints.
5. Required-structure planning prefers the planned clearings, respecting spacing
   and walking-distance rules. The existing deterministic repair remains a last
   resort for restrictive/custom configurations.
6. Resource scattering uses resumable searches with a bounded candidate count per
   step. The village geometry is prepared before final route validation, and
   navigation points/connections rebuild in budgeted slices.
7. Outstanding tile/structure callbacks finish before initialization. Player
   movement/interactions and automatic expansion wait for the world to be ready.

`RegionInfo` owns biome tables, priorities, distance weights and resource caps.
`RegionInstance` owns placement jobs and counts. `DiscoveryRandomizer` chooses
site variants when revealed. Gameplay effects stay in the existing site/quest
systems; generation only chooses positions and starting conditions.

## Inspector controls

| Setting on the main grid | Default | Purpose |
| --- | --- | --- |
| `generation_version` | 2 | New terrain planning and discovery pacing |
| `startup_work_budget_ms` | 4 ms | Cooperative startup computation slice |
| `initial_streaming_budget_ms` | 10 ms | Initial tile/structure worker budget |
| `runtime_streaming_budget_ms` | 3 ms | Exploration worker budget |
| `structure_candidates_per_step` | 8 | Bound failed placement searches |
| `world_chunk_radius` | 12 | Finite square world boundary |
| `same_discovery_spacing` | 5 tiles | Exclusion radius for another site of the same type |
| `discovery_repeat_penalty` | 0.5 | Reduce weights of resource types already common in a biome component |
| `discovery_variation_radius` | 8 tiles | Nearby variant-repeat detection |
| `discovery_variant_repeat_penalty` | 2 | Reduce repeated local discovery variants |
| `disruption_spacing` | 6 tiles | Keep damaged/occupied discoveries apart |

Chunks default to 4×4 tiles. The initial radius of 4 requests 81 chunks / 1,296
tiles. A world radius of 12 permits 625 chunks / 10,000 tiles. The effective
limit cannot be smaller than the initial chunk radius. New worlds get an ocean
rim at the boundary when ocean generation is enabled; movement/expansion are
bounded even if it is disabled.

This is a finite-world policy, not chunk unloading. Generated chunks remain
resident within that limit. Every chunk present in a save is retained even if
it lies outside a subsequently reduced limit; new expansion beyond the configured
boundary is refused. A future larger-world mode should add chunk persistence and
unloading rather than simply increasing the radius indefinitely.

## Discovery pacing

Normal resource scattering keeps equal resource types more than five tiles
apart, and gradually reduces the selection weight of already common types in a
biome component. Existing density and capacity limits still apply. Required
opening resources remain guaranteed rather than relying on random scattering.

On reveal, repeated nearby discovery variants get lower weight. Definitions
marked `is_disruption` cannot be chosen within the disruption exclusion radius
of another revealed disruption. These flags are configured on the existing
remnant forest, prowler forest, unstable mine, tainted water and occupied ruin
resources. Useful/healthy discoveries remain in the pool, and required opening
sources still select only `safe_for_opening` variants. Resolved variants are saved
and do not reroll after loading.

## Save compatibility

New worlds use generation version 2 and save all generation/pacing controls.
Saves without a generation version load as version 1: they use the previous
terrain and scattering/variant rules before their persisted terrain is restored.
The new budgeted execution and finite expansion policy still apply. Existing
gate choices, edited biomes, tile states, structures and exploration are retained.
The bundled legacy development checkpoints are intentionally not regenerated.
Older documents without per-tile biome fields still receive the existing village
clearance/building-placement migrations. New documents restore authoritative
terrain after all structure footprints finish rebuilding.

A fixed seed is deterministic for the same generation version, settings and
requested chunk sequence. Different exploration orders can still change later
resource placement because growing/merging biome components change their caps
and seed keys. Local variant variety intentionally also reflects discoveries
already revealed in that playthrough.

## Measurements and limitations

Before these changes, seed 3 required a 326-tile fallback repair and approximately
190 ms of uninterrupted startup work. In the new headless run it required no
fallback repair, cooperative startup slices peaked around 5.4 ms and the worker
peaked around 10.3 ms. The initial searches take several frames to finish; total
elapsed startup time and maximum uninterrupted work are different measurements.

The sweep covered seeds 1–32, 42, 20261102 and 20261106. All 35 completed without
fallback terrain repairs and passed chunk/index/navigation, resource-spacing,
disruption-spacing and boundary checks. Reference layouts matched with worker
step limits of 16 and 128. Save round trips include extra generated chunks and a
retained outlying chunk beyond the configured world boundary.

Budgets are cooperative rather than a hard frame-time guarantee. A scene
instantiation, resource-ready callback, sort or renderer/shader operation can
still overshoot. The rendered seed-3 check passed, but included a roughly 30 ms
startup slice; headless CPU measurements do not guarantee equivalent rendered
frame times. Large custom maps also need their own profiling.

## Validation

`WorldLoading` is a persistent autoload using `scenes/ui/world_loading.tscn`.
It covers scene changes and paused save restoration, consumes gameplay input,
then shows 100% and fades only after initialization, pending callbacks and the
player are ready. Runtime chunk streaming does not reopen it. Generation reports
weighted phase/tile progress through `WorldGenerationProgress`; restoration uses
the optional progress argument on `GameSnapshot.restore`. Add new phases to those
reports rather than advancing the bar with a timer. A generation/load failure
keeps the cover visible with its error and a New world recovery button.

`world_loading_test` verifies coverage, monotonic progress, paused restoration,
input release, runtime streaming and failure recovery at 1280×720/960×540. Append
`-- --capture` with a renderer for loading-screen screenshots.

Use isolated APPDATA/LOCALAPPDATA so test saves cannot touch personal saves:

```text
godot --headless --path . res://tests/world_generation_test.tscn -- --seed=3 --roundtrip
godot --headless --path . res://tests/world_generation_test.tscn -- --seed=20261102 --steps=16 --record-layout
godot --path . --rendering-method gl_compatibility res://tests/world_generation_test.tscn -- --seed=3 --capture
```

Layout records and the rendered overview go to `.godot/validation`. Timing is
opt-in through `grid.generation_metrics.enabled`. `startup_slice` measures a
cooperative computation slice. Stages ending in `_elapsed` include frame waits.
The fingerprint excludes people/recruit names and other non-world random state.

Also run typed-data, village-boundary, settlement-placement, transport, trade,
regional-progression, quest-board and crafting regressions after shared changes.

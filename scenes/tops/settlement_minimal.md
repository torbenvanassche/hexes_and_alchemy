Minimal world settlement
========================

`settlement_minimal.tscn` contains two KayKit cottages, a well, a central market, collisions, and an
Arrival marker. Its Settlement root claims a radius-one footprint (seven hexes).
The StructureInfo reserves radius two (19 hexes), leaving one tile of walkable,
level clearance outside the wooden walls. This also applies when older saves load.
Each cottage, the well, and Arrival use Building Hex Offsets on the root to snap
to actual hex centres and elevations when placed. Edit those cube offsets to
rearrange the village. Model and collision children move together.
The scene is passive: it does not activate the player settlement, spawn a player,
reveal fog, or provide the starting settlement's guild and campaign services.
Player construction is disabled on this village's land.

Use `res://resources/structure_info/village.tres` when placing it on the hex map.
It is registered in the default content catalog and supports multiple instances.
Placement through the existing structure system:

```gdscript
var village := preload("res://resources/structure_info/village.tres")
var placed := hex.region_instance.try_place_required_structure_at(hex.cube_id, village)
```

This validates space and spacing before placement and updates region records.
For procedural generation, add the village resource to a RegionInfo's Structures
dictionary with a positive weight. Its count curve permits one per region. It is
not included in region resource scattering. The main generator places one nearby
village before resource scattering by default.

In `scenes/generator.tscn`, the Nearby Settlement settings control its resource and
minimum/maximum walking distance from the starting settlement's centre. Defaults
are 8–16 hex steps along a traversable route. Clear Nearby Settlement to disable
this spawn. A world seed reproduces its placement. Other required resources keep
their own existing walking-distance limit. Invalid reversed limits use the
minimum as both ends of the range.

Additional copies can be added to Required Starting Structures. Copies of the
nearby-settlement resource use the same distance range.

For manual scene composition, instance `settlement_minimal.tscn` under the world
grid and align its origin to a hex centre. Use structure placement when footprint
reservation and region bookkeeping are needed. Add future village services under
Buildings or a separate Services node; the Settlement root registers Interaction
children automatically. Arrival defines the gate approach; Buildings/Market/Approach is the player and packhorse arrival point.

Run `tests/village_boundary_test.tscn` to check the perimeter, gate access,
market interaction, discovery marker, stock persistence, and legacy save migration.

The village now uses the matching KayKit wooden fence/gate scenes. A grid-aligned
perimeter surrounds two cottages, the well and a central village market. Walls
block physical movement and hex navigation; the single gate is selected from a
reachable outside approach and its edge is persisted in saves. Geometry rebuilds
after loading terrain. The trade counter is at `Buildings/Market`; old arrival-trade save paths migrate automatically. A first-visit red arrow points at its visible geometry;
the smaller arrow bobs gently and remains visible alongside the input prompt until contact.
Locate village continues to track the same counter; there is no floating market label.

The door uses the starting stone gate's rotating interaction with a collider fitted
to the wooden mesh. Players open and close it with the usual interaction button.
NPCs and packhorse shipments open it when passing; closed doors physically block
the entrance while the gate remains available to route planning. The open/closed
state is saved and restored when the boundary is rebuilt.

The central market is a normal Market service, like the starting settlement's:
interacting opens the shared buy/sell window with a small local stock. Its
Shipments button opens the village's delivery requests. The starting market keeps
its existing UI. The village has no guild hall, recruitment hub or other starting
settlement facilities; it remains a small, passive neighbour.

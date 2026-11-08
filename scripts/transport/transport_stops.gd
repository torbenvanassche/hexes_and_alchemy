class_name TransportStops
extends RefCounted

## Stables occupy the existing cleared ring, outside the settlement footprint.
## A saved plot and front approach keep loading bays stable across save/load.
const STABLE := preload("res://scenes/transport/stable.tscn")
var _instances: Dictionary[int, Node3D] = {}

func interiors(grid: HexGrid) -> Dictionary[Vector3i, bool]:
	var result: Dictionary[Vector3i, bool] = {}
	for settlement: Settlement in Manager.instance.settlements:
		if not is_instance_valid(settlement) or not grid.is_ancestor_of(settlement): continue
		for hex: HexBase in settlement.get_settlement_hexes(grid): result[hex.cube_id] = true
	return result

func ensure_all(grid: HexGrid) -> void:
	for settlement: Settlement in Manager.instance.settlements:
		if is_instance_valid(settlement) and grid.is_ancestor_of(settlement): get_stable(grid, settlement)

func get_stable(grid: HexGrid, settlement: Settlement) -> Node3D:
	if grid == null or not is_instance_valid(settlement): return null
	# A freshly streamed village chooses its gate in a deferred setup pass.
	# Wait for that choice rather than committing a stable to an arbitrary side.
	if "gate_outside" in settlement and settlement.get("gate_outside") == Vector3i.MAX: return null
	var key := settlement.get_instance_id()
	var existing := _instances.get(key) as Node3D
	if is_instance_valid(existing):
		_reveal_stop(grid, settlement, existing)
		return existing
	var inside := interiors(grid)
	var tile := grid.get_hex_at_cube_id(settlement.transport_stable_tile)
	var front := grid.get_hex_at_cube_id(settlement.transport_stable_approach)
	if not _clear_site(grid, tile, inside) or not _clear_site(grid, front, inside):
		if not _choose_site(grid, settlement, inside): return null
		tile = grid.get_hex_at_cube_id(settlement.transport_stable_tile)
		front = grid.get_hex_at_cube_id(settlement.transport_stable_approach)
	var stable := STABLE.instantiate() as Node3D
	stable.name = "TransportStable"
	settlement.add_child(stable)
	stable.global_position = tile.global_position
	var direction := front.global_position - tile.global_position
	stable.global_rotation.y = atan2(direction.x, direction.z)
	stable.set_meta("tile", tile.cube_id)
	stable.set_meta("approach", front.cube_id)
	_instances[key] = stable
	tile.can_generate = false
	front.can_generate = false
	for mesh: MeshInstance3D in stable.find_children("*", "MeshInstance3D", true, false):
		mesh.create_trimesh_collision()
	stable.visibility_changed.connect(_toggle_collisions.bind(stable))
	_toggle_collisions(stable)
	_reveal_stop(grid, settlement, stable)
	return stable

func loading_position(grid: HexGrid, settlement: Settlement) -> Vector3:
	var stable := get_stable(grid, settlement)
	return stable.get_node("LoadingPoint").global_position if stable != null else Vector3.INF

func permits_edge(a: Vector3i, b: Vector3i) -> bool:
	for stable: Node3D in _instances.values():
		if not is_instance_valid(stable): continue
		var tile: Vector3i = stable.get_meta("tile")
		var front: Vector3i = stable.get_meta("approach")
		if a == tile and b != front: return false
		if b == tile and a != front: return false
	return true

func _clear_site(grid: HexGrid, hex: HexBase, inside: Dictionary[Vector3i, bool]) -> bool:
	return hex != null and not hex is HexSlope and not inside.has(hex.cube_id) and hex.structure == null and hex.is_traversable(HexInfo.TraversalTag.WALK) and grid.pathfinder.cube_to_id.has(hex.cube_id)

func _choose_site(grid: HexGrid, settlement: Settlement, inside: Dictionary[Vector3i, bool]) -> bool:
	var origin := settlement._get_settlement_origin_hex(grid)
	if origin == null: return false
	var gates: Array[Vector3] = []
	if "gate_outside" in settlement:
		var outside := grid.get_hex_at_cube_id(settlement.get("gate_outside"))
		if outside != null: gates.append(outside.global_position)
	if gates.is_empty():
		var entrances := settlement.get_node_or_null("entrances")
		if entrances != null:
			for gate: Node3D in entrances.get_children(): gates.append(gate.global_transform * Vector3.LEFT)
	if gates.is_empty(): gates.append(origin.global_position)
	var radius := settlement.initial_footprint_radius + 1
	var candidates: Array[HexBase] = []
	for entry: SceneInstance in grid.get_tiles_in_radius(origin.cube_id, radius):
		var tile := entry.node as HexBase
		if GridUtils.cube_distance(origin.cube_id, tile.cube_id) != radius: continue
		if not _clear_site(grid, tile, inside) or tile.elevation_units != origin.elevation_units: continue
		if settlement.is_gate_approach(grid, tile) or _reserved_by_other(settlement, tile.cube_id): continue
		candidates.append(tile)
	candidates.sort_custom(func(a: HexBase, b: HexBase) -> bool:
		var da := _gate_distance(a.global_position, gates)
		var db := _gate_distance(b.global_position, gates)
		return str(a.cube_id) < str(b.cube_id) if is_equal_approx(da, db) else da < db
	)
	for tile: HexBase in candidates:
		var front: HexBase
		var best := INF
		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			var next := grid.get_hex_at_cube_id(tile.cube_id + direction)
			if not _clear_site(grid, next, inside) or next.elevation_units != tile.elevation_units: continue
			if _reserved_by_other(settlement, next.cube_id): continue
			if GridUtils.cube_distance(origin.cube_id, next.cube_id) < radius: continue
			var nav := grid.pathfinder
			if not nav.are_points_connected(nav.cube_to_id[tile.cube_id], nav.cube_to_id[next.cube_id]): continue
			var score := _gate_distance(next.global_position, gates)
			if score < best:
				front = next
				best = score
		if front != null:
			settlement.transport_stable_tile = tile.cube_id
			settlement.transport_stable_approach = front.cube_id
			return true
	return false

func _gate_distance(point: Vector3, gates: Array[Vector3]) -> float:
	var result := INF
	for gate: Vector3 in gates: result = minf(result, point.distance_squared_to(gate))
	return result

func _reserved_by_other(owner_settlement: Settlement, coord: Vector3i) -> bool:
	var grid := owner_settlement._get_active_grid()
	for settlement: Settlement in Manager.instance.settlements:
		if not is_instance_valid(settlement) or not grid.is_ancestor_of(settlement): continue
		if settlement == owner_settlement: continue
		if coord in [settlement.transport_stable_tile, settlement.transport_stable_approach]: return true
	return false

func _reveal_stop(grid: HexGrid, settlement: Settlement, stable: Node3D) -> void:
	if stable.has_meta("revealed"): return
	var origin := settlement._get_settlement_origin_hex(grid)
	if origin == null or not origin.is_explored: return
	stable.set_meta("revealed", true)
	if settlement.reveal_on_spawn:
		for entry: SceneInstance in grid.get_tiles_in_radius(origin.cube_id, settlement.initial_footprint_radius + 1):
			(entry.node as HexBase).is_explored = true
	grid.get_hex_at_cube_id(settlement.transport_stable_tile).is_explored = true
	grid.get_hex_at_cube_id(settlement.transport_stable_approach).is_explored = true

func _toggle_collisions(stable: Node3D) -> void:
	for shape: CollisionShape3D in stable.find_children("*", "CollisionShape3D", true, false):
		shape.set_deferred("disabled", not stable.is_visible_in_tree())

extends Settlement

const WOOD_GATE := preload("res://scenes/tops/fence_wood_gate.tscn")
var gate_inside := Vector3i.MAX
var gate_outside := Vector3i.MAX
var gate_open := false

func prepare_gate_passage(a: Vector3i, b: Vector3i) -> bool:
	if not ((a == gate_inside and b == gate_outside) or (b == gate_inside and a == gate_outside)): return true
	var door := get_node("entrances").find_child("fence_wood_straight_door", true, false)
	return door != null and door.open_for_traveller()

func _ready_deferred() -> void:
	var origin := get_parent() as HexBase
	if origin != null: origin.refresh_structure_footprint(true)
	super()
	rebuild_boundary()

func rebuild_boundary() -> void:
	var grid := _get_active_grid()
	if grid == null: return
	# Gate choice is saved so later roads/exploration cannot rotate the village.
	var footprint := get_settlement_hexes(grid)
	var coords: Array[Vector3i] = []
	for hex: HexBase in footprint: coords.append(hex.cube_id)
	if gate_inside == Vector3i.MAX: _choose_gate(grid, coords)
	if gate_inside == Vector3i.MAX:
		push_error("Village has no reachable entrance")
		return
	for root_name: String in ["walls", "entrances"]:
		var old := get_node_or_null(root_name)
		if old != null:
			remove_child(old)
			old.free()
		var container := Node3D.new()
		container.name = root_name
		add_child(container)
	for hex: HexBase in footprint:
		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			var outside := hex.cube_id + direction
			if coords.has(outside): continue
			var neighbour := grid.get_hex_at_cube_id(outside)
			if neighbour == null: continue
			var is_gate := hex.cube_id == gate_inside and outside == gate_outside
			var piece := (WOOD_GATE if is_gate else boundary_wall_scene).instantiate() as Node3D
			piece.name = "Gate" if is_gate else "Fence_%s_%s" % [hex.cube_id, outside]
			piece.position = to_local(hex.global_position)
			piece.rotation.y = _get_wall_rotation_y(neighbour.global_position - hex.global_position)
			piece.set_meta(BOUNDARY_EDGE_META, _get_boundary_edge_key(hex.cube_id, outside))
			get_node("entrances" if is_gate else "walls").add_child(piece)
	collision_shapes.assign(find_children("*", "CollisionShape3D", true, false))
	_toggle_collision()
	if not SaveGames.is_loading and (not grid is MainGrid or not grid._finishing_generation): grid.pathfinder.rebuild()

func _choose_gate(grid: HexGrid, coords: Array[Vector3i]) -> void:
	var home := Manager.instance.active_settlement
	if home == null: return
	var origin := home.get_parent() as HexBase
	var arrival := grid.get_hex_at_world_position($Arrival.global_position)
	# Exclude the village interior when choosing the approach: a candidate must
	# really be reachable from outside, rather than through another fence edge.
	var reuse_navigation: bool = grid is MainGrid and grid.generation_version >= 2 and grid._finishing_generation
	var nav: HexAStar = grid.pathfinder if reuse_navigation else HexAStar.new(grid)
	if not reuse_navigation: nav.rebuild()
	for coord: Vector3i in coords:
		if nav.cube_to_id.has(coord): nav.set_point_disabled(nav.cube_to_id[coord])
	var best_score := INF
	for coord: Vector3i in coords:
		var inside := grid.get_hex_at_cube_id(coord)
		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			var outside := grid.get_hex_at_cube_id(coord + direction)
			if outside == null or coords.has(outside.cube_id) or not grid.can_traverse_between(inside, outside, HexInfo.TraversalTag.WALK): continue
			var path := nav.get_hex_path(origin.cube_id, outside.cube_id)
			if path.is_empty(): continue
			# Face the reachable approach from home. Arrival proximity breaks ties;
			# prioritizing it over the route could put the gate on the far side.
			var score := float(path.size()) + GridUtils.cube_distance(arrival.cube_id, coord) * 0.001
			if score < best_score:
				best_score = score
				gate_inside = coord
				gate_outside = outside.cube_id
	if reuse_navigation:
		for coord: Vector3i in coords:
			if nav.cube_to_id.has(coord): nav.set_point_disabled(nav.cube_to_id[coord], false)

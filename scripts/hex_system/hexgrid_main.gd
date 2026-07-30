class_name MainGrid extends HexGrid

@export var player_settlement: StructureInfo;
@export var target_position: Node3D;
@export_group("Starter Progression")
@export var required_starting_structures: Array[StructureInfo] = []
@export_range(1, 64, 1) var required_structure_max_walk_distance := 24

func _ready() -> void:
	super();
	
func _on_map_ready() -> void:
	SceneManager.set_active_scene(DataManager.instance.node_to_info(self));
	_queue_starting_settlement();

func _queue_starting_settlement() -> void:
	if player_settlement == null:
		Debug.err("No player settlement is configured for the main grid.");
		_finish_map_generation();
		return;
	
	if player_settlement.is_cached:
		settlement_created(player_settlement);
		return;
	
	if not player_settlement.cached.is_connected(settlement_created):
		player_settlement.cached.connect(settlement_created, CONNECT_ONE_SHOT)
	
	if not player_settlement.is_queued:
		SceneManager.scene_cache.queue(player_settlement);
	
func settlement_created(sI: StructureInfo) -> void:
	var center_hex: HexBase = chunks[Vector2i.ZERO].get_best_structure_hex();
	if center_hex == null:
		Debug.err("Could not place the starting settlement because the center hex was not found.");
		_finish_map_generation();
		return;
	
	if not center_hex.structure_loaded.is_connected(_on_starting_structure_loaded):
		center_hex.structure_loaded.connect(_on_starting_structure_loaded, CONNECT_ONE_SHOT)
	
	center_hex.region_instance.structures[center_hex.cube_id] = sI
	center_hex.set_structure(sI);

func _finish_map_generation() -> void:
	if initialized:
		return;
	ensure_elevated_areas_reachable_from(_get_starter_origin_hex())
	_ensure_elevated_areas_have_entrances()
	_place_required_starting_structures()
	generate_structures();
	pathfinder.rebuild();
	mark_initialized();

func _place_required_starting_structures() -> void:
	if required_starting_structures.is_empty():
		return
	var origin_hex := _get_starter_origin_hex()
	if origin_hex == null:
		Debug.err("Could not find a starting hex for required structures.")
		return

	var reachable_distances := _get_walk_reachable_distances(origin_hex)
	for required_structure in required_starting_structures:
		if required_structure == null or _has_generated_structure(required_structure):
			continue
		if not _place_required_structure(required_structure, reachable_distances):
			Debug.err("Could not place required starting structure: %s" % required_structure.id)

func _get_starter_origin_hex() -> HexBase:
	if Manager.instance == null or Manager.instance.active_settlement == null:
		return null
	return Manager.instance.active_settlement.get_parent() as HexBase

func _get_walk_reachable_distances(origin: HexBase) -> Dictionary:
	var distances: Dictionary = {origin.cube_id: 0}
	var frontier: Array[HexBase] = [origin]
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		var current_distance: int = int(distances[current.cube_id])
		if current_distance >= required_structure_max_walk_distance:
			continue

		for direction in DataManager.instance.CUBE_DIRS:
			var neighbor := get_hex_at_cube_id(current.cube_id + direction)
			if neighbor == null or distances.has(neighbor.cube_id):
				continue
			if not can_traverse_between(current, neighbor, HexInfo.TraversalTag.WALK):
				continue
			distances[neighbor.cube_id] = current_distance + 1
			frontier.append(neighbor)
	return distances

func _has_generated_structure(required_structure: StructureInfo) -> bool:
	for region_list in region_instances.values():
		for region_instance: RegionInstance in region_list:
			for structure in region_instance.structures.values():
				if structure == required_structure:
					return true
	return false

func _place_required_structure(required_structure: StructureInfo, reachable_distances: Dictionary) -> bool:
	var candidates: Array[HexBase] = []
	for cube_id in reachable_distances:
		var hex := get_hex_at_cube_id(cube_id)
		if hex == null or not can_generate_structures_on_hex(hex):
			continue
		candidates.append(hex)
	if candidates.is_empty():
		return false

	var rng := create_rng("required_starting_structure:%s" % required_structure.id)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var candidate := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = candidate

	for candidate in candidates:
		if candidate.region_instance == null:
			continue
		if candidate.region_instance.try_place_required_structure_at(candidate.cube_id, required_structure):
			return true
	return false

func _on_starting_structure_loaded(_structure_info: StructureInfo, structure_node: Node) -> void:
	if structure_node is Settlement:
		var settlement := structure_node as Settlement;
		Manager.instance.set_active_settlement(settlement);
		Manager.instance.spawn_in_settlement();

	_finish_map_generation();

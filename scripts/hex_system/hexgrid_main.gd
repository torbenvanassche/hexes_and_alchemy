class_name MainGrid extends HexGrid

@export var player_settlement: StructureInfo;
@export var target_position: Node3D;
@export_group("Starting Resources")
@export var starting_resource_search_radius: int = 12
@export var guaranteed_starting_structures: Array[StructureInfo] = []

var path: Array[HexBase];

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
	generate_structures();
	pathfinder.rebuild();
	_ensure_starting_resource_structures();
	pathfinder.rebuild();
	mark_initialized();

func _on_starting_structure_loaded(_structure_info: StructureInfo, structure_node: Node) -> void:
	if structure_node is Settlement:
		var settlement := structure_node as Settlement;
		Manager.instance.set_active_settlement(settlement);
		Manager.instance.spawn_in_settlement();

	_finish_map_generation();

func _ensure_starting_resource_structures() -> void:
	for structure_info: StructureInfo in guaranteed_starting_structures:
		pathfinder.rebuild()
		_ensure_starting_resource_structure(structure_info)

func _ensure_starting_resource_structure(structure_info: StructureInfo) -> void:
	if structure_info == null:
		return
	if _has_accessible_structure(structure_info):
		return

	var placement_hex := _force_starting_resource_structure(structure_info)
	if placement_hex == null:
		Debug.warn("Could not find a valid reachable hex for guaranteed starting resource '%s'." % structure_info.id)
		return

func _force_starting_resource_structure(structure_info: StructureInfo) -> HexBase:
	var candidates := _get_shuffled_starting_resource_candidates(structure_info)
	for hex: HexBase in candidates:
		if not _can_place_guaranteed_starting_resource(hex, structure_info):
			continue
		if _place_starting_resource_structure_at(hex, structure_info):
			return hex
	return null

func _place_starting_resource_structure_at(hex: HexBase, structure_info: StructureInfo) -> bool:
	if hex == null or structure_info == null or hex.region_instance == null:
		return false

	hex.region_instance.structures[hex.cube_id] = structure_info
	if not hex.set_structure(structure_info, true, NAN, true):
		hex.region_instance.structures.erase(hex.cube_id)
		return false

	if hex.region_instance.structure_counts.has(structure_info):
		hex.region_instance.structure_counts[structure_info] += 1
	return true

func _has_accessible_structure(structure_info: StructureInfo) -> bool:
	var origin_hex := _get_starting_resource_origin_hex()
	if origin_hex == null:
		return false

	for hex: HexBase in _get_starting_resource_search_hexes(origin_hex):
		if hex == null or hex.region_instance == null:
			continue
		if hex.region_instance.structures.get(hex.cube_id) != structure_info:
			continue
		if _is_hex_accessible_from(origin_hex, hex):
			return true

	return false

func _get_shuffled_starting_resource_candidates(structure_info: StructureInfo) -> Array[HexBase]:
	var origin_hex := _get_starting_resource_origin_hex()
	if origin_hex == null:
		return []

	var candidates := _get_starting_resource_candidates(origin_hex, structure_info)
	if candidates.is_empty():
		return candidates

	var rng := create_rng("guaranteed_starting_resource:%s" % structure_info.resource_path)
	for i in range(candidates.size() - 1, 0, -1):
		var swap_idx := rng.randi_range(0, i)
		var temp := candidates[i]
		candidates[i] = candidates[swap_idx]
		candidates[swap_idx] = temp

	return candidates

func _get_starting_resource_candidates(origin_hex: HexBase, structure_info: StructureInfo) -> Array[HexBase]:
	var candidates: Array[HexBase] = []
	for hex: HexBase in _get_starting_resource_search_hexes(origin_hex):
		if hex == null:
			continue
		if not _is_hex_accessible_from(origin_hex, hex):
			continue
		if not _can_place_guaranteed_starting_resource(hex, structure_info):
			continue
		candidates.append(hex)
	return candidates

func _get_starting_resource_search_hexes(origin_hex: HexBase) -> Array[HexBase]:
	var result: Array[HexBase] = []
	var seen: Dictionary[Vector3i, bool] = {}

	if origin_hex == null:
		return result

	if origin_hex.region_instance != null:
		for hex: HexBase in origin_hex.region_instance.hexes.values():
			_add_starting_resource_search_hex(hex, seen, result)

	for scene_instance: SceneInstance in get_tiles_in_radius(origin_hex.cube_id, starting_resource_search_radius):
		_add_starting_resource_search_hex(scene_instance.node as HexBase, seen, result)

	return result

func _add_starting_resource_search_hex(hex: HexBase, seen: Dictionary[Vector3i, bool], result: Array[HexBase]) -> void:
	if hex == null or seen.has(hex.cube_id):
		return

	seen[hex.cube_id] = true
	result.append(hex)

func _can_place_guaranteed_starting_resource(hex: HexBase, structure_info: StructureInfo) -> bool:
	if hex == null or structure_info == null:
		return false
	if hex.region_instance == null or not hex.region_instance.has_hex(hex.cube_id):
		return false
	if hex.structure != null or not hex.can_generate:
		return false
	if not hex.is_traversable(HexInfo.TraversalTag.WALK):
		return false
	if not hex.has_walkable_random_rotation(structure_info):
		return false

	var footprint := get_tiles_in_radius(hex.cube_id, structure_info.required_space_radius)
	var expected_tile_count := 1 + 3 * structure_info.required_space_radius * (structure_info.required_space_radius + 1)
	if footprint.size() != expected_tile_count:
		return false

	for scene_instance: SceneInstance in footprint:
		var tile := scene_instance.node as HexBase
		if tile == null:
			return false
		if tile.structure != null or not tile.can_generate:
			return false
		if not tile.is_traversable(HexInfo.TraversalTag.WALK):
			return false

	return true

func _is_hex_accessible_from(origin_hex: HexBase, target_hex: HexBase) -> bool:
	if origin_hex == null or target_hex == null:
		return false
	return not pathfinder.get_hex_path(origin_hex.cube_id, target_hex.cube_id).is_empty()

func _get_starting_resource_origin_hex() -> HexBase:
	if Manager.instance != null and Manager.instance.quests != null:
		var quest_origin := Manager.instance.quests.get_active_quest_origin_hex(self)
		if quest_origin != null:
			return quest_origin

	if Manager.instance == null or Manager.instance.active_settlement == null:
		return null

	var settlement_hex := Manager.instance.active_settlement.get_parent() as HexBase
	if settlement_hex != null:
		return settlement_hex

	return get_hex_at_world_position(Manager.instance.active_settlement.global_position)

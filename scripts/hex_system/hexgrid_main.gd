class_name MainGrid extends HexGrid

@export var player_settlement: StructureInfo;
@export var target_position: Node3D;
@export_group("Starting Resources")
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
		_ensure_starting_resource_structure(structure_info)

func _ensure_starting_resource_structure(structure_info: StructureInfo) -> void:
	if structure_info == null:
		return
	if _has_accessible_structure(structure_info):
		return

	var placement_hex := _pick_starting_resource_hex(structure_info)
	if placement_hex == null:
		Debug.warn("Could not find a valid reachable hex for guaranteed starting resource '%s'." % structure_info.id)
		return

	placement_hex.region_instance.structures[placement_hex.cube_id] = structure_info
	if not placement_hex.set_structure(structure_info, false, NAN, true):
		placement_hex.region_instance.structures.erase(placement_hex.cube_id)

func _has_accessible_structure(structure_info: StructureInfo) -> bool:
	var origin_hex := _get_starting_resource_origin_hex()
	if origin_hex == null:
		return false

	for scene_instance: SceneInstance in tiles.values():
		var hex := scene_instance.node as HexBase
		if hex == null or hex.region_instance == null:
			continue
		if hex.region_instance.structures.get(hex.cube_id) != structure_info:
			continue
		if _is_hex_accessible_from(origin_hex, hex):
			return true

	return false

func _pick_starting_resource_hex(structure_info: StructureInfo) -> HexBase:
	var origin_hex := _get_starting_resource_origin_hex()
	if origin_hex == null:
		return null

	var candidates := _get_starting_resource_candidates(origin_hex, structure_info)
	if candidates.is_empty():
		return null

	var rng := create_rng("guaranteed_starting_resource:%s" % structure_info.resource_path)
	for i in range(candidates.size() - 1, 0, -1):
		var swap_idx := rng.randi_range(0, i)
		var temp := candidates[i]
		candidates[i] = candidates[swap_idx]
		candidates[swap_idx] = temp

	for hex: HexBase in candidates:
		if _can_place_guaranteed_starting_resource(hex, structure_info):
			return hex

	return null

func _get_starting_resource_candidates(origin_hex: HexBase, structure_info: StructureInfo) -> Array[HexBase]:
	var candidates: Array[HexBase] = []
	for scene_instance: SceneInstance in tiles.values():
		var hex := scene_instance.node as HexBase
		if hex == null:
			continue
		if not _is_hex_accessible_from(origin_hex, hex):
			continue
		if not _can_place_guaranteed_starting_resource(hex, structure_info):
			continue
		candidates.append(hex)
	return candidates

func _can_place_guaranteed_starting_resource(hex: HexBase, structure_info: StructureInfo) -> bool:
	if hex == null or structure_info == null:
		return false
	if hex.region_instance == null or not hex.region_instance.has_hex(hex.cube_id):
		return false
	return hex.region_instance._can_place_structure_at(hex.cube_id, structure_info)

func _is_hex_accessible_from(origin_hex: HexBase, target_hex: HexBase) -> bool:
	if origin_hex == null or target_hex == null:
		return false
	return not pathfinder.get_hex_path(origin_hex.cube_id, target_hex.cube_id).is_empty()

func _get_starting_resource_origin_hex() -> HexBase:
	if Manager.instance == null or Manager.instance.active_settlement == null:
		return null

	var settlement_hex := Manager.instance.active_settlement.get_parent() as HexBase
	if settlement_hex != null:
		return settlement_hex

	return get_hex_at_world_position(Manager.instance.active_settlement.global_position)

class_name MainGrid extends HexGrid

@export var player_settlement: StructureInfo;
@export var target_position: Node3D;

var path: Array[HexBase]

func _ready() -> void:
	super()
	
func _on_map_ready() -> void:
	SceneManager.set_active_scene(DataManager.instance.node_to_info(self))
	_queue_starting_settlement()

func _queue_starting_settlement() -> void:
	if player_settlement == null:
		Debug.err("No player settlement is configured for the main grid.")
		_finish_map_generation()
		return
	
	if player_settlement.is_cached:
		settlement_created(player_settlement)
		return
	
	if not player_settlement.cached.is_connected(settlement_created):
		player_settlement.cached.connect(settlement_created, CONNECT_ONE_SHOT)
	
	if not player_settlement.is_queued:
		SceneManager.scene_cache.queue(player_settlement)
	
func settlement_created(sI: StructureInfo) -> void:
	var center_hex: HexBase = chunks[Vector2i.ZERO].get_best_structure_hex()
	if center_hex == null:
		Debug.err("Could not place the starting settlement because the center hex was not found.")
		_finish_map_generation()
		return
	
	if not center_hex.structure_loaded.is_connected(_on_starting_structure_loaded):
		center_hex.structure_loaded.connect(_on_starting_structure_loaded, CONNECT_ONE_SHOT)
	
	center_hex.region_instance.structures[center_hex.cube_id] = sI
	center_hex.set_structure(sI);
	_finish_map_generation()
	pathfinder.rebuild()

func _finish_map_generation() -> void:
	if initialized:
		return
	generate_structures()
	initialized = true;

func _on_starting_structure_loaded(_structure_info: StructureInfo, structure_node: Node) -> void:
	if structure_node is Settlement:
		var settlement := structure_node as Settlement
		Manager.instance.set_active_settlement(settlement)
		Manager.instance.spawn_in_settlement()

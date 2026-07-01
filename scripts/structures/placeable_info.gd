class_name PlaceableStructureInfo extends StructureInfo

@export var build_cost: Dictionary[ItemInfo, int];
@export var placement_handler: Script;

@export var journal_task: JournalTask;

func can_place_on(hex: HexBase, inventory: ContentGroup = null, placement_rotation_y: float = NAN) -> bool:
	if hex == null:
		return false;
	if not _has_build_cost(inventory):
		return false;
	if not _has_explored_space(hex):
		return false;
	if not _has_clear_space(hex):
		return false;
	if not _has_player_clear_space(hex):
		return false;
	if not _has_required_distance(hex):
		return false;
	return _passes_handler_checks(hex, inventory, placement_rotation_y);

func place_on(hex: HexBase, inventory: ContentGroup = null, placement_rotation_y: float = NAN) -> bool:
	if not can_place_on(hex, inventory, placement_rotation_y):
		return false;
	_pay_build_cost(inventory);
	hex.set_structure(self, false, placement_rotation_y);
	Manager.instance.journal.complete_task(journal_task.id)
	return true;

func uses_content(content: Resource) -> bool:
	return content == self or build_cost.has(content);

func get_placement_rotation_y(hex: HexBase, placement_rotation_y: float = NAN) -> Dictionary:
	if placement_rotation_y == placement_rotation_y:
		return {
			"has_rotation": true,
			"rotation_y": float(placement_rotation_y)
		};

	if placement_handler == null:
		return { "has_rotation": false };

	var handler: RefCounted = placement_handler.new();
	if handler == null or not handler.has_method("get_rotation_y"):
		return { "has_rotation": false };

	return {
		"has_rotation": true,
		"rotation_y": float(handler.get_rotation_y(self, hex))
	};

func _has_build_cost(inventory: ContentGroup) -> bool:
	if build_cost.is_empty():
		return true;
	if inventory == null:
		return false;
	return inventory.has_all(build_cost);

func _pay_build_cost(inventory: ContentGroup) -> void:
	if inventory == null:
		return;
	for item: ItemInfo in build_cost.keys():
		inventory.remove(item, int(build_cost[item]));

func _has_explored_space(hex: HexBase) -> bool:
	var grid := SceneManager.get_active_scene().node as HexGrid;
	if grid == null:
		return false;

	for scene_instance: SceneInstance in grid.get_tiles_in_radius(hex.cube_id, required_space_radius):
		var tile := scene_instance.node as HexBase;
		if tile == null or not tile.is_explored:
			return false;
	return true;

func _has_clear_space(hex: HexBase) -> bool:
	var grid := SceneManager.get_active_scene().node as HexGrid;
	if grid == null:
		return false;

	for scene_instance: SceneInstance in grid.get_tiles_in_radius(hex.cube_id, required_space_radius):
		var tile := scene_instance.node as HexBase;
		if tile == null:
			return false;
		if tile.structure != null:
			return false;
	return true;

func _has_player_clear_space(hex: HexBase) -> bool:
	var player := Manager.instance.player_instance if Manager.instance != null else null
	if player == null:
		return true;

	var player_hex := player.get_hex();
	if player_hex == null:
		return true;

	var grid := SceneManager.get_active_scene().node as HexGrid;
	if grid == null:
		return false;

	for scene_instance: SceneInstance in grid.get_tiles_in_radius(hex.cube_id, required_space_radius):
		var tile := scene_instance.node as HexBase;
		if tile != null and tile.cube_id == player_hex.cube_id:
			return false;
	return true;

func _has_required_distance(hex: HexBase) -> bool:
	var grid := SceneManager.get_active_scene().node as HexGrid;
	if grid == null:
		return false;

	var required_distance := required_space_radius + minimum_distance_from_other_structures;
	for region_list: Array in grid.region_instances.values():
		for region_instance: RegionInstance in region_list:
			for other_pos: Vector3i in region_instance.structures.keys():
				var other := region_instance.structures[other_pos] as StructureInfo;
				if other == null:
					continue;

				if GridUtils.cube_distance(hex.cube_id, other_pos) <= required_distance:
					return false;
	return true;

func _passes_handler_checks(hex: HexBase, inventory: ContentGroup, placement_rotation_y: float = NAN) -> bool:
	if placement_handler == null:
		return true;

	var handler: RefCounted = placement_handler.new();
	if handler == null:
		return true;
	if not handler.has_method("can_place"):
		Debug.err("%s placement handler must define can_place(structure_info, hex, inventory)." % id);
		return false;

	if not bool(handler.can_place(self, hex, inventory)):
		return false;

	if placement_rotation_y == placement_rotation_y and handler.has_method("can_place_rotation"):
		return bool(handler.can_place_rotation(self, hex, inventory, float(placement_rotation_y)));

	return true;

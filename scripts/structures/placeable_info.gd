class_name PlaceableStructureInfo extends StructureInfo

@export var build_cost: Dictionary[ItemInfo, int];
@export var placement_handler: Script;

func can_place_on(hex: HexBase, inventory: ContentGroup = null) -> bool:
	if hex == null:
		return false;
	if not _has_build_cost(inventory):
		return false;
	if not _has_clear_space(hex):
		return false;
	if not _has_required_distance(hex):
		return false;
	return _is_allowed_by_handler(hex, inventory);

func place_on(hex: HexBase, inventory: ContentGroup = null) -> bool:
	if not can_place_on(hex, inventory):
		return false;
	_pay_build_cost(inventory);
	hex.set_structure(self);
	return true;

func uses_content(content: Resource) -> bool:
	return content == self or build_cost.has(content);

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

func _has_clear_space(hex: HexBase) -> bool:
	var grid := SceneManager.get_active_scene().node as HexGrid;
	if grid == null:
		return false;

	for scene_instance: SceneInstance in grid.get_tiles_in_radius(hex.cube_id, required_space_radius):
		var tile := scene_instance.node as HexBase;
		if tile == null:
			return false;
		if tile.structure != null or not tile.can_generate:
			return false;
	return true;

func _has_required_distance(hex: HexBase) -> bool:
	var grid := SceneManager.get_active_scene().node as HexGrid;
	if grid == null:
		return false;

	for region_list: Array in grid.region_instances.values():
		for region_instance: RegionInstance in region_list:
			for other_pos: Vector3i in region_instance.structures.keys():
				var other := region_instance.structures[other_pos] as StructureInfo;
				if other == null:
					continue;

				var min_dist := (
					maxi(required_space_radius, other.required_space_radius)
					+ maxi(minimum_distance_from_other_structures, other.minimum_distance_from_other_structures)
					+ 1
				);
				if GridUtils.cube_distance(hex.cube_id, other_pos) <= min_dist:
					return false;
	return true;

func _is_allowed_by_handler(hex: HexBase, inventory: ContentGroup) -> bool:
	if placement_handler == null:
		return true;

	var handler: RefCounted = placement_handler.new();
	if handler == null:
		return true;
	if not handler.has_method("can_place"):
		Debug.err("%s placement handler must define can_place(structure_info, hex, inventory)." % id);
		return false;
	return bool(handler.can_place(self, hex, inventory));

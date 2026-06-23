class_name PlaceableStructureInfo extends StructureInfo

@export var build_cost: Dictionary[ItemInfo, int];
@export var placement_handler: Script;
var last_placement_debug_reason: String = "";

func can_place_on(hex: HexBase, inventory: ContentGroup = null) -> bool:
	return bool(get_placement_debug(hex, inventory).get("can_place", false));

func place_on(hex: HexBase, inventory: ContentGroup = null) -> bool:
	if not can_place_on(hex, inventory):
		return false;
	_pay_build_cost(inventory);
	hex.set_structure(self);
	return true;

func uses_content(content: Resource) -> bool:
	return content == self or build_cost.has(content);

func get_placement_rotation_y(hex: HexBase) -> Dictionary:
	if placement_handler == null:
		return { "has_rotation": false };

	var handler: RefCounted = placement_handler.new();
	if handler == null or not handler.has_method("get_rotation_y"):
		return { "has_rotation": false };

	return {
		"has_rotation": true,
		"rotation_y": float(handler.get_rotation_y(self, hex))
	};

func get_placement_debug(hex: HexBase, inventory: ContentGroup = null) -> Dictionary:
	var result := {
		"can_place": false,
		"reason": ""
	};

	if hex == null:
		result["reason"] = "No hex is being hovered.";
	elif not _has_build_cost(inventory):
		result["reason"] = _get_missing_cost_reason(inventory);
	elif not _has_explored_space(hex):
		result["reason"] = "The target space has unexplored tiles.";
	elif not _has_clear_space(hex):
		result["reason"] = "The target space already has a structure.";
	elif not _has_required_distance(hex):
		result["reason"] = "Too close for this structure's placement spacing.";
	else:
		var handler_reason := _get_handler_block_reason(hex, inventory);
		if handler_reason == "":
			result["can_place"] = true;
			result["reason"] = "Placement valid.";
		else:
			result["reason"] = handler_reason;

	last_placement_debug_reason = str(result["reason"]);
	return result;

func _has_build_cost(inventory: ContentGroup) -> bool:
	if build_cost.is_empty():
		return true;
	if inventory == null:
		return false;
	return inventory.has_all(build_cost);

func _get_missing_cost_reason(inventory: ContentGroup) -> String:
	if inventory == null:
		return "No inventory was available for placement validation.";

	var missing: Array[String] = [];
	for item: ItemInfo in build_cost.keys():
		var required := int(build_cost[item]);
		var owned := inventory.get_count(item);
		if owned < required:
			missing.append("%s %d/%d" % [item.get_display_name(), owned, required]);

	if missing.is_empty():
		return "Missing build cost.";
	return "Missing build cost: %s" % ", ".join(missing);

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

func _get_handler_block_reason(hex: HexBase, inventory: ContentGroup) -> String:
	if placement_handler == null:
		return "";

	var handler: RefCounted = placement_handler.new();
	if handler == null:
		return "";
	if not handler.has_method("can_place"):
		Debug.err("%s placement handler must define can_place(structure_info, hex, inventory)." % id);
		return "Placement handler is missing can_place().";

	if bool(handler.can_place(self, hex, inventory)):
		return "";
	if handler.has_method("get_block_reason"):
		return str(handler.get_block_reason(self, hex, inventory));
	return "Placement handler rejected this tile.";

class_name SettlementExpansionInfo
extends PlaceableStructureInfo

func can_place_on(hex: HexBase, inventory: ContentGroup = null, _placement_rotation_y: float = NAN) -> bool:
	if hex == null:
		return false
	if not _has_expansion_cost(inventory):
		return false
	if hex.structure != null:
		return false

	var grid := _get_active_grid()
	if grid == null:
		return false

	return _get_expandable_settlement(grid, hex) != null

func place_on(hex: HexBase, inventory: ContentGroup = null, _placement_rotation_y: float = NAN) -> bool:
	if not can_place_on(hex, inventory):
		return false

	var grid := _get_active_grid()
	var settlement := _get_expandable_settlement(grid, hex)
	if settlement == null:
		return false

	_pay_expansion_cost(inventory)
	return settlement.expand_to_hex(grid, hex)

func get_placement_rotation_y(_hex: HexBase, _placement_rotation_y: float = NAN) -> Dictionary:
	return { "has_rotation": false }

func _get_expandable_settlement(grid: HexGrid, hex: HexBase) -> Settlement:
	if grid == null or hex == null or Manager.instance == null:
		return null

	if Manager.instance.active_settlement != null and Manager.instance.active_settlement.can_expand_to_hex(grid, hex):
		return Manager.instance.active_settlement

	for settlement: Settlement in Manager.instance.settlements:
		if settlement == null or not is_instance_valid(settlement):
			continue
		if not grid.is_ancestor_of(settlement):
			continue
		if settlement.can_expand_to_hex(grid, hex):
			return settlement
	return null

func _get_active_grid() -> HexGrid:
	var active_scene := SceneManager.get_active_scene()
	if active_scene == null:
		return null
	return active_scene.node as HexGrid

func _has_expansion_cost(inventory: ContentGroup) -> bool:
	if build_cost.is_empty():
		return true
	if inventory == null:
		return false
	return inventory.has_all(build_cost)

func _pay_expansion_cost(inventory: ContentGroup) -> void:
	if inventory == null:
		return
	for item: ItemInfo in build_cost.keys():
		inventory.remove(item, int(build_cost[item]))

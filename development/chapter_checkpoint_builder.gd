class_name ChapterCheckpointBuilder
extends RefCounted

## Development-only preparation. Uses normal fieldwork timers, costs, crafting,
## blueprint placement and foundation delivery; never sets completion flags.
static func complete_project(id: String, checkpoint: Callable = Callable()) -> bool:
	var manager := Manager.instance
	var definition := manager.regional.get_definition(id)
	var tree := manager.get_tree()
	var paused := tree.paused
	tree.paused = false
	Engine.time_scale = 8
	var site: QuestObjective
	for candidate: QuestObjective in manager.regional.discoveries.sites:
		if is_instance_valid(candidate) and DiscoveryRandomizer.get_kind(candidate) == definition.site_kind:
			site = candidate
			break
	if site == null: return _finish(tree, paused, false)
	site.hex.is_explored = true
	site.discovery_resolved = true
	var spot := site.get_spot_progress()
	if spot != null: spot.resolve_no_occupation(true)
	var key := ""
	match id:
		"water": site.apply_site_state("FRESH"); key = "fill"
		"food": site.apply_site_state("WATERED"); key = "harvest"
		"workshop": site.apply_site_state("POOR_VEIN"); key = "extract"
	if not site.get_filtered_quest_types().has(key): return _finish(tree, paused, false)
	var quest := Quest.new(site.hex, key)
	var profile := site.get_profile(key)
	if profile != null:
		for item: ItemInfo in profile.required_supplies:
			if not await _supply(item, profile.required_supplies[item]): return _finish(tree, paused, false)
	if not site.assign_required_supplies(quest, manager.hub.stockpile): return _finish(tree, paused, false)
	manager.operations.register_quest(quest)
	quest.set_state(Quest.QuestState.IN_PROGRESS)
	await site.execute_quest(quest)
	quest.set_state(Quest.QuestState.COMPLETE)
	if not manager.regional.projects[id].fieldwork_done: return _finish(tree, paused, false)
	for item: ItemInfo in definition.materials:
		if not await _supply(item, definition.materials[item]): return _finish(tree, paused, false)
	if not manager.regional.complete_project(id): return _finish(tree, paused, false)
	if definition.construction != null:
		if checkpoint.is_valid() and not checkpoint.call("well_blueprint"): return _finish(tree, paused, false)
		var grid := manager.transport.get_grid()
		var placed := false
		for hex: HexBase in manager.active_settlement.get_settlement_hexes(grid):
			if definition.construction.can_place_on(hex, manager.hub.stockpile):
				placed = definition.construction.place_on(hex, manager.hub.stockpile)
				break
		if not placed: return _finish(tree, paused, false)
		for frame in 4: await tree.process_frame
		var building := manager.regional.get_project_buildable(id)
		if building == null: return _finish(tree, paused, false)
		if checkpoint.is_valid() and not checkpoint.call("well_foundation"): return _finish(tree, paused, false)
		var foundation := building.current_step as BuildRequest
		foundation.quest.initialize()
		for item: ItemInfo in foundation.quest.requested_items:
			var amount := foundation.quest.requested_items[item]
			if manager.hub.stockpile.get_count(item) < amount: return _finish(tree, paused, false)
			manager.hub.stockpile.remove(item, amount)
			foundation.quest.progress_tracker.add(item, amount)
		foundation.completed.emit()
	return _finish(tree, paused, manager.regional.project_complete(id))

static func _supply(item: ItemInfo, amount: int) -> bool:
	var manager := Manager.instance
	while manager.hub.stockpile.get_count(item) < amount:
		if not item.has_recipe():
			# Tools such as empty buckets are bought from the normal market stock.
			var market := manager.active_settlement.get_service(&"Market") as Market
			var bought := false
			for slot: ContentSlotResource in market.buy_inventory.data:
				if slot.get_content() == item:
					bought = manager.market.buy_from_slot(slot, manager.hub.stockpile, 1)
					break
			if not bought: return false
		else:
			for ingredient: ItemInfo in item.recipe:
				if not await _supply(ingredient, item.recipe[ingredient]): return false
			if not manager.crafting.start(item, manager.hub.stockpile): return false
			while manager.crafting.active_job != null: await manager.get_tree().process_frame
	return true

static func _finish(tree: SceneTree, paused: bool, result: bool) -> bool:
	Engine.time_scale = 1
	tree.paused = paused
	return result

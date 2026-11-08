extends Node

## Run this dedicated scene to rebuild the bundled fixtures, never in a live session.
const WORLD_SEED := 20261102
const WOOD := preload("res://resources/item_info/wood_raw.tres")
const IRON := preload("res://resources/item_info/iron_ore.tres")
var grid: MainGrid
var _deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var partner_only := OS.get_cmdline_user_args().has("--generate-trade-partner-checkpoint")
	if not OS.get_cmdline_user_args().has("--generate-development-checkpoints") and not partner_only:
		push_error("Pass -- --generate-development-checkpoints to rebuild bundled fixtures.")
		get_tree().quit(1)
		return
	_deadline = Time.get_ticks_msec() + 180000
	seed(WORLD_SEED)
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = WORLD_SEED
	)
	if partner_only:
		_generate_partner_from_checkpoint.call_deferred()
		return
	_generate.call_deferred()

func _process(_delta: float) -> void:
	if _deadline > 0 and Time.get_ticks_msec() > _deadline: _fail("Generation timed out")

func _generate() -> void:
	while grid == null or not grid.initialized or grid.is_streaming_busy() or Manager.instance.player_instance == null:
		await get_tree().process_frame
		var active := SceneManager.get_active_scene()
		if active != null: grid = active.node as MainGrid
	for frame in 8: await get_tree().process_frame
	get_tree().paused = true
	var manager := Manager.instance
	manager.time_of_day._time = 10.0
	if not _write_fixture("arrival"): return

	# Pay for the blueprint and first timber through the same market API as play.
	var forge := SettlementCampaign.FORGE as PlaceableStructureInfo
	if not _buy(manager.campaign.get_blueprint(), 1): return
	var placed := false
	for coord: Vector3i in grid.tiles:
		var hex := grid.get_hex_at_cube_id(coord)
		if forge.can_place_on(hex, manager.hub.stockpile):
			placed = forge.place_on(hex, manager.hub.stockpile)
			break
	if not placed: _fail("No legal forge site"); return
	for frame in 8: await get_tree().process_frame
	var foundation := manager.campaign.get_foundation()
	if foundation == null: _fail("Forge foundation did not initialize"); return
	foundation.quest.initialize()
	if not _buy(WOOD, 1): return
	manager.hub.stockpile.remove(WOOD, 1)
	foundation.quest.progress_tracker.add(WOOD, 1)
	manager.time_of_day._time = 30.0
	manager.campaign.refresh()
	if not _write_fixture("foundation"): return

	# Supply the remaining materials, finish construction, and apply the real upgrade.
	if not _buy(WOOD, 1) or not _buy(IRON, 5): return
	for item: ItemInfo in foundation.quest.requested_items:
		var remaining := foundation.quest.requested_items[item] - foundation.quest.progress_tracker.get_count(item)
		manager.hub.stockpile.remove(item, remaining)
		foundation.quest.progress_tracker.add(item, remaining)
	foundation.completed.emit()
	if not manager.active_settlement.try_upgrade(manager.hub.stockpile):
		_fail("Could not upgrade settlement after opening the blacksmith"); return
	manager.campaign.refresh()
	# Explicit development working capital, so later systems are easy to exercise.
	manager.hub.currency = 250
	manager.hub.prestige = 4
	manager.hub.deposit_items({WOOD: 24, IRON: 16, preload("res://resources/item_info/travel_rations.tres"): 6})
	manager.time_of_day.days = 1
	manager.time_of_day._time = 10.0
	if not _write_fixture("blacksmith"): return
	if not await ChapterCheckpointBuilder.complete_project("water", _write_fixture): _fail(manager.regional.last_error); return
	if not _write_fixture("first_improvement"): return
	if not await ChapterCheckpointBuilder.complete_project("food"): _fail(manager.regional.last_error); return
	if not _write_fixture("village_improved"): return
	if not _reveal_village(): return
	if not _write_fixture("trade_ready"): return
	if not await _generate_partner_checkpoint("chapter_complete", true): return

	# Alternate branches retain their stable IDs for targeted tests and tools.
	# Reloading the base avoids manually undoing project/reward state.
	reparent(SaveGames)
	if not await _load_base("blacksmith"): return
	if not _reveal_village(): return
	if not _write_fixture("village"): return
	if not await _generate_partner_checkpoint("trade_partner"): return
	if not await _load_base("blacksmith"): return
	if not await _generate_active_commission(): return
	print("DEVELOPMENT CHECKPOINTS GENERATED: all chapter stages and alternate branches")
	get_tree().quit()

func _load_base(id: String) -> bool:
	get_tree().paused = false
	if not SaveGames.load_development_checkpoint(id): _fail(SaveGames.last_error); return false
	var result: Array = await SaveGames.load_finished
	if not result[0]: _fail(str(result[1])); return false
	while WorldLoading.blocks_input: await get_tree().process_frame
	grid = Manager.instance.transport.get_grid()
	get_tree().paused = true
	return true

func _reveal_village() -> bool:
	var manager := Manager.instance

	var village: Settlement
	for settlement in manager.settlements:
		if settlement != manager.active_settlement and settlement.get_parent() is HexBase and not settlement.allows_player_construction:
			village = settlement
			break
	if village == null: _fail("No neighbouring village"); return false
	var origin := grid.get_hex_at_world_position(manager.active_settlement.spawn_position.global_position)
	var destination := grid.get_hex_at_world_position(village.spawn_position.global_position)
	var path := grid.pathfinder.get_hex_path(origin.cube_id, destination.cube_id)
	if path.is_empty(): _fail("Village entrance has no walking route"); return false
	for hex: HexBase in path:
		for nearby: SceneInstance in grid.get_tiles_in_radius(hex.cube_id, 1): nearby.node.is_explored = true
	for hex: HexBase in village.get_settlement_hexes(grid): hex.is_explored = true
	manager.player_instance.global_position = village.spawn_position.global_position
	manager.time_of_day._time = 45.0
	manager.transport.register_discovered_village(village.get_parent().cube_id)
	return true

func _generate_partner_from_checkpoint() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	if not SaveGames.load_development_checkpoint("village"): _fail("Village checkpoint unavailable"); return
	var result: Array = await SaveGames.load_finished
	if not result[0]: _fail("Village checkpoint failed to load"); return
	grid = Manager.instance.transport.get_grid()
	get_tree().paused = true
	if await _generate_partner_checkpoint():
		print("DEVELOPMENT CHECKPOINT GENERATED: trade_partner (older fixtures preserved)")
		get_tree().quit()

func _generate_partner_checkpoint(id: String = "trade_partner", capture_first_delivery := false) -> bool:
	var manager := Manager.instance
	var village := manager.transport.destinations()[0]
	var coord: Vector3i = village.get_parent().cube_id
	manager.transport.register_discovered_village(coord)
	if not await _complete_delivery(coord): return false
	if not manager.transport.next_request(coord): _fail("Equipment request unavailable"); return false
	if capture_first_delivery and not _write_fixture("first_shipment"): return false
	var window := load("res://scenes/ui/crafting_ui.tscn").instantiate() as DraggableControl
	manager.get_parent().get_node("game_ui").add_child(window)
	var crafting := window.content as CraftingUI
	crafting.inventory = manager.hub.stockpile
	crafting.on_enter()
	for item: ItemInfo in [load("res://resources/item_info/work_supplies.tres"), load("res://resources/item_info/work_supplies.tres"), load("res://resources/item_info/field_kit.tres"), load("res://resources/item_info/wood_log.tres"), load("res://resources/item_info/wood_log.tres")]:
		var index := crafting.recipes.find(item)
		if index < 0: _fail("Missing recipe " + item.unique_id); return false
		crafting._select_recipe(index)
		var previous := manager.hub.stockpile.get_count(item)
		crafting._craft_selected_item()
		get_tree().paused = false
		Engine.time_scale = 8
		while manager.crafting.active_job != null: await get_tree().process_frame
		Engine.time_scale = 1
		get_tree().paused = true
		if manager.hub.stockpile.get_count(item) != previous + 1: _fail("Could not craft " + item.unique_id); return false
	window.queue_free()
	if not await _complete_delivery(coord): return false
	manager.campaign.refresh()
	return _write_fixture(id)

func _generate_active_commission() -> bool:
	var manager := Manager.instance
	var forest: HexBase
	for info: StructureInfo in grid._required_starting_structure_coords:
		if info.id == "forest": forest = grid.get_hex_at_cube_id(grid._required_starting_structure_coords[info][0])
	if forest == null: _fail("No starting forest for commission checkpoint"); return false
	forest.is_explored = true
	manager.operations.auto_resolve_completed_quests = false
	var result := QuestPostingService.new(manager.quests, manager.hub, manager.player_instance).post_quest(forest, "forage", 15, -1, 1, [], manager.hub.stockpile)
	if not result.success: _fail(result.message_key); return false
	get_tree().paused = false
	Engine.time_scale = 8
	while not result.quest.is_state(Quest.QuestState.IN_PROGRESS): await get_tree().process_frame
	Engine.time_scale = 1
	get_tree().paused = true
	return _write_fixture("active_commission")

func _complete_delivery(coord: Vector3i) -> bool:
	if not Manager.instance.transport.dispatch(coord): _fail(Manager.instance.transport.last_error); return false
	get_tree().paused = false
	Engine.time_scale = 8
	while not Manager.instance.transport.active_shipment.is_empty(): await get_tree().process_frame
	Engine.time_scale = 1
	get_tree().paused = true
	return true

func _buy(item: ItemInfo, count: int) -> bool:
	var market := Manager.instance.active_settlement.get_service(&"Market") as Market
	for slot: ContentSlotResource in market.buy_inventory.data:
		if slot.get_content() == item and Manager.instance.market.buy_from_slot(slot, Manager.instance.hub.stockpile, count): return true
	_fail("Could not purchase %s x%d" % [item.unique_id, count])
	return false

func _write_fixture(id: String) -> bool:
	Manager.instance.campaign.refresh()
	var reason := SaveGames.save_block_reason()
	if not reason.is_empty(): _fail(reason); return false
	var snapshot := GameSnapshot.new()
	var data := snapshot.capture(grid)
	if not snapshot.codec.errors.is_empty(): _fail(str(snapshot.codec.errors)); return false
	var label := id
	for definition in SaveGames.DEVELOPMENT_CHECKPOINTS:
		if definition.id == id: label = definition.label
	var document := SaveGames.create_document(label, data)
	DirAccess.make_dir_recursive_absolute(SaveGames.DEVELOPMENT_DIRECTORY)
	var file := FileAccess.open(SaveGames.DEVELOPMENT_DIRECTORY.path_join(id + ".json"), FileAccess.WRITE)
	if file == null: _fail("Could not write fixture " + id); return false
	file.store_string(JSON.stringify(document))
	file.close()
	print("Generated development checkpoint: ", id)
	return true

func _fail(message: String) -> void:
	push_error("DEVELOPMENT CHECKPOINTS: " + message)
	get_tree().quit(1)

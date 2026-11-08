extends Node

var failures: Array[String] = []
var deadline := 0
var stale_deliveries := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	deadline = Time.get_ticks_msec() + 90000
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("Construction test timed out")
		get_tree().quit(1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func reload_save(label: String) -> void:
	check(SaveGames.save_slot(label), "Cannot save construction state")
	check(SaveGames.load_slot(SaveGames.slot_id(label)), "Cannot reload construction state")
	var loaded: Array = await SaveGames.load_finished
	check(loaded[0], "Construction save failed to restore")
	while WorldLoading.blocks_input: await get_tree().process_frame

func capture_request(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	var info := DataManager.instance.get_scene_by_name("quest_list_ui")
	info.queue(func(_info: SceneInfo) -> void: pass)
	while not info.is_cached: await get_tree().process_frame
	var window := SceneManager.add(info, false).node as DraggableControl
	var board := window.content as QuestListUI
	board.show_request("water")
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = viewport
		await window.on_enter()
		for frame in 6: await get_tree().process_frame
		var scroll := board.get_node("Layout/Scroll") as ScrollContainer
		check(scroll.get_v_scroll_bar().max_value <= scroll.size.y + 1, "Water request requires vertical scrolling: " + name + str(viewport))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + name + "-%d.png" % viewport.y)
	window.hide()
	get_window().size = Vector2i(1280, 720)

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	check(SaveGames.load_development_checkpoint("blacksmith"), "Cannot load blacksmith")
	var loaded: Array = await SaveGames.load_finished
	check(loaded[0], "Blacksmith checkpoint failed")
	while WorldLoading.blocks_input: await get_tree().process_frame
	var regional := Manager.instance.regional
	var definition := regional.get_definition("water")
	var hub := Manager.instance.hub
	var gold := hub.currency
	var prestige := hub.prestige
	check(not regional.complete_project("water", true), "Funding bypass is still accepted")
	check(not regional.complete_project("water"), "Missing fieldwork accepted")
	check(hub.currency == gold and hub.prestige == prestige, "Blocked action consumed standing")
	await capture_request("well-request-fieldwork")
	var plank_recipe := preload("res://resources/item_info/wood_log.tres")
	check(not CraftingGuidance.needed_by(plank_recipe).is_empty(), "Construction demand is missing from crafting guidance")
	CraftingGuidance.view_recipe(plank_recipe)
	var recipe_info := DataManager.instance.get_scene_by_name("crafting_ui")
	while recipe_info.get_live_instances().is_empty(): await get_tree().process_frame
	var recipe_window := recipe_info.get_live_instances()[0].node as DraggableControl
	var recipe_ui := recipe_window.content as CraftingUI
	while not recipe_window.visible: await get_tree().process_frame
	for frame in 8: await get_tree().process_frame
	check(recipe_ui.preview_only and recipe_ui.selected_item == plank_recipe, "View recipe did not select the requested recipe")
	recipe_ui._craft_selected_item()
	check(Manager.instance.crafting.active_job == null and Manager.instance.campaign.destination is Blacksmith, "Recipe preview crafted remotely instead of locating the forge")
	var forge := Manager.instance.active_settlement.get_service(&"Blacksmith") as Blacksmith
	forge._open_window(recipe_info)
	while not recipe_window.visible: await get_tree().process_frame
	for frame in 8: await get_tree().process_frame
	check(not recipe_ui.preview_only, "Recipe preview mode leaked into the actual blacksmith")
	recipe_window.hide()
	# Fieldwork completion itself is exercised by the checkpoint builder and the
	# regional integration test. Isolate construction transitions here.
	regional.projects["water"].fieldwork_done = true
	check(regional.complete_project("water"), "Blueprint cannot be issued")
	check(not regional.project_complete("water"), "Issuing blueprint grants improvement too soon")
	check(hub.currency == gold - definition.coin_cost and hub.prestige == prestige - definition.prestige_cost, "Blueprint price incorrect")
	check(hub.stockpile.get_count(definition.blueprint) == 1, "Blueprint missing")
	check(not regional.complete_project("water"), "Blueprint can be issued twice")
	await capture_request("well-request-blueprint")
	await reload_save("Well permit")
	regional = Manager.instance.regional
	hub = Manager.instance.hub
	check(regional.projects["water"].blueprint_issued and not regional.project_complete("water"), "Permit state lost")
	var slot := hub.stockpile.get_available_slots(definition.blueprint).filter(func(entry: ContentSlotResource) -> bool: return entry.get_content() == definition.blueprint)[0] as ContentSlotResource
	var journal_info := DataManager.instance.get_scene_by_name("hub_window")
	journal_info.queue(func(_info: SceneInfo) -> void: pass)
	while not journal_info.is_cached: await get_tree().process_frame
	var journal := SceneManager.add(journal_info, true).node as DraggableControl
	await journal.on_enter()
	journal.content.show_tab("inventory")
	for frame in 3: await get_tree().process_frame
	check(journal.is_visible_in_tree(), "Journal was not opened before placement")
	var slot_ui: PlaceableContentSlotUI
	for child: Node in journal.find_children("*", "Control", true, false):
		if child is PlaceableContentSlotUI and child.contentSlot == slot: slot_ui = child
	check(slot_ui != null, "Blueprint slot is missing from Stores")
	if slot_ui == null: get_tree().quit(1); return
	var context_click := InputEventMouseButton.new()
	context_click.button_index = MOUSE_BUTTON_RIGHT
	context_click.pressed = true
	slot_ui._gui_input(context_click)
	var menu: ContextMenu
	for child: Node in slot_ui.get_children():
		if child is ContextMenu: menu = child
	check(menu != null and menu.item_count == 1, "Blueprint has no Place context action")
	if menu == null: get_tree().quit(1); return
	menu._on_idx(0)
	check(WorldPlacement.structure == definition.construction, "Context action did not start placement mode")
	check(get_viewport().get_visible_rect().encloses(WorldPlacement._hint.get_global_rect()), "Placement controls hint is off screen")
	check(not journal.visible, "Placement leaves journal covering the world")
	check(not WorldPlacement.try_place_at(null) and WorldPlacement.structure != null, "Invalid placement ended mode")
	check(hub.stockpile.get_count(definition.blueprint) == 1, "Invalid click consumed blueprint")
	var escape := InputEventAction.new()
	escape.action = "cancel"
	escape.pressed = true
	WorldPlacement._input(escape)
	check(WorldPlacement.structure == null and journal.visible and hub.stockpile.get_count(definition.blueprint) == 1, "Escape did not restore window/blueprint")
	check(WorldPlacement.begin(definition.construction, hub.stockpile, slot), "Cannot restart placement")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	WorldPlacement._input(right)
	check(WorldPlacement.structure == null and journal.visible, "Right-click cancellation failed")
	var grid := Manager.instance.transport.get_grid()
	var plot: HexBase
	for hex: HexBase in Manager.instance.active_settlement.get_settlement_hexes(grid):
		if definition.construction.can_place_on(hex, hub.stockpile): plot = hex; break
	check(plot != null, "No legal well plot")
	if plot == null: get_tree().quit(1); return
	WorldPlacement.begin(definition.construction, hub.stockpile, slot)
	var count := Manager.instance.active_settlement.buildables.size()
	WorldPlacement.preview.update(definition.construction, plot, true, NAN)
	for frame in 3: await get_tree().process_frame
	check(Manager.instance.active_settlement.buildables.size() == count, "Preview registered a real building")
	check(WorldPlacement.try_place_at(plot), "Valid placement failed")
	for frame in 4: await get_tree().process_frame
	check(hub.stockpile.get_count(definition.blueprint) == 0, "Placement did not consume exactly one blueprint")
	check(not regional.project_complete("water") and regional.get_project_buildable("water") != null, "Foundation completed request prematurely")
	var building := regional.get_project_buildable("water")
	var foundation := building.current_step as BuildRequest
	foundation.quest.initialize()
	var plank := preload("res://resources/item_info/wood_log.tres")
	hub.stockpile.add(plank, 2, true)
	hub.stockpile.remove(plank, 1)
	foundation.quest.progress_tracker.add(plank, 1)
	foundation.completed.emit()
	check(building.current_step == foundation and not regional.project_complete("water"), "Incomplete delivery opened well")
	await reload_save("Well partial delivery")
	regional = Manager.instance.regional
	hub = Manager.instance.hub
	building = regional.get_project_buildable("water")
	foundation = building.current_step as BuildRequest
	check(foundation.quest.progress_tracker.get_count(plank) == 1, "Partial materials lost on reload")
	for item: ItemInfo in foundation.quest.requested_items:
		var remaining := foundation.quest.requested_items[item] - foundation.quest.progress_tracker.get_count(item)
		hub.stockpile.add(item, remaining, true)
	var deposit_info := DataManager.instance.get_scene_by_name("deposit_ui")
	deposit_info.queue(func(_info: SceneInfo) -> void: pass)
	while not deposit_info.is_cached: await get_tree().process_frame
	# Open an old foundation first to exercise reuse of the unique delivery UI.
	for candidate: Buildable in Manager.instance.active_settlement.buildables:
		if candidate != building and candidate.build_steps[0] is BuildRequest:
			var previous := candidate.build_steps[0] as BuildRequest
			previous.completed.connect(func() -> void: stale_deliveries += 1)
			previous._open_window(deposit_info)
			break
	foundation._open_window(deposit_info)
	var deposit_window := deposit_info.get_live_instances()[0].node as DraggableControl
	var deposit := deposit_window.content.get_node("InventoryHud") as DepositUI
	gold = hub.currency
	prestige = hub.prestige
	var reputation := Manager.instance.reputation.reputation
	deposit._on_complete_order_pressed()
	check(regional.project_complete("water") and not building.current_step is BuildRequest, "Well does not finish request")
	check(hub.currency == gold and hub.prestige == prestige, "Construction charged permit price twice")
	check(Manager.instance.reputation.reputation == reputation + definition.reputation_reward, "Well reward missing")
	check(stale_deliveries == 0, "Delivery window retained the previous foundation callback")
	foundation.completed.emit()
	check(not regional.finish_construction("water") and Manager.instance.reputation.reputation == reputation + definition.reputation_reward, "Well reward duplicated")
	await reload_save("Well complete")
	check(Manager.instance.regional.project_complete("water") and not Manager.instance.regional.get_project_buildable("water").current_step is BuildRequest, "Completed well lost on reload")
	await capture_request("well-request-complete")
	if OS.get_cmdline_user_args().has("--capture"):
		var camera := Manager.instance.spring_arm_camera
		camera.target = Manager.instance.regional.get_project_buildable("water")
		camera.global_position = camera.target.global_position
		for frame in 12: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/validation/well-built-world.png")
	check(SaveGames.load_development_checkpoint("blacksmith"), "Cannot prepare legacy water test")
	loaded = await SaveGames.load_finished
	check(loaded[0], "Cannot restore legacy test base")
	Manager.instance.regional.projects["water"].completed = true
	reputation = Manager.instance.reputation.reputation
	await reload_save("Legacy completed water")
	check(Manager.instance.regional.project_complete("water") and Manager.instance.regional.projects["water"].blueprint_issued, "Legacy water progress was reset")
	check(Manager.instance.hub.stockpile.get_count(definition.blueprint) == 1 and Manager.instance.reputation.reputation == reputation, "Legacy well migration lost permit or repaid rewards")
	await reload_save("Migrated completed water")
	check(Manager.instance.hub.stockpile.get_count(definition.blueprint) == 1, "Legacy permit migration repeats on reload")
	print("COMMUNITY CONSTRUCTION TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

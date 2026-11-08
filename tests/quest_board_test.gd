extends Node

var failures: Array[String] = []
var deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280,720)
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	deadline = Time.get_ticks_msec() + 60000
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline: get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _settle(window: DraggableControl) -> void:
	window.on_enter()
	for frame in 16: await get_tree().process_frame

func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + name + ".png")

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	check(SaveGames.load_development_checkpoint("arrival"), "Cannot load opening fixture")
	await SaveGames.load_finished
	Manager.instance.regional.open_request("water")
	var info := DataManager.instance.get_scene_by_name("quest_list_ui")
	while info.get_live_instances().is_empty(): await get_tree().process_frame
	var window := info.get_live_instances()[0].node as DraggableControl
	var board := window.content as QuestListUI
	await _settle(window)
	check(board.active_tab == "village" and board.selected_request == "water", "Request deep link failed")
	check(not board.create_quest_button.is_visible_in_tree(), "Player posting action leaks into villager requests")
	check(board.request_list.get_child_count() == 3 and board.request_details.complete.disabled, "Villager requests are hidden at the start or skip their blacksmith requirement")
	check(board.request_details.objectives.get_child_count() == 2, "Blacksmith and fieldwork objectives are not shown")
	for notice: VillageRequestNotice in board.request_list.get_children():
		check(notice.state_label.text == tr("QUEST_REQUEST_FORGE_REQUIRED"), "Opening request shows the wrong blocker")
		check(notice.state_label.get_tooltip() == notice.state_label.text, "Status hover does not show the full status")
		check(notice.state_label.mouse_filter == Control.MOUSE_FILTER_STOP and notice.tooltip_text.is_empty(), "Row reward tooltip overrides the status cell")
	check(Manager.instance.active_settlement.find_children("Resident_*", "Node", true, false).is_empty(), "Static quest givers are still present")
	board.show_tab("guild")
	await _settle(window)
	check(not board.get_node("Layout/Scroll").get_v_scroll_bar().is_visible_in_tree(), "Empty board shows a scrollbar")
	check(board.empty_label.get_node("Content").size.x >= 400, "Empty-state text still wraps in a narrow column")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/validation/quest-board-empty-clean.png")
	var codec := SaveCodec.new()
	codec.grid = Manager.instance.transport.get_grid()
	var home := Manager.instance.active_settlement
	var home_hex := home.get_parent() as HexBase
	var legacy: Dictionary[String, Variant] = {"$node": codec.encode(home_hex.cube_id), "path": str(home_hex.get_path_to(home)) + "/Resident_water"}
	check(codec.decode(legacy) is QuestBoard, "Legacy request-author marker does not migrate to the board")
	check(SaveGames.load_development_checkpoint("blacksmith"), "Cannot load blacksmith fixture")
	await SaveGames.load_finished
	Manager.instance.regional.open_request("water")
	while info.get_live_instances().is_empty(): await get_tree().process_frame
	window = info.get_live_instances()[0].node as DraggableControl
	board = window.content as QuestListUI
	await _settle(window)
	# Missing sites are explicit exploration, never a misleading assignment.
	var hidden_water: Dictionary[HexBase, bool] = {}
	for site: QuestObjective in Manager.instance.regional.discoveries.sites:
		if DiscoveryRandomizer.get_kind(site) == "water_source":
			hidden_water[site.hex] = site.hex.is_explored
			site.hex.is_explored = false
	board.show_request("water")
	check(board.request_details.work.text == tr("QUEST_REQUEST_EXPLORE_WATER"), "Missing water still offers an assignment instead of exploration")
	Manager.instance.regional.open_project_work("water")
	var creation_info := DataManager.instance.get_scene_by_name("quest_creation_ui")
	while creation_info.get_live_instances().is_empty(): await get_tree().process_frame
	for frame in 4: await get_tree().process_frame
	var creation_window := creation_info.get_live_instances()[0].node as DraggableControl
	check((creation_window.content as QuestCreationUI).scout_only, "Explicit exploration did not open scouting")
	creation_window.hide()
	for hex: HexBase in hidden_water: hex.is_explored = hidden_water[hex]
	# Known unplanted fields should offer preparation instead of more scouting.
	for site: QuestObjective in Manager.instance.regional.discoveries.sites:
		if site is FarmTile and site.hex.is_explored: site.apply_site_state("FALLOW")
	var preparation := Manager.instance.regional.get_project_work_site("food")
	if preparation != null:
		board.show_request("food")
		check(board.request_details.work.text == tr("QUEST_REQUEST_PREPARE_SOURCE"), "Known fallow field falls back to exploration")
		Manager.instance.regional.open_project_work("food")
		for frame in 6: await get_tree().process_frame
		check(not (creation_window.content as QuestCreationUI).scout_only and (creation_window.content as QuestCreationUI)._get_selected_objective() == preparation, "Preparation did not open the known source")
		creation_window.hide()
	# UI fixture: three independently authored guild jobs, without assigning AI.
	# The regional integration test covers real assignment/travel/completion.
	var grid := Manager.instance.transport.get_grid()
	var origin := Manager.instance.active_settlement.get_parent() as HexBase
	for index in 3:
		var quest := Quest.new(origin,"scout")
		quest.context["scout_distance"] = index + 1
		Manager.instance.quests.active_quests.append(quest)
	Manager.instance.quests.quest_list_changed.emit()
	for viewport_size: Vector2i in [Vector2i(1280,720), Vector2i(960,540)]:
		get_window().size = viewport_size
		board.show_tab("guild")
		await _settle(window)
		check(board._get_quest_notes().size() == 3, "Player jobs missing")
		check(not board.request_list.visible and board.board_surface.visible and board.create_quest_button.is_visible_in_tree(), "Board authorship tabs mix their content")
		var bounds := board.board_surface.get_global_rect().grow(1)
		var occupied: Array[Rect2] = []
		for note: QuestListItemUI in board._get_quest_notes():
			var rect := note.paper.get_global_rect()
			check(bounds.encloses(rect), "Note %s overflows board %s" % [rect, bounds])
			for other: Rect2 in occupied: check(not rect.intersects(other), "Commission cards overlap")
			occupied.append(rect)
		board.show_tab("village")
		await _settle(window)
		check(board.request_list.get_child_count() == 3 and not board.board_surface.visible, "Village notices disappeared when player jobs were posted")
		var previous_bottom := -INF
		var author_x := (board.request_list.get_child(0) as VillageRequestNotice).author_label.global_position.x
		for notice: VillageRequestNotice in board.request_list.get_children():
			check(notice.state_label.get_tooltip() == notice.state_label.text, "Updated status and tooltip disagree")
			check(notice.size.y < 65 and notice.global_position.y >= previous_bottom, "Request rows are oversized or overlap")
			check(is_equal_approx(notice.author_label.global_position.x, author_x), "Requester columns are not aligned")
			previous_bottom = notice.get_global_rect().end.y
		check(absf(board.request_table_header.get_child(1).global_position.x - author_x) < 2, "Header does not align with table rows")
		check(not board.get_node("Layout/Heading").visible, "Redundant villagers heading is still shown")
		check(board.request_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_RESERVE, "Vertical scrollbar space is not reserved")
		await _capture("request-notes-%d" % viewport_size.y)
		var stack_height := board.request_scroll.size.y
		for index in 4: board._add_notice("overflow_probe", "Extra request", "Villager", "Open", "")
		for frame in 8: await get_tree().process_frame
		var vertical_bar := board.request_scroll.get_v_scroll_bar()
		check(vertical_bar.max_value > vertical_bar.page, "Extra requests cannot be reached by vertical scrolling")
		check(is_equal_approx(stack_height, board.request_scroll.size.y), "Overflow changed the request stack height")
		board.show_request("water")
		await _settle(window)
		check(board.request_details.contribution.get_child_count() == 2 and board.request_details.currency_costs.get_child_count() == 2, "Request supplies/coin/prestige icons are missing")
		check(board.request_details.reward_items.get_child_count() == 2 and board.request_details.benefits.get_child_count() == 2, "Item, reputation or permanent-effect rewards are missing")
		for slot: Node in board.request_details.contribution.get_children():
			if slot is ContentSlotUI: check(not slot.can_drag and slot.custom_minimum_size == Vector2(56,56), "Contribution is not using the mine UI's readonly item slots")
		await _capture("request-icons-%d" % viewport_size.y)
		var scroll_bounds := (board.get_node("Layout/Scroll") as ScrollContainer).get_global_rect().grow(1)
		check(scroll_bounds.encloses(board.request_details.benefits.get_global_rect()), "Permanent rewards are below the visible notice")
		check(scroll_bounds.encloses(board.request_details.currency_costs.get_global_rect()), "Currency costs are below the visible notice")
		var window_bounds := window.get_global_rect().grow(1)
		for button: Button in [board.request_details.work, board.request_details.complete, board.request_details.fund]:
			check(window_bounds.encloses(button.get_global_rect()), "Request action extends beyond window")
		check(get_viewport().get_visible_rect().grow(1).encloses(window.get_global_rect()), "Board extends beyond screen")
		for definition: CommunityProjectDefinition in Manager.instance.regional.catalog.projects:
			board.show_request(definition.id)
			await _settle(window)
			var details := board.request_details
			check(details.contribution.get_child_count() == definition.materials.size(), "Request materials are missing: " + definition.id)
			check(details.benefits.get_child_count() == definition.benefits.size(), "Permanent effects are missing: " + definition.id)
			for row: Container in [details.contribution, details.currency_costs, details.reward_items, details.benefits]:
				check(scroll_bounds.encloses(row.get_global_rect()), "Request icons clip the notice: " + definition.id)
			var bar := (board.get_node("Layout/Scroll") as ScrollContainer).get_v_scroll_bar()
			check(bar.max_value <= bar.page + 1, "Request still needs scrolling: " + definition.id)
			check(not board.get_node("Layout/Heading").visible and board.back_button.get_parent() == window.header_actions, "Request navigation still occupies a content row")
			await _capture("request-icons-%s-%d" % [definition.id,viewport_size.y])
	for quest: Quest in Manager.instance.quests.active_quests.duplicate(): Manager.instance.quests.remove_quest(quest)
	print("QUEST BOARD TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

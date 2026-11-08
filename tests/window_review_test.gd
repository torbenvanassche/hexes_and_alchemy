extends Node

var failures: Array[String] = []
var deadline := 0

func _ready() -> void:
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	get_window().size = Vector2i(1280, 720)
	deadline = Time.get_ticks_msec() + 60000
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline: get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func _open(name: String) -> DraggableControl:
	if name == "npc_details_ui":
		return SceneManager.add(load("res://resources/scene_info/ui/npc_details_ui.tres")).node as DraggableControl
	var info := DataManager.instance.get_scene_by_name(name)
	info.queue(func(_info: SceneInfo) -> void: pass)
	while not info.is_cached: await get_tree().process_frame
	return SceneManager.add(info).node as DraggableControl

func _settle(window: DraggableControl, screenshot: String) -> void:
	window.on_enter()
	for frame in 12: await get_tree().process_frame
	var bounds := get_viewport().get_visible_rect()
	check(window.position.x >= 0 and window.position.y >= 0 and window.get_global_rect().end.x <= bounds.end.x and window.get_global_rect().end.y <= bounds.end.y, "Window exceeds viewport: " + screenshot)
	check(is_equal_approx(window.top_bar.size.x + 2.0, window.size.x), "Header width mismatch")
	for handle in [window.resize_handle_x, window.resize_handle_y, window.resize_handle_xy]:
		check(handle.color.a == 0, "Visible resize block")
	_check_fixed_actions(window, window.get_global_rect().grow(1), screenshot)
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + screenshot + ".png")

func _check_fixed_actions(root: Control, bounds: Rect2, screen: String) -> void:
	for button: Button in root.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree(): continue
		var ancestor := button.get_parent()
		var scrollable := false
		while ancestor != null and ancestor != root:
			if ancestor is ScrollContainer: scrollable = true; break
			ancestor = ancestor.get_parent()
		if not scrollable: check(bounds.encloses(button.get_global_rect()), "Fixed action outside frame: %s/%s" % [screen,button.name])

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	var tavern := Manager.instance.active_settlement.get_service(&"Tavern") as Tavern
	var window := await _open("tavern_recruitment_ui")
	var recruitment := window.content as TavernRecruitmentUI
	recruitment.setup_interaction(tavern)
	await _settle(window, "tavern-revised")
	check(recruitment.candidate_rows.get_child_count() == tavern.get_candidates().size(), "Missing visiting recruits")
	for row: RecruitCandidateRowUI in recruitment.candidate_rows.get_children():
		check(row.hire_button.size.y <= 40 and row.hire_button.get_theme_font_size("font_size") == 16, "Hire button too large")
		check(row.get_global_rect().end.x <= recruitment.candidate_list.get_global_rect().end.x, "Recruit row overflows")
		check(row.get_global_rect().end.y <= recruitment.candidate_list.get_global_rect().end.y, "Recruit clipped")
	# Fill the actual pool to capacity and check every full row and action is visible.
	while tavern.candidates.size() < 5: tavern._add_candidate()
	tavern.recruitment_changed.emit()
	await _settle(window, "tavern-five-recruits")
	check(recruitment.candidate_rows.get_child_count() == 5, "Five recruits not displayed")
	check(recruitment.find_children("*", "ScrollContainer", true, false).is_empty(), "Tavern still contains scrolling")
	for row: RecruitCandidateRowUI in recruitment.candidate_rows.get_children():
		check(row.get_global_rect().end.y <= recruitment.refresh_button.get_global_rect().position.y, "Recruit overlaps footer")
		check(row.hire_button.get_global_rect().end.y <= window.get_global_rect().end.y, "Hire action off-screen")
	Manager.instance.hub.currency = 250
	var previous := tavern.get_candidates().size()
	for row: RecruitCandidateRowUI in recruitment.candidate_rows.get_children():
		if not row.hire_button.disabled:
			row.hire_button.pressed.emit()
			check(tavern.get_candidates().size() == previous - 1, "Hire action did not work")
			break
	window.hide()
	window = await _open("npc_details_ui")
	var details := window.content as NpcDetailsUI
	var home := Manager.instance.active_settlement.get_service(&"FactionHome") as FactionHome
	var npc := home.get_roster_npcs()[0].node as NPC
	details.setup_npc(npc)
	await _settle(window, "character-revised")
	check(not details.name_label.text.is_empty(), "Character identity missing")
	check(details.equipment_slot_uis.size() == 4, "Equipment slots missing")
	for item: ItemInfo in DataManager.instance.items:
		if item is EquipmentInfo and item.slot == EquipmentInfo.Slot.ARMOR:
			details.equipment_slots[&"armor"].add(1, item)
			check(npc.equipment.armor == item, "Equipment edit did not reach character")
			break
	var previous_slot := details.equipment_slots[&"weapon"] as ContentSlotResource
	npc.active_injuries.append(load("res://resources/injuries/sprain.tres"))
	npc.rest_duration_seconds = 60
	npc.rest_remaining_seconds = 45
	npc.recovering_from_injury = true
	npc.set_state(NPC.NPCState.RESTING)
	npc.injuries_changed.emit(npc)
	previous_slot = details.equipment_slots[&"weapon"]
	npc.rest_remaining_seconds = 35
	npc.rest_progress_changed.emit(npc)
	check(details.equipment_slots[&"weapon"] == previous_slot, "Recovery updates replaced equipment slots")
	check(details.status_label.text.contains("35") and details.get_node("%RecoveryBar").visible, "Recovery did not update live")
	await _settle(window, "character-injured")
	check(not details.equipment_slot_uis[&"weapon"].can_drag, "Assigned character can change equipment")
	window.hide()
	# Audit every service/window family at both reference resolutions.
	var audit_alchemist := Alchemist.new()
	audit_alchemist.settlement = Manager.instance.active_settlement
	Manager.instance.active_settlement.add_child(audit_alchemist)
	for viewport_size: Vector2i in [Vector2i(1280,720), Vector2i(960,540)]:
		get_window().size = viewport_size
		for screen: String in ["hub_window", "quest_list_ui", "quest_creation_ui", "crafting_ui", "market_ui", "inventory_ui", "alchemist_ui", "settlement_upgrade_ui", "transport_ui", "journal_ui", "settings_menu", "game_settings", "input_settings", "pause_menu"]:
			var info := load("res://resources/scene_info/ui/%s.tres" % screen) as SceneInfo
			info.queue(func(_info: SceneInfo) -> void: pass)
			while not info.is_cached: await get_tree().process_frame
			var opened := SceneManager.add(info, false)
			window = opened.node as DraggableControl
			if window == null:
				# Pause/settings are deliberately full-screen overlays.
				var overlay := opened.node as Control
				check(overlay != null, "UI is not a Control: " + screen)
				if overlay == null: continue
				opened.on_enter.emit()
				for frame in 12: await get_tree().process_frame
				check(get_viewport().get_visible_rect().grow(1).encloses(overlay.get_global_rect()), "Overlay exceeds viewport: " + screen)
				_check_fixed_actions(overlay, get_viewport().get_visible_rect().grow(1), screen)
				if OS.get_cmdline_user_args().has("--capture"):
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("res://.godot/validation/audit-%s-%d.png" % [screen, viewport_size.y])
				overlay.hide()
				continue
			if window.content is CraftingUI: window.content.inventory = Manager.instance.hub.stockpile
			if window.content is InventoryUI: window.content.inventory = Manager.instance.hub.stockpile
			if window.content is MarketUI:
				var market := Manager.instance.active_settlement.get_service(&"Market") as Market
				window.content.setup(market.buy_inventory, market.sell_inventory, Manager.instance.hub.stockpile)
			if window.content is AlchemistUI: window.content.setup_interaction(audit_alchemist)
			if window.content is SettlementUpgradeUI:
				window.content.settlement = Manager.instance.active_settlement
				window.content.player_inventory = Manager.instance.hub.stockpile
			await _settle(window, "audit-%s-%d" % [screen, viewport_size.y])
			window.hide()
	print("WINDOW REVIEW %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

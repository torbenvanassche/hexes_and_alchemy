extends Node

const WOOD := preload("res://resources/item_info/wood_raw.tres")
const IRON := preload("res://resources/item_info/iron_ore.tres")
const WATER := preload("res://resources/item_info/water_bucket.tres")
const GRAIN := preload("res://resources/item_info/grain.tres")
var failures: Array[String] = []
var deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	deadline = Time.get_ticks_msec() + 180000
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("REGIONAL TEST timeout")
		get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _fixture(id: String) -> void:
	check(SaveGames.load_development_checkpoint(id), "Cannot load " + id)
	var result: Array = await SaveGames.load_finished
	check(result[0], "Fixture restore failed")
	for frame in 6: await get_tree().process_frame

func _reload(label: String) -> void:
	check(SaveGames.save_slot(label), "Cannot save: " + SaveGames.last_error)
	check(SaveGames.load_slot(SaveGames.slot_id(label)), "Cannot load save")
	var result: Array = await SaveGames.load_finished
	check(result[0], "Regional restore failed")
	for frame in 6: await get_tree().process_frame

func _site(kind: String) -> QuestObjective:
	for site: QuestObjective in Manager.instance.regional.discoveries.sites:
		if is_instance_valid(site) and DiscoveryRandomizer.get_kind(site) == kind:
			site.hex.is_explored = true
			return site
	return null

func _stock() -> void:
	for item: ItemInfo in DataManager.instance.items:
		if not item is EquipmentInfo: Manager.instance.hub.stockpile.add(item, 30, true)
	Manager.instance.hub.add_currency(1000)
	Manager.instance.hub.add_prestige(20)

## Run actual objective timers/outcomes and the shared operation/payout path.
## Travel is tested separately through a real posted commission below.
func _complete_work(site: QuestObjective, key: String) -> Quest:
	check(site != null, "Missing commission site: " + key)
	if site == null: return null
	site.discovery_resolved = true
	check(site.get_filtered_quest_types().has(key), "Unavailable approach: " + key)
	var quest := Quest.new(site.hex, key)
	check(site.assign_required_supplies(quest, Manager.instance.hub.stockpile), "Cannot reserve supplies: " + key)
	Manager.instance.operations.register_quest(quest)
	quest.set_state(Quest.QuestState.IN_PROGRESS)
	Engine.time_scale = 20
	await site.execute_quest(quest)
	Engine.time_scale = 1
	quest.set_state(Quest.QuestState.COMPLETE)
	check(quest.context.get("reward_claimed", false), "Shared payout not claimed: " + key)
	return quest

func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + name + ".png")

func _ui() -> void:
	Manager.instance.toast.hide()
	var prefix := "community-complete" if Manager.instance.regional.project_complete("water") else "community"
	Manager.instance.player_instance.global_position = Manager.instance.active_settlement.spawn_position.global_position
	Manager.instance.spring_arm_camera.snap_to_target()
	for frame in 8: await get_tree().process_frame
	await _capture("community-village")
	Manager.instance.player_instance.toggle_hub_tab("projects")
	var info := DataManager.instance.get_scene_by_name("hub_window")
	while info.get_live_instances().is_empty(): await get_tree().process_frame
	var window := info.get_live_instances()[0].node as DraggableControl
	check(not window.content.has_node("Spread/PageHost/ProjectsPage/Body/Scroll/Content/CommunityProjects"), "Project controls remain duplicated in the journal")
	window.hide()
	SceneManager.remove_scene(info)
	Manager.instance.regional.open_request("water")
	info = DataManager.instance.get_scene_by_name("quest_list_ui")
	while info.get_live_instances().is_empty(): await get_tree().process_frame
	window = info.get_live_instances()[0].node as DraggableControl
	var board := window.content as QuestListUI
	var community := board.request_details
	for viewport_size: Vector2i in [Vector2i(1280,720), Vector2i(960,540)]:
		get_window().size = viewport_size
		window.on_enter()
		for frame in 12: await get_tree().process_frame
		check(get_viewport().get_visible_rect().grow(2).encloses(window.get_global_rect()), "Quest board clips screen")
		var scroll := board.get_node("Layout/Scroll") as ScrollContainer
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1, "Projects overflow horizontally")
		for button: Button in [community.work, community.complete, community.fund]:
			check(button.size.y < 50, "Project buttons are oversized")
		check(community.resident_label.text.contains("Mara") and board.selected_request == "water", "Request author or selection missing")
		await _capture(prefix + "-request-%d" % viewport_size.y)
		board.show_tab("village")
		for frame in 6: await get_tree().process_frame
		check(not board.create_quest_button.is_visible_in_tree() and not board.board_surface.visible, "Guild posting controls leak into village requests")
		check(not board.get_node("Layout/Heading").visible, "Redundant villagers heading remains visible")
		if not Manager.instance.regional.project_complete("water"):
			check(board.request_list.get_child_count() == 3, "Villagers did not post three requests")
			var notice := board.request_list.get_child(0) as VillageRequestNotice
			notice.view_button.pressed.emit()
			check(board.selected_request == notice.request_id, "Notice did not open the matching request")
			board.show_board()
		else:
			check(board.completed_button.visible, "Completed request history is missing")
			var open_count := board.request_list.get_child_count()
			board.completed_button.button_pressed = true
			check(board.request_list.get_child_count() == open_count + 3, "Completed requests were lost or mixed into the open list")
			board.completed_button.button_pressed = false
		await _capture(prefix + "-request-board-%d" % viewport_size.y)
		board.show_tab("guild")
		for frame in 6: await get_tree().process_frame
		check(board.create_quest_button.is_visible_in_tree() and not board.request_list.visible and not board.request_details.visible, "Villager requests leak into guild commissions")
		check(board.get_node("Layout/Heading/Context").text == tr("QUEST_BOARD_GUILD_HINT"), "Guild notices lack an authorship heading")
		await _capture("guild-commission-board-%d" % viewport_size.y)
		board.show_request("water")
	if Manager.instance.regional.active_incident != null:
		board.show_request(CommunityProjectsUI.INCIDENT_REQUEST)
		for frame in 6: await get_tree().process_frame
		check(community.resident_label.text.contains(Manager.instance.regional.get_incident_requester().resident_name), "Local request lacks its villager author")
		check(community.work.visible and community.fund.visible and not community.complete.visible, "Local repair request shows project hand-in controls")
		await _capture("village-local-request")
		board.show_request("water")
	window.hide()
	get_window().size = Vector2i(1280,720)
	check(Manager.instance.active_settlement.find_children("Resident_*", "Node", true, false).is_empty(), "Stationary request NPCs still spawn in town")
	if not Manager.instance.regional.project_complete("water"):
		Manager.instance.regional.open_project_work("water")
		var quest_info := DataManager.instance.get_scene_by_name("quest_creation_ui")
		while quest_info.get_live_instances().is_empty(): await get_tree().process_frame
		for frame in 8: await get_tree().process_frame
		var quest_window := quest_info.get_live_instances()[0].node as DraggableControl
		var creation := quest_window.content as QuestCreationUI
		check(creation._get_selected_objective() is WaterSource and creation._get_selected_profile() != null, "Arrange work did not open a water commission")
		await _capture("community-commission-choice")
		quest_window.hide()
	Manager.instance.toast.show()

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	await _fixture("arrival")
	check(not Manager.instance.regional.is_unlocked(), "Projects skip the opening forge")
	check(not Manager.instance.regional.complete_project("water", true), "Project can be funded before forge")
	var randomizer := Manager.instance.regional.discoveries
	var seen: Dictionary[String, bool] = {}
	for seed_value in 128:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var rolled := randomizer.roll_definition("forest", rng)
		seen[rolled.initial_state] = true
		var repeat := RandomNumberGenerator.new()
		repeat.seed = seed_value
		check(randomizer.roll_definition("forest", repeat).id == rolled.id, "Discovery roll is not deterministic")
		check(randomizer.roll_definition("mines", repeat, true).initial_state in ["POOR_VEIN", "RICH_VEIN"], "Opening mine can roll blocked")
	check(seen.has("HEALTHY") and seen.has("DEPLETED"), "Discoveries are always broken or always intact")
	for site: QuestObjective in randomizer.sites:
		if site.hex.is_explored: check(site.discovery_resolved, "Old checkpoint site was rerolled")
	await _fixture("blacksmith")
	_stock()
	var regional := Manager.instance.regional
	regional.set_process(false)
	check(regional.is_unlocked() and regional.projects.size() == 3, "Community projects missing")
	var water := _site("water_source") as WaterSource
	var mine := _site("mines") as Mineshaft
	var forest := _site("forest")
	var farm := _site("farmland") as FarmTile
	var ruin := _site("ancient_ruins") as AncientRuins
	check(water != null and mine != null and forest != null and farm != null and ruin != null, "Missing regional test sites")
	if water == null or mine == null or forest == null or farm == null or ruin == null:
		get_tree().quit(1)
		return
	await _ui()
	for site: QuestObjective in [water, mine, forest, farm, ruin]:
		site.discovery_resolved = true
		var spot := site.get_spot_progress()
		if spot != null: spot.resolve_no_occupation(true)
	var initial_coins := Manager.instance.hub.currency
	check(not regional.complete_project("water") and Manager.instance.hub.currency == initial_coins, "Project accepts missing fieldwork")
	water.apply_site_state("FRESH")
	await _complete_work(water, "protect_spring")
	check(water.protected_uses == 3 and not water.get_filtered_quest_types().has("protect_spring"), "Spring protection is not persistent")
	check(regional.projects["water"].fieldwork_done, "Commission did not count toward its project")
	var board_info := DataManager.instance.get_scene_by_name("quest_list_ui")
	var request_board := (board_info.get_live_instances()[0].node as DraggableControl).content as QuestListUI
	request_board.show_request("water")
	request_board.request_details.refresh()
	check(not request_board.request_details.complete.disabled, "Ready request cannot be completed on the board")
	request_board.request_details.complete.pressed.emit()
	check(regional.projects["water"].blueprint_issued and not regional.project_complete("water"), "Water request must issue a blueprint before completion")
	await _build_well()
	check(regional.project_complete("water"), "Well construction did not finish request")
	var after_project := Manager.instance.hub.currency
	check(not regional.complete_project("water") and Manager.instance.hub.currency == after_project, "Project paid twice")
	var before_water := Manager.instance.hub.stockpile.get_count(WATER)
	var expected := water.get_quest_profile_reward_preview("draw_careful")
	check(expected[0].minimum == 4 and expected[0].maximum == 5, "Permanent water bonus missing from preview")
	check(is_equal_approx(water.get_effective_quest_duration(Quest.new(water.hex,"draw_careful"),10),water.get_quest_duration("draw_careful",10)*0.8), "Water project does not shorten work")
	await _complete_work(water, "draw_careful")
	check(Manager.instance.hub.stockpile.get_count(WATER) - before_water >= 4 and water.protected_uses == 2, "Water benefit/protection not applied")
	var draw_profile := water.get_profile("draw_extra")
	var original_outcomes := draw_profile.outcomes.duplicate()
	draw_profile.outcomes = [preload("res://resources/quest_outcomes/quest_outcome_water_draw_tainted.tres")]
	await _complete_work(water,"draw_extra")
	check(water.state_machine.get_current_state() == "FRESH" and water.protected_uses == 1, "Protection did not prevent tainting on a heavy draw")
	draw_profile.outcomes = original_outcomes
	mine.apply_site_state("POOR_VEIN")
	await _complete_work(mine,"brace")
	check(mine.reinforced_uses == 3 and not mine.get_filtered_quest_types().has("brace"), "Mine supports do not last")
	await _complete_work(mine,"extract")
	check(mine.reinforced_uses == 2, "Extraction did not consume a support use")
	mine.apply_site_state("UNSTABLE")
	await _complete_work(mine,"quick_reopen")
	check(mine.temporary_supports and mine.state_machine.get_current_state() in ["POOR_VEIN","RICH_VEIN"], "Quick reopening did not restore mine")
	var before_workshop := Manager.instance.hub.currency
	var before_materials := Manager.instance.hub.stockpile.get_count(IRON)
	request_board.show_request("workshop")
	check(not request_board.request_details.fund.visible, "Permanent project still offers instant funding")
	check(not regional.complete_project("workshop", true), "Permanent funding bypass remains")
	request_board.request_details.complete.pressed.emit()
	check(regional.project_complete("workshop"), "Workshop cannot complete with fieldwork and supplies")
	check(Manager.instance.hub.currency == before_workshop - regional.get_definition("workshop").coin_cost and Manager.instance.hub.stockpile.get_count(IRON) == before_materials - 2, "Workshop charged incorrect materials or coins")
	check(Manager.instance.crafting.duration_for(preload("res://resources/item_info/work_supplies.tres")) < 1, "Workshop crafting benefit missing")
	forest.apply_site_state("HEALTHY")
	await _complete_work(forest,"selective_cut")
	check(forest.state_machine.get_current_state() == "HEALTHY", "Selective cutting depleted grove")
	forest.apply_site_state("DEPLETED")
	await _complete_work(forest,"recover_timber")
	check(forest.salvaged_remnants and not forest.get_filtered_quest_types().has("recover_timber"), "Offcuts can be farmed infinitely")
	forest.apply_site_state("HEALTHY")
	check(not forest.salvaged_remnants, "Regrowth did not replenish offcuts")
	farm.apply_site_state("WATERED")
	var before_grain := Manager.instance.hub.stockpile.get_count(GRAIN)
	await _complete_work(farm,"careful_harvest")
	check(Manager.instance.hub.stockpile.get_count(GRAIN) - before_grain >= 5 and farm.state_machine.get_current_state() == "FALLOW", "Careful harvest tradeoff did not apply")
	check(regional.complete_project("food"), "Food project cannot complete")
	var recipe := preload("res://resources/item_info/surveyors_kit.tres")
	check(not regional.recipe_available(recipe), "Surveyor recipe unlocks before expedition")
	check(not Manager.instance.crafting.start(recipe, Manager.instance.hub.stockpile), "Locked recipe can be crafted through the manager")
	check(not regional.chapter_complete, "Chapter completed without a trade partnership")
	ruin.apply_site_state("SECURED")
	var before_catalogue := Manager.instance.hub.currency
	var catalogue_quest := await _complete_work(ruin,"catalogue")
	for frame in 4: await get_tree().process_frame
	check(ruin.archive_recorded and not ruin.get_filtered_quest_types().has("catalogue") and ruin.state_machine.get_current_state() == "SECURED", "Catalogue did not preserve site or repeats its reward")
	check(regional.recipe_available(recipe) and not regional.chapter_complete, "Optional expedition changed mandatory chapter requirements")
	check(Manager.instance.hub.currency == before_catalogue + 12, "Catalogue service fee incorrect")
	var counted := regional.completed_commissions
	catalogue_quest.parse_reward()
	Manager.instance.operations.on_quest_completed(catalogue_quest)
	check(regional.completed_commissions == counted and Manager.instance.hub.currency == before_catalogue + 12, "Operation rewards/progression recorded twice")
	check(Manager.instance.crafting.start(recipe, Manager.instance.hub.stockpile), "Unlocked recipe cannot craft")
	while Manager.instance.crafting.active_job != null: await get_tree().process_frame
	check(Manager.instance.hub.stockpile.get_count(recipe) == 1, "Unlocked equipment output missing")
	# Real posting path: reject missing supplies atomically, then let a resident
	# guild member travel, work and return through the normal quest system.
	water.apply_site_state("FRESH")
	var work_item := preload("res://resources/item_info/work_supplies.tres")
	var work_count := Manager.instance.hub.stockpile.get_count(work_item)
	Manager.instance.hub.stockpile.remove(work_item, work_count)
	var service := QuestPostingService.new(Manager.instance.quests, Manager.instance.hub, Manager.instance.player_instance)
	var coins := Manager.instance.hub.currency
	var rejected := service.post_quest(water.hex,"draw_careful",2,-1,-1,[],Manager.instance.hub.stockpile)
	check(not rejected.success and Manager.instance.hub.currency == coins, "Missing supplies consumed payment")
	Manager.instance.hub.stockpile.add(work_item,work_count,true)
	counted = regional.completed_commissions
	var posted := service.post_quest(water.hex,"draw_careful",30,-1,-1,[],Manager.instance.hub.stockpile)
	check(posted.success, "Real commission cannot post")
	if posted.success:
		request_board.show_tab("guild")
		var board_window := board_info.get_live_instances()[0].node as DraggableControl
		board_window.on_enter()
		for frame in 16: await get_tree().process_frame
		check(request_board._get_quest_notes().any(func(note: QuestListItemUI) -> bool: return note.questData == posted.quest), "Player commission did not appear on its board tab")
		check(not request_board.request_list.visible and request_board.board_surface.visible, "Villager notices mix with player commission notes")
		for note: QuestListItemUI in request_board._get_quest_notes():
			check(request_board.board_surface.get_global_rect().grow(1).encloses(note.paper.get_global_rect()), "Commission note %s overflows board %s" % [note.paper.get_global_rect(), request_board.board_surface.get_global_rect()])
		if OS.get_cmdline_user_args().has("--capture"):
			for frame in 6: await get_tree().process_frame
			await _capture("guild-commission-active")
		board_window.hide()
		Engine.time_scale = 4
		var wait_until := Time.get_ticks_msec() + 30000
		while not posted.quest.is_state(Quest.QuestState.COMPLETE) and not posted.quest.is_state(Quest.QuestState.FAILED) and Time.get_ticks_msec() < wait_until:
			await get_tree().process_frame
		Engine.time_scale = 1
		if not posted.quest.is_state(Quest.QuestState.COMPLETE):
			for npc: NPC in posted.quest.party: print("NPC route ", npc.global_position, " index ", npc.current_target_index, " path ", npc.current_path.map(func(tile: HexBase) -> Vector3: return tile.global_position))
		check(posted.quest.is_state(Quest.QuestState.COMPLETE) and regional.completed_commissions == counted + 1, "Guild member did not complete the new approach: " + posted.quest.state_machine.get_current_state() + " " + str(posted.quest.context))
		if not posted.quest.is_state(Quest.QuestState.COMPLETE):
			Manager.instance.quests.cancel_quest(posted.quest)
	# Incident affects one idle source, has no deadline, and survives a save.
	water.protected_uses = 0
	mine.reinforced_uses = 0
	mine.apply_site_state("POOR_VEIN")
	water.apply_site_state("FRESH")
	check(regional.try_start_incident(), "Eligible local incident did not start")
	check(not regional.try_start_incident(), "Two incidents started together")
	await _ui()
	Manager.instance.campaign.destination = Manager.instance.campaign.get_destination("board")
	Manager.instance.campaign.destination_name = tr("WINDOW_QUEST_BOARD")
	var incident_id := regional.active_incident.definition.id
	var incident_coord := regional.active_incident.site
	var incident_previous := regional.active_incident.previous_state
	var saved_coins := Manager.instance.hub.currency
	var saved_remaining := regional.incident_remaining
	var hidden_coord := Vector3i.MAX
	for site: QuestObjective in regional.discoveries.sites:
		if is_instance_valid(site) and not site.hex.is_explored and DiscoveryRandomizer.get_kind(site) in ["forest","mines","water_source","farmland","ancient_ruins"]:
			site.discovery_id = ""
			site.discovery_resolved = false
			hidden_coord = site.hex.cube_id
			break
	var water_coord := water.hex.cube_id
	var ruin_coord := ruin.hex.cube_id
	await _reload("Community chapter and local request")
	regional = Manager.instance.regional
	var grid := Manager.instance.transport.get_grid()
	check(regional.completed_project_count() == 3 and not regional.chapter_complete and regional.recipe_available(recipe), "Project/chapter/recipe progress lost on load")
	check(regional.active_incident != null and regional.active_incident.site == incident_coord and regional.active_incident.definition.id == incident_id, "Incident changed on load")
	check(Manager.instance.hub.currency == saved_coins and absf(regional.incident_remaining - saved_remaining) < 1, "Load replayed rewards or restarted cooldown")
	check(Manager.instance.campaign.destination is QuestBoard, "Tracked quest board did not restore")
	check(regional._presentation.props.size() == 2 and regional.get_project_buildable("water") != null and Manager.instance.active_settlement.find_children("Resident_*", "Node", true, false).is_empty(), "Loading lost completed improvements or restored removed NPCs")
	ruin = grid.get_hex_at_cube_id(ruin_coord).structure.instance as AncientRuins
	check(ruin.archive_recorded and not ruin.get_filtered_quest_types().has("catalogue"), "Load reopened catalogue reward")
	check(regional.fund_incident(), "Local help cannot resolve incident")
	check(regional.active_incident == null and regional.resolved_incidents.has(incident_id) and Manager.instance.hub.currency == saved_coins - 35, "Local help charged or rewarded incorrectly")
	var repaired := grid.get_hex_at_cube_id(incident_coord).structure.instance as QuestObjective
	check(repaired.state_machine.get_current_state() == incident_previous, "Local help did not restore previous site state")
	check(not regional.fund_incident(), "Incident charged twice")
	check(regional.try_start_incident(), "Second distinct local request unavailable")
	incident_coord = regional.active_incident.site
	var incident := regional.active_incident.definition
	var target := grid.get_hex_at_cube_id(incident_coord).structure.instance as QuestObjective
	var before_fee := Manager.instance.hub.currency
	var key := incident.repair_types[0]
	await _complete_work(target,key)
	check(regional.active_incident == null and Manager.instance.hub.currency == before_fee + incident.coin_reward + target.get_profile(key).guild_currency_reward, "Commission did not resolve/pay local request")
	check(not regional.try_start_incident(), "Resolved local incidents repeated during the chapter")
	if hidden_coord != Vector3i.MAX:
		var hidden := grid.get_hex_at_cube_id(hidden_coord).structure.instance as QuestObjective
		check(not hidden.discovery_resolved, "Unexplored saved site was marked resolved")
		hidden.hex.is_explored = true
		regional.queue_refresh()
		for frame in 4: await get_tree().process_frame
		check(hidden.discovery_resolved and not hidden.discovery_id.is_empty(), "Newly explored saved site did not get a discovery")
	else: check(false,"No hidden site available for discovery save regression")
	await _reload("Completed community chapter")
	check(Manager.instance.regional.active_incident == null and Manager.instance.regional.resolved_incidents.size() == 2, "Resolved requests did not persist")
	await _fixture("arrival")
	check(Manager.instance.regional.completed_project_count() == 0 and not Manager.instance.regional.chapter_complete and Manager.instance.regional.unlocked_recipes.is_empty(), "Chapter progress leaked into a fresh checkpoint")
	print("REGIONAL PROGRESSION TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func _build_well() -> void:
	var regional := Manager.instance.regional
	var definition := regional.get_definition("water")
	var grid := Manager.instance.transport.get_grid()
	for hex: HexBase in Manager.instance.active_settlement.get_settlement_hexes(grid):
		if definition.construction.can_place_on(hex, Manager.instance.hub.stockpile):
			check(definition.construction.place_on(hex, Manager.instance.hub.stockpile), "Well placement failed")
			break
	for frame in 4: await get_tree().process_frame
	var building := regional.get_project_buildable("water")
	check(building != null, "Well foundation missing")
	if building == null: return
	var foundation := building.current_step as BuildRequest
	foundation.quest.initialize()
	for item: ItemInfo in foundation.quest.requested_items:
		var amount := foundation.quest.requested_items[item]
		Manager.instance.hub.stockpile.remove(item, amount)
		foundation.quest.progress_tracker.add(item, amount)
	foundation.completed.emit()

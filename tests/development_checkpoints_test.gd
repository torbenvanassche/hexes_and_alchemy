extends Node
var failures: Array[String] = []
var deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	deadline = Time.get_ticks_msec() + 120000
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("Development checkpoint verification timed out")
		get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	var definitions := SaveGames.list_development_checkpoints()
	check(definitions.size() == 13, "Missing development checkpoints")
	for definition: Dictionary in definitions:
		var id: String = definition.id
		var source := SaveGames._read_document(SaveGames.DEVELOPMENT_DIRECTORY.path_join(id + ".json"))
		check(not source.is_empty(), "Invalid/checksum-corrupt checkpoint: " + id)
		check(source.world.settings.generation_version == 2, "Checkpoint uses outdated generation: " + id)
		check(SaveGames.load_development_checkpoint(id), "Cannot start loading " + id)
		var loaded: Array = await SaveGames.load_finished
		check(loaded[0], "Checkpoint failed to restore: " + id)
		var manager := Manager.instance
		var campaign := manager.campaign
		var count := manager.regional.completed_project_count()
		var expected := SettlementCampaign.Stage.IMPROVE_VILLAGE
		match id:
			"arrival": expected = SettlementCampaign.Stage.BLUEPRINT
			"foundation": expected = SettlementCampaign.Stage.MATERIALS
			"village_improved": expected = SettlementCampaign.Stage.MEET_VILLAGE
			"trade_ready": expected = SettlementCampaign.Stage.FIRST_SHIPMENT
			"first_shipment": expected = SettlementCampaign.Stage.CRAFT_SHIPMENT
			"chapter_complete": expected = SettlementCampaign.Stage.COMPLETE
		check(campaign.stage == expected, "Wrong chapter stage: " + id)
		var expected_projects := 1 if id == "first_improvement" else (2 if id in ["village_improved", "trade_ready", "first_shipment", "chapter_complete"] else 0)
		if id in ["first_improvement", "village_improved", "trade_ready", "first_shipment", "chapter_complete"]:
			check(manager.regional.get_project_buildable("water") != null, "Completed water request has no placed well: " + id)
		if id in ["well_blueprint", "well_foundation"]:
			check(manager.regional.projects["water"].blueprint_issued, "Well checkpoint has no issued blueprint")
			check((manager.regional.get_project_buildable("water") != null) == (id == "well_foundation"), "Wrong well construction stage")
		check(count == expected_projects, "Wrong completed-request count: " + id)
		check(manager.transport.active_shipment.is_empty() and manager.crafting.active_job == null, "Fixture captured unfinished delivery/crafting: " + id)
		if id == "active_commission":
			check(manager.quests.get_commissions().size() == 1 and not manager.operations.auto_resolve_completed_quests, "Active-commission checkpoint lost its job/settings")
			check(manager.quests.get_commissions()[0].party.size() == 1, "Active-commission checkpoint lost the worker")
		else: check(manager.quests.get_commissions().is_empty(), "Unexpected active work: " + id)
		if id in ["trade_partner", "chapter_complete"]:
			check(manager.transport.is_partner(campaign.get_trade_coord()), "Partnership missing: " + id)
		if id == "chapter_complete":
			var gold := manager.hub.currency
			check(campaign._chapter_completion_announced and manager.regional.chapter_complete, "Chapter grant/conclusion was not recorded")
			campaign.refresh()
			check(manager.hub.currency == gold, "Loading checkpoint repeats chapter grant")
		print("DEVELOPMENT CHECKPOINT VERIFIED: ", id)
	while WorldLoading.blocks_input: await get_tree().process_frame
	var menu_info := DataManager.instance.get_scene_by_name("pause_menu")
	menu_info.queue(func(_info: SceneInfo) -> void: pass)
	while not menu_info.is_cached: await get_tree().process_frame
	var menu := SceneManager.add(menu_info, true).node as PauseMenu
	get_tree().paused = true
	menu.show_checkpoints()
	for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = viewport
		for index in definitions.size():
			menu.get_node("%DevelopmentCheckpoints").select(index)
			menu._select_development_checkpoint(index)
			for frame in 3: await get_tree().process_frame
			check(get_viewport().get_visible_rect().encloses(menu.get_node("CenterContainer/MenuPanel").get_global_rect()), "Checkpoint submenu overflows " + str(viewport))
		check(menu.get_node("%DevelopmentCheckpoints").item_count == definitions.size(), "Checkpoint dropdown omits stages")
		if OS.get_cmdline_user_args().has("--capture"):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.godot/validation/development-checkpoints-%d.png" % viewport.y)
	print("DEVELOPMENT CHECKPOINT TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

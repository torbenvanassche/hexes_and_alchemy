extends Node
var failures: Array[String] = []
var deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	deadline = Time.get_ticks_msec() + 60000
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline: get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	var info := DataManager.instance.get_scene_by_name("hub_window")
	info.queue(func(_loaded: SceneInfo) -> void: pass)
	while not info.is_cached: await get_tree().process_frame
	var window := SceneManager.add(info, false).node as DraggableControl
	window.content.show_tab("projects")
	window.on_enter()
	for frame in 15: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + name + ".png")
	window.hide()

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	check(SaveGames.load_development_checkpoint("foundation"), "Cannot load forge foundation")
	var foundation_loaded: Array = await SaveGames.load_finished
	check(foundation_loaded[0], "Foundation restore failed")
	var foundation := Manager.instance.campaign.get_foundation()
	var forge_gold := Manager.instance.hub.currency
	for item: ItemInfo in foundation.quest.requested_items:
		foundation.quest.progress_tracker.add(item, foundation.quest.requested_items[item] - foundation.quest.progress_tracker.get_count(item), true)
	foundation.completed.emit()
	Manager.instance.campaign.refresh()
	check(Manager.instance.campaign.stage == SettlementCampaign.Stage.IMPROVE_VILLAGE, "Forge does not lead to village improvements")
	check(Manager.instance.hub.currency == forge_gold + Manager.instance.campaign.chapter.forge_grant, "Forge completion grant is missing")
	Manager.instance.campaign.refresh()
	check(Manager.instance.hub.currency == forge_gold + Manager.instance.campaign.chapter.forge_grant, "Forge grant repeated")
	check(SaveGames.load_development_checkpoint("trade_partner"), "Cannot load established partner")
	var loaded: Array = await SaveGames.load_finished
	check(loaded[0], "Partner restore failed")
	while WorldLoading.blocks_input: await get_tree().process_frame
	var campaign := Manager.instance.campaign
	var regional := Manager.instance.regional
	check(campaign.stage == SettlementCampaign.Stage.IMPROVE_VILLAGE, "Trade alone completes opening chapter")
	check(campaign.get_primary_action() == "requests", "Chapter sends player away from villager requests")
	Manager.instance.hub.deposit_items({preload("res://resources/item_info/wood_log.tres"): 10, preload("res://resources/item_info/iron_ore.tres"): 10, preload("res://resources/item_info/work_supplies.tres"): 10, preload("res://resources/item_info/bucket.tres"): 2})
	var before := Manager.instance.hub.currency
	campaign.refresh()
	check(Manager.instance.hub.currency == before, "Legacy forge grant was paid again")
	Manager.instance.hub.add_prestige(2)
	get_window().size = Vector2i(1280, 720)
	await _capture("opening-chapter-improvements")
	check(await ChapterCheckpointBuilder.complete_project("water"), "First village improvement failed")
	campaign.refresh()
	check(campaign.stage == SettlementCampaign.Stage.IMPROVE_VILLAGE, "One improvement completes chapter")
	var second_cost := regional.get_definition("food").coin_cost
	check(await ChapterCheckpointBuilder.complete_project("food"), "Second village improvement failed")
	campaign.refresh()
	check(campaign.stage == SettlementCampaign.Stage.COMPLETE and regional.chapter_complete, "Two improvements and trade did not finish chapter")
	check(regional.expeditions_completed == 0, "Test unexpectedly required an expedition")
	check(Manager.instance.journal.is_task_completed("community_foothold"), "Journal has no chapter conclusion")
	var fieldwork_income := preload("res://resources/quest_profiles/quest_profile_water_fill.tres").guild_currency_reward + preload("res://resources/quest_profiles/quest_profile_farm_harvest.tres").guild_currency_reward
	var expected := before + fieldwork_income - regional.get_definition("water").coin_cost - second_cost + campaign.chapter.completion_grant
	check(Manager.instance.hub.currency == expected, "Chapter grant was not paid exactly once")
	for repeat in 3: campaign.refresh(); regional.queue_refresh()
	check(Manager.instance.hub.currency == expected, "Refresh duplicated chapter grant")
	get_window().size = Vector2i(960, 540)
	await _capture("opening-chapter-complete")
	check(SaveGames.save_slot("Opening chapter completed"), "Cannot save completed chapter")
	check(SaveGames.load_slot(SaveGames.slot_id("Opening chapter completed")), "Cannot load completed chapter")
	loaded = await SaveGames.load_finished
	check(loaded[0], "Completed chapter restore failed")
	check(Manager.instance.campaign.stage == SettlementCampaign.Stage.COMPLETE and Manager.instance.regional.chapter_complete, "Chapter conclusion lost on load")
	check(Manager.instance.hub.currency == expected, "Loading paid chapter grant again")
	print("OPENING CHAPTER TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

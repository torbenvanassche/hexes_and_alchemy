extends Node
const WORK := preload("res://resources/item_info/work_supplies.tres")
const WOOD := preload("res://resources/item_info/wood_raw.tres")
var failures: Array[String] = []
var deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	deadline = Time.get_ticks_msec() + 180000
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("Commission save test timed out")
		get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _arrival() -> void:
	check(SaveGames.load_development_checkpoint("arrival"), "Cannot load arrival")
	var result: Array = await SaveGames.load_finished
	check(result[0], "Arrival failed")
	while WorldLoading.blocks_input: await get_tree().process_frame

func _post(waiting: bool) -> Quest:
	var manager := Manager.instance
	var grid := manager.transport.get_grid()
	var location: HexBase
	for coordinate: Vector3i in grid._generated_structure_index:
		if grid._generated_structure_index[coordinate].id == "forest":
			location = grid.get_hex_at_cube_id(coordinate)
			break
	location.is_explored = true
	var objective := location.structure.instance as QuestObjective
	objective.apply_site_state("HEALTHY")
	objective.clear_occupation()
	manager.hub.stockpile.add(WORK, 2, true)
	if waiting:
		for home: FactionHome in manager.active_settlement.get_services(&"FactionHome"):
			for instance: SceneInstance in home.get_roster_npcs():
				var member := instance.node as NPC
				member.rest_remaining_seconds = 1000.0
				member.set_state(NPC.NPCState.RESTING)
	var posted := QuestPostingService.new(manager.quests, manager.hub, manager.player_instance).post_quest(location, "fell_timber", 15, -1, 2, [], manager.hub.stockpile)
	check(posted.success, "Timber posting failed: " + posted.message_key)
	return posted.quest

func _roundtrip(label: String) -> Quest:
	Engine.time_scale = 1.0
	check(SaveGames.save_block_reason().is_empty(), "Active commissions still block saves")
	check(SaveGames.save_slot(label), "Cannot save commission: " + SaveGames.last_error)
	check(SaveGames.load_slot(SaveGames.slot_id(label)), "Cannot load commission")
	var result: Array = await SaveGames.load_finished
	check(result[0], "Commission restore failed")
	check(Manager.instance.quests.get_commissions().size() == 1, "Commission missing or duplicated")
	return Manager.instance.quests.get_commissions()[0]

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	for state: String in ["waiting", "en_route", "in_progress", "returning", "complete"]:
		await _arrival()
		Manager.instance.operations.auto_resolve_completed_quests = false
		var gold := Manager.instance.hub.currency
		var quest := _post(state == "waiting")
		Engine.time_scale = 12.0
		while quest.state_machine.get_current_state() != state: await get_tree().process_frame
		Engine.time_scale = 1.0
		var remaining := quest.work_remaining
		if state == "complete":
			for member: NPC in quest.party: quest.party_fates[member.get_instance_id()] = NPC.QuestFate.INJURED
		var wood := Manager.instance.hub.stockpile.get_count(WOOD)
		var work := Manager.instance.hub.stockpile.get_count(WORK)
		var members := quest.party.size()
		quest = await _roundtrip("Commission " + state)
		check(Manager.instance.hub.currency == gold - 15, "Payment charged again after " + state)
		check(Manager.instance.hub.stockpile.get_count(WORK) == work, "Reserved supplies changed after " + state)
		check(quest.supplies.get_count(WORK) == 1 and quest.party.size() == members, "Cargo/party lost after " + state)
		if state == "in_progress": check(quest.work_remaining <= remaining + 0.2 and quest.work_remaining > 0.0, "Work timer restarted or vanished")
		if state == "complete":
			for member: NPC in quest.party: check(quest._get_party_fate(member) == NPC.QuestFate.INJURED, "Saved outcome fates were rerolled or lost")
		if state == "waiting":
			Manager.instance.quests.cancel_quest(quest)
			Manager.instance.quests.cancel_quest(quest)
			check(Manager.instance.hub.currency == gold and Manager.instance.hub.stockpile.get_count(WORK) == work + 1, "Waiting cancellation did not refund exactly once")
		else:
			Engine.time_scale = 12.0
			while not quest.is_state(Quest.QuestState.COMPLETE): await get_tree().process_frame
			Engine.time_scale = 1.0
			check(not Manager.instance.operations.auto_resolve_completed_quests, "Auto-collect preference was lost")
			check(Manager.instance.hub.stockpile.get_count(WOOD) == wood, "Unclaimed loot was paid early")
			quest.parse_reward()
			var paid := Manager.instance.hub.stockpile.get_count(WOOD)
			check(paid >= wood + 7 and paid <= wood + 10, "Saved work paid incorrect timber")
			quest.parse_reward()
			check(Manager.instance.hub.stockpile.get_count(WOOD) == paid, "Claiming twice duplicated rewards")
			check(Manager.instance.quests.get_commissions().is_empty(), "Claimed commission stayed active")
		print("COMMISSION RESTORE %s PASS" % state)
	await _arrival()
	var timber := _post(false)
	var grid := Manager.instance.transport.get_grid()
	var scout_site := Manager.instance.quests.get_available_scout_locations(grid)[0]
	var scouting := QuestPostingService.new(Manager.instance.quests, Manager.instance.hub, Manager.instance.player_instance).post_quest(scout_site, "scout", 15, -1, 1, [], Manager.instance.hub.stockpile)
	check(scouting.success, "Cannot post a concurrent scout")
	var gold := Manager.instance.hub.currency
	check(SaveGames.save_slot("Concurrent commissions"), "Concurrent jobs cannot be saved")
	check(SaveGames.load_slot(SaveGames.slot_id("Concurrent commissions")), "Concurrent jobs cannot be loaded")
	var loaded: Array = await SaveGames.load_finished
	check(loaded[0] and Manager.instance.quests.get_commissions().size() == 2, "Concurrent jobs were dropped")
	var assigned: Dictionary[NPC, bool] = {}
	for active: Quest in Manager.instance.quests.get_commissions():
		for member: NPC in active.party:
			check(not assigned.has(member) and member.current_quest == active, "Worker assigned to multiple restored jobs")
			assigned[member] = true
	Engine.time_scale = 12.0
	while not Manager.instance.quests.get_commissions().is_empty(): await get_tree().process_frame
	Engine.time_scale = 1.0
	check(Manager.instance.hub.currency == gold, "Resuming concurrent jobs charged again")
	print("COMMISSION SAVE TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

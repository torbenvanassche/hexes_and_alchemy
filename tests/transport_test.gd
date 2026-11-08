extends Node

var failures: Array[String] = []
var deadline := 0
var coord := Vector3i.ZERO

func _ready() -> void:
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	deadline = Time.get_ticks_msec() + 120000
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("TRANSPORT TEST timed out")
		get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + name + ".png")

func _check_layout(window: DraggableControl) -> void:
	var bounds := window.get_global_rect().grow(1)
	check(get_viewport().get_visible_rect().grow(1).encloses(bounds), "Shipment frame exceeds viewport")
	for button_name: String in ["Dispatch", "Recall", "Resume", "NextRequest", "Locate"]:
		var button := (window.content as HubWindowUI).trade_page.get_node("%" + button_name) as Button
		if button.is_visible_in_tree(): check(bounds.encloses(button.get_global_rect()), "Shipment action outside frame: " + button_name)

func _check_stable_clearance(settlement: Settlement) -> void:
	var transport := Manager.instance.transport
	var grid := transport.get_grid()
	var stable := transport.stops.get_stable(grid, settlement)
	check(stable != null, "Settlement has no stable")
	if stable == null: return
	for frame in 3: await get_tree().physics_frame
	var start := transport.stops.loading_position(grid, settlement)
	var finish := grid.get_hex_at_cube_id(settlement.transport_stable_approach).global_position
	var direction := finish - start
	var body := BoxShape3D.new()
	body.size = Vector3(0.42, 0.46, 0.62)
	for step in 16:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = body
		query.transform = Transform3D(Basis(Vector3.UP, atan2(direction.x, direction.z)), start.lerp(finish, step / 15.0) + Vector3.UP * 0.25)
		for hit: Dictionary in stable.get_world_3d().direct_space_state.intersect_shape(query):
			check(not settlement.is_ancestor_of(hit.collider), "Horse approach intersects stable or settlement geometry")

func _reload(label: String) -> void:
	var stable_plots: Dictionary[Vector3i, Array] = {}
	var grid := Manager.instance.transport.get_grid()
	for settlement: Settlement in Manager.instance.settlements:
		if not grid.is_ancestor_of(settlement) or not settlement.get_parent() is HexBase: continue
		stable_plots[settlement.get_parent().cube_id] = [settlement.transport_stable_tile, settlement.transport_stable_approach]
	check(SaveGames.save_slot(label), "Cannot save transport: " + SaveGames.last_error)
	check(SaveGames.load_slot(SaveGames.slot_id(label)), "Cannot load transport: " + SaveGames.last_error)
	var result: Array = await SaveGames.load_finished
	check(result[0], "Transport restore failed")
	grid = Manager.instance.transport.get_grid()
	for settlement: Settlement in Manager.instance.settlements:
		if not grid.is_ancestor_of(settlement) or not settlement.get_parent() is HexBase: continue
		check(stable_plots[settlement.get_parent().cube_id] == [settlement.transport_stable_tile, settlement.transport_stable_approach], "Loading moved a stable or its front approach")

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	# Existing fixture files predate transport. They must still load cleanly.
	for fixture: String in ["arrival", "foundation", "blacksmith", "arrival", "village"]:
		check(SaveGames.load_development_checkpoint(fixture), "Cannot open legacy checkpoint " + fixture)
		var result: Array = await SaveGames.load_finished
		check(result[0], "Legacy checkpoint restore failed")
		check(Manager.instance.transport.active_shipment.is_empty(), "Active transport state leaked into an older checkpoint")
		check(Manager.instance.transport.villages.size() == Manager.instance.transport.destinations().size(), "Loading did not register discovered villages")
		for record: VillageTradeRecord in Manager.instance.transport.villages.values():
			check(record.completed == 0 and record.phase == "available", "Later delivery progress leaked into an older checkpoint")
		if fixture == "arrival":
			check(Manager.instance.campaign.stage == SettlementCampaign.Stage.BLUEPRINT, "Opening checkpoint changed")
			check(not Manager.instance.journal.is_task_completed("open_blacksmith"), "Journal inherited later progress")
			for settlement: Settlement in Manager.instance.settlements:
				if settlement.allows_player_construction or not settlement.get_parent() is HexBase: continue
				var discovered_hex := settlement.get_parent() as HexBase
				if discovered_hex.is_explored: continue
				discovered_hex.is_explored = true
				for frame in 4: await get_tree().process_frame
				check(Manager.instance.transport.villages.has(discovered_hex.cube_id), "Revealing a village did not register trade without a market visit")
				check(Manager.instance.transport.get_relationship_text(discovered_hex.cube_id) == tr("SHIPMENT_RELATION_KNOWN"), "Discovered village still shows not met")
				break
	var manager := Manager.instance
	var transport := manager.transport
	var village := transport.destinations()[0]
	coord = village.get_parent().cube_id
	await _check_stable_clearance(manager.active_settlement)
	await _check_stable_clearance(village)
	check(not transport.dispatch(coord + Vector3i(100, -100, 0)), "Could dispatch to an undiscovered destination")
	check(transport.villages.has(coord), "Discovery did not make the village available for trade")
	check(not village.gate_open, "Village gate should start closed")
	check(manager.journal.is_task_completed("meet_neighbouring_village"), "Discovery journal objective missing")
	# The first dispatch happens from home without ever interacting at the market.
	var home_position := manager.active_settlement.spawn_position.global_position
	var stable_position := transport.stops.loading_position(transport.get_grid(), manager.active_settlement)
	manager.player_instance.global_position = home_position
	manager.player_instance.velocity = Vector3.ZERO
	manager.player_instance.toggle_hub_tab("trade")
	var journal_info := DataManager.instance.get_scene_by_name("hub_window")
	while journal_info.get_live_instances().is_empty(): await get_tree().process_frame
	for frame in 12: await get_tree().process_frame
	var journal := journal_info.get_live_instances()[0].node as DraggableControl
	var hub := journal.content as HubWindowUI
	check(hub.active_tab == "trade" and hub.trade_page.is_visible_in_tree(), "Journal did not open its Trade tab")
	check(not hub.projects_page.has_node("Body/Scroll/Content/Trade"), "Shipping still appears on Village page")
	check(not hub.operations_page.is_visible_in_tree(), "Trade shows commission controls")
	var shipping := hub.trade_page
	hub.show_tab("projects")
	check(not shipping.visible, "Shipment controls remain visible on Village tab")
	check(hub.projects_page.get_node("Body/Scroll/Content/Step").text == tr("SETTLEMENT_UPGRADE_NEXT") % manager.active_settlement.get_next_upgrade().target_level, "Village does not show the next settlement upgrade")
	check(hub.projects_page.get_node("Body/Scroll/Content/MaterialsHeader").text == tr("SETTLEMENT_UPGRADE_REQUIREMENTS_HEADER"), "Village requirements heading is untranslated")
	hub.get_node("Spread/Contents/Trade").pressed.emit()
	check(hub.active_tab == "trade" and shipping.visible, "Trade navigation button does not switch pages")
	for frame in 12: await get_tree().process_frame
	await _capture("shipment-request")
	var window := journal
	check(window.get_global_rect().end.y <= 720, "Shipment UI exceeds screen")
	_check_layout(window)
	check(not shipping.get_node("%Dispatch").disabled, "Ready shipment button disabled")
	var request := transport.get_request(coord)
	var item := request.cargo.keys()[0] as ItemInfo
	var before_count := manager.hub.stockpile.get_count(item)
	manager.hub.stockpile.remove(item, before_count)
	check(not transport.dispatch(coord) and transport.active_shipment.is_empty(), "Dispatch allowed missing cargo")
	manager.hub.stockpile.add(item, before_count)
	var arrival := transport._arrival_hex(coord)
	arrival.blocked = true
	check(not transport.dispatch(coord), "Dispatch allowed unreachable destination")
	arrival.blocked = false
	var original_carrier := transport.carrier
	transport.carrier = original_carrier.duplicate()
	transport.carrier.capacity = 1
	check(not transport.dispatch(coord), "Carrier capacity ignored")
	transport.carrier = original_carrier
	var before_gold := manager.hub.currency
	var before_rep := manager.reputation.reputation
	shipping.get_node("%Dispatch").pressed.emit()
	check(not transport.active_shipment.is_empty(), "Dispatch from home journal failed: " + transport.last_error)
	var delivery := transport.active_shipment.quest as ShipmentQuest
	check(delivery is DeliveryQuest and manager.quests.active_quests.has(delivery), "Shipment does not use the shared delivery quest")
	check(manager.operations.operations.any(func(op: HubOperation) -> bool: return op.quest == delivery), "Shipment missing from operation history")
	check(delivery.party.is_empty() and manager.quests.get_commissions().is_empty(), "Shipment borrowed roster members or appeared as a commission")
	check(delivery.supplies.has_all(request.cargo), "Delivery quest does not hold reserved cargo")
	var commission_limit := manager.quests.max_active_quest
	manager.quests.max_active_quest = 1
	check(manager.quests.get_posting_error(Quest.new(village.get_parent(), "scout")) == "", "Shipment used the sole commission slot")
	manager.quests.max_active_quest = commission_limit
	check((transport.active_shipment.position as Vector3).is_equal_approx(stable_position), "Packhorse did not depart from its stable")
	var inside := transport.stops.interiors(transport.get_grid())
	for route_coord: Vector3i in transport.active_shipment.route:
		check(not inside.has(route_coord), "Shipment route enters a settlement")
	check(transport._carrier_visual.get_node("Cargo").visible, "Loaded horse has no cargo")
	check(manager.hub.stockpile.get_count(item) == before_count - request.cargo[item], "Cargo not withdrawn once")
	check(not transport.dispatch(coord), "Duplicate dispatch allowed")
	check(manager.hub.currency == before_gold, "Paid before delivery")
	window.hide()
	var start: Vector3 = transport.active_shipment.position
	var moving_pose := false
	for frame in 12:
		await get_tree().physics_frame
		moving_pose = moving_pose or transport._carrier_visual.get_node("Model").position.y > 0.0001
	check(moving_pose, "Travelling horse stays completely rigid")
	check(transport._carrier_visual.global_position.is_equal_approx(transport.active_shipment.position), "Motion offset changed the horse's route position")
	for frame in 10: await get_tree().physics_frame
	check(start.distance_to(transport.active_shipment.position) > 0.01, "Packhorse is not travelling")
	var route_tile := transport.get_grid().get_hex_at_cube_id(transport.active_shipment.route[int(transport.active_shipment.index)])
	var original_cost := route_tile.movement_cost
	var original_eta := transport.remaining_seconds()
	route_tile.movement_cost = 0.5
	check(transport.remaining_seconds() < original_eta, "Transport ignores faster terrain for future roads")
	route_tile.movement_cost = original_cost
	if OS.get_cmdline_user_args().has("--capture"):
		while int(transport.active_shipment.index) < 3: await get_tree().physics_frame
		manager.spring_arm_camera.target = transport._carrier_visual
		manager.spring_arm_camera.snap_to_target()
		for frame in 4: await get_tree().process_frame
		await _capture("packhorse-in-world")
		manager.spring_arm_camera.target = manager.player_instance
		manager.spring_arm_camera.snap_to_target()
	# Pause must freeze travel, including the manager's always-processing parent.
	get_tree().paused = true
	start = transport.active_shipment.position
	var paused_pose: Transform3D = transport._carrier_visual.get_node("Model").transform
	for frame in 6: await get_tree().process_frame
	check(start == transport.active_shipment.position, "Horse moved while paused")
	check(paused_pose == transport._carrier_visual.get_node("Model").transform, "Horse motion continued while paused")
	get_tree().paused = false
	await _reload("Transport outbound")
	transport = Manager.instance.transport
	check(transport.active_shipment.phase == "outbound", "Outbound state lost")
	delivery = transport.active_shipment.quest
	check(delivery is ShipmentQuest and Manager.instance.quests.active_quests.has(delivery), "Loaded shipment lost its active quest")
	check(delivery.supplies.has_all(request.cargo), "Loaded delivery quest lost its cargo")
	check(Manager.instance.hub.stockpile.get_count(item) == before_count - request.cargo[item], "Cargo deducted again on load")
	# An older outbound save may contain a horse inside the town. Relocate it to
	# the stable and replan its route without another withdrawal or payment.
	transport.active_shipment.route_version = 0
	# Genuine pre-quest save shape: only the journey manifest exists.
	Manager.instance.quests.remove_quest(delivery)
	Manager.instance.operations.operations = Manager.instance.operations.operations.filter(func(op: HubOperation) -> bool: return op.quest != delivery)
	transport.active_shipment.quest = null
	transport.active_shipment.position = Manager.instance.active_settlement.spawn_position.global_position
	await _reload("Legacy market route outbound")
	transport = Manager.instance.transport
	check(transport.active_shipment.route_version == TransportManager.STABLE_ROUTE_VERSION, "Old outbound route did not migrate")
	check(not transport.stops.interiors(transport.get_grid()).has(transport.get_grid().get_hex_at_world_position(transport.active_shipment.position).cube_id), "Legacy horse stayed inside town")
	check(Manager.instance.hub.stockpile.get_count(item) == before_count - request.cargo[item], "Migration withdrew cargo twice")
	check(Manager.instance.hub.currency == before_gold, "Migration paid an outbound reward")
	check(transport.active_shipment.quest is ShipmentQuest and transport.active_shipment.quest.supplies.has_all(request.cargo), "Legacy journey did not acquire a delivery quest")
	var next := transport.get_grid().get_hex_at_cube_id(transport.active_shipment.route[int(transport.active_shipment.index)])
	next.blocked = true
	for frame in 3: await get_tree().physics_frame
	check(transport.active_shipment.blocked, "Blocked route did not stop horse")
	for frame in 30: await get_tree().process_frame
	check(transport._carrier_visual.get_node("Model").position.length() < 0.001, "Blocked horse did not settle")
	next.blocked = false
	check(transport.resume_route(), "Horse could not resume route")
	Engine.time_scale = 4
	while not transport.active_shipment.is_empty() and transport.active_shipment.phase == "outbound": await get_tree().process_frame
	Engine.time_scale = 1
	check(Manager.instance.hub.currency == before_gold + request.payment, "Delivery payment missing or duplicated")
	check(Manager.instance.reputation.reputation == before_rep + request.reputation_reward, "Reputation missing")
	check(transport.villages[coord].completed == 1 and transport.villages[coord].influence == 1, "Delivery influence not recorded")
	check(Manager.instance.journal.is_task_completed("deliver_first_shipment"), "Shipment journal objective missing")
	check(not Manager.instance.transport.village_at(coord).gate_open, "Packhorse opened a gate instead of using the outside stable")
	check(not transport._carrier_visual.get_node("Cargo").visible, "Delivered horse still carries cargo")
	check(transport.active_shipment.phase == "unloading", "Horse immediately returned without unloading")
	delivery = transport.active_shipment.quest
	check(delivery.is_state(Quest.QuestState.IN_PROGRESS) and delivery.outcome.is_applied(), "Unloading does not use the quest work phase and outcome")
	check(Manager.instance.quests._get_inventory_contents(delivery.supplies).is_empty(), "Delivery did not consume reserved cargo")
	check(not transport.recall() and not transport.resume_route(), "Unloading can be skipped by journey actions")
	start = transport.active_shipment.position
	var unload_time := transport.remaining_seconds()
	for frame in 12: await get_tree().physics_frame
	check(start == transport.active_shipment.position and transport.remaining_seconds() < unload_time, "Horse did not wait at its stable")
	get_tree().paused = true
	unload_time = transport.remaining_seconds()
	for frame in 6: await get_tree().process_frame
	check(is_equal_approx(transport.remaining_seconds(), unload_time), "Unloading countdown continued while paused")
	get_tree().paused = false
	await _reload("Transport unloading")
	transport = Manager.instance.transport
	check(transport.active_shipment.phase == "unloading", "Loading skipped the unloading pause")
	check(absf(transport.remaining_seconds() - unload_time) < 0.25, "Loading restarted the unloading countdown")
	check(Manager.instance.hub.currency == before_gold + request.payment, "Loading unloading replayed payment")
	transport.open_window(coord)
	for frame in 12: await get_tree().process_frame
	await _capture("shipment-unloading")
	Engine.time_scale = 4
	while transport.active_shipment.phase == "unloading": await get_tree().process_frame
	Engine.time_scale = 1
	delivery = transport.active_shipment.quest
	check(delivery.is_state(Quest.QuestState.RETURNING), "Delivery quest did not begin returning")
	delivery.resolve_delivery()
	check(Manager.instance.hub.currency == before_gold + request.payment, "Resolving delivery again paid twice")
	transport.active_shipment.route_version = 0
	transport.active_shipment.position = transport.village_at(coord).spawn_position.global_position
	await _reload("Transport returning")
	transport = Manager.instance.transport
	check(transport.active_shipment.phase == "returning", "Return journey lost")
	check(not transport.stops.interiors(transport.get_grid()).has(transport.get_grid().get_hex_at_world_position(transport.active_shipment.position).cube_id), "Legacy returning horse stayed in the village")
	check(Manager.instance.hub.currency == before_gold + request.payment, "Loading replayed reward")
	delivery = transport.active_shipment.quest
	Engine.time_scale = 4
	while not transport.active_shipment.is_empty(): await get_tree().process_frame
	Engine.time_scale = 1
	check(transport.villages[coord].phase == "fulfilled", "Horse not released on return")
	check(delivery.is_state(Quest.QuestState.COMPLETE) and not Manager.instance.quests.active_quests.has(delivery), "Returned delivery stayed active")
	check(Manager.instance.operations.operations.any(func(op: HubOperation) -> bool: return op.quest == delivery and op.completion_recorded), "Delivery completion missing from history")
	check(is_instance_valid(transport._carrier_visual), "Returned horse vanished instead of parking in the stable")
	check(transport._carrier_visual.global_position.is_equal_approx(transport.stops.loading_position(transport.get_grid(), Manager.instance.active_settlement)), "Returned horse is not at its stable")
	# Visiting is optional shopping and must not reset the remotely completed job.
	manager = Manager.instance
	manager.player_instance.global_position = transport.village_at(coord).spawn_position.global_position
	for frame in 6: await get_tree().physics_frame
	check(manager.player_instance.interactor_component.interact(), "Village market is not interactable")
	var market_info := DataManager.instance.get_scene_by_name("market_ui")
	while market_info.get_live_instances().is_empty(): await get_tree().process_frame
	for frame in 12: await get_tree().process_frame
	var market_window := market_info.get_live_instances()[0].node as DraggableControl
	check(not market_window.content.has_node("TopRow/Shipments"), "Village market still manages outbound guild shipments")
	check(transport.villages[coord].completed == 1 and transport.villages[coord].phase == "fulfilled", "Optional market visit reset delivery progress")
	market_window.close_window(true)
	manager.player_instance.global_position = manager.active_settlement.spawn_position.global_position
	check(transport.next_request(coord), "Next request did not unlock")
	request = transport.get_request(coord)
	check(request != transport.REQUESTS[0], "Request did not rotate")
	# This test exercises transport transactions; the campaign test crafts these
	# goods through the blacksmith UI and checks the partnership unlock.
	for required_item: ItemInfo in request.cargo:
		var missing := int(request.cargo[required_item]) - Manager.instance.hub.stockpile.get_count(required_item)
		if missing > 0: Manager.instance.hub.stockpile.add(required_item, missing, true)
	check(transport.dispatch(coord), "Second dispatch failed")
	check(transport.recall(), "Could not recall loaded horse")
	await _reload("Transport recalled")
	transport = Manager.instance.transport
	delivery = transport.active_shipment.quest
	Engine.time_scale = 4
	while not transport.active_shipment.is_empty(): await get_tree().process_frame
	Engine.time_scale = 1
	check(transport.villages[coord].phase == "available", "Recall lost request")
	check(delivery.is_state(Quest.QuestState.CANCELLED) and not Manager.instance.quests.active_quests.has(delivery), "Recall bypassed quest cancellation")
	check(Manager.instance.hub.currency == before_gold + transport.REQUESTS[0].payment, "Recall paid reward")
	check(Manager.instance.hub.stockpile.get_count(item) == before_count - transport.REQUESTS[0].cargo[item], "Recall did not return cargo exactly once")
	check(transport.dispatch(coord), "Cannot dispatch after recall")
	transport.open_window(coord)
	for frame in 12: await get_tree().process_frame
	await _capture("shipment-travelling")
	for resolution: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720)]:
		get_window().size = resolution
		for frame in 12: await get_tree().process_frame
		_check_layout(DataManager.instance.get_scene_by_name("hub_window").get_live_instances()[0].node as DraggableControl)
	await _test_delivery_definition(item)
	print("TRANSPORT TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_delivery_definition(item: ItemInfo) -> void:
	# No horse/controller: an authored delivery can complete on arrival alone.
	var manager := Manager.instance
	var definition := DeliveryDefinition.new()
	definition.id = "test_supply_delivery"
	definition.title_key = "QUEST_TYPE_DELIVERY"
	definition.cargo = {item: 1}
	definition.payment = 7
	definition.reputation_reward = 1
	definition.completion_task = load("res://resources/journal_tasks/complete_timber_commission.tres")
	manager.journal.reopen_task(definition.completion_task.id)
	var quest := DeliveryQuest.new(manager.transport.village_at(coord).get_parent())
	quest.configure_delivery(definition)
	var count := manager.hub.stockpile.get_count(item)
	check(quest.reserve_cargo(manager.hub.stockpile), "Generic delivery could not reserve cargo")
	check(not quest.reserve_cargo(manager.hub.stockpile), "Generic delivery reserved cargo twice")
	check(manager.quests.add_quest(quest), "Generic delivery could not enter quest system")
	quest.set_state(Quest.QuestState.EN_ROUTE)
	definition.payment = 999
	definition.cargo[item] = 999
	await _reload("Independent delivery quest")
	manager = Manager.instance
	for active: Quest in manager.quests.active_quests:
		if active.quest_key == "delivery": quest = active as DeliveryQuest
	check(quest is DeliveryQuest and quest.is_state(Quest.QuestState.EN_ROUTE), "Generic delivery type or state lost on load")
	check(quest.supplies.get_count(item) == 1, "Authored cargo changed in flight")
	check(not manager.journal.is_task_completed(definition.completion_task.id), "Configured completion task ran before delivery")
	var coins := manager.hub.currency
	var rep := manager.reputation.reputation
	var prestige := manager.hub.prestige
	var commissions := manager.reputation.completed_quests
	manager.operations.auto_resolve_completed_quests = false
	quest.set_state(Quest.QuestState.IN_PROGRESS)
	quest.supplies.remove(item, 1)
	quest.resolve_delivery()
	check(manager.hub.currency == coins and not quest.context.get("delivery_paid", false), "Incomplete cargo was accepted as a delivery")
	quest.supplies.add(item, 1, true)
	quest.resolve_delivery()
	quest.resolve_delivery()
	quest.finish_return()
	check(quest.is_state(Quest.QuestState.COMPLETE) and not manager.quests.active_quests.has(quest), "One-way delivery requires a horse return or manual collection")
	check(manager.hub.currency == coins + 7 and manager.reputation.reputation == rep + 1, "Generic delivery rewards missing, edited in flight or duplicated")
	check(manager.hub.prestige == prestige and manager.reputation.completed_quests == commissions, "Generic delivery awarded unconfigured prestige or commission credit")
	check(manager.hub.stockpile.get_count(item) == count - 1, "Generic delivery cargo not consumed exactly once")
	check(manager.journal.is_task_completed(definition.completion_task.id), "Authored completion task was not applied")
	# Cancellation shares the ordinary quest refund; it cannot pay on arrival later.
	definition.cargo = {item: 1}
	quest = DeliveryQuest.new(manager.transport.village_at(coord).get_parent())
	quest.configure_delivery(definition)
	check(quest.reserve_cargo(manager.hub.stockpile) and manager.quests.add_quest(quest), "Cancellation delivery could not start")
	manager.quests.cancel_quest(quest)
	manager.quests.cancel_quest(quest)
	quest.resolve_delivery()
	check(manager.hub.stockpile.get_count(item) == count - 1 and manager.hub.currency == coins + 7, "Cancelled delivery duplicated a refund or paid a reward")
	# Settle the separate carrier before comparing ordinary commission rewards.
	Engine.time_scale = 4
	while not manager.transport.active_shipment.is_empty(): await get_tree().process_frame
	Engine.time_scale = 1
	# An ordinary commission still recruits, travels and resolves through its
	# existing NPC lifecycle.
	manager.operations.auto_resolve_completed_quests = true
	var target := manager.quests.get_scout_location_for_distance(manager.transport.get_grid(), 3)
	check(target != null, "No scouting target for commission regression")
	if target == null: return
	var service := QuestPostingService.new(manager.quests, manager.hub, manager.player_instance)
	var posted := service.post_quest(target, "scout", 0, -1, 1, [], manager.hub.stockpile)
	check(posted.success and not posted.quest.party.is_empty(), "Ordinary scout no longer posts and recruits")
	check(manager.quests.get_commissions().has(posted.quest) and not SaveGames.save_block_reason().is_empty(), "Commission filtering removed a real commission")
	var scout_rep := manager.reputation.reputation
	var scout_prestige := manager.hub.prestige
	Engine.time_scale = 4
	while manager.quests.active_quests.has(posted.quest): await get_tree().process_frame
	Engine.time_scale = 1
	check(posted.quest.is_state(Quest.QuestState.COMPLETE), "Ordinary scouting commission failed to complete")
	check(manager.reputation.completed_quests == commissions + 1 and manager.reputation.reputation == scout_rep + 1 and manager.hub.prestige == scout_prestige + 1, "Ordinary commission completion/rewards changed")

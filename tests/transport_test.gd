extends Node

var failures: Array[String] = []
var deadline := 0
var coord := Vector3i.ZERO

func _ready() -> void:
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

func _reload(label: String) -> void:
	check(SaveGames.save_slot(label), "Cannot save transport: " + SaveGames.last_error)
	check(SaveGames.load_slot(SaveGames.slot_id(label)), "Cannot load transport: " + SaveGames.last_error)
	var result: Array = await SaveGames.load_finished
	check(result[0], "Transport restore failed")

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	# Existing fixture files predate transport. They must still load cleanly.
	for fixture: String in ["arrival", "foundation", "blacksmith", "arrival", "village"]:
		check(SaveGames.load_development_checkpoint(fixture), "Cannot open legacy checkpoint " + fixture)
		var result: Array = await SaveGames.load_finished
		check(result[0], "Legacy checkpoint restore failed")
		check(Manager.instance.transport.active_shipment.is_empty() and Manager.instance.transport.villages.is_empty(), "Transport state leaked into an older checkpoint")
		if fixture == "arrival":
			check(Manager.instance.campaign.stage == SettlementCampaign.Stage.BLUEPRINT, "Opening checkpoint changed")
			check(not Manager.instance.journal.is_task_completed("open_blacksmith"), "Journal inherited later progress")
	var manager := Manager.instance
	var transport := manager.transport
	var village := transport.destinations()[0]
	coord = village.get_parent().cube_id
	check(not transport.dispatch(coord), "Could dispatch before meeting village")
	manager.player_instance.global_position = village.spawn_position.global_position
	for frame in 6: await get_tree().physics_frame
	check(manager.player_instance.interactor_component.interact(), "Village market is not interactable")
	check(transport.villages.has(coord), "Village interaction did not establish contact")
	check(not village.gate_open, "Village gate should start closed")
	check(manager.journal.is_task_completed("meet_neighbouring_village"), "Contact journal objective missing")
	var market_info := DataManager.instance.get_scene_by_name("market_ui")
	while market_info.get_live_instances().is_empty(): await get_tree().process_frame
	for frame in 12: await get_tree().process_frame
	var market_window := market_info.get_live_instances()[0].node as DraggableControl
	var market_ui := market_window.content as MarketUI
	check(market_ui.get_node("TopRow/Shipments").visible, "Village market has no shipment action")
	market_ui.get_node("TopRow/Shipments").pressed.emit()
	for frame in 12: await get_tree().process_frame
	check(not market_window.visible, "Market stayed open behind shipment screen")
	await _capture("shipment-request")
	var window := TransportManager.WINDOW.get_live_instances()[0].node as DraggableControl
	check(window.get_global_rect().end.y <= 720, "Shipment UI exceeds screen")
	check(not window.content.get_node("%Dispatch").disabled, "Ready shipment button disabled")
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
	check(transport.dispatch(coord), "Dispatch failed: " + transport.last_error)
	check(manager.hub.stockpile.get_count(item) == before_count - request.cargo[item], "Cargo not withdrawn once")
	check(not transport.dispatch(coord), "Duplicate dispatch allowed")
	check(manager.hub.currency == before_gold, "Paid before delivery")
	window.hide()
	var start: Vector3 = transport.active_shipment.position
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
	for frame in 6: await get_tree().process_frame
	check(start == transport.active_shipment.position, "Horse moved while paused")
	get_tree().paused = false
	await _reload("Transport outbound")
	transport = Manager.instance.transport
	check(transport.active_shipment.phase == "outbound", "Outbound state lost")
	check(Manager.instance.hub.stockpile.get_count(item) == before_count - request.cargo[item], "Cargo deducted again on load")
	var next := transport.get_grid().get_hex_at_cube_id(transport.active_shipment.route[int(transport.active_shipment.index)])
	next.blocked = true
	for frame in 3: await get_tree().physics_frame
	check(transport.active_shipment.blocked, "Blocked route did not stop horse")
	next.blocked = false
	check(transport.resume_route(), "Horse could not resume route")
	Engine.time_scale = 4
	while not transport.active_shipment.is_empty() and transport.active_shipment.phase == "outbound": await get_tree().process_frame
	Engine.time_scale = 1
	check(Manager.instance.hub.currency == before_gold + request.payment, "Delivery payment missing or duplicated")
	check(Manager.instance.reputation.reputation == before_rep + request.reputation_reward, "Reputation missing")
	check(transport.villages[coord].completed == 1 and transport.villages[coord].influence == 1, "Delivery influence not recorded")
	check(Manager.instance.journal.is_task_completed("deliver_first_shipment"), "Shipment journal objective missing")
	check(Manager.instance.transport.village_at(coord).gate_open, "Packhorse did not open the village gate for delivery")
	await _reload("Transport returning")
	transport = Manager.instance.transport
	check(transport.active_shipment.phase == "returning", "Return journey lost")
	check(Manager.instance.hub.currency == before_gold + request.payment, "Loading replayed reward")
	Engine.time_scale = 4
	while not transport.active_shipment.is_empty(): await get_tree().process_frame
	Engine.time_scale = 1
	check(transport.villages[coord].phase == "fulfilled", "Horse not released on return")
	check(transport.next_request(coord), "Next request did not unlock")
	request = transport.get_request(coord)
	check(request != transport.REQUESTS[0], "Request did not rotate")
	check(transport.dispatch(coord), "Second dispatch failed")
	check(transport.recall(), "Could not recall loaded horse")
	await _reload("Transport recalled")
	transport = Manager.instance.transport
	Engine.time_scale = 4
	while not transport.active_shipment.is_empty(): await get_tree().process_frame
	Engine.time_scale = 1
	check(transport.villages[coord].phase == "available", "Recall lost request")
	check(Manager.instance.hub.currency == before_gold + transport.REQUESTS[0].payment, "Recall paid reward")
	check(Manager.instance.hub.stockpile.get_count(item) == before_count - transport.REQUESTS[0].cargo[item], "Recall did not return cargo exactly once")
	check(transport.dispatch(coord), "Cannot dispatch after recall")
	transport.open_window(coord)
	for frame in 12: await get_tree().process_frame
	await _capture("shipment-travelling")
	print("TRANSPORT TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

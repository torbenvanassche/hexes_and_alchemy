extends Node

var failures: Array[String] = []
var deadline := 0

func _ready() -> void:
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid: node.world_seed = 20261102
	)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	deadline = Time.get_ticks_msec() + 60000
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline: get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/validation/" + name + ".png")

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	for frame in 6: await get_tree().process_frame
	var fresh_grid := Manager.instance.transport.get_grid()
	var fresh_village: Settlement
	for settlement: Settlement in Manager.instance.settlements:
		if settlement.has_method("rebuild_boundary") and fresh_grid.is_ancestor_of(settlement): fresh_village = settlement
	check(fresh_village != null, "New world did not generate its village")
	if fresh_village != null:
		_check_clearance(fresh_village, fresh_grid)
		check(Manager.instance.transport.stops.get_stable(fresh_grid, fresh_village) != null, "New village has no exterior stable")
		check(fresh_village.transport_stable_approach == fresh_village.get("gate_outside"), "New stable approach does not meet the village entrance")
		var fresh_origin := fresh_grid.get_hex_at_world_position(Manager.instance.active_settlement.spawn_position.global_position)
		var fresh_arrival := fresh_grid.get_hex_at_world_position(fresh_village.spawn_position.global_position)
		check(not fresh_grid.pathfinder.get_hex_path(fresh_origin.cube_id, fresh_arrival.cube_id).is_empty(), "New village clearance cuts off its approach route")
	check(SaveGames.load_development_checkpoint("village"), "Village fixture load failed")
	await SaveGames.load_finished
	var manager := Manager.instance
	var grid := manager.transport.get_grid()
	var village := manager.transport.destinations()[0]
	for frame in 6: await get_tree().process_frame
	check(village.get_node("walls").get_child_count() == 17, "Village perimeter has missing fence pieces")
	check(village.get_node("entrances").get_child_count() == 1, "Village must have one clear entrance")
	var gate := village.get_node("entrances").get_child(0) as Node3D
	var gate_door := gate.find_child("fence_wood_straight_door", true, false) as MeshInstance3D
	check(gate_door != null, "Village gate has no door")
	if gate_door != null:
		var door_bounds: AABB = gate.global_transform.affine_inverse() * gate_door.global_transform * gate_door.get_aabb()
		check(door_bounds.size.y > 0.2, "Open gate door lies flat instead of staying upright")
	var inside: Vector3i = village.get("gate_inside")
	var outside: Vector3i = village.get("gate_outside")
	check(not grid.pathfinder._is_blocked(inside, outside), "Openable gate blocks NPC route planning")
	_check_clearance(village, grid)
	for wall: Obstacle in village.get_node("walls").get_children():
		check(grid.pathfinder._is_blocked(wall.cube_id, wall.adjacent_id), "Fence can be crossed by pathfinding")
		check(not wall.find_children("*", "CollisionShape3D", true, false).is_empty(), "Fence lacks physical collision")
	var origin := grid.get_hex_at_world_position(manager.active_settlement.spawn_position.global_position)
	var arrival := grid.get_hex_at_world_position(village.spawn_position.global_position)
	var path := grid.pathfinder.get_hex_path(origin.cube_id, arrival.cube_id)
	check(not path.is_empty(), "Trade post unreachable from main settlement")
	var gate_used := false
	for index in range(1, path.size()):
		if path[index - 1].cube_id == outside and path[index].cube_id == inside: gate_used = true
	check(gate_used, "Village route bypasses entrance")
	var trade := village.get_node("Buildings/Market")
	check(trade.find_children("*", "Label3D", true, false).is_empty(), "Village market label remains visible")
	check(trade is Market and village.get_service(&"Market") == trade, "Village does not reuse the starting settlement market service")
	check(village.get_node("Buildings").find_children("Cottage*", "Node3D", false, false).size() == 2, "Village should contain only two cottages")
	var steward_bounds := LocationMarker.get_visible_bounds(trade.get_node("Steward"))
	check(steward_bounds.end.y > trade.global_position.y + 0.24, "Steward is hidden behind the counter")
	check(trade.find_children("*", "MeshInstance3D", true, false).size() >= 3, "Trade interaction has no visible destination")
	check(trade.prompt_anchor != null and trade.get_prompt_position().y > trade.global_position.y + 0.4, "Interaction prompt still targets bare ground")
	manager.player_instance.global_position = grid.get_hex_at_cube_id(outside).global_position
	for frame in 6: await get_tree().physics_frame
	# Discovery unlocks remote trade; only explicitly locating the market adds an
	# arrow. The ordinary tracked destination still clears when interacted with.
	manager.campaign.destination = trade
	manager.campaign.destination_changed.emit()
	for frame in 3: await get_tree().process_frame
	var marker := manager.find_child("LocationMarker", true, false) as LocationMarker
	check(marker != null and marker.visible, "Located market marker missing")
	var bounds := LocationMarker.get_visible_bounds(trade)
	check(marker.global_position.y >= bounds.end.y, "Trade marker below geometry")
	marker.track(null)
	marker.track(trade)
	var rest_position := marker.global_position
	marker._process(marker.bob_period * 0.5)
	check(is_equal_approx(marker.global_position.y - rest_position.y, marker.bob_height), "Marker does not bob above its roof clearance")
	check(is_equal_approx(marker.global_position.x, rest_position.x) and is_equal_approx(marker.global_position.z, rest_position.z), "Marker drifts sideways while bobbing")
	manager.spring_arm_camera.target = village
	manager.spring_arm_camera.target_zoom = 0.5
	manager.spring_arm_camera.snap_to_target()
	for frame in 6: await get_tree().process_frame
	await capture("village-wooden-boundary")
	# Confirm geometry collision agrees with the graph: fence blocks, gate is open.
	var wall: Obstacle = village.get_node("walls").get_child(0)
	var from := grid.get_hex_at_cube_id(wall.cube_id).global_position + Vector3.UP * 0.2
	var to := grid.get_hex_at_cube_id(wall.adjacent_id).global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [manager.player_instance.get_rid()]
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	check(not hit.is_empty(), "Player can pass straight through wooden fence")
	from = grid.get_hex_at_cube_id(inside).global_position + Vector3.UP * 0.2
	to = grid.get_hex_at_cube_id(outside).global_position + Vector3.UP * 0.2
	query = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [manager.player_instance.get_rid()]
	hit = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and gate_door.is_ancestor_of(hit.collider), "Closed gate has no door collision")
	var approach_direction := (to - from).normalized()
	var gate_approach: Vector3 = gate_door.get_prompt_position() + approach_direction * 0.55
	gate_approach.y = grid.get_hex_at_cube_id(outside).global_position.y
	manager.player_instance.global_position = gate_approach
	for frame in 6: await get_tree().physics_frame
	check(manager.player_instance.interactor_component.current_triggers.has(gate_door), "Gate does not expose an interaction prompt")
	check(manager.player_instance.interactor_component.interact(), "Player cannot open the village gate")
	await get_tree().create_timer(0.6).timeout
	check(village.gate_open and gate_door.at_max, "Player interaction did not open the gate")
	hit = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	check(hit.is_empty(), "Open door collision still blocks the entrance")
	var open_bounds: AABB = gate.global_transform.affine_inverse() * gate_door.global_transform * gate_door.get_aabb()
	check(open_bounds.size.y > 0.2, "Opening the gate tips its door onto the floor")
	gate_door.on_interact()
	await get_tree().create_timer(0.6).timeout
	check(not village.gate_open, "Player cannot close the gate")
	hit = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and gate_door.is_ancestor_of(hit.collider), "Closing the gate failed to restore collision")
	gate_door.on_interact()
	await get_tree().create_timer(0.6).timeout
	manager.campaign.destination = trade
	manager.campaign.destination_changed.emit()
	for frame in 3: await get_tree().process_frame
	check(marker.visible, "Located market marker vanished")
	manager.player_instance.global_position = village.spawn_position.global_position
	for frame in 6: await get_tree().physics_frame
	for frame in 3: await get_tree().physics_frame
	# Keep the tracking arrow visible when close enough for the input prompt.
	manager.campaign.destination = trade
	manager.campaign.destination_changed.emit()
	for frame in 3: await get_tree().process_frame
	check(manager.player_instance.interactor_component.current_triggers.has(trade), "Player did not enter the market prompt area")
	check(marker.visible, "Interaction prompt incorrectly hides the tracking arrow")
	manager.campaign.destination = trade
	manager.campaign.destination_changed.emit()
	check(manager.player_instance.interactor_component.interact(), "Steward cannot be interacted with")
	for frame in 3: await get_tree().process_frame
	check(manager.transport.villages.has(village.get_parent().cube_id), "Discovered village is missing from trade destinations")
	check(manager.campaign.destination == null, "Interacting at counter did not clear tracked destination")
	check(not marker.visible, "Tracked market marker did not clear after interaction")
	var market_info := DataManager.instance.get_scene_by_name("market_ui")
	while market_info.get_live_instances().is_empty(): await get_tree().process_frame
	for frame in 12: await get_tree().process_frame
	var market_window := market_info.get_live_instances()[0].node as DraggableControl
	var market_ui := market_window.content as MarketUI
	check(market_ui.buy_inventory == trade.buy_inventory, "Village market opened the wrong stock")
	check(not market_ui.has_node("TopRow/Shipments"), "Village market still manages outbound guild shipments")
	var stock: ContentSlotResource = trade.buy_inventory.data[0]
	var previous_stock := stock.count
	check(manager.market.buy_from_slot(stock, manager.hub.stockpile, 1), "Village market buy action failed")
	check(stock.count == previous_stock - 1, "Village stock not depleted by purchase")
	market_window.hide()
	var home_market := manager.active_settlement.get_service(&"Market") as Market
	home_market._open_window(market_info)
	for frame in 12: await get_tree().process_frame
	check(market_ui.buy_inventory == home_market.buy_inventory, "Starting market opened the wrong stock")
	market_window.hide()
	var coord: Vector3i = village.get_parent().cube_id
	check(SaveGames.save_slot("Village boundary"), "Cannot save village geometry")
	check(SaveGames.load_slot(SaveGames.slot_id("Village boundary")), "Cannot reload village")
	await SaveGames.load_finished
	village = Manager.instance.transport.village_at(coord)
	check(village.get("gate_inside") == inside and village.get("gate_outside") == outside, "Loading moved the entrance")
	check(village.get_node("walls").get_child_count() == 17, "Loading duplicated or removed fences")
	check(village.gate_open, "Loading forgot the open gate state")
	var restored_door := village.get_node("entrances").find_child("fence_wood_straight_door", true, false)
	check(restored_door.at_max, "Loaded door does not match saved open state")
	check(village.get_node("Buildings/Market").buy_inventory.data[0].count == previous_stock - 1, "Village market stock reset on load")
	# Migrate the previous arrival-trade node path in real save data and tracking.
	var snapshot := GameSnapshot.new()
	var data := snapshot.capture(Manager.instance.transport.get_grid())
	for row in data.world.tiles:
		if snapshot.codec.decode(row.coord) != coord: continue
		for state in row.get("nodes", []):
			if state.path == "Buildings/Market": state.path = "Arrival/Trade"
	data.campaign.destination = {"$node": snapshot.codec.encode(coord), "path": str(village.name) + "/Arrival/Trade"}
	var legacy_slot := SaveGames.slot_id("Village legacy trade")
	var file := FileAccess.open(SaveGames.DIRECTORY.path_join(legacy_slot + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveGames.create_document("Village legacy trade", data)))
	file.close()
	check(SaveGames.load_slot(legacy_slot), "Legacy village save rejected")
	var result: Array = await SaveGames.load_finished
	check(result[0], "Legacy trade point failed to migrate")
	village = Manager.instance.transport.village_at(coord)
	check(Manager.instance.campaign.destination == village.get_node("Buildings/Market"), "Legacy tracking does not point to central market")
	print("VILLAGE BOUNDARY TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_clearance(village: Settlement, grid: HexGrid) -> void:
	var village_hex := village.get_parent() as HexBase
	check(village_hex.structure.structure_info.required_space_radius == village.initial_footprint_radius + 1, "Village footprint lacks its one-tile clearance ring")
	var ring: Array[Vector3i] = []
	for tile_instance: SceneInstance in grid.get_tiles_in_radius(village_hex.cube_id, 2):
		var tile := tile_instance.node as HexBase
		check(not tile.can_generate, "Village clearance is not reserved from generation")
		check(tile.is_traversable(), "Village clearance contains impassable terrain")
		if GridUtils.cube_distance(tile.cube_id, village_hex.cube_id) == 2: ring.append(tile.cube_id)
	check(ring.size() == 12, "Village clearance ring is incomplete")
	var ring_nav := HexAStar.new(grid)
	ring_nav.rebuild()
	for coord: Vector3i in ring_nav.cube_to_id:
		if not ring.has(coord): ring_nav.set_point_disabled(ring_nav.cube_to_id[coord])
	for coord: Vector3i in ring:
		check(not ring_nav.get_hex_path(ring[0], coord).is_empty(), "Village blocks passage around its outside: %s to %s" % [ring[0], coord])

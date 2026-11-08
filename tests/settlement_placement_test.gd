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
func _forge(grid: HexGrid) -> HexBase:
	for coord: Vector3i in grid.tiles:
		var hex := grid.get_hex_at_cube_id(coord)
		if hex.structure != null and hex.structure.structure_info.id == "forge": return hex
	return null
func _run() -> void:
	while not SaveGames.save_block_reason().is_empty(): await get_tree().process_frame
	reparent(SaveGames)
	var forge_info := preload("res://resources/structure_info/forge.tres")
	var handler: RefCounted = forge_info.placement_handler.new()
	for fixture: String in ["arrival", "foundation", "blacksmith", "village", "trade_partner"]:
		check(SaveGames.load_development_checkpoint(fixture), "Cannot open " + fixture)
		var result: Array = await SaveGames.load_finished
		check(result[0], "Cannot restore " + fixture)
		var manager := Manager.instance
		var grid := manager.transport.get_grid()
		var home := manager.active_settlement
		var plots: Dictionary[Vector3i, bool] = {}
		for building: Node3D in home.get_node("structures").get_children():
			var hex := grid.get_hex_at_world_position(building.global_position)
			if building.name != &"questboard":
				check(building.global_position.is_equal_approx(hex.global_position), "Built-in building is off grid")
			check(not plots.has(hex.cube_id), "Built-in buildings share a plot")
			check(not home.is_gate_approach(grid, hex), "Built-in building blocks gate: " + str(building.name))
			plots[hex.cube_id] = true
		var board := home.get_node("structures/questboard") as Node3D
		var wall := home.get_node("walls/Wall_M02_00_W") as Node3D
		check(wall.to_local(board.global_position).is_equal_approx(Vector3(-0.7, 0, 0)), "Quest board is not against the inside wall")
		check(board.global_basis.z.dot(wall.global_basis.x) > 0.99, "Quest board has the wrong orientation")
		manager.player_instance.global_position = board.global_position + wall.global_basis.x * 0.55
		manager.player_instance.velocity = Vector3.ZERO
		for frame in 6: await get_tree().physics_frame
		check(manager.player_instance.interactor_component.current_triggers.has(board), "Wall-side quest board cannot be approached from inside")
		for hex: HexBase in home.get_settlement_hexes(grid):
			if home.is_gate_approach(grid, hex) or home.is_building_plot_occupied(grid, hex):
				check(not handler.can_place(forge_info, hex, null), "Occupied/gate plot allows construction")
				check(not handler.can_place_rotation(forge_info, hex, null, 0.0), "Rotation bypasses reserved plot")
		var forge := _forge(grid)
		if fixture == "arrival": check(forge == null, "Arrival inherited a forge")
		else:
			check(forge != null and home.is_construction_site_clear(grid, forge, true), "Saved forge still obstructs services or gate")
		if fixture == "foundation":
			var foundation := manager.campaign.get_foundation()
			check(foundation != null and foundation.quest.progress_tracker.get_count(preload("res://resources/item_info/wood_raw.tres")) == 1, "Migration lost delivered timber")
		# Re-loading a newly written save must preserve the selected site, rather
		# than moving a valid building again. Tracking follows the same root.
		if fixture == "village":
			var saved_coord := forge.cube_id
			manager.campaign.destination = forge.structure.instance
			manager.campaign.destination_name = "Blacksmith"
			check(SaveGames.save_slot("Placement migration"), "Cannot save migrated plot")
			check(SaveGames.load_slot(SaveGames.slot_id("Placement migration")), "Cannot reload migrated plot")
			result = await SaveGames.load_finished
			check(result[0], "Migrated save failed to restore")
			grid = Manager.instance.transport.get_grid()
			check(_forge(grid).cube_id == saved_coord, "Valid forge moved again on reload")
			check(Manager.instance.campaign.destination == _forge(grid).structure.instance, "Tracked building reference lost")
	# A legacy node reference must move with its building when first loaded.
	var data := SaveGames._read_document("res://tests/fixtures/legacy_foundation.json")
	data.campaign.destination = {"$node": {"$v3i": [0, 0, 0]}, "path": "buildable_forge"}
	data.campaign.destination_name = "Blacksmith"
	check(SaveGames._load_data(data), "Cannot load legacy tracked forge")
	var loaded: Array = await SaveGames.load_finished
	check(loaded[0], "Legacy tracked forge restore failed")
	var actual := _forge(Manager.instance.transport.get_grid())
	check(Manager.instance.campaign.destination == actual.structure.instance, "Legacy tracked reference did not migrate")
	print("SETTLEMENT PLACEMENT TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

extends Node
## Run separate processes with -- --seed=42 --steps=1 to compare scheduling.
var failures: Array[String] = []
var deadline := 0
var seed_value := 20261102
var steps := 128
var original_noise_seeds: Dictionary[RegionInfo, int] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	deadline = Time.get_ticks_msec() + 90000
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = argument.trim_prefix("--seed=").to_int()
		if argument.begins_with("--steps="): steps = argument.trim_prefix("--steps=").to_int()
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is MainGrid:
			for region: RegionInfo in DataManager.instance.regions:
				if region.noise != null: original_noise_seeds[region] = region.noise.seed
			node.world_seed = seed_value
			node.max_streaming_steps_per_frame = maxi(1, steps)
			node.generation_metrics.enabled = true
	)
	_run.call_deferred()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > deadline:
		push_error("World generation timed out")
		get_tree().quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _fingerprint(grid: HexGrid) -> String:
	var coordinates: Array[Vector3i] = grid.tiles.keys()
	coordinates.sort_custom(grid._sort_cube_ids)
	var records: PackedStringArray = []
	for coordinate: Vector3i in coordinates:
		var hex := grid.get_hex_at_cube_id(coordinate)
		var structure := hex.structure.structure_info.id if hex.structure != null else ""
		records.append("%s:%s:%s:%s:%s:%s" % [coordinate, hex.region.resource_path, hex.generated_elevation_units, hex.scene_instance.scene_info.id, snappedf(hex.rotation.y, 0.001), structure])
	if OS.get_cmdline_user_args().has("--record-layout"):
		var output := FileAccess.open("res://.godot/validation/layout-%d-%d-%d.txt" % [seed_value, steps, grid.tiles.size()], FileAccess.WRITE)
		output.store_string("\n".join(records))
	return "\n".join(records).sha256_text()

func _validate(grid: MainGrid) -> void:
	var valid := grid._validate_required_starting_structures()
	if not valid:
		var distances := grid._get_walk_reachable_distances(grid._get_starter_origin_hex())
		for structure: StructureInfo in grid._required_starting_structure_coords:
			for coordinate: Vector3i in grid._required_starting_structure_coords[structure]:
				print("INVALID START %s at %s distance=%s" % [structure.id, coordinate, distances.get(coordinate, -1)])
	check(valid, "Starter resource/village distance or reachability failed")
	for key: Vector2i in grid.chunks:
		var chunk := grid.chunks[key]
		check(chunk.is_post_processed and chunk.hexes.size() == grid.chunk_size.x * grid.chunk_size.y, "Incomplete chunk: " + str(key))
		for instance: SceneInstance in chunk.hexes:
			var hex := instance.node as HexBase
			check(grid.get_hex_at_cube_id(hex.cube_id) == hex, "Duplicate/stale tile: " + str(hex.cube_id))
			check(grid.grid_to_chunk_coords(hex.grid_id) == key, "Incorrect negative-coordinate chunk ownership")
	for coordinate: Vector3i in grid.tiles:
		var hex := grid.get_hex_at_cube_id(coordinate)
		check(hex.region_instance != null and hex.region_instance.hexes.get(coordinate) == hex, "Stale region membership")
		if grid._is_within_protected_chunk_elevation_buffer(hex.grid_id):
			check(hex.generated_elevation_units == 0, "Starter protected terrain is elevated")
		check(hex.region_instance.info == hex.region, "Tile is assigned to a different biome's component")
		var point_id: int = grid.pathfinder.cube_to_id.get(coordinate, -1)
		check((point_id >= 0) == hex.is_traversable(), "Navigation does not match terrain traversal")
		if point_id < 0: continue
		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			var neighbor := grid.get_hex_at_cube_id(coordinate + direction)
			if neighbor == null: continue
			var expected := grid.can_traverse_between(hex, neighbor) and not grid.pathfinder._is_blocked(coordinate, neighbor.cube_id)
			var neighbor_id: int = grid.pathfinder.cube_to_id.get(neighbor.cube_id, -1)
			var connected := neighbor_id >= 0 and grid.pathfinder.are_points_connected(point_id, neighbor_id)
			check(connected == expected, "Navigation edge is stale after streaming/replacement")
	if grid.generation_version >= 2:
		var occupied: Array[Vector3i] = grid._generated_structure_index.keys()
		for first in occupied.size():
			var definition := grid._generated_structure_index[occupied[first]]
			if not definition.is_quest_target: continue
			for second in range(first + 1, occupied.size()):
				if grid._generated_structure_index[occupied[second]] == definition:
					check(GridUtils.cube_distance(occupied[first], occupied[second]) > grid.same_discovery_spacing, "Repeated resource sites are too close")

func _check_world_boundary(grid: MainGrid) -> void:
	var limit := maxi(grid.world_chunk_radius, grid.chunk_radius)
	var before := grid.chunks.size()
	check(grid.generate_chunk(limit + 1, limit + 1) == null, "World expanded beyond its configured limit")
	check(grid.chunks.size() == before, "Rejected chunk was allocated")
	var edge := grid.generate_chunk(limit, limit)
	while grid.is_streaming_busy(): await get_tree().process_frame
	check(edge != null and edge.is_post_processed, "World boundary chunk could not finish")
	for instance: SceneInstance in edge.hexes:
		check(instance.node.region == DataManager.instance.get_ocean_descriptor(), "World edge lacks its coastal boundary")
	# Existing saves may contain chunks beyond a newly reduced world limit.
	var retained := Vector2i(limit + 3, 0)
	grid._retained_chunk_coords[retained] = true
	check(grid.generate_chunk(retained.x, retained.y) != null, "Saved outlying chunk was discarded")
	while grid.is_streaming_busy(): await get_tree().process_frame

func _check_discovery_pacing(grid: MainGrid) -> void:
	var randomizer := Manager.instance.regional.discoveries
	for site: QuestObjective in randomizer.sites:
		if is_instance_valid(site) and site.hex != null and grid.is_ancestor_of(site): site.hex.is_explored = true
	randomizer.refresh(grid)
	var disrupted: Array[Vector3i] = []
	var kinds: Dictionary[String, bool] = {}
	for site: QuestObjective in randomizer.sites:
		if not is_instance_valid(site) or site.hex == null or not grid.is_ancestor_of(site): continue
		var definition := randomizer.get_definition(site.discovery_id)
		if definition == null: continue
		kinds[definition.site_kind] = true
		if randomizer._is_opening_source(site, grid): check(definition.safe_for_opening, "Required opening source rolled a disruption")
		if not definition.is_disruption: continue
		for coordinate: Vector3i in disrupted:
			check(GridUtils.cube_distance(coordinate, site.hex.cube_id) > grid.disruption_spacing, "Disruptions formed a repair chain")
		disrupted.append(site.hex.cube_id)
	check(kinds.size() >= 2, "World lacks varied resource discoveries")

func _check_noise_and_options(grid: MainGrid) -> void:
	for region: RegionInfo in original_noise_seeds:
		check(region.noise.seed == original_noise_seeds[region], "Generation mutated shared biome noise")
	var probe := HexGrid.new()
	probe.generation_seed = seed_value + 1
	probe.region_options.assign(grid.region_options)
	probe._apply_seed_to_region_noise()
	for region: RegionInfo in grid._region_noise:
		check(grid._region_noise[region].seed == grid.get_seeded_int("region_noise:%s" % region.resource_path), "Another grid reseeded active world noise")
	probe.generate_ocean = false
	for y in range(-20, 21, 4):
		for x in range(-20, 21, 4):
			check(probe._get_region_for_grid_id(Vector2i(x, y)) != DataManager.instance.get_ocean_descriptor(), "Disabled ocean still generates ocean")
	probe.free()

func _check_obstacles(grid: MainGrid) -> void:
	var obstacle := Obstacle.new()
	var existing := HexAStar.obstacles[0]
	var a := existing.cube_id
	var b := existing.adjacent_id
	check(grid.pathfinder._is_blocked(a, b) and grid.pathfinder._is_blocked(b, a), "Wall lookup is not symmetric")
	var foreign_grid := HexGrid.new()
	foreign_grid.pathfinder = HexAStar.new(foreign_grid)
	check(not foreign_grid.pathfinder._is_blocked(a, b), "Walls leak between worlds")
	foreign_grid.free()
	# Register/remove a second wall on an already blocked edge. The original wins.
	existing.get_parent().add_child(obstacle)
	obstacle.cube_id = a
	obstacle.adjacent_id = b
	grid.pathfinder.apply_obstacle(obstacle)
	grid.pathfinder.remove_obstacle(obstacle, false)
	check(grid.pathfinder._is_blocked(a, b), "Removing a duplicate wall cleared the original edge")
	obstacle.free()
	grid.pathfinder.rebuild()

func _check_delayed_tiles(grid: MainGrid) -> void:
	var key := Vector2i(-grid.chunk_radius - 1, 0)
	var first_tile := key * grid.chunk_size
	var region := grid._get_region_for_grid_id(first_tile)
	var info := DataManager.instance.pick_scene_for_region(region, grid.create_rng("tile:%s:%s" % [first_tile.x, first_tile.y]))
	# Hold the real SceneInfo's callbacks for this one synchronous test section.
	var was_cached := info.is_cached
	info.is_cached = false
	info.is_queued = true
	grid.generate_chunk(key.x, key.y)
	while not grid._chunk_generation_queue.is_empty(): grid._process_chunk_generation_step()
	check(grid._pending_tile_loads > 0, "Pending asset callbacks were not counted")
	check(grid.is_streaming_busy(), "Generation reported idle while tiles were still loading")
	info.is_cached = was_cached
	info.is_queued = false
	info.cached.emit(info)
	while grid.is_streaming_busy(): await get_tree().process_frame
	check(grid._pending_tile_loads == 0, "Completed loads left generation busy")

func _run() -> void:
	while not SaveGames.save_block_reason().is_empty():
		var active := SceneManager.get_active_scene()
		if active != null and active.node is MainGrid:
			var candidate := active.node as MainGrid
			if candidate._initial_generation_completed and not candidate._finishing_generation and not candidate.is_streaming_busy() and not candidate.initialized and Manager.instance.active_settlement != null:
				var distances := candidate._get_walk_reachable_distances(candidate._get_starter_origin_hex())
				print("FAILED START seed=%d reachable=%d" % [seed_value, distances.size()])
				for structure: StructureInfo in candidate._required_starting_structure_coords:
					for coordinate: Vector3i in candidate._required_starting_structure_coords[structure]:
						print("PLACED %s at %s distance=%s" % [structure.id, coordinate, distances.get(coordinate, -1)])
				for structure: StructureInfo in candidate._get_required_structures():
					for mode in 4:
						print("%s mode=%d candidates=%d" % [structure.id, mode, (await candidate._get_required_structure_candidates(structure, distances, mode)).size()])
				get_tree().quit(1)
				return
		await get_tree().process_frame
	var grid := Manager.instance.transport.get_grid() as MainGrid
	_validate(grid)
	var initial_fingerprint := _fingerprint(grid)
	_check_noise_and_options(grid)
	check(_fingerprint(grid) == initial_fingerprint, "Noise isolation check changed active terrain")
	_check_obstacles(grid)
	check(_fingerprint(grid) == initial_fingerprint, "Obstacle check changed active terrain")
	var navigation_started := Time.get_ticks_usec()
	for repeat in 5: grid.pathfinder.rebuild()
	print("NAVIGATION average=%.2fms obstacles=%d" % [(Time.get_ticks_usec() - navigation_started) / 5000.0, HexAStar.obstacles.size()])
	print("INITIAL seed=%d steps=%d tiles=%d repaired=%d fingerprint=%s\n%s" % [seed_value, steps, grid.tiles.size(), grid.starter_terrain_repaired_tiles, _fingerprint(grid), grid.generation_metrics.report()])
	grid.generation_metrics.samples.clear()
	# Generate a contiguous outer strip across positive and negative chunk boundaries.
	var count := grid.chunks.size()
	for y in range(-grid.chunk_radius, grid.chunk_radius + 1):
		grid.generate_chunk(grid.chunk_radius + 1, y)
	while grid.is_streaming_busy(): await get_tree().process_frame
	_validate(grid)
	check(grid.chunks.size() == count + grid.chunk_radius * 2 + 1, "Streaming duplicated or skipped chunks")
	print("EXPANDED tiles=%d fingerprint=%s\n%s" % [grid.tiles.size(), _fingerprint(grid), grid.generation_metrics.report()])
	await _check_delayed_tiles(grid)
	await _check_world_boundary(grid)
	_check_discovery_pacing(grid)
	_validate(grid)
	if OS.get_cmdline_user_args().has("--roundtrip"):
		reparent(SaveGames)
		var fingerprint := _fingerprint(grid)
		var saved_regions: Dictionary[Vector3i, RegionInfo] = {}
		for coordinate: Vector3i in grid.tiles: saved_regions[coordinate] = grid.get_hex_at_cube_id(coordinate).region
		check(SaveGames.save_slot("World generation regression"), "Generated world cannot be saved")
		check(SaveGames.load_slot(SaveGames.slot_id("World generation regression")), "Generated world cannot be loaded")
		var result: Array = await SaveGames.load_finished
		check(result[0], "Generated world failed to restore")
		grid = Manager.instance.transport.get_grid() as MainGrid
		for coordinate: Vector3i in saved_regions:
			if grid.get_hex_at_cube_id(coordinate).region != saved_regions[coordinate]:
				print("RESTORE BIOME MISMATCH %s: %s -> %s" % [coordinate, saved_regions[coordinate].resource_path, grid.get_hex_at_cube_id(coordinate).region.resource_path])
		check(_fingerprint(grid) == fingerprint, "Terrain/structures changed after save/load")
		_validate(grid)
	if OS.get_cmdline_user_args().has("--capture"):
		for coordinate: Vector3i in grid.tiles: grid.get_hex_at_cube_id(coordinate).is_explored = true
		var overview := Camera3D.new()
		grid.add_child(overview)
		var center := grid._get_starter_origin_hex().global_position
		overview.global_position = center + Vector3(0, 48, 28)
		overview.look_at(center)
		overview.projection = Camera3D.PROJECTION_ORTHOGONAL
		overview.size = 72
		overview.current = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/validation/world-v2-overview-%d.png" % seed_value)
	print("WORLD GENERATION TEST %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

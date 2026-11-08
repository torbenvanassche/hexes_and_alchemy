class_name MainGrid extends HexGrid

@export var player_settlement: StructureInfo;
@export var target_position: Node3D;
@export_group("Starter Progression")
@export var required_starting_structures: Array[StructureInfo] = []
@export_range(1, 64, 1) var required_structure_max_walk_distance := 24
## Repair isolated starter islands only when normal required placement fails.
@export var repair_failed_starter_terrain := true
var starter_terrain_repaired_tiles := 0
var _finishing_generation := false
var starter_layout: StarterLayoutPlan
@export_group("Nearby Settlement")
## One passive settlement is placed before resource scattering. Empty disables it.
@export var nearby_settlement: StructureInfo
## Walking distance in hex steps from the main settlement's centre.
@export_range(1, 128, 1) var settlement_min_walk_distance := 8
@export_range(1, 128, 1) var settlement_max_walk_distance := 16
const REQUIRED_PLACEMENT_STANDARD := 0
const REQUIRED_PLACEMENT_ALLOW_EXCLUDED := 1
const REQUIRED_PLACEMENT_ALLOW_SETTLEMENT_SPACING := 2
const REQUIRED_PLACEMENT_ALLOW_RESERVED := 3
var _required_starting_structure_coords: Dictionary[StructureInfo, Array] = {}

func _get_required_structures() -> Array[StructureInfo]:
	var structures: Array[StructureInfo] = required_starting_structures.duplicate()
	if nearby_settlement != null and not structures.has(nearby_settlement):
		structures.append(nearby_settlement)
	return structures

func _within_required_walk_range(structure: StructureInfo, distance: int) -> bool:
	if structure == nearby_settlement:
		var minimum := maxi(1, settlement_min_walk_distance)
		return distance >= minimum and distance <= maxi(minimum, settlement_max_walk_distance)
	return distance <= required_structure_max_walk_distance

func _ready() -> void:
	await super()

func _prepare_terrain_plan() -> void:
	if generation_version < 2: return
	loading_progress.report(0.02, "LOADING_PREPARING")
	startup_budget = GenerationBudget.new(self)
	starter_layout = StarterLayoutPlan.new()
	await starter_layout.build(self, startup_budget)
	startup_budget.finish_slice()
	
func _on_map_ready() -> void:
	SceneManager.set_active_scene(DataManager.instance.node_to_info(self));
	_queue_starting_settlement();

func _queue_starting_settlement() -> void:
	if player_settlement == null:
		Debug.err("No player settlement is configured for the main grid.");
		_finish_map_generation();
		return;
	
	if player_settlement.is_cached:
		settlement_created(player_settlement);
		return;
	
	if not player_settlement.cached.is_connected(settlement_created):
		player_settlement.cached.connect(settlement_created, CONNECT_ONE_SHOT)
	
	if not player_settlement.is_queued:
		SceneManager.scene_cache.queue(player_settlement);
	
func settlement_created(sI: StructureInfo) -> void:
	var center_hex: HexBase = chunks[Vector2i.ZERO].get_best_structure_hex();
	if starter_layout != null: center_hex = get_hex_at_grid_id(starter_layout.home)
	if center_hex == null:
		Debug.err("Could not place the starting settlement because the center hex was not found.");
		_finish_map_generation();
		return;
	
	if not center_hex.structure_loaded.is_connected(_on_starting_structure_loaded):
		center_hex.structure_loaded.connect(_on_starting_structure_loaded, CONNECT_ONE_SHOT)
	
	center_hex.region_instance.register_structure(center_hex.cube_id, sI)
	center_hex.set_structure(sI);

func _finish_map_generation() -> void:
	if initialized or _finishing_generation:
		return;
	_finishing_generation = true
	startup_budget = GenerationBudget.new(self)
	var started := generation_metrics.begin()
	_prepare_settlement_geometry()
	loading_progress.report(0.60, "LOADING_PATHS")
	await ensure_elevated_areas_reachable_from(_get_starter_origin_hex())
	await _ensure_elevated_areas_have_entrances()
	generation_metrics.end("initial_slopes_elapsed", started)
	started = generation_metrics.begin()
	_register_navigation_obstacles()
	loading_progress.report(0.72, "LOADING_NAVIGATION")
	await pathfinder.rebuild_budgeted(startup_budget);
	generation_metrics.end("initial_navigation_elapsed", started)
	started = generation_metrics.begin()
	loading_progress.report(0.76, "LOADING_SETTLEMENTS")
	var required_structures_placed := await _place_required_starting_structures(false)
	loading_progress.report(0.80, "LOADING_SETTLEMENTS")
	if not required_structures_placed and repair_failed_starter_terrain:
		starter_terrain_repaired_tiles = await StarterTerrainRepair.repair(self, _get_starter_origin_hex())
		_register_navigation_obstacles()
		await pathfinder.rebuild_budgeted(startup_budget)
		required_structures_placed = await _place_required_starting_structures()
	elif not required_structures_placed:
		_report_missing_starting_structures(_get_required_structures())
	generation_metrics.end("required_structures_elapsed", started)
	started = generation_metrics.begin()
	_prepare_settlement_geometry()
	# Use the same incremental worker as exploration instead of scattering every
	# region in one uninterrupted call. Keep the original region order/RNG keys.
	for region: RegionInfo in region_instances:
		for instance: RegionInstance in region_instances[region]:
			var job := GenerationJobs.RegionStructures.new()
			job.region_instance = instance
			job.candidates.assign(instance.hexes.keys())
			_structure_generation_queue.append(job)
	startup_budget.finish_slice()
	var initial_structure_jobs := maxi(1, _structure_generation_queue.size())
	while not _structure_generation_queue.is_empty() or _pending_structure_loads > 0:
		loading_progress.report(0.82 + 0.10 * (1.0 - float(_structure_generation_queue.size()) / initial_structure_jobs), "LOADING_RESOURCES")
		await get_tree().process_frame
	startup_budget.restart_after_wait()
	generation_metrics.end("initial_scatter_elapsed", started)
	loading_progress.report(0.94, "LOADING_NAVIGATION")
	started = generation_metrics.begin()
	_register_navigation_obstacles()
	await pathfinder.rebuild_budgeted(startup_budget);
	generation_metrics.end("final_navigation_elapsed", started)
	if not required_structures_placed or not _validate_required_starting_structures():
		_finishing_generation = false
		Debug.err("Required starting structures could not be generated within reach of the player (seed %d)." % generation_seed)
		loading_progress.fail(tr("LOADING_GENERATION_FAILED") % generation_seed)
		return
	_finishing_generation = false
	startup_budget.finish_slice()
	mark_initialized();

func _prepare_settlement_geometry() -> void:
	for settlement: Settlement in Manager.instance.settlements.duplicate():
		if is_ancestor_of(settlement): settlement.ensure_world_ready()

func _register_navigation_obstacles() -> void:
	for obstacle: Obstacle in find_children("*", "Obstacle", true, false):
		obstacle.register_with_grid(self)

func _place_required_starting_structures(report_failure: bool = true) -> bool:
	_required_starting_structure_coords.clear()
	if _get_required_structures().is_empty():
		return true
	var origin_hex := _get_starter_origin_hex()
	if origin_hex == null:
		Debug.err("Could not find a starting hex for required structures.")
		return false

	var reachable_distances := _get_walk_reachable_distances(origin_hex)
	if reachable_distances.is_empty():
		Debug.err("No walkable tiles are reachable from the starting settlement.")
		return false

	var missing_structures := _collect_missing_required_structures(reachable_distances)
	if missing_structures.is_empty():
		return true

	var placement_modes: Array[int] = [
		REQUIRED_PLACEMENT_STANDARD,
		REQUIRED_PLACEMENT_ALLOW_EXCLUDED,
		REQUIRED_PLACEMENT_ALLOW_SETTLEMENT_SPACING,
		REQUIRED_PLACEMENT_ALLOW_RESERVED,
	]
	for placement_mode in placement_modes:
		var plan := await _plan_required_structure_placements(
			missing_structures,
			reachable_distances,
			placement_mode
		)
		if plan.is_empty():
			continue
		var failed_structures := _apply_required_structure_plan(plan, placement_mode)
		if failed_structures.is_empty():
			return true
		missing_structures = failed_structures

	if report_failure: _report_missing_starting_structures(missing_structures)
	return false

func _report_missing_starting_structures(missing_structures: Array[StructureInfo]) -> void:
	for required_structure in missing_structures:
		if required_structure == nearby_settlement:
			Debug.err("Could not place nearby settlement '%s' within %d–%d walking steps. Adjust Nearby Settlement distance limits or generate a larger world." % [required_structure.id, settlement_min_walk_distance, maxi(settlement_min_walk_distance, settlement_max_walk_distance)])
		else:
			Debug.err("Could not place required starting structure: %s" % required_structure.id)

func _get_starter_origin_hex() -> HexBase:
	if Manager.instance == null or Manager.instance.active_settlement == null:
		return null
	return Manager.instance.active_settlement.get_parent() as HexBase

func _get_walk_reachable_distances(origin: HexBase) -> Dictionary[Vector3i, int]:
	var max_distance := required_structure_max_walk_distance
	if nearby_settlement != null:
		max_distance = maxi(max_distance, maxi(settlement_min_walk_distance, settlement_max_walk_distance))
	return pathfinder.get_reachable_distances(
		origin.cube_id,
		max_distance
	)

func _collect_missing_required_structures(reachable_distances: Dictionary[Vector3i, int]) -> Array[StructureInfo]:
	var missing: Array[StructureInfo] = []
	var claimed_existing: Dictionary[Vector3i, bool] = {}
	for required_structure in _get_required_structures():
		if required_structure == null:
			continue
		var existing_coord := _find_existing_required_structure(
			required_structure,
			reachable_distances,
			claimed_existing
		)
		if existing_coord != Vector3i.MAX:
			claimed_existing[existing_coord] = true
			_record_required_structure(required_structure, existing_coord)
		else:
			missing.append(required_structure)
	return missing

func _find_existing_required_structure(
	required_structure: StructureInfo,
	reachable_distances: Dictionary[Vector3i, int],
	claimed_existing: Dictionary[Vector3i, bool]
) -> Vector3i:
	var coords: Array[Vector3i] = []
	for region_list in region_instances.values():
		for region_instance: RegionInstance in region_list:
			for cube_id: Vector3i in region_instance.structures.keys():
				if region_instance.structures[cube_id] != required_structure:
					continue
				if not reachable_distances.has(cube_id) or claimed_existing.has(cube_id):
					continue
				if not _within_required_walk_range(required_structure, int(reachable_distances[cube_id])):
					continue
				coords.append(cube_id)
	coords.sort_custom(_sort_cube_ids)
	return coords[0] if not coords.is_empty() else Vector3i.MAX

func _plan_required_structure_placements(
	required_structures: Array[StructureInfo],
	reachable_distances: Dictionary[Vector3i, int],
	placement_mode: int
) -> Array[GenerationJobs.RequiredPlacement]:
	var entries: Array[GenerationJobs.RequiredCandidates] = []
	for required_structure in required_structures:
		if startup_budget != null: await startup_budget.checkpoint()
		var candidates := await _get_required_structure_candidates(
			required_structure,
			reachable_distances,
			placement_mode
		)
		if candidates.is_empty():
			return []
		var entry := GenerationJobs.RequiredCandidates.new()
		entry.structure = required_structure
		entry.candidates = candidates
		entries.append(entry)
	entries.sort_custom(
		func(a: GenerationJobs.RequiredCandidates, b: GenerationJobs.RequiredCandidates) -> bool:
			var a_candidates := a.candidates
			var b_candidates := b.candidates
			if a_candidates.size() != b_candidates.size():
				return a_candidates.size() < b_candidates.size()
			return a.structure.id < b.structure.id
	)

	var reservations: Array[GenerationJobs.RequiredPlacement] = []
	var assignments: Array[GenerationJobs.RequiredPlacement] = []
	if await _build_required_structure_plan(entries, 0, reservations, assignments):
		return assignments
	return []

func _get_required_structure_candidates(
	required_structure: StructureInfo,
	reachable_distances: Dictionary[Vector3i, int],
	placement_mode: int
) -> Array[HexBase]:
	var candidates: Array[HexBase] = []
	var origin := _get_starter_origin_hex()
	for cube_id: Vector3i in reachable_distances.keys():
		if startup_budget != null: await startup_budget.checkpoint()
		if not _within_required_walk_range(required_structure, int(reachable_distances[cube_id])):
			continue
		# Footprint/passage repairs can shorten a winding route after placement.
		# Keep the physical lower bound too, so the village cannot become too near.
		if required_structure == nearby_settlement and origin != null:
			if GridUtils.cube_distance(origin.cube_id, cube_id) < maxi(1, settlement_min_walk_distance):
				continue
		var hex := get_hex_at_cube_id(cube_id)
		if hex == null or hex.region_instance == null:
			continue
		if not hex.region_instance.can_place_required_structure_at(
			cube_id,
			required_structure,
			placement_mode
		):
			continue
		if (
			placement_mode >= REQUIRED_PLACEMENT_ALLOW_SETTLEMENT_SPACING
			and _required_structure_conflicts_with_recorded_placements(
				cube_id,
				required_structure
			)
		):
			continue
		candidates.append(hex)
	candidates.sort_custom(
		func(a: HexBase, b: HexBase) -> bool:
			if starter_layout != null and starter_layout.locations.has(required_structure):
				var planned := starter_layout.locations[required_structure]
				if a.cube_id == planned and b.cube_id != planned: return true
				if b.cube_id == planned and a.cube_id != planned: return false
			var a_distance := int(reachable_distances[a.cube_id])
			var b_distance := int(reachable_distances[b.cube_id])
			if required_structure == nearby_settlement:
				var a_seed := get_seeded_int("village_candidate:%s" % a.cube_id)
				var b_seed := get_seeded_int("village_candidate:%s" % b.cube_id)
				if a_seed != b_seed:
					return a_seed < b_seed
			if a_distance != b_distance:
				if placement_mode >= REQUIRED_PLACEMENT_ALLOW_SETTLEMENT_SPACING:
					return a_distance > b_distance
				return a_distance < b_distance
			var a_rank := get_seeded_int(
				"required_candidate:%s:%s" % [required_structure.id, a.cube_id]
			)
			var b_rank := get_seeded_int(
				"required_candidate:%s:%s" % [required_structure.id, b.cube_id]
			)
			if a_rank != b_rank:
				return a_rank < b_rank
			return _sort_cube_ids(a.cube_id, b.cube_id)
	)
	return candidates

func _required_structure_conflicts_with_recorded_placements(
	cube_id: Vector3i,
	required_structure: StructureInfo
) -> bool:
	for other_structure in _required_starting_structure_coords.keys():
		var required_distance := (
			maxi(required_structure.required_space_radius, other_structure.required_space_radius)
			+ maxi(
				required_structure.minimum_distance_from_other_structures,
				other_structure.minimum_distance_from_other_structures
			)
			+ 1
		)
		var other_coords := _required_starting_structure_coords[other_structure] as Array
		for other_cube_id in other_coords:
			if GridUtils.cube_distance(cube_id, other_cube_id) <= required_distance:
				return true
	return false

func _build_required_structure_plan(
	entries: Array[GenerationJobs.RequiredCandidates],
	index: int,
	reservations: Array[GenerationJobs.RequiredPlacement],
	assignments: Array[GenerationJobs.RequiredPlacement]
) -> bool:
	if index >= entries.size():
		return true
	var entry := entries[index]
	var required_structure := entry.structure
	var candidates := entry.candidates
	for candidate in candidates:
		if startup_budget != null: await startup_budget.checkpoint()
		if _required_structure_conflicts_with_reservations(
			candidate.cube_id,
			required_structure,
			reservations
		):
			continue
		var assignment := GenerationJobs.RequiredPlacement.new()
		assignment.structure = required_structure
		assignment.cube_id = candidate.cube_id
		reservations.append(assignment)
		assignments.append(assignment)
		if await _build_required_structure_plan(entries, index + 1, reservations, assignments):
			return true
		assignments.pop_back()
		reservations.pop_back()
	return false

func _required_structure_conflicts_with_reservations(
	cube_id: Vector3i,
	required_structure: StructureInfo,
	reservations: Array[GenerationJobs.RequiredPlacement]
) -> bool:
	for reservation in reservations:
		var other := reservation.structure
		var required_distance := (
			maxi(required_structure.required_space_radius, other.required_space_radius)
			+ maxi(
				required_structure.minimum_distance_from_other_structures,
				other.minimum_distance_from_other_structures
			)
			+ 1
		)
		if GridUtils.cube_distance(cube_id, reservation.cube_id) <= required_distance:
			return true
	return false

func _apply_required_structure_plan(
	plan: Array[GenerationJobs.RequiredPlacement],
	placement_mode: int
) -> Array[StructureInfo]:
	var failed: Array[StructureInfo] = []
	for assignment in plan:
		var required_structure := assignment.structure
		var cube_id := assignment.cube_id
		var hex := get_hex_at_cube_id(cube_id)
		if (
			hex == null
			or hex.region_instance == null
			or not hex.region_instance.try_place_required_structure_at(
				cube_id,
				required_structure,
				placement_mode
			)
		):
			failed.append(required_structure)
			continue
		_record_required_structure(required_structure, cube_id)
	return failed

func _record_required_structure(required_structure: StructureInfo, cube_id: Vector3i) -> void:
	if not _required_starting_structure_coords.has(required_structure):
		_required_starting_structure_coords[required_structure] = [] as Array[Vector3i]
	var coords := _required_starting_structure_coords[required_structure] as Array[Vector3i]
	coords.append(cube_id)

func _validate_required_starting_structures() -> bool:
	if _get_required_structures().is_empty():
		return true
	var origin_hex := _get_starter_origin_hex()
	if origin_hex == null:
		return false
	var reachable_distances := _get_walk_reachable_distances(origin_hex)
	var consumed: Dictionary[StructureInfo, int] = {}
	for required_structure in _get_required_structures():
		if required_structure == null:
			continue
		var index := int(consumed.get(required_structure, 0))
		var coords := _required_starting_structure_coords.get(required_structure, []) as Array
		if index >= coords.size():
			return false
		var cube_id := coords[index] as Vector3i
		consumed[required_structure] = index + 1
		var hex := get_hex_at_cube_id(cube_id)
		if hex == null or hex.structure == null:
			return false
		if hex.structure.structure_info != required_structure:
			return false
		if not reachable_distances.has(cube_id):
			return false
		if not _within_required_walk_range(required_structure, int(reachable_distances[cube_id])):
			return false
	return true

func _on_starting_structure_loaded(_structure_info: StructureInfo, structure_node: Node) -> void:
	if structure_node is Settlement:
		var settlement := structure_node as Settlement;
		Manager.instance.set_active_settlement(settlement);
		Manager.instance.spawn_in_settlement();

	_finish_map_generation();

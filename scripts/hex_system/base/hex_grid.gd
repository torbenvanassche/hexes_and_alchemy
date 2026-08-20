class_name HexGrid extends Node3D

var pointy_top: bool = false;
var _spacing: float = 0.25

##The radius for initial chunk generation, more can be generated on demand
@export_group("Chunk Generation")
@export var chunk_radius: int = 3;
@export var chunk_size: Vector2i = Vector2i(4, 4):
	set(value):
		chunk_size = Vector2i(maxi(1, value.x), maxi(1, value.y))
@export var generate_chunks_near_player := true
@export_range(0, 8, 1) var player_chunk_generation_radius := 1
@export var grid_name: String;

@export_group("Chunk Streaming")
@export_range(0.25, 16.0, 0.25) var runtime_streaming_budget_ms := 3.0
@export_range(0.25, 33.0, 0.25) var initial_streaming_budget_ms := 10.0
@export_range(1, 256, 1) var max_streaming_steps_per_frame := 128

## Set this to reproduce a specific world. Leave it at 0 to generate a new seed on each run.
@export_group("World Seed")
@export var world_seed: int = 0;
var generation_seed: int = 0;

@export_group("Elevation")
@export var generate_elevation := true
@export_range(0.01, 5.0, 0.01) var elevation_unit_height := 0.5
@export_range(4, 32, 1) var elevation_feature_cell_size := 14
@export_range(0.0, 1.0, 0.01) var elevation_feature_density := 0.65
@export_range(3, 16, 1) var elevation_min_radius := 6
@export_range(3, 16, 1) var elevation_max_radius := 10
@export var keep_protected_chunks_flat := true
@export_range(0, 4, 1) var protected_chunk_elevation_buffer := 2
@export var generate_slope_entrances := true
@export_range(0.05, 1.0, 0.05) var slope_entrance_density := 0.50
@export_range(1, 8, 1) var minimum_slope_entrances_per_area := 3
@export_range(4, 64, 1) var elevated_tiles_per_extra_slope_entrance := 8

##Optionally define custom regions that can generate if you don't want to use the global setting
@export_group("Regions")
@export var custom_regions: Array[RegionInfo] = []
@export var generate_ocean: bool = true;

##Whether or not to merge the general list of regions as part of the generation process
@export var use_global_regions: bool = true;
var region_options: Array[RegionInfo] = []

var initialized: bool = false;

##Chunks that should not generate water or structures
@export_group("Structure Rules")
@export var protected_chunks: Array[Vector2i] = []
@export_range(0, 4, 1) var protected_chunk_feature_buffer := 1
@export_range(0, 8, 1) var settlement_feature_buffer := 1

static var RADIUS_IN: float = 1.0
const HALF_SLOPE_INFO_PATH := "res://resources/scene_info/hex/hex_grass_slope_half.tres"

var chunks: Dictionary[Vector2i, HexChunk] = {}
var region_instances: Dictionary[RegionInfo, Array] = {} 
var tiles: Dictionary[Vector3i, SceneInstance] = {}
var elevation_areas: Dictionary[int, ElevationArea] = {}
var generated_regions: Dictionary[Vector2i, RegionInfo] = {}
var generated_elevations: Dictionary[Vector2i, int] = {}
var _generated_structure_index: Dictionary[Vector3i, StructureInfo] = {}
var _maximum_structure_space_radius := 0
var _maximum_structure_minimum_distance := 0
var _settlement_structure_exclusion_cache: Dictionary[Vector3i, bool] = {}
var _settlement_structure_exclusion_cache_valid := false
var _elevation_feature_cache: Dictionary[Vector3i, Vector4] = {}
var _cached_spacing := Vector2.ZERO
var _pathfinder_rebuild_queued := false
var _chunk_generation_queue: Array[Dictionary] = []
var _tile_instantiation_queue: Array[Dictionary] = []
var _chunk_post_process_queue: Array[Dictionary] = []
var _pending_structure_hexes: Dictionary[Vector3i, bool] = {}
var _structure_generation_queue: Array[Dictionary] = []
var _initial_generation_completed := false
var _half_slope_info: HexInfo
var _cached_slope_profile: HexSlope
@onready var pathfinder: HexAStar = HexAStar.new(self)

signal generated();
signal initialized_changed();

enum ChunkDir {
	NORTH,
	EAST,
	SOUTH,
	WEST
}

const CHUNK_DIR_VECTORS: Dictionary[ChunkDir, Vector2i] = {
	ChunkDir.NORTH: Vector2i(0, -1),
	ChunkDir.EAST:  Vector2i(1, 0),
	ChunkDir.SOUTH: Vector2i(0, 1),
	ChunkDir.WEST:  Vector2i(-1, 0),
}

func _init() -> void:
	generated.connect(_on_map_ready, CONNECT_ONE_SHOT);

func _ready() -> void:
	_initialize_generation_seed()
	_cached_spacing = GridUtils.get_spacing(RADIUS_IN, _spacing, pointy_top)

	if use_global_regions:
		region_options = DataManager.instance.regions.duplicate()
	for region in custom_regions:
		if not region_options.has(region):
			region_options.append(region);

	_apply_seed_to_region_noise()

	for chunk_coords in _get_initial_chunk_coords():
		generate_chunk(chunk_coords.x, chunk_coords.y)

func _process(_delta: float) -> void:
	_process_streaming_work()

func _exit_tree() -> void:
	if is_instance_valid(_cached_slope_profile):
		_cached_slope_profile.free()
	_cached_slope_profile = null

func _process_streaming_work() -> void:
	var budget_ms := initial_streaming_budget_ms if not _initial_generation_completed else runtime_streaming_budget_ms
	var deadline_usec := Time.get_ticks_usec() + int(budget_ms * 1000.0)
	var steps := 0

	while steps < max_streaming_steps_per_frame:
		var did_work := false
		if not _tile_instantiation_queue.is_empty():
			did_work = _process_tile_instantiation_step()
		elif not _chunk_generation_queue.is_empty():
			did_work = _process_chunk_generation_step()
		elif not _chunk_post_process_queue.is_empty():
			did_work = _process_chunk_post_process_step()
		elif not _pending_structure_hexes.is_empty():
			did_work = _prepare_structure_generation_jobs()
		elif not _structure_generation_queue.is_empty():
			did_work = _process_structure_generation_step()

		if not did_work:
			break
		steps += 1
		if Time.get_ticks_usec() >= deadline_usec:
			break

func _get_initial_chunk_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for cy in range(-chunk_radius, chunk_radius + 1):
		for cx in range(-chunk_radius, chunk_radius + 1):
			coords.append(Vector2i(cx, cy))
	coords.sort_custom(_sort_chunks_center_first)
	return coords

func _sort_chunks_center_first(a: Vector2i, b: Vector2i) -> bool:
	var a_ring := maxi(absi(a.x), absi(a.y))
	var b_ring := maxi(absi(b.x), absi(b.y))
	if a_ring != b_ring:
		return a_ring < b_ring

	var a_distance := a.length_squared()
	var b_distance := b.length_squared()
	if a_distance != b_distance:
		return a_distance < b_distance

	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x

func _initialize_generation_seed() -> void:
	if world_seed != 0:
		generation_seed = world_seed
	else:
		generation_seed = int(Time.get_unix_time_from_system() * 1000000.0) + Time.get_ticks_usec() + get_instance_id()
		world_seed = generation_seed

	_update_seed_label();

func _update_seed_label() -> void:
	var seed_label := get_tree().root.find_child("WorldSeedLabel", true, false) as Label
	if seed_label == null:
		return;

	seed_label.text = tr("WORLD_SEED_LABEL") % generation_seed;

func _apply_seed_to_region_noise() -> void:
	var seeded_regions := region_options.duplicate()
	var ocean_descriptor := DataManager.instance.get_ocean_descriptor()
	if ocean_descriptor != null and not seeded_regions.has(ocean_descriptor):
		seeded_regions.append(ocean_descriptor)

	for region: RegionInfo in seeded_regions:
		if region == null or region.noise == null:
			continue

		region.noise.seed = get_seeded_int("region_noise:%s" % region.resource_path)

func get_seeded_int(key: String) -> int:
	var mixed_seed := generation_seed + (int(key.hash()) * 1103515245) + 12345
	return absi(mixed_seed % 2147483647)

func create_rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_seeded_int(key);
	return rng;

func mark_initialized() -> void:
	if initialized:
		return;
	initialized = true;
	initialized_changed.emit();

func _on_map_ready() -> void:
	_ensure_elevated_areas_have_entrances()
	SceneManager.set_active_scene(DataManager.instance.node_to_info(self));
	
	generate_structures();
	pathfinder.rebuild()
	mark_initialized();

func generate_structures() -> void:
	for reg in region_instances.keys():
		for rI: RegionInstance in region_instances[reg]:
			rI.generate_structures_for_region();
	
func has_chunk(cx: int, cy: int) -> bool:
	return chunks.has(Vector2i(cx, cy));

func can_generate_structures_on_grid_id(grid_id: Vector2i) -> bool:
	if _is_within_protected_chunk_buffer(grid_id):
		return false
	return not _is_near_settlement(GridUtils.offset_to_cube(grid_id, pointy_top))

func can_generate_structures_on_hex(hex: HexBase) -> bool:
	return hex != null and not hex is HexSlope and can_generate_structures_on_grid_id(hex.grid_id)

func register_generated_structure(cube_id: Vector3i, structure_info: StructureInfo) -> void:
	if structure_info == null:
		return
	_generated_structure_index[cube_id] = structure_info
	_maximum_structure_space_radius = maxi(_maximum_structure_space_radius, structure_info.required_space_radius)
	_maximum_structure_minimum_distance = maxi(
		_maximum_structure_minimum_distance,
		structure_info.minimum_distance_from_other_structures
	)

func unregister_generated_structure(cube_id: Vector3i, structure_info: StructureInfo = null) -> void:
	if structure_info != null and _generated_structure_index.get(cube_id) != structure_info:
		return
	_generated_structure_index.erase(cube_id)

func has_generated_structure_in_radius(center: Vector3i, radius: int) -> bool:
	for dx in range(-radius, radius + 1):
		for dy in range(maxi(-radius, -dx - radius), mini(radius, -dx + radius) + 1):
			var cube := center + Vector3i(dx, dy, -dx - dy)
			if _generated_structure_index.has(cube):
				return true
	return false

func has_generated_structure_too_close(center: Vector3i, candidate: StructureInfo) -> bool:
	var search_radius := (
		maxi(candidate.required_space_radius, _maximum_structure_space_radius)
		+ maxi(candidate.minimum_distance_from_other_structures, _maximum_structure_minimum_distance)
		+ 1
	)
	for dx in range(-search_radius, search_radius + 1):
		for dy in range(
			maxi(-search_radius, -dx - search_radius),
			mini(search_radius, -dx + search_radius) + 1
		):
			var other_pos := center + Vector3i(dx, dy, -dx - dy)
			var other := _generated_structure_index.get(other_pos) as StructureInfo
			if other == null:
				continue
			var required_distance := (
				maxi(candidate.required_space_radius, other.required_space_radius)
				+ maxi(
					candidate.minimum_distance_from_other_structures,
					other.minimum_distance_from_other_structures
				)
				+ 1
			)
			if GridUtils.cube_distance(center, other_pos) <= required_distance:
				return true
	return false

func can_generate_slope_entrance_on_hex(hex: HexBase) -> bool:
	if hex == null:
		return false
	return not _is_near_settlement(hex.cube_id)

func invalidate_settlement_structure_exclusion_cache() -> void:
	_settlement_structure_exclusion_cache_valid = false

func _is_near_settlement(cube_id: Vector3i) -> bool:
	if Manager.instance == null:
		return false
	if not _settlement_structure_exclusion_cache_valid:
		_rebuild_settlement_structure_exclusion_cache()
	return _settlement_structure_exclusion_cache.has(cube_id)

func _rebuild_settlement_structure_exclusion_cache() -> void:
	_settlement_structure_exclusion_cache.clear()
	for settlement: Settlement in Manager.instance.settlements:
		if settlement == null or not is_instance_valid(settlement):
			continue
		if not is_ancestor_of(settlement):
			continue

		var exclusion_radius := settlement.structure_invalid_range + settlement_feature_buffer
		for settlement_hex in settlement.get_settlement_hexes(self):
			if settlement_hex == null:
				continue
			for dx in range(-exclusion_radius, exclusion_radius + 1):
				for dy in range(
					maxi(-exclusion_radius, -dx - exclusion_radius),
					mini(exclusion_radius, -dx + exclusion_radius) + 1
				):
					var offset := Vector3i(dx, dy, -dx - dy)
					_settlement_structure_exclusion_cache[settlement_hex.cube_id + offset] = true
	_settlement_structure_exclusion_cache_valid = true
	
func get_structured_hexes() -> Array[HexBase]:
	var instances: Array[HexBase] = []
	for region_instance in region_instances.keys():
		var region := _get_instances_for_region(region_instance);
		for instance: RegionInstance in region:
			instances.append_array(instance.get_structured_hexes());
	return instances;
	
func _get_instances_for_region(region: RegionInfo) -> Array:
	if not region_instances.has(region):
		region_instances[region] = [];
	return region_instances[region];
		
func create_hex(
	grid_id: Vector2i,
	info: SceneInfo,
	region: RegionInfo,
	generated_elevation: int = -1
) -> SceneInstance:
	var scene_instance := info.get_instance();
	var hex := scene_instance.node;
	
	hex.region = region;
	var spacing := _cached_spacing

	hex.grid_id = grid_id;
	hex.cube_id = GridUtils.offset_to_cube(grid_id, pointy_top)
	
	tiles[hex.cube_id] = scene_instance;

	var pos := Vector3.ZERO;
	if pointy_top:
		pos.x = grid_id.x * spacing.x
		pos.z = grid_id.y * spacing.y + (grid_id.x & 1) * (spacing.y / 2)
	else:
		pos.x = grid_id.x * spacing.x + (grid_id.y & 1) * (spacing.x / 2)
		pos.z = grid_id.y * spacing.y
	hex.position = pos
	if generated_elevation < 0:
		generated_elevation = get_generated_elevation_units(grid_id)
	hex.generated_elevation_units = generated_elevation
	hex.set_elevation(hex.generated_elevation_units, elevation_unit_height)
	return scene_instance;

func _get_elevation_units(grid_id: Vector2i, region: RegionInfo) -> int:
	if not generate_elevation:
		return 0
	if keep_protected_chunks_flat and _is_within_protected_chunk_elevation_buffer(grid_id):
		return 0
	if region == DataManager.instance.get_ocean_descriptor():
		return 0

	var cell_size := maxi(1, elevation_feature_cell_size)
	var max_radius := maxi(elevation_min_radius, elevation_max_radius)
	var search_radius := ceili(float(max_radius) / float(cell_size)) + 1
	var cell := Vector2i(
		floori(float(grid_id.x) / float(cell_size)),
		floori(float(grid_id.y) / float(cell_size))
	)
	var elevation := 0

	for y in range(cell.y - search_radius, cell.y + search_radius + 1):
		for x in range(cell.x - search_radius, cell.x + search_radius + 1):
			elevation = maxi(elevation, _get_elevation_feature_units(grid_id, Vector2i(x, y), cell_size))
			if elevation == 2:
				return _limit_elevation_at_flat_boundaries(grid_id, elevation)

	return _limit_elevation_at_flat_boundaries(grid_id, elevation)

func get_generated_elevation_units(grid_id: Vector2i) -> int:
	if generated_elevations.has(grid_id):
		return int(generated_elevations[grid_id])
	var elevation := _get_elevation_units(grid_id, _get_region_for_grid_id(grid_id))
	generated_elevations[grid_id] = elevation
	return elevation

func _get_elevation_feature_units(grid_id: Vector2i, cell: Vector2i, cell_size: int) -> int:
	var feature := _get_cached_elevation_feature(cell, cell_size)
	var outer_radius := int(feature.z)
	if outer_radius < 0:
		return 0
	var center := Vector2i(int(feature.x), int(feature.y))
	var plateau_radius := int(feature.w)
	var distance := GridUtils.cube_distance(
		GridUtils.offset_to_cube(grid_id, pointy_top),
		GridUtils.offset_to_cube(center, pointy_top)
	)

	if distance <= plateau_radius:
		return 2
	if distance <= outer_radius:
		return 1
	return 0

func _get_cached_elevation_feature(cell: Vector2i, cell_size: int) -> Vector4:
	var cache_key := Vector3i(cell.x, cell.y, cell_size)
	if _elevation_feature_cache.has(cache_key):
		return _elevation_feature_cache[cache_key]

	var rng := create_rng("elevation_feature_v1:%s:%s" % [cell.x, cell.y])
	if rng.randf() > elevation_feature_density:
		var empty_feature := Vector4(0.0, 0.0, -1.0, 0.0)
		_elevation_feature_cache[cache_key] = empty_feature
		return empty_feature

	var center := Vector2i(
		cell.x * cell_size + rng.randi_range(0, cell_size - 1),
		cell.y * cell_size + rng.randi_range(0, cell_size - 1)
	)
	var outer_radius := rng.randi_range(
		mini(elevation_min_radius, elevation_max_radius),
		maxi(elevation_min_radius, elevation_max_radius)
	)
	var plateau_radius := maxi(2, floori(float(outer_radius) / 2.0))
	var feature := Vector4(center.x, center.y, outer_radius, plateau_radius)
	_elevation_feature_cache[cache_key] = feature
	return feature

func _limit_elevation_at_flat_boundaries(grid_id: Vector2i, elevation: int) -> int:
	if elevation < 2:
		return elevation

	var cube_id := GridUtils.offset_to_cube(grid_id, pointy_top)
	for direction in DataManager.instance.CUBE_DIRS:
		var neighbor_id := GridUtils.cube_to_offset(cube_id + direction, pointy_top)
		if keep_protected_chunks_flat and _is_within_protected_chunk_elevation_buffer(neighbor_id):
			return 1
		if _get_region_for_grid_id(neighbor_id) == DataManager.instance.get_ocean_descriptor():
			return 1

	return elevation

func _get_region_for_grid_id(grid_id: Vector2i) -> RegionInfo:
	if generated_regions.has(grid_id):
		var cached_region: RegionInfo = generated_regions[grid_id]
		return cached_region

	var region_rng := create_rng("region:%s:%s" % [grid_id.x, grid_id.y])
	var distance := GridUtils.cube_distance(GridUtils.offset_to_cube(grid_id, pointy_top), Vector3i.ZERO)
	var region := DataManager.instance.get_region_for(
		grid_id.x,
		grid_id.y,
		region_options,
		region_rng,
		distance
	)
	if _is_protected_grid_id(grid_id) and region == DataManager.instance.get_ocean_descriptor():
		var fallback := _get_protected_land_region(distance, region_rng)
		if fallback != null:
			region = fallback

	generated_regions[grid_id] = region
	return region

func _is_protected_grid_id(grid_id: Vector2i) -> bool:
	return protected_chunks.has(grid_to_chunk_coords(grid_id))

func _is_within_protected_chunk_buffer(grid_id: Vector2i) -> bool:
	var chunk_coords := grid_to_chunk_coords(grid_id)
	for protected_chunk in protected_chunks:
		var within_x_buffer := absi(chunk_coords.x - protected_chunk.x) <= protected_chunk_feature_buffer
		var within_y_buffer := absi(chunk_coords.y - protected_chunk.y) <= protected_chunk_feature_buffer
		if within_x_buffer and within_y_buffer:
			return true
	return false

func _is_within_protected_chunk_elevation_buffer(grid_id: Vector2i) -> bool:
	var chunk_coords := grid_to_chunk_coords(grid_id)
	for protected_chunk in protected_chunks:
		var within_x_buffer := absi(chunk_coords.x - protected_chunk.x) <= protected_chunk_elevation_buffer
		var within_y_buffer := absi(chunk_coords.y - protected_chunk.y) <= protected_chunk_elevation_buffer
		if within_x_buffer and within_y_buffer:
			return true
	return false

func _get_protected_land_region(distance: int, rng: RandomNumberGenerator) -> RegionInfo:
	var ocean_descriptor := DataManager.instance.get_ocean_descriptor()
	var candidates: Array[RegionInfo] = []
	var cumulative: Array[float] = []
	var best_priority := -INF
	var total_weight := 0.0

	for region: RegionInfo in region_options:
		if region == null or region == ocean_descriptor:
			continue
		if region.scene_multipliers.is_empty():
			continue

		var weight := region.get_generation_weight(distance)
		if weight <= 0.0:
			continue

		if region.priority > best_priority:
			best_priority = region.priority
			candidates.clear()
			cumulative.clear()
			total_weight = 0.0

		if region.priority == best_priority:
			total_weight += weight
			candidates.append(region)
			cumulative.append(total_weight)

	if candidates.is_empty():
		return null

	if total_weight <= 0.0:
		return candidates[0]

	var r := rng.randf() * total_weight
	for i in cumulative.size():
		if r <= cumulative[i]:
			return candidates[i]

	return candidates[-1]

func expand_from_chunk(cx: int, cy: int, dir: int) -> void:
	var offset := CHUNK_DIR_VECTORS[dir]
	var new_coords := Vector2i(cx + offset.x, cy + offset.y)

	if has_chunk(new_coords.x, new_coords.y):
		return;

	generate_chunk(new_coords.x, new_coords.y);
	
func _queue_chunk_post_processing(chunk: HexChunk) -> void:
	_chunk_post_process_queue.append({
		"chunk": chunk,
		"stage": 0,
		"index": 0,
		"slope_candidates": chunk.hexes.duplicate(),
	})

func _process_chunk_post_process_step() -> bool:
	if _chunk_post_process_queue.is_empty():
		return false

	var job: Dictionary = _chunk_post_process_queue[0]
	var chunk := job["chunk"] as HexChunk
	if not is_instance_valid(chunk):
		_chunk_post_process_queue.pop_front()
		return true

	var stage := int(job["stage"])
	var index := int(job["index"])

	if stage == 0:
		if initialized and generate_elevation and generate_slope_entrances:
			var slope_candidates: Array = job["slope_candidates"]
			if index < slope_candidates.size():
				var slope_profile := _get_cached_slope_profile()
				if slope_profile != null:
					_try_replace_with_slope_entrance(slope_candidates[index], slope_profile)
				job["index"] = index + 1
				return true
			_reserve_slope_approaches(chunk)
		job["stage"] = 1
		job["index"] = 0
		return true

	if stage == 1:
		if index < chunk.hexes.size():
			var scene_instance := chunk.hexes[index] as SceneInstance
			if scene_instance != null:
				_assign_region_instance(scene_instance.node as HexBase)
			job["index"] = index + 1
			return true
		job["stage"] = 2
		job["index"] = 0
		return true

	if stage == 2:
		if initialized and index < chunk.hexes.size():
			var scene_instance := chunk.hexes[index] as SceneInstance
			var hex := scene_instance.node as HexBase if scene_instance != null else null
			if hex != null and hex.is_inside_tree():
				pathfinder.update_hex(hex)
			job["index"] = index + 1
			return true
		job["stage"] = 3
		job["index"] = 0
		return true

	if initialized and chunk.generate_structures:
		for scene_instance: SceneInstance in chunk.hexes:
			var hex := scene_instance.node as HexBase
			if hex != null:
				_pending_structure_hexes[hex.cube_id] = true

	chunk.is_post_processed = true
	_chunk_post_process_queue.pop_front()
	_check_initial_generation_complete()
	return true

func _prepare_structure_generation_jobs() -> bool:
	if _pending_structure_hexes.is_empty():
		return false

	var grouped_candidates: Dictionary = {}
	for cube_id: Vector3i in _pending_structure_hexes.keys():
		var hex := get_hex_at_cube_id(cube_id)
		if hex == null or hex.region_instance == null:
			continue
		if not grouped_candidates.has(hex.region_instance):
			grouped_candidates[hex.region_instance] = [] as Array[Vector3i]
		var candidates := grouped_candidates[hex.region_instance] as Array[Vector3i]
		candidates.append(cube_id)
	_pending_structure_hexes.clear()

	var prepared_jobs: Array[Dictionary] = []
	for region_instance: RegionInstance in grouped_candidates.keys():
		var candidates := grouped_candidates[region_instance] as Array[Vector3i]
		candidates.sort_custom(_sort_cube_ids)
		prepared_jobs.append({
			"region_instance": region_instance,
			"candidates": candidates,
			"generation_state": {},
		})
	prepared_jobs.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_candidates := a["candidates"] as Array[Vector3i]
			var b_candidates := b["candidates"] as Array[Vector3i]
			return _sort_cube_ids(a_candidates[0], b_candidates[0])
	)
	_structure_generation_queue.append_array(prepared_jobs)
	return true

func _process_structure_generation_step() -> bool:
	if _structure_generation_queue.is_empty():
		return false
	var job: Dictionary = _structure_generation_queue[0]
	var region_instance := job["region_instance"] as RegionInstance
	if region_instance == null:
		_structure_generation_queue.pop_front()
		return true
	var candidates := job["candidates"] as Array[Vector3i]
	if not _get_instances_for_region(region_instance.info).has(region_instance):
		for cube_id in candidates:
			_pending_structure_hexes[cube_id] = true
		_structure_generation_queue.pop_front()
		return true

	var generation_state := job["generation_state"] as Dictionary
	if generation_state.is_empty():
		generation_state = region_instance.create_structure_generation_job(candidates)
		job["generation_state"] = generation_state
		if generation_state.is_empty():
			_structure_generation_queue.pop_front()
			return true

	if region_instance.process_structure_generation_job(generation_state):
		_structure_generation_queue.pop_front()
	return true

func _check_initial_generation_complete() -> void:
	if _initial_generation_completed or chunks.is_empty():
		return
	for chunk: HexChunk in chunks.values():
		if not chunk.is_post_processed:
			return
	_initial_generation_completed = true
	generated.emit()

func _queue_pathfinder_rebuild() -> void:
	if _pathfinder_rebuild_queued:
		return
	_pathfinder_rebuild_queued = true
	call_deferred("_rebuild_pathfinder")

func _rebuild_pathfinder() -> void:
	_pathfinder_rebuild_queued = false
	if is_inside_tree():
		pathfinder.rebuild()

func _resolve_slope_entrances(chunk: HexChunk) -> void:
	if not initialized or not generate_elevation or not generate_slope_entrances:
		return
	var slope_profile := _get_cached_slope_profile()
	if slope_profile == null:
		return

	for scene_instance: SceneInstance in chunk.hexes.duplicate():
		_try_replace_with_slope_entrance(scene_instance, slope_profile)
	_reserve_slope_approaches(chunk)

func _get_cached_slope_profile() -> HexSlope:
	var half_slope_info := _get_half_slope_info()
	if half_slope_info == null:
		return null
	if not is_instance_valid(_cached_slope_profile):
		_cached_slope_profile = half_slope_info.packed_scene.instantiate() as HexSlope
	return _cached_slope_profile

func _get_half_slope_info() -> HexInfo:
	if _half_slope_info == null:
		_half_slope_info = load(HALF_SLOPE_INFO_PATH) as HexInfo
	return _half_slope_info

func _try_replace_with_slope_entrance(
	scene_instance: SceneInstance,
	slope_profile: HexSlope,
	force_placement: bool = false,
	reachable_low_tiles: Dictionary = {}
) -> bool:
	if scene_instance == null:
		return false
	var hex := scene_instance.node as HexBase
	if hex == null or hex is HexSlope or hex.structure != null:
		return false
	if not force_placement and not hex.can_generate:
		return false
	if not can_generate_slope_entrance_on_hex(hex):
		return false
	if _has_adjacent_slope(hex):
		return false

	var sampled_elevation := hex.generated_elevation_units
	if sampled_elevation <= 0:
		return false

	var rotation_steps := _get_slope_placement_rotation(
		hex, sampled_elevation, slope_profile, reachable_low_tiles
	)
	if rotation_steps < 0:
		return false
	if not force_placement and not _should_generate_slope(hex.grid_id, rotation_steps):
		return false

	var cube_id := hex.cube_id
	_replace_with_half_slope(scene_instance, sampled_elevation, rotation_steps)
	var slope: HexSlope = get_hex_at_cube_id(cube_id) as HexSlope
	_reserve_slope_approach(slope)
	return true

func _ensure_elevated_areas_have_entrances() -> void:
	if not generate_elevation or not generate_slope_entrances:
		return
	var slope_profile := _get_cached_slope_profile()
	if slope_profile == null:
		return

	_rebuild_elevation_areas()
	var area_ids: Array[int] = []
	for area_id_variant in elevation_areas.keys():
		area_ids.append(int(area_id_variant))
	area_ids.sort()
	for area_id in area_ids:
		var area: ElevationArea = elevation_areas[area_id]
		var target_entrances := _get_elevation_area_entrance_target(area)
		while area.entrance_count < target_entrances:
			if not _place_required_component_entrance(area, slope_profile):
				break
			area.entrance_count += 1

func ensure_elevated_areas_reachable_from(start_hex: HexBase) -> void:
	if start_hex == null or not generate_elevation or not generate_slope_entrances:
		return
	var slope_profile := _get_cached_slope_profile()
	if slope_profile == null:
		return

	_rebuild_elevation_areas()
	var reachable_tiles := _get_walk_reachable_tiles(start_hex)
	var max_elevation := 0
	for area_id_variant in elevation_areas.keys():
		var area_id := int(area_id_variant)
		var area: ElevationArea = elevation_areas[area_id]
		max_elevation = maxi(max_elevation, area.elevation_units)

	for elevation in range(1, max_elevation + 1):
		var area_ids: Array[int] = []
		for area_id_variant in elevation_areas.keys():
			var area_id := int(area_id_variant)
			var area: ElevationArea = elevation_areas[area_id]
			if area.elevation_units == elevation:
				area_ids.append(area_id)
		area_ids.sort()

		for area_id in area_ids:
			var area: ElevationArea = elevation_areas[area_id]
			while not _is_elevation_area_reachable(area, reachable_tiles):
				if not _place_required_component_entrance(
					area, slope_profile, reachable_tiles, true
				):
					break
				reachable_tiles = _get_walk_reachable_tiles(start_hex)
			area.is_reachable_from_start = _is_elevation_area_reachable(area, reachable_tiles)
			if not area.is_reachable_from_start:
				continue

			var target_entrances := _get_elevation_area_entrance_target(area)
			while area.entrance_count < target_entrances:
				if not _place_required_component_entrance(area, slope_profile, reachable_tiles):
					break
				area.entrance_count += 1
				reachable_tiles = _get_walk_reachable_tiles(start_hex)

func _get_walk_reachable_tiles(start_hex: HexBase) -> Dictionary:
	var reachable: Dictionary = {start_hex.cube_id: true}
	var frontier: Array[HexBase] = [start_hex]
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		for direction in DataManager.instance.CUBE_DIRS:
			var neighbor := get_hex_at_cube_id(current.cube_id + direction)
			if neighbor == null or reachable.has(neighbor.cube_id):
				continue
			if not can_traverse_between(current, neighbor, HexInfo.TraversalTag.WALK):
				continue
			reachable[neighbor.cube_id] = true
			frontier.append(neighbor)
	return reachable

func _is_elevation_area_reachable(area: ElevationArea, reachable_tiles: Dictionary) -> bool:
	for previous_hex in area.hexes:
		if reachable_tiles.has(previous_hex.cube_id):
			return true
	return false

func _rebuild_elevation_areas() -> void:
	elevation_areas.clear()
	var visited: Dictionary = {}
	var cube_ids: Array[Vector3i] = []
	for cube_id in tiles.keys():
		cube_ids.append(cube_id)
	cube_ids.sort_custom(_sort_cube_ids)

	var next_area_id := 0
	for cube_id in cube_ids:
		if visited.has(cube_id):
			continue
		var hex := get_hex_at_cube_id(cube_id)
		if hex == null or not hex.is_traversable(HexInfo.TraversalTag.WALK):
			continue
		var elevation := hex.generated_elevation_units
		if elevation <= 0:
			continue
		var component := _get_elevation_component(hex, elevation, visited)
		var area := ElevationArea.new()
		area.id = next_area_id
		area.elevation_units = elevation
		area.hexes = component
		for component_hex in component:
			if component_hex is HexSlope:
				area.entrance_count += 1
		elevation_areas[area.id] = area
		next_area_id += 1

func _get_elevation_area_entrance_target(area: ElevationArea) -> int:
	var extra_entrances := ceili(
		float(area.hexes.size()) / float(elevated_tiles_per_extra_slope_entrance)
	)
	return maxi(minimum_slope_entrances_per_area, extra_entrances)

func _sort_cube_ids(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z

func _sort_hexes_by_cube_id(a: HexBase, b: HexBase) -> bool:
	return _sort_cube_ids(a.cube_id, b.cube_id)

func _get_elevation_component(start: HexBase, elevation: int, visited: Dictionary) -> Array[HexBase]:
	var component: Array[HexBase] = []
	var frontier: Array[HexBase] = [start]
	visited[start.cube_id] = true
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		component.append(current)
		for direction in DataManager.instance.CUBE_DIRS:
			var neighbor := get_hex_at_cube_id(current.cube_id + direction)
			if neighbor == null or visited.has(neighbor.cube_id):
				continue
			if not neighbor.is_traversable(HexInfo.TraversalTag.WALK):
				continue
			if neighbor.generated_elevation_units != elevation:
				continue
			visited[neighbor.cube_id] = true
			frontier.append(neighbor)
	return component

func _place_required_component_entrance(
	area: ElevationArea,
	slope_profile: HexSlope,
	reachable_low_tiles: Dictionary = {},
	allow_reorientation: bool = false
) -> bool:
	area.hexes.sort_custom(_sort_hexes_by_cube_id)
	if allow_reorientation:
		for previous_hex in area.hexes:
			var existing_slope: HexSlope = get_hex_at_cube_id(previous_hex.cube_id) as HexSlope
			if existing_slope != null and _try_reorient_slope_entrance(existing_slope, reachable_low_tiles):
				return true

	for previous_hex in area.hexes:
		var hex := get_hex_at_cube_id(previous_hex.cube_id)
		if hex == null or hex is HexSlope:
			continue
		if _try_replace_with_slope_entrance(
			hex.scene_instance, slope_profile, true, reachable_low_tiles
		):
			return true
	return false

func _try_reorient_slope_entrance(slope: HexSlope, reachable_low_tiles: Dictionary) -> bool:
	if slope == null or not can_generate_slope_entrance_on_hex(slope):
		return false
	var sampled_elevation := slope.generated_elevation_units
	var rotation_steps := _get_slope_placement_rotation(
		slope, sampled_elevation, slope, reachable_low_tiles
	)
	if rotation_steps < 0:
		return false

	slope.rotation.y = float(rotation_steps) * TAU / 6.0
	slope.set_elevation(sampled_elevation - slope.slope_rise_units, elevation_unit_height)
	_reserve_slope_approach(slope)
	return true

func _get_slope_placement_rotation(
	hex: HexBase,
	sampled_elevation: int,
	slope_profile: HexSlope,
	reachable_low_tiles: Dictionary = {}
) -> int:
	var base_elevation := sampled_elevation - slope_profile.slope_rise_units
	if base_elevation < 0 or slope_profile.connector_mask == 0:
		return -1

	var best_rotation := -1
	var best_navigation_connections := -1
	for rotation_steps in range(6):
		var has_low_connection := false
		var has_high_connection := false
		var has_reachable_low_connection := reachable_low_tiles.is_empty()
		var valid := true

		for local_edge in range(6):
			if (slope_profile.connector_mask & (1 << local_edge)) == 0:
				continue
			var edge_offset: int = 0
			if local_edge < slope_profile.edge_height_offsets.size():
				edge_offset = int(slope_profile.edge_height_offsets[local_edge])
			var world_edge := posmod(local_edge + rotation_steps, 6)
			var expected_elevation := base_elevation + edge_offset
			if not _is_valid_slope_neighbor(hex, world_edge, expected_elevation):
				valid = false
				break
			if edge_offset == 0:
				has_low_connection = true
				var low_neighbor_cube_id := hex.cube_id + DataManager.instance.CUBE_DIRS[world_edge]
				if reachable_low_tiles.has(low_neighbor_cube_id):
					has_reachable_low_connection = true
			if edge_offset == slope_profile.slope_rise_units:
				has_high_connection = true

		if valid and has_low_connection and has_high_connection and has_reachable_low_connection:
			var navigation_connections := _count_matching_navigation_edges(
				hex, base_elevation, rotation_steps, slope_profile
			)
			if navigation_connections > best_navigation_connections:
				best_navigation_connections = navigation_connections
				best_rotation = rotation_steps

	return best_rotation

func _count_matching_navigation_edges(
	hex: HexBase,
	base_elevation: int,
	rotation_steps: int,
	slope_profile: HexSlope
) -> int:
	var connections := 0
	for local_edge in range(6):
		if (slope_profile.navigation_only_mask & (1 << local_edge)) == 0:
			continue
		var edge_offset: int = 0
		if local_edge < slope_profile.edge_height_offsets.size():
			edge_offset = int(slope_profile.edge_height_offsets[local_edge])
		var world_edge := posmod(local_edge + rotation_steps, 6)
		if _is_valid_slope_neighbor(hex, world_edge, base_elevation + edge_offset):
			connections += 1
	return connections

func _is_valid_slope_neighbor(hex: HexBase, edge: int, expected_elevation: int) -> bool:
	var neighbor_cube_id := hex.cube_id + DataManager.instance.CUBE_DIRS[edge]
	var neighbor_grid_id := GridUtils.cube_to_offset(neighbor_cube_id, pointy_top)
	var neighbor := get_hex_at_cube_id(neighbor_cube_id)
	var neighbor_elevation := get_generated_elevation_units(neighbor_grid_id)
	if neighbor != null:
		neighbor_elevation = neighbor.generated_elevation_units
	if neighbor_elevation != expected_elevation:
		return false
	if _get_region_for_grid_id(neighbor_grid_id) == DataManager.instance.get_ocean_descriptor():
		return false

	if neighbor == null:
		return true
	if neighbor is HexSlope or neighbor.structure != null:
		return false
	return neighbor.is_traversable(HexInfo.TraversalTag.WALK)

func _replace_with_half_slope(scene_instance: SceneInstance, sampled_elevation: int, rotation_steps: int) -> void:
	var previous_hex := scene_instance.node as HexBase
	if previous_hex == null:
		return
	var half_slope_info := _get_half_slope_info()
	if half_slope_info == null:
		return

	var region := previous_hex.region
	var was_explored := previous_hex.is_explored
	var replacement_instance := half_slope_info.get_instance()
	replace(scene_instance, replacement_instance, region)

	var slope := replacement_instance.node as HexSlope
	if slope == null:
		return

	slope.rotation.y = float(rotation_steps) * TAU / 6.0
	slope.set_elevation(sampled_elevation - slope.slope_rise_units, elevation_unit_height)
	slope.apply_region(region)
	slope.is_explored = was_explored

func _should_generate_slope(grid_id: Vector2i, rotation_steps: int) -> bool:
	var rng := create_rng("slope_entrance_v2:%s:%s:%s" % [grid_id.x, grid_id.y, rotation_steps])
	return rng.randf() <= slope_entrance_density

func _has_adjacent_slope(hex: HexBase) -> bool:
	for direction in DataManager.instance.CUBE_DIRS:
		var neighbor := get_hex_at_cube_id(hex.cube_id + direction)
		if neighbor is HexSlope:
			return true
	return false

func _reserve_slope_approaches(chunk: HexChunk) -> void:
	for scene_instance: SceneInstance in chunk.hexes:
		var hex := scene_instance.node as HexBase
		if hex == null:
			continue
		if hex is HexSlope:
			_reserve_slope_approach(hex as HexSlope)
		elif _has_adjacent_slope(hex):
			hex.can_generate = false

func _reserve_slope_approach(slope: HexSlope) -> void:
	if slope == null:
		return
	slope.can_generate = false
	for direction in DataManager.instance.CUBE_DIRS:
		var neighbor := get_hex_at_cube_id(slope.cube_id + direction)
		if neighbor != null:
			neighbor.can_generate = false

func _assign_region_instance(hex: HexBase) -> void:
	if hex.region_instance != null:
		return;

	var touching_instances: Array[RegionInstance] = [];

	for d in DataManager.instance.CUBE_DIRS:
		var nid := hex.cube_id + d
		if not tiles.has(nid):
			continue

		var neighbor := tiles[nid].node;
		if neighbor.region != hex.region:
			continue

		if neighbor.region_instance != null and not touching_instances.has(neighbor.region_instance):
			touching_instances.append(neighbor.region_instance)

	match touching_instances.size():
		0:
			var reg := RegionInstance.new(hex.region, self);
			reg.add_hex(hex);
			_get_instances_for_region(hex.region).append(reg);
		1:
			touching_instances[0].add_hex(hex);
		_:
			touching_instances.sort_custom(
				func(a: RegionInstance, b: RegionInstance) -> bool:
					return a.hexes.size() > b.hexes.size()
			)
			var primary := touching_instances[0];
			primary.add_hex(hex);
			for i in range(1, touching_instances.size()):
				var other := touching_instances[i];
				primary.merge_from(other)
				_get_instances_for_region(hex.region).erase(other);

func generate_chunk(cx: int, cy: int) -> HexChunk:
	var key := Vector2i(cx, cy)
	if chunks.has(key):
		return chunks[key];

	var chunk := HexChunk.new(cx, cy, chunk_size);
	chunks[key] = chunk;
	add_child(chunk)
	chunk.generate_structures = not protected_chunks.has(key)
	chunk.generated.connect(_queue_chunk_post_processing, CONNECT_ONE_SHOT)
	_chunk_generation_queue.append({
		"chunk": chunk,
		"next_cell": 0,
	})
	return chunk

func _process_chunk_generation_step() -> bool:
	if _chunk_generation_queue.is_empty():
		return false

	var job: Dictionary = _chunk_generation_queue[0]
	var chunk := job["chunk"] as HexChunk
	if not is_instance_valid(chunk):
		_chunk_generation_queue.pop_front()
		return true

	var next_cell := int(job["next_cell"])
	var cell_count := chunk_size.x * chunk_size.y
	if next_cell >= cell_count:
		_chunk_generation_queue.pop_front()
		return true

	var local_x := next_cell % chunk_size.x
	var local_y := next_cell / chunk_size.x
	var gx := chunk.chunk_x * chunk_size.x + local_x
	var gy := chunk.chunk_y * chunk_size.y + local_y
	var grid_id := Vector2i(gx, gy)
	var region := _get_region_for_grid_id(grid_id)
	var scene_rng := create_rng("tile:%s:%s" % [gx, gy])
	var scene_info := DataManager.instance.pick_scene_for_region(region, scene_rng)
	job["next_cell"] = next_cell + 1

	if scene_info == null:
		Debug.err("No tile scene could be generated at %s." % grid_id)
		return true

	var elevation_units := get_generated_elevation_units(grid_id)
	scene_info.queue(
		func(sI: SceneInfo) -> void:
			_tile_instantiation_queue.append({
				"chunk": chunk,
				"grid_id": grid_id,
				"scene_info": sI,
				"region": region,
				"elevation_units": elevation_units,
			})
	)
	return true

func _process_tile_instantiation_step() -> bool:
	if _tile_instantiation_queue.is_empty():
		return false
	var tile_job: Dictionary = _tile_instantiation_queue.pop_front()
	var chunk := tile_job["chunk"] as HexChunk
	var scene_info := tile_job["scene_info"] as SceneInfo
	var region := tile_job["region"] as RegionInfo
	if not is_instance_valid(chunk) or scene_info == null:
		return true
	var grid_id := tile_job["grid_id"] as Vector2i
	var elevation_units := int(tile_job["elevation_units"])
	chunk.add_hex(create_hex(grid_id, scene_info, region, elevation_units))
	return true

func generate_chunks_around_grid_id(grid_id: Vector2i, radius: int = -1) -> void:
	if not generate_chunks_near_player:
		return
	if radius < 0:
		radius = player_chunk_generation_radius
	var center_chunk := grid_to_chunk_coords(grid_id)

	var requested_chunks: Array[Vector2i] = []
	for cy in range(center_chunk.y - radius, center_chunk.y + radius + 1):
		for cx in range(center_chunk.x - radius, center_chunk.x + radius + 1):
			if not has_chunk(cx, cy):
				requested_chunks.append(Vector2i(cx, cy))
	requested_chunks.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(center_chunk) < b.distance_squared_to(center_chunk)
	)
	for chunk_coords in requested_chunks:
		generate_chunk(chunk_coords.x, chunk_coords.y)
	
func get_hex_at_world_position(world_pos: Vector3, max_distance: float = 1.2) -> HexBase:
	var approx_cube := world_to_cube_id(world_pos)
	var candidates: Array[HexBase] = [];
	var candidate_hex := get_hex_at_cube_id(approx_cube);
	if candidate_hex != null:
		candidates.append(candidate_hex);
	
	for dir in DataManager.instance.CUBE_DIRS:
		var neighbor_hex := get_hex_at_cube_id(approx_cube + dir)
		if neighbor_hex != null and not candidates.has(neighbor_hex):
			candidates.append(neighbor_hex);
	
	var containing_candidates: Array[HexBase] = [];
	for hex in candidates:
		if GridUtils.is_point_in_hex(world_pos, hex.global_position, RADIUS_IN, pointy_top):
			containing_candidates.append(hex);
	
	var search_pool := containing_candidates if not containing_candidates.is_empty() else candidates;
	if search_pool.is_empty():
		return null;
	
	var closest_hex: HexBase = null;
	var closest_distance := INF;
	for hex in search_pool:
		var distance := Vector2(hex.global_position.x, hex.global_position.z).distance_squared_to(
			Vector2(world_pos.x, world_pos.z)
		)
		if distance < closest_distance:
			closest_distance = distance;
			closest_hex = hex;
	
	if closest_hex == null:
		return null;
	
	if containing_candidates.is_empty():
		if max_distance <= 0.0:
			return null;
		
		var best_dist := max_distance * max_distance;
		if closest_distance > best_dist:
			return null;
	
	return closest_hex;

func get_hex_at_grid_id(grid_id: Vector2i) -> HexBase:
	return get_hex_at_cube_id(GridUtils.offset_to_cube(grid_id, pointy_top))

func get_hex_at_cube_id(cube_id: Vector3i) -> HexBase:
	var scene_instance := tiles.get(cube_id) as SceneInstance
	if scene_instance == null:
		return null;
	return scene_instance.node as HexBase;

func can_traverse_between(
	from_hex: HexBase,
	to_hex: HexBase,
	method: HexInfo.TraversalTag = HexInfo.TraversalTag.WALK
) -> bool:
	if from_hex == null or to_hex == null:
		return false
	if not from_hex.is_traversable(method) or not to_hex.is_traversable(method):
		return false

	var from_edge := DataManager.instance.CUBE_DIRS.find(to_hex.cube_id - from_hex.cube_id)
	if from_edge < 0:
		return false
	var to_edge := posmod(from_edge + 3, DataManager.instance.CUBE_DIRS.size())
	if not from_hex.can_traverse_edge(from_edge, method):
		return false
	if not to_hex.can_traverse_edge(to_edge, method):
		return false

	return (
		from_hex.get_edge_elevation_units_for_method(from_edge, method)
		== to_hex.get_edge_elevation_units_for_method(to_edge, method)
	)

func can_traverse_between_for_methods(from_hex: HexBase, to_hex: HexBase, methods: Array) -> bool:
	for method in methods:
		if can_traverse_between(from_hex, to_hex, method):
			return true
	return false

func get_tiles_in_radius(center: Vector3i, radius: int) -> Array[SceneInstance]:
	var result: Array[SceneInstance] = [];
	for dx in range(-radius, radius + 1):
		for dy in range(
			max(-radius, -dx - radius),
			min(radius, -dx + radius) + 1
		):
			var dz := -dx - dy
			var cube := center + Vector3i(dx, dy, dz)

			if tiles.has(cube):
				result.append(tiles[cube]);
	return result;
	
func grid_to_chunk_coords(grid_id: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(grid_id.x) / float(chunk_size.x)),
		floori(float(grid_id.y) / float(chunk_size.y))
	)

func replace(hex_instance: SceneInstance, replacement_instance: SceneInstance, region: RegionInfo) -> void:
	var hex := hex_instance.node as HexBase;
	var replacement := replacement_instance.node as HexBase;
	
	if hex == null or replacement == null:
		return;
		
	if replacement.get_parent() == self:
		return;

	replacement.grid_id = hex.grid_id
	replacement.cube_id = hex.cube_id
	replacement.region = region
	replacement.region_instance = null
	replacement.can_generate = hex.can_generate
	replacement.elevation_units = hex.elevation_units
	replacement.elevation_unit_height = hex.elevation_unit_height
	replacement.generated_elevation_units = hex.generated_elevation_units

	replacement.global_transform = hex.global_transform

	if tiles.get(hex.cube_id) == hex_instance:
		tiles.erase(hex.cube_id);

	var old_region_instance := hex.region_instance
	if old_region_instance != null:
		old_region_instance.remove_hex(hex.cube_id);

	tiles[replacement.cube_id] = replacement_instance
	if old_region_instance != null:
		old_region_instance.add_hex(replacement)
	
	var chunk_coords := grid_to_chunk_coords(hex.grid_id);
	chunks[chunk_coords].hexes.erase(hex_instance);
	chunks[chunk_coords].add_hex(replacement_instance);
	replacement.apply_region(region)
	
	if initialized:
		pathfinder.update_hex(replacement);
	
	hex_instance.destroy();

func world_to_grid_id(world_pos: Vector3) -> Vector2i:
	return GridUtils.world_to_offset(world_pos, RADIUS_IN, _spacing, pointy_top);

func world_to_cube_id(world_pos: Vector3) -> Vector3i:
	return GridUtils.offset_to_cube(world_to_grid_id(world_pos), pointy_top);

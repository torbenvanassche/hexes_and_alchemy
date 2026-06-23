class_name HexGrid extends Node3D

var pointy_top: bool = false;
var _spacing: float = 0.25

##The radius for initial chunk generation, more can be generated on demand
@export var chunk_radius: int = 3;
@export var grid_name: String;

## Set this to reproduce a specific world. Leave it at 0 to generate a new seed on each run.
@export var world_seed: int = 0;
var generation_seed: int = 0;

##Optionally define custom regions that can generate if you don't want to use the global setting
@export var custom_regions: Array[RegionInfo];
@export var generate_ocean: bool = true;

##Whether or not to merge the general list of regions as part of the generation process
@export var use_global_regions: bool = true;
var region_options: Array[RegionInfo];

var initialized: bool = false;

##Chunks that should not generate structures
@export var skipped_chunks: Array[Vector2i];

static var RADIUS_IN: float = 1.0

var chunks: Dictionary[Vector2i, HexChunk] = {}
var region_instances: Dictionary[RegionInfo, Array] = {} 
var tiles: Dictionary[Vector3i, SceneInstance] = {}
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

	if use_global_regions:
		region_options = DataManager.instance.regions;
	for region in custom_regions:
		if not region_options.has(region):
			region_options.append(region);

	_apply_seed_to_region_noise()

	for cy in range(-chunk_radius, chunk_radius + 1):
		for cx in range(-chunk_radius, chunk_radius + 1):
			generate_chunk(cx, cy)

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
	if DataManager.instance.ocean_descriptor != null and not seeded_regions.has(DataManager.instance.ocean_descriptor):
		seeded_regions.append(DataManager.instance.ocean_descriptor)

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
	SceneManager.set_active_scene(DataManager.instance.node_to_info(self));
	
	generate_structures();
	mark_initialized();

func generate_structures() -> void:
	for reg in region_instances.keys():
		for rI: RegionInstance in region_instances[reg]:
			rI.generate_structures_for_region();
	
func has_chunk(cx: int, cy: int) -> bool:
	return chunks.has(Vector2i(cx, cy));
	
func get_structured_hexes() -> Array[HexBase]:
	var instances : Array[HexBase];
	for region_instance in region_instances.keys():
		var region := _get_instances_for_region(region_instance);
		for instance: RegionInstance in region:
			instances.append_array(instance.get_structured_hexes());
	return instances;
	
func _get_instances_for_region(region: RegionInfo) -> Array:
	if not region_instances.has(region):
		region_instances[region] = [];
	return region_instances[region];
		
func create_hex(grid_id: Vector2i, info: SceneInfo) -> SceneInstance:
	var scene_instance := info.get_instance();
	var hex := scene_instance.node;
	
	hex.region = DataManager.instance.get_region_for(grid_id.x, grid_id.y, region_options);
	var spacing =  GridUtils.get_spacing(RADIUS_IN, _spacing, pointy_top);

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
	return scene_instance;

func expand_from_chunk(cx: int, cy: int, dir: int) -> void:
	var offset := CHUNK_DIR_VECTORS[dir]
	var new_coords := Vector2i(cx + offset.x, cy + offset.y)

	if chunks.has(new_coords):
		return;

	generate_chunk(new_coords.x, new_coords.y);
	
func _post_process_chunk(chunk: HexChunk) -> void:
	for hex: SceneInstance in chunk.hexes:
		_assign_region_instance(hex.node);
	
	var all_chunks_generated: bool = true;
	for c in chunks.keys():
		if not chunks[c].is_generated:
			all_chunks_generated = false;
	if all_chunks_generated:
		generated.emit();

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
			var primary := touching_instances[0];
			primary.add_hex(hex);
			for i in range(1, touching_instances.size()):
				var other := touching_instances[i];
				for h: HexBase in other.hexes.values():
					primary.add_hex(h);
				_get_instances_for_region(hex.region).erase(other);

func generate_chunk(cx: int, cy: int) -> HexChunk:
	var key := Vector2i(cx, cy)
	if chunks.has(key):
		return chunks[key];

	var chunk := HexChunk.new(cx, cy);
	chunks[key] = chunk;
	add_child(chunk);
	
	chunk.generate_structures = not skipped_chunks.has(key);

	var start_x := cx * chunk.CHUNK_WIDTH
	var start_y := cy * chunk.CHUNK_HEIGHT
	
	chunk.generated.connect(_post_process_chunk);

	for gy in range(start_y, start_y + chunk.CHUNK_HEIGHT):
		for gx in range(start_x, start_x + chunk.CHUNK_WIDTH):
			var grid_id := Vector2i(gx, gy);
			var scene_rng := create_rng("tile:%s:%s" % [gx, gy]);
			var scene_info := DataManager.instance.pick_scene(gx, gy, region_options, scene_rng);
			if scene_info == null:
				continue;
			
			scene_info.queue(
				func(sI: SceneInfo) -> void:
					chunk.add_hex(create_hex(grid_id, sI)));
	return chunk;
	
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
		var distance := hex.global_position.distance_squared_to(world_pos);
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
		floori(float(grid_id.x) / HexChunk.CHUNK_WIDTH),
		floori(float(grid_id.y) / HexChunk.CHUNK_HEIGHT)
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

	replacement.global_transform = hex.global_transform

	if tiles.get(hex.cube_id) == hex_instance:
		tiles.erase(hex.cube_id);

	if hex.region_instance != null:
		hex.region_instance.remove_hex(hex.cube_id);

	tiles[replacement.cube_id] = replacement_instance
	
	var chunk_coords := grid_to_chunk_coords(hex.grid_id);
	chunks[chunk_coords].hexes.erase(hex_instance);
	chunks[chunk_coords].add_hex(replacement_instance);
	
	pathfinder.update_hex(replacement);
	
	hex_instance.destroy();

func world_to_grid_id(world_pos: Vector3) -> Vector2i:
	return GridUtils.world_to_offset(world_pos, RADIUS_IN, _spacing, pointy_top);

func world_to_cube_id(world_pos: Vector3) -> Vector3i:
	return GridUtils.offset_to_cube(world_to_grid_id(world_pos), pointy_top);

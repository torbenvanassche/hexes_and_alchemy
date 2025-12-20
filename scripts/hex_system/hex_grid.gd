class_name HexGrid
extends Node3D

var pointy_top: bool = false;
var _spacing: float = 0.25

@export var chunk_radius: int = 3;
var initial_generation: bool = true;

const RADIUS_IN := 1.0

var chunks: Dictionary[Vector2i, HexChunk] = {}
var region_instances: Dictionary[RegionInfo, Array] = {} 
var tiles: Dictionary[Vector3i, HexBase] = {}

signal map_ready();

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

func _ready() -> void:
	Manager.instance.hex_grid = self;
	map_ready.connect(_on_map_ready)
	for cy in range(-chunk_radius, chunk_radius + 1):
		for cx in range(-chunk_radius, chunk_radius + 1):
			if Vector2(cx, cy).length() > chunk_radius:
				continue
			generate_chunk(cx, cy)

func _on_map_ready() -> void:
	for reg in region_instances.keys():
		for rI: RegionInstance in region_instances[reg]:
			rI.generate_structures_for_region()
			
	if initial_generation:
		initial_generation = false;
		Manager.instance.spawn_player(chunks[Vector2i(0, 0)].pick_random())
	
func has_chunk(cx: int, cy: int) -> bool:
	return chunks.has(Vector2i(cx, cy))
	
func get_spacing() -> Vector2:
	if pointy_top:
		return Vector2(3.0 * RADIUS_IN / 2.0 + _spacing, sqrt(3.0) * RADIUS_IN + _spacing)
	else:
		return Vector2(sqrt(3.0) * RADIUS_IN + _spacing, 3.0 * RADIUS_IN / 2.0 + _spacing)
	
func _get_instances_for_region(region: RegionInfo) -> Array:
	if not region_instances.has(region):
		region_instances[region] = []
	return region_instances[region];
		
func create_hex(grid_id: Vector2i, spacing: Vector2, hex: HexBase) -> HexBase:
	add_child(hex)
	hex.region = DataManager.instance.get_region_for(grid_id.x, grid_id.y);

	hex.grid_id = grid_id;
	hex.cube_id = offset_to_cube(grid_id)
	tiles[hex.cube_id] = hex;

	var pos := Vector3.ZERO
	if pointy_top:
		pos.x = grid_id.x * spacing.x
		pos.z = grid_id.y * spacing.y + (grid_id.x & 1) * (spacing.y / 2)
	else:
		pos.x = grid_id.x * spacing.x + (grid_id.y & 1) * (spacing.x / 2)
		pos.z = grid_id.y * spacing.y
	hex.position = pos
	return hex
	
func offset_to_cube(grid: Vector2i) -> Vector3i:
	if pointy_top:
		var x: int = grid.x
		var z: int = grid.y - ((grid.x - (grid.x & 1)) >> 1)
		var y: int = -x - z
		return Vector3i(x, y, z)
	else:
		var x: int = grid.x - ((grid.y - (grid.y & 1)) >> 1)
		var z: int = grid.y
		var y: int = -x - z
		return Vector3i(x, y, z)

func expand_from_chunk(cx: int, cy: int, dir: int) -> void:
	var offset := CHUNK_DIR_VECTORS[dir]
	var new_coords := Vector2i(cx + offset.x, cy + offset.y)

	if chunks.has(new_coords):
		return

	generate_chunk(new_coords.x, new_coords.y)
	
func _post_process_chunk(chunk: HexChunk) -> void:
	for hex: HexBase in chunk.hexes:
		_assign_region_instance(hex)
	
	var all_chunks_generated: bool = true;
	for c in chunks.keys():
		if not chunks[c].is_generated:
			all_chunks_generated = false;
	if all_chunks_generated:
		map_ready.emit();

func _assign_region_instance(hex: HexBase) -> void:
	if hex.region_instance != null:
		return

	var touching_instances: Array[RegionInstance] = []

	for d in DataManager.instance.CUBE_DIRS:
		var nid := hex.cube_id + d
		if not tiles.has(nid):
			continue

		var neighbor := tiles[nid]
		if neighbor.region != hex.region:
			continue

		if neighbor.region_instance != null and not touching_instances.has(neighbor.region_instance):
			touching_instances.append(neighbor.region_instance)

	match touching_instances.size():
		0:
			var reg := RegionInstance.new(hex.region)
			reg.add_hex(hex)
			_get_instances_for_region(hex.region).append(reg)
		1:
			touching_instances[0].add_hex(hex)
		_:
			var primary := touching_instances[0]
			primary.add_hex(hex)
			for i in range(1, touching_instances.size()):
				var other := touching_instances[i]
				for h: HexBase in other.hexes.values():
					primary.add_hex(h)
				_get_instances_for_region(hex.region).erase(other)

		
func generate_chunk(cx: int, cy: int) -> HexChunk:
	var key := Vector2i(cx, cy)
	if chunks.has(key):
		return chunks[key]

	var chunk := HexChunk.new(cx, cy)
	chunks[key] = chunk

	var spacing_vec := get_spacing()
	var start_x := cx * chunk.CHUNK_WIDTH
	var start_y := cy * chunk.CHUNK_HEIGHT
	
	chunk.generated.connect(_post_process_chunk)

	for gy in range(start_y, start_y + chunk.CHUNK_HEIGHT):
		for gx in range(start_x, start_x + chunk.CHUNK_WIDTH):
			var grid_id := Vector2i(gx, gy)
			DataManager.instance.pick_scene(gx, gy).queue(
				func(sI: SceneInfo) -> void:
					chunk.add_hex(create_hex(grid_id, spacing_vec, sI.get_instance())))
	return chunk
	
func get_hex_at_world_position(pos: Vector3) -> HexBase:
	var spacing := get_spacing()

	var gx: int
	var gy: int

	if pointy_top:
		gx = roundi(pos.x / spacing.x)
		gy = roundi((pos.z - (gx & 1) * spacing.y * 0.5) / spacing.y)
	else:
		gy = roundi(pos.z / spacing.y)
		gx = roundi((pos.x - (gy & 1) * spacing.x * 0.5) / spacing.x)

	var cube := offset_to_cube(Vector2i(gx, gy))
	return tiles.get(cube, null)

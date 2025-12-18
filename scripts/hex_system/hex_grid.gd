class_name HexGrid
extends Node3D

var pointy_top: bool = false;
var spacing: float = 0.25

@export var initial_chunks: Vector2i = Vector2i(2, 2)

const RADIUS_IN := 1.0

var chunks: Dictionary[Vector2i, HexChunk] = {}
var region_instances: Dictionary[RegionInfo, Array] = {} 

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
	for cy in range(initial_chunks.y):
		for cx in range(initial_chunks.x):
			generate_chunk(cx, cy)
	
func has_chunk(cx: int, cy: int) -> bool:
	return chunks.has(Vector2i(cx, cy))
	
func get_spacing() -> Vector2:
	if pointy_top:
		return Vector2(3.0 * RADIUS_IN / 2.0 + spacing, sqrt(3.0) * RADIUS_IN + spacing)
	else:
		return Vector2(sqrt(3.0) * RADIUS_IN + spacing, 3.0 * RADIUS_IN / 2.0 + spacing)
	
func _get_instances_for_region(region: RegionInfo) -> Array:
	if not region_instances.has(region):
		region_instances[region] = []
	return region_instances[region];
		
func create_hex(grid_id: Vector2i, spacing_vec: Vector2, hex: HexBase) -> HexBase:
	add_child(hex)
	hex.grid_id = grid_id

	var region := DataManager.instance.get_region_for(grid_id.x, grid_id.y)
	hex.apply_region(region)

	var pos := Vector3.ZERO

	if pointy_top:
		pos.x = grid_id.x * spacing_vec.x
		pos.z = grid_id.y * spacing_vec.y + (grid_id.x & 1) * (spacing_vec.y / 2.0)
	else:
		pos.x = grid_id.x * spacing_vec.x + (grid_id.y & 1) * (spacing_vec.x / 2.0)
		pos.z = grid_id.y * spacing_vec.y
	hex.position = pos
	
	return hex

func expand_from_chunk(cx: int, cy: int, dir: int) -> void:
	var offset := CHUNK_DIR_VECTORS[dir]
	var new_coords := Vector2i(cx + offset.x, cy + offset.y)

	if chunks.has(new_coords):
		return

	generate_chunk(new_coords.x, new_coords.y)
	
func _post_process_chunk(chunk: HexChunk) -> void:
	for generated_hex in chunk.hexes:
		var hex_right = chunk.get_hex(generated_hex.grid_id + Vector2i(1, 0))
		if hex_right && hex_right.region == generated_hex.region:
			var found_hex: bool = false;
			for r: RegionInstance in _get_instances_for_region(generated_hex.region):
				if r.has_hex(hex_right.grid_id):
					r.add_hex(generated_hex.grid_id, generated_hex)
					found_hex = true;
			
			if not found_hex:
				var reg = RegionInstance.new(generated_hex.region);
				reg.add_hex(generated_hex.grid_id, generated_hex)
				_get_instances_for_region(generated_hex.region).append(reg);
		
	var done: bool = true;
	for c in chunks:
		if not chunks[c].is_generated:
			done = false;
	if done:
		for i in region_instances:
			print(i.id, region_instances[i].size())
		
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
					chunk.add_hex(create_hex(grid_id, spacing_vec, sI.packed_scene.instantiate())))
	return chunk

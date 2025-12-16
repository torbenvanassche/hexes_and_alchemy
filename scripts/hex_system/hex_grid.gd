class_name HexGrid
extends Node3D

var pointy_top: bool = false;
var spacing: float = 0.25

@export var initial_chunks: Vector2i = Vector2i(2, 2)

const RADIUS_IN := 1.0
const CHUNK_WIDTH := 8
const CHUNK_HEIGHT := 8

var chunks: Dictionary[Vector2i, HexChunk] = {}

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
		
func get_chunk_coords(x: int, y: int) -> Vector2i:
	return Vector2i(floori(float(x) / CHUNK_WIDTH), floori(float(y) / CHUNK_HEIGHT))
		
func create_hex(x: int, y: int, spacing_vec: Vector2, hex: HexBase) -> HexBase:
	add_child(hex)

	var pos := Vector3.ZERO

	if pointy_top:
		pos.x = x * spacing_vec.x
		pos.z = y * spacing_vec.y + (x % 2) * (spacing_vec.y / 2)
	else:
		pos.x = x * spacing_vec.x + (y % 2) * (spacing_vec.x / 2)
		pos.z = y * spacing_vec.y

	hex.position = pos
	return hex

func expand_from_chunk(cx: int, cy: int, dir: int) -> void:
	var offset := CHUNK_DIR_VECTORS[dir]
	var new_coords := Vector2i(cx + offset.x, cy + offset.y)

	if chunks.has(new_coords):
		return

	generate_chunk(new_coords.x, new_coords.y)
	
func generate_chunk(cx: int, cy: int) -> HexChunk:
	var key := Vector2i(cx, cy)
	if chunks.has(key):
		return chunks[key]

	var chunk := HexChunk.new(cx, cy)
	chunks[key] = chunk

	var spacing_vec := get_spacing()
	var start_x := cx * CHUNK_WIDTH
	var start_y := cy * CHUNK_HEIGHT

	for y in range(start_y, start_y + CHUNK_HEIGHT):
		for x in range(start_x, start_x + CHUNK_WIDTH):
			DataManager.instance.pick_scene(x, y).queue(func(sI: SceneInfo) -> void: chunk.add_hex(create_hex(x, y, spacing_vec, sI.packed_scene.instantiate())));
	return chunk	

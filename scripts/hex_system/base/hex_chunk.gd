class_name HexChunk
extends Node3D

var chunk_x: int
var chunk_y: int

const CHUNK_WIDTH := 8
const CHUNK_HEIGHT := 8

var hexes: Array[HexBase] = []
var bounds: AABB

var _bounds_initialized := false

var is_generated: bool = false;
signal generated(chunk: HexChunk);

func _init(cx: int, cy: int) -> void:
	chunk_x = cx
	chunk_y = cy
	
	name = "Chunk(%s, %s)" % [chunk_x, chunk_y]
	visibility_changed.connect(_propagate_visibility)

func add_hex(hex: HexBase) -> void:
	hexes.append(hex)
	add_child(hex)

	var pos := hex.global_position
	if not _bounds_initialized:
		bounds = AABB(pos, Vector3.ZERO)
		_bounds_initialized = true
	else:
		bounds = bounds.expand(pos)
	
	if hexes.size() == CHUNK_HEIGHT * CHUNK_WIDTH:
		is_generated = true;
		generated.emit(self)

func _propagate_visibility() -> void:
	for hex in hexes:
		hex.visible = visible;

func get_hex(idx: Vector2i) -> HexBase:
	var rV = hexes.filter(func(h: HexBase) -> bool: return h.grid_id == idx);
	if rV.size() == 1:
		return rV[0];
	return null;
	
func pick_random() -> HexBase:
	return hexes.pick_random()

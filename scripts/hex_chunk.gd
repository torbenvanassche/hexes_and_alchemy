class_name HexChunk
extends RefCounted

var chunk_x: int
var chunk_y: int

var hexes: Array[HexBase] = []
var bounds: AABB

var _bounds_initialized := false

func _init(cx: int, cy: int) -> void:
	chunk_x = cx
	chunk_y = cy

func add_hex(hex: HexBase) -> void:
	hexes.append(hex)

	var pos := hex.global_position
	if not _bounds_initialized:
		bounds = AABB(pos, Vector3.ZERO)
		_bounds_initialized = true
	else:
		bounds = bounds.expand(pos)

func set_visible(visible: bool) -> void:
	for hex in hexes:
		hex.visible = visible

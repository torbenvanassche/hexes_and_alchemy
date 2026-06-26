class_name HexChunk
extends Node3D

var chunk_x: int
var chunk_y: int

var chunk_size: Vector2i = Vector2i(4, 4)

var hexes: Array[SceneInstance] = []
var bounds: AABB

var _bounds_initialized := false

var is_generated: bool = false;
signal generated(chunk: HexChunk);

var generate_structures: bool = true;

func _init(cx: int, cy: int, size: Vector2i = Vector2i(4, 4)) -> void:
	chunk_x = cx
	chunk_y = cy
	chunk_size = Vector2i(maxi(1, size.x), maxi(1, size.y))
	
	name = "Chunk(%s, %s)" % [chunk_x, chunk_y]
	visibility_changed.connect(_propagate_visibility)

func add_hex(instance: SceneInstance) -> void:
	var hex := instance.node as HexBase;
	hex.name = "hex(%s, %s, %s)" % [hex.cube_id.x, hex.cube_id.y, hex.cube_id.z]
	hexes.append(instance)
	add_child(hex)

	var pos := hex.global_position
	if not _bounds_initialized:
		bounds = AABB(pos, Vector3.ZERO)
		_bounds_initialized = true
	else:
		bounds = bounds.expand(pos)
	
	if hexes.size() == chunk_size.x * chunk_size.y:
		is_generated = true;
		generated.emit(self)

func _propagate_visibility() -> void:
	for hex in hexes:
		hex.node.visible = visible;
		
func get_center() -> HexBase:
	if hexes.is_empty():
		return null
		
	var center_pos := bounds.position + bounds.size * 0.5
	var closest: HexBase = null
	var best_dist := INF
	
	for hex in hexes:
		var d := hex.node.global_position.distance_squared_to(center_pos) as float;
		if d < best_dist:
			best_dist = d
			closest = hex.node
	return closest

func get_best_structure_hex() -> HexBase:
	if hexes.is_empty():
		return null
	
	var center_pos := bounds.position + bounds.size * 0.5
	var closest: HexBase = null
	var best_dist := INF
	
	for hex_instance in hexes:
		var hex := hex_instance.node as HexBase
		if hex == null or not hex.can_generate or not hex.is_traversable():
			continue
		
		var dist := hex.global_position.distance_squared_to(center_pos)
		if dist < best_dist:
			best_dist = dist
			closest = hex
	
	if closest != null:
		return closest
	return get_center()


func get_hex(idx: Vector2i) -> SceneInstance:
	var rV = hexes.filter(func(h: SceneInstance) -> bool: return h.node.grid_id == idx);
	if rV.size() == 1:
		return rV[0];
	return null;
	
func pick_random() -> SceneInstance:
	return hexes.pick_random()

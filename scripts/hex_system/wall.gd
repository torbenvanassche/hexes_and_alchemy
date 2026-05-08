class_name Obstacle extends Node3D

var cube_id: Vector3i;
var adjacent_id: Vector3i;

func _on_level_generated() -> void:
	var grid := SceneManager.get_active_scene().node as HexGrid
	var target_world := global_transform * (Vector3.LEFT * 2.0)
	
	cube_id = grid.get_hex_at_world_position(global_position).cube_id
	adjacent_id = grid.get_hex_at_world_position(target_world).cube_id
	grid.pathfinder.apply_obstacle(self)

func _ready() -> void:
	(SceneManager.get_active_scene().node as HexGrid).generated.connect(_on_level_generated, CONNECT_ONE_SHOT)

func rotation_to_cube_offset(rot_radians: float) -> Vector3i:
	var deg := rad_to_deg(rot_radians)
	deg = fposmod(-deg, 360.0)

	var dir := int(floor((deg + 30.0) / 60.0)) % 6

	return DataManager.instance.CUBE_DIRS[dir]

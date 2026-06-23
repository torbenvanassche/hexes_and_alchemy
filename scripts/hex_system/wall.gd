class_name Obstacle extends Node3D

var cube_id: Vector3i;
var adjacent_id: Vector3i;

func _on_level_initialized() -> void:
	var grid := SceneManager.get_active_scene().node as HexGrid;
	var target_world := global_transform * (Vector3.LEFT * 2.0);
	var current_hex := grid.get_hex_at_world_position(global_position);
	var adjacent_hex := grid.get_hex_at_world_position(target_world);
	
	if current_hex == null or adjacent_hex == null:
		return;

	cube_id = current_hex.cube_id;
	adjacent_id = adjacent_hex.cube_id;
	grid.pathfinder.apply_obstacle(self);

func _ready() -> void:
	var grid := SceneManager.get_active_scene().node as HexGrid;
	if grid == null:
		return;
	if grid.initialized:
		_on_level_initialized();
	elif not grid.initialized_changed.is_connected(_on_level_initialized):
		grid.initialized_changed.connect(_on_level_initialized, CONNECT_ONE_SHOT);

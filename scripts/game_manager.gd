class_name Manager extends Node

enum InputDevice {
	KEYBOARD_MOUSE,
	CONTROLLER
}

static var instance: Manager;

var camera: SpringArmFollowCamera;
var player_instance: Node3D;
var hex_grid: HexGrid;

var move_player: bool = true;
var current_input_device := InputDevice.KEYBOARD_MOUSE
var snap_camera_on_player_moving: bool = true;

func _ready() -> void:
	instance = self;
	
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		current_input_device = InputDevice.CONTROLLER
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		current_input_device = InputDevice.KEYBOARD_MOUSE
	
func _physics_process(_delta: float) -> void:
	if current_input_device == InputDevice.KEYBOARD_MOUSE && Input.is_action_just_pressed("toggle_input"):
		camera.snapping = !move_player && snap_camera_on_player_moving;
		move_player = !move_player;
		
func input_moves_player() -> bool:
	return move_player || current_input_device == InputDevice.CONTROLLER;

func spawn_player(spawn_hex: HexBase) -> void:
	DataManager.instance.player.queue(_on_player_loaded.bind(spawn_hex))
	
func _on_player_loaded(player_scene: SceneInfo, spawn_hex: HexBase) -> void:
	player_instance = player_scene.get_instance()
	SceneManager.instance.add_child(player_instance)
	player_instance.position = spawn_hex.position;
	camera.target = player_instance;

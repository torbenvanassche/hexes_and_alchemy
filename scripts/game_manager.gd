class_name Manager extends Node

static var instance: Manager;

var camera: SpringArmFollowCamera;
var player_instance: Node3D;
var hex_grid: HexGrid;

var move_player: bool = true;
var snap_camera_on_player_moving: bool = true;

var is_paused: bool = false;

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	instance = self;
	
func input_moves_player() -> bool:
	return move_player || InputManager.is_device(InputManager.InputDevice.CONTROLLER);
	
func _physics_process(_delta: float) -> void:
	if  InputManager.is_device(InputManager.InputDevice.KEYBOARD_MOUSE) && Input.is_action_just_pressed("toggle_input"):
		camera.snapping = !move_player && snap_camera_on_player_moving;
		move_player = !move_player;
		
	if Input.is_action_just_pressed("cancel"):
		pause_game(true);

func spawn_player(spawn_hex: HexBase) -> void:
	DataManager.instance.player.queue(_on_player_loaded.bind(spawn_hex))
	
func _on_player_loaded(player_scene: SceneInfo, spawn_hex: HexBase) -> void:
	player_instance = player_scene.get_instance()
	SceneManager.add_child(player_instance)
	player_instance.position = spawn_hex.position;
	camera.target = player_instance;
	
func pause_game(force: bool = !is_paused) -> void:
	is_paused = force;
	get_tree().paused = is_paused;
	if is_paused:
		DataManager.instance.pause_menu.queue(func(s: SceneInfo) -> void: SceneManager.add(s))

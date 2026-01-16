class_name Manager extends Node

static var instance: Manager;

var spring_arm_camera: SpringArmFollowCamera;
var player_instance: PlayerController;

var grid_storage: Dictionary[String, HexGrid];
var hex_grid: HexGrid;

var move_player: bool = true;
var is_paused: bool = false;

@onready var interaction_prompt: WSD = $"../game_ui/interaction_prompt";

@export var initial_scene: SceneInfo;

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	instance = self;
	
	if DataManager.instance == null:
		call_deferred("_ready");
		return
		
	initial_scene.queue(_initialized);
	
func _initialized(_scene_info: SceneInfo) -> void:
	SceneManager.add(_scene_info);
	SceneManager.set_active_scene(_scene_info);
	pass
	
func input_moves_player() -> bool:
	return move_player || InputManager.is_device(InputManager.InputDevice.CONTROLLER);
	
func _physics_process(_delta: float) -> void:
	if  InputManager.is_device(InputManager.InputDevice.KEYBOARD_MOUSE) && Input.is_action_just_pressed("toggle_input"):
		spring_arm_camera.snap_camera_on_player_moved(!move_player)
		move_player = !move_player;
		
	if Input.is_action_just_pressed("cancel"):
		var current_scene := SceneManager.get_current_scene();
		if current_scene && current_scene.id == "pause_menu":
			pause_game(false);
		else:
			pause_game(true);

func spawn_player(spawn_hex: HexBase) -> void:
	DataManager.instance.get_scene_by_name("player").queue(_on_player_loaded.bind(spawn_hex))
	
func _on_player_loaded(player_scene: SceneInfo, spawn_hex: HexBase) -> void:
	if not player_instance:
		player_instance = SceneManager.add(player_scene, false, true, false);
		spring_arm_camera.target = player_instance;
	player_instance.position = spawn_hex.position;
	
func pause_game(force: bool = !is_paused) -> void:
	is_paused = force;
	get_tree().paused = is_paused;
	var scene := DataManager.instance.get_scene_by_name("pause_menu");
	if is_paused:
		scene.queue(func(s: SceneInfo) -> void: SceneManager.add(s))
	else:
		SceneManager.remove_scene(scene)

class_name Manager extends Node

const FILE_PATH := "user://settings.ini"

static var instance: Manager;

var spring_arm_camera: SpringArmFollowCamera;
var player_instance: PlayerController;

var move_player: bool = true;
var is_paused: bool = false;

var config := ConfigFile.new()
var input: InputSettings

@onready var interaction_prompt: WSD = $"../game_ui/interaction_prompt";
@onready var market: MarketManager = $market_manager;
@onready var quests: QuestManager = $quest_manager;
@onready var journal: JournalManager = $journal_manager;
@onready var toast: Toast = $"../game_ui/RichTextLabel";

@export var initial_scene: SceneInfo;
var active_settlement: Settlement;

var settlements: Array[Settlement] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	instance = self;
	_load_or_create()
	input = InputSettings.new(config)
	
	if DataManager.instance == null:
		call_deferred("_ready");
		return
		
	initial_scene.queue(_initialized);
	
func _initialized(_scene_info: SceneInfo) -> void:
	SceneManager.add(_scene_info);

func _load_or_create() -> void:
	if FileAccess.file_exists(FILE_PATH):
		config.load(FILE_PATH)
	else:
		config.save(FILE_PATH)

func save() -> void:
	config.save(FILE_PATH)
	
func input_moves_player() -> bool:
	return move_player || InputManager.is_device(InputManager.InputDevice.CONTROLLER);
	
func _physics_process(_delta: float) -> void:
	if  InputManager.is_device(InputManager.InputDevice.KEYBOARD_MOUSE) && Input.is_action_just_pressed("toggle_input"):
		spring_arm_camera.snap_camera_on_player_moved(!move_player);
		move_player = !move_player;

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not event.is_action_pressed("cancel"):
		return

	_handle_cancel_input()
	get_viewport().set_input_as_handled()

func _handle_cancel_input() -> void:
	var current_ui_scene := SceneManager.get_current_ui_scene()
	if current_ui_scene != null and current_ui_scene.id != "pause_menu":
		if _can_close_ui_scene(current_ui_scene):
			SceneManager.remove_current_ui_scene()
		return

	pause_game(not is_paused)

func _can_close_ui_scene(scene_info: SceneInfo) -> bool:
	for scene_instance in scene_info.get_live_instances():
		if not SceneManager.is_visible(scene_instance):
			continue
		if scene_instance.node.has_method("can_close") and not scene_instance.node.can_close():
			return false
	return true

func spawn_player(spawn_hex: HexBase = null) -> void:
	var spawn_position := _resolve_spawn_position(spawn_hex);
	DataManager.instance.get_scene_by_name("player").queue(_on_player_loaded.bind(spawn_position));

func _resolve_spawn_position(spawn_hex: HexBase = null) -> Vector3:
	if spawn_hex != null:
		return spawn_hex.global_position;
	if active_settlement != null and active_settlement.spawn_position != null:
		return active_settlement.spawn_position.global_position;
	return Vector3.ZERO;
	
func spawn_in_settlement() -> void:
	if active_settlement:
		DataManager.instance.get_scene_by_name("player").queue(_on_player_loaded.bind(active_settlement.spawn_position.global_position));
	else:
		Debug.err("Can't create player in settlement, no settlement is active.");

func _on_player_loaded(player_scene: SceneInfo, spawn_position: Vector3) -> void:
	if not player_instance:
		player_instance = SceneManager.add(player_scene, true).node;
		spring_arm_camera.target = player_instance;
	player_instance.global_position = spawn_position;
	Manager.instance.spring_arm_camera.snap_to_target();
	
func pause_game(force: bool = !is_paused) -> void:
	is_paused = force;
	get_tree().paused = is_paused;
	var pause_scene := DataManager.instance.get_scene_by_name("pause_menu");
	var settings_scene := DataManager.instance.get_scene_by_name("settings_menu");
	if is_paused:
		pause_scene.queue(func(s: SceneInfo) -> void: SceneManager.add(s));
	else:
		SceneManager.remove_scene(settings_scene);
		SceneManager.remove_scene(pause_scene);
		
func set_active_settlement(settle: Settlement) -> void:
	active_settlement = settle;
	
func get_settlement(interaction: Interaction) -> Settlement:
	if interaction != null and interaction.settlement != null:
		return interaction.settlement
	for settlement in settlements:
		if settlement.contains_interaction(interaction):
			return settlement;
	return null;

class_name Manager extends Node

static var instance: Manager;
var camera: SpringArmFollowCamera;
var player_instance: Node3D;

func _ready() -> void:
	instance = self;

func spawn_player(spawn_hex: HexBase) -> void:
	DataManager.instance.player.queue(_on_player_loaded.bind(spawn_hex))
	
func _on_player_loaded(player_scene: SceneInfo, spawn_hex: HexBase) -> void:
	player_instance = player_scene.packed_scene.instantiate()
	SceneManager.instance.add_child(player_instance)
	player_instance.position = spawn_hex.position;
	camera.target = player_instance;

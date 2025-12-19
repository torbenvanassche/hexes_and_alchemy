class_name Manager extends Node

static var instance: Node;

func _ready() -> void:
	instance = self;

func spawn_player() -> void:
	DataManager.instance.player.queue(_on_player_loaded)
	
func _on_player_loaded(player_scene: SceneInfo) -> void:
	pass

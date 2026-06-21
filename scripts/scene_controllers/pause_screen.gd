class_name PauseMenu extends Panel

@export var resume_button: Button;
@export var settings_button: Button;
@export var quit_button: Button;

func _ready() -> void:
	resume_button.pressed.connect(Manager.instance.pause_game.bind(false))
	
	settings_button.pressed.connect(_on_settings)
	
func _on_settings() -> void:
	SceneManager.set_visible_by_name("pause_menu", false);
	SceneManager.add(DataManager.instance.get_scene_by_name("settings_menu"))
	
func _on_quit() -> void:
	pass

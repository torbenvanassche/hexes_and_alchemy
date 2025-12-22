class_name PauseMenu extends Panel

@export var resume_button: Button;
@export var settings_button: Button;
@export var quit_button: Button;

func _ready() -> void:
	resume_button.pressed.connect(Manager.instance.pause_game.bind(false))
	resume_button.pressed.connect(_on_resume)
	
func _on_resume() -> void:
	SceneManager.remove_scene_by_name("pause_menu")

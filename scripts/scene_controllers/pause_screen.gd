class_name PauseMenu extends Panel

@export var resume_button: Button;
@export var settings_button: Button;
@export var quit_button: Button;

func _ready() -> void:
	resume_button.pressed.connect(Manager.instance.pause_game.bind(false))

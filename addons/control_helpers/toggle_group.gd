extends Node

@export var button_group_parent: Control;
@export var tab_instance_parent: Control;

@export var group_buttons: Dictionary[Button, SceneInfo];

var btn_group: ButtonGroup;

func _ready() -> void:
	btn_group = ButtonGroup.new();
	for btn in group_buttons.keys():
		btn.button_group = btn_group;
		btn.pressed.connect(_on_tab_changed.bind(group_buttons[btn]))
	
func _on_tab_changed(button: BaseButton, scene_info: SceneInfo) -> void:
	scene_info.queue(_on_tab_change_scene_loaded)
	
func _on_tab_change_scene_loaded(scene_info: SceneInfo) -> void:
	pass

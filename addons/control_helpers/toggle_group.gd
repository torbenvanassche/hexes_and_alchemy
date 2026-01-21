extends Node

@export var button_group_parent: Control;
@export var tab_instance_parent: Control;

@export var group_buttons: Dictionary[Button, SceneInfo];
@export var back_button: Button;

var btn_group: ButtonGroup;

func _ready() -> void:
	btn_group = ButtonGroup.new();
	for btn in group_buttons.keys():
		btn.button_group = btn_group;
		btn.toggle_mode = true;
	btn_group.pressed.connect(_on_tab_changed)
	back_button.pressed.connect(_on_back_button)
	
	_on_tab_changed(group_buttons.keys()[0])
	
func _on_back_button() -> void:
	SceneManager.set_visible_by_name("settings_menu", false);
	var prev_scene := SceneManager.to_previous_scene()
	SceneManager.set_visible(prev_scene)
	
func _on_tab_changed(button: BaseButton) -> void:
	for tab: SceneInfo in group_buttons.values():
		if tab:
			var instance = tab.get_instance();
			if "visible" in instance:
				instance.visible = false;
	var scene_info: SceneInfo = group_buttons.get(button)
	if scene_info:
		scene_info.queue(_on_tab_change_scene_loaded)
	
func _on_tab_change_scene_loaded(scene_info: SceneInfo) -> void:
	var opened_scene := scene_info.get_instance()
	if not opened_scene.is_inside_tree():
		tab_instance_parent.add_child(opened_scene)
	opened_scene.visible = true;

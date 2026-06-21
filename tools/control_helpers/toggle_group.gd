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
	back_button.pressed.connect(_on_back_button)
	
	var first_button := group_buttons.keys()[0] as BaseButton
	first_button.button_pressed = true
	btn_group.pressed.connect(_on_tab_changed)
	_on_tab_changed(first_button)
	
func _on_back_button() -> void:
	SceneManager.remove_current_ui_scene()
	
func _on_tab_changed(button: BaseButton) -> void:
	for tab: SceneInfo in group_buttons.values():
		if tab:
			for instance in tab.get_live_instances():
				if "visible" in instance.node:
					instance.node.visible = false;
	var scene_info: SceneInfo = group_buttons.get(button)
	if scene_info:
		scene_info.queue(_on_tab_change_scene_loaded)
	
func _on_tab_change_scene_loaded(scene_info: SceneInfo) -> void:
	var opened_scene := scene_info.get_instance()
	var node := opened_scene.node
	if node.get_parent() != tab_instance_parent:
		if node.get_parent() != null:
			node.reparent(tab_instance_parent)
		else:
			tab_instance_parent.add_child(node)
	
	if node is Control:
		var control := node as Control
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	if "visible" in node:
		node.visible = true;

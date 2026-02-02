class_name SceneInstance
extends Node

var scene_info: SceneInfo
var node: Node

signal on_leave
signal on_enter

func _init(_n: Node, s_info: SceneInfo) -> void:
	node = _n; 
	scene_info = s_info;
	
	if "scene_instance" in node:
		node.scene_instance = self

	if node.has_method("on_load"):
		on_enter.connect(node.on_load, CONNECT_ONE_SHOT)

	if node.has_method("on_enter"):
		on_enter.connect(node.on_enter)

	if scene_info.destroy_on_player_leave:
		on_leave.connect(destroy)

	on_enter.emit()

func destroy() -> void:
	if is_instance_valid(node):
		node.queue_free()
	queue_free()

func set_processing(enabled: bool) -> void:
	node.process_mode = (scene_info.process_mode_enabled if enabled else scene_info.process_mode_disabled)

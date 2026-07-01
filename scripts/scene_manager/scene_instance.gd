class_name SceneInstance
extends Node

var scene_info: SceneInfo
var node: Node
var _is_destroyed := false

signal on_leave
signal on_enter

func _init(_n: Node, s_info: SceneInfo) -> void:
	node = _n; 
	scene_info = s_info;
	node.tree_exiting.connect(_on_node_tree_exiting, CONNECT_ONE_SHOT)
	
	if "scene_instance" in node:
		node.scene_instance = self

	if node.has_method("on_load"):
		on_enter.connect(node.on_load, CONNECT_ONE_SHOT)

	if node.has_method("on_enter"):
		on_enter.connect(node.on_enter)

	if scene_info.destroy_on_player_leave:
		on_leave.connect(destroy)

func destroy() -> void:
	_unregister()
	if is_instance_valid(node):
		node.queue_free()
	queue_free()

func _on_node_tree_exiting() -> void:
	_unregister()

func _unregister() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	if scene_info != null:
		scene_info.instances.erase(self)
	if DataManager.instance != null:
		DataManager.instance.unregister_scene_instance(self)
	
func hide() -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("can_close") and not node.call("can_close"):
		return
	if "visible" in node:
		node.visible = false;

func set_processing(enabled: bool) -> void:
	node.process_mode = (scene_info.process_mode_enabled if enabled else scene_info.process_mode_disabled)

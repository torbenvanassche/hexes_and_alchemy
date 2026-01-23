class_name SceneInstance extends RefCounted

var node: Node;
var scene_info: SceneInfo;

signal on_leave();
signal on_enter();

func _init(_n: Node, s_info: SceneInfo) -> void:
	node = _n;
	scene_info = s_info;
	if "scene_instance" in node:
		node.scene_instance = self;
	if node.has_method("on_load"):
		on_enter.connect(node.on_load, CONNECT_ONE_SHOT)
	if node.has_method("on_enter"):
		on_enter.connect(node.on_enter);
	if s_info.destroy_on_player_leave:
		on_leave.connect(s_info.destroy_instance.bind(self))
		
func set_process_mode(b: bool) -> void:
	if b: 
		node.process_mode = scene_info.process_mode_enabled;
	else:
		node.process_mode = scene_info.process_mode_disabled;

func destroy() -> void:
	for sig in on_leave.get_connections():
		if on_leave.is_connected(sig.callable):
			on_leave.disconnect(sig.callable);
	for sig in on_enter.get_connections():
		if on_enter.is_connected(sig.callable):
			on_enter.disconnect(sig.callable);
	node.free();
		
	if get_reference_count() > 0:
		Debug.message("Reference count for object %s is %s" % [self, get_reference_count()])

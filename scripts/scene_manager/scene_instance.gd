class_name SceneInstance extends RefCounted

var node: Node;
var scene_info: SceneInfo;

signal on_player_leave();
signal on_player_enter();

func _init(_n: Node, s_info: SceneInfo) -> void:
	node = _n;
	scene_info = s_info;
	if "scene_instance" in node:
		node.scene_instance = self;

func destroy() -> void:
	if node is HexGrid:
		SceneManager.remove_hex_grid((node as HexGrid).grid_name)
	
	for sig in on_player_leave.get_connections():
		if on_player_leave.is_connected(sig.callable):
			on_player_leave.disconnect(sig.callable);
	for sig in on_player_enter.get_connections():
		if on_player_enter.is_connected(sig.callable):
			on_player_enter.disconnect(sig.callable);
	node.free();
		
	if get_reference_count() > 0:
		Debug.message("Reference count for object %s is %s" % [self, get_reference_count()])

class_name SceneInstance extends RefCounted

var node: Node;
var scene_info: SceneInfo;

func _init(_n: Node, s_info: SceneInfo) -> void:
	node = _n;
	scene_info = s_info;
	if "scene_instance" in node:
		node.scene_instance = self;

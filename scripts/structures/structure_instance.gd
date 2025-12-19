class_name StructureInstance extends RefCounted

var structure_info: StructureInfo;
var instance: Node3D;

func _init(s: StructureInfo, node: Node) -> void:
	structure_info = s;
	instance = node;

class_name StructureInstance extends RefCounted

var structure_info: StructureInfo;
var instance: Node3D;

func _init(s: StructureInfo, node: Node) -> void:
	structure_info = s;
	instance = node;
	
	var enterable_triggers:= instance.find_children("*", "Area3D", true, false)
	if enterable_triggers.size() == 1:
		var trigger: Area3D = enterable_triggers[0];
		trigger.area_entered.connect(s.queue.bind(_on_area_load))
		
func _on_area_load(scene_info: SceneInfo) -> void:
	var scene = SceneManager.add(scene_info)
	SceneManager.transition(scene);

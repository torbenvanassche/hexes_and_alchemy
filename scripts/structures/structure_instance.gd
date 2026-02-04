class_name StructureInstance extends SceneInstance

var structure_info: StructureInfo;
var instance: Node3D;

var meshes: Array[MeshInstance3D]

func _init(_n: Node, s: SceneInfo) -> void:
	structure_info = s;
	instance = _n;
	
	meshes.assign(instance.find_children("*", "MeshInstance3D", true, false))
		
func destroy() -> void:
	instance.queue_free()
	queue_free()
	super();

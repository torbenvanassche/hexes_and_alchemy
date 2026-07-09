class_name StructureInstance extends SceneInstance

var structure_info: StructureInfo;
var instance: Node;

var meshes: Array[MeshInstance3D] = []

func _init(_n: Node, s: SceneInfo) -> void:
	super(_n, s);
	structure_info = s as StructureInfo;
	instance = node;
	
	meshes.assign(instance.find_children("*", "MeshInstance3D", true, false));
		
func destroy() -> void:
	super();

extends Interaction

@export var material: StandardMaterial3D;
@export var item_info: ItemInfo;

func _ready() -> void:
	super();
	for mesh: MeshInstance3D in hex.structure.meshes:
		mesh.material_override = material;

func interact() -> void:
	var mined_structure := hex.structure
	hex.structure = null
	if mined_structure:
		mined_structure.destroy()
	Manager.instance.player_instance.inventory.add(item_info, 1)
	
func can_interact() -> bool:
	return true;

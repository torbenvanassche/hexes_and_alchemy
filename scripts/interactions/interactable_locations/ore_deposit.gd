extends Interaction

@export var material: StandardMaterial3D;
@export var item_info: ItemInfo;

func _ready() -> void:
	super();
	for mesh: MeshInstance3D in structure_instance.meshes:
		mesh.material_override = material;

func interact() -> void:
	structure_instance.destroy()
	Manager.instance.player_instance.inventory.add(item_info, 1)
	pass
	
func can_interact() -> bool:
	return true;

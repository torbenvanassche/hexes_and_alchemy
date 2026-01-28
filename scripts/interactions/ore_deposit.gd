extends Interaction

@export var material: StandardMaterial3D;

func setup() -> void:
	for mesh: MeshInstance3D in structure_instance.meshes:
		mesh.material_override = material;

func interact() -> void:
	pass

extends Interaction

@export var material: StandardMaterial3D;

func _ready() -> void:
	super()
	for mesh: MeshInstance3D in structure_instance.meshes:
		mesh.material_override = material;

func interact() -> void:
	structure_instance.destroy()
	pass

extends Interaction

@onready var foundation: Node3D = $foundation
@onready var fully_built: Node3D = $fully_built

func interact() -> void:
	pass

func can_interact() -> bool:
	return true;

extends Interaction

@export var project_id := "water"

func interact() -> void:
	Manager.instance.regional.open_request(project_id)

func can_interact() -> bool:
	return true

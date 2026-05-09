extends QuestObjective

@onready var wheat: Node3D = $wheat

func interact() -> void:
	pass
	
func can_interact() -> bool:
	return true;
	
func execute_quest(q: Quest) -> void:
	pass

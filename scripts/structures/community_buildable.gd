extends Buildable

@export var project_id := "water"

func _ready() -> void:
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = preload("res://materials/kay_fantasy_default.tres")
	super()

func _on_step_completed(step: BuildRequest) -> void:
	if step != current_step or step.quest == null: return
	step.quest.initialize()
	if not step.quest.progress_tracker.has_all(step.quest.requested_items): return
	super(step)
	Manager.instance.regional.finish_construction(project_id)

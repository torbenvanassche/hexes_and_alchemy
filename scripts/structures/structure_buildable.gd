extends Node

@export var build_steps: Array[Interaction];
var current_step: Interaction;

func _ready() -> void:
	current_step = build_steps[0];
	for step in build_steps:
		if step is FetchQuest:
			step.completed.connect(_on_step_completed.bind(step))
		if build_steps.find(step) != 0:
			step.visible = false;
			
func _on_step_completed(step: FetchQuest) -> void:
	var index := build_steps.find(step);
	if index < build_steps.size() - 1:
		current_step.visible = false;
		current_step = build_steps[index + 1];
		current_step.visible = true;
	else:
		Debug.err("Can't advance step on structure, as it would go out of range!")

class_name Buildable extends Node

@export var build_steps: Array[Interaction];
@export var start_step_index: int = 0;
var current_step: Interaction;

func _ready() -> void:
	current_step = build_steps[start_step_index];
	for step in build_steps:
		if step is BuildRequest:
			step.completed.connect(_on_step_completed.bind(step))
		if build_steps.find(step) != start_step_index:
			step.visible = false;
		if "buildable_structure" in step:
			step.buildable_structure = self;
		step._on_visibility_changed();
	current_step.visible = true;
	
func _on_step_completed(step: BuildRequest) -> void:
	var index := build_steps.find(step);
	if index < build_steps.size() - 1:
		current_step.visible = false;
		current_step = build_steps[index + 1];
		current_step.visible = true;
	else:
		Debug.err("Can't advance step on structure, as it would go out of range!")

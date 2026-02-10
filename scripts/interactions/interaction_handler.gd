@abstract class_name Interaction extends Node3D

var structure_instance: StructureInstance;

var enterable_triggers: Array[Area3D];
var colliders: Array[StaticBody3D];
var collision_shapes: Array[CollisionShape3D];

@abstract func interact() -> void;
@abstract func can_interact() -> bool;

func _ready() -> void:
	enterable_triggers.assign(find_children("*", "Area3D", true, false))
	colliders.assign(find_children("*", "StaticBody3D", true, false))
	collision_shapes.assign(find_children("*", "CollisionShape3D", true, false))
	
	for trigger: Area3D in enterable_triggers:
		trigger.set_meta("target", self)
		trigger.area_entered.connect(_on_area_enter)
		trigger.area_exited.connect(_on_area_exit);
		
	visibility_changed.connect(_on_visibility_changed)
	
func on_interact() -> void:
	if can_interact():
		interact();

func _on_visibility_changed() -> void:
	for shape in collision_shapes:
		shape.disabled = not is_visible_in_tree();

func _on_area_exit(other: Area3D) -> void:
	if other.get_parent() is PlayerController:
		Manager.instance.interaction_prompt.show_rect(null)
		
func _on_area_enter(other: Area3D) -> void:
	if other.get_parent() is PlayerController && can_interact():
		Manager.instance.interaction_prompt.show_rect(self);

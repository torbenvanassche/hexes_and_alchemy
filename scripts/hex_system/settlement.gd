class_name Settlement extends Node3D

@export var spawn_position: Node3D;
@export var is_active_settlement: bool = false;

var collision_shapes: Array[CollisionShape3D];

func _ready() -> void:
	collision_shapes.assign(find_children("*", "CollisionShape3D", true, false))
	
	if is_active_settlement:
		Manager.instance.set_active_settlement(self);
	Manager.instance.spawn_in_settlement();
	visibility_changed.connect(_toggle_collision)
	
func _toggle_collision() -> void:
	for collision in collision_shapes:
		collision.disabled = not self.is_visible_in_tree();

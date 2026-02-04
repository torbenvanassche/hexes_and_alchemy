class_name Settlement extends Node

@export var spawn_position: Node3D;
@export var is_active_settlement: bool = false;

func _ready() -> void:
	if is_active_settlement:
		Manager.instance.set_active_settlement(self);
	Manager.instance.spawn_in_settlement();

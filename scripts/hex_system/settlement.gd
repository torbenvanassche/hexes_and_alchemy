class_name Settlement extends Node

@export var spawn_position: Node3D;

func _ready() -> void:
	Manager.instance.set_active_settlement(self);
	#TODO: Spawn player in settlement at spawn_position

extends Node3D

@export var max_angle: float = 0;
@export var duration: float = 1;
var start_angle: float;

func _ready() -> void:
	start_angle = rotation.z;

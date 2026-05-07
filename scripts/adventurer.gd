extends Node3D

@export var material: Material;

func _ready() -> void:
	$"mesh/RootNode/unit".material_override = material;

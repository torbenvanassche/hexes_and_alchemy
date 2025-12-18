class_name HexBase
extends Node3D

var grid_id: Vector2i;

var meshes: Array[MeshInstance3D] = [];
var region: RegionInfo;

func _ready() -> void:
	meshes.assign(find_children("*", "MeshInstance3D", true, false))

func apply_region(reg: RegionInfo) -> void:
	region = reg;
	for mesh in meshes:
		if reg && reg.material:
			mesh.material_override = reg.material;

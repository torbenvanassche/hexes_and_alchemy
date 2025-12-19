class_name HexBase
extends Node3D

var grid_id: Vector2i;
var cube_id: Vector3i;

var meshes: Array[MeshInstance3D] = [];
var region_instance: RegionInstance;
var region: RegionInfo;

var structure: StructureInstance;

func _ready() -> void:
	meshes.assign(find_children("*", "MeshInstance3D", true, false))

func apply_region(reg: RegionInfo) -> void:
	region = reg;
	for mesh in meshes:
		if reg && reg.material:
			mesh.material_override = reg.material;

func set_structure(s: StructureInfo) -> void:
	s.queue(_on_structure_loaded)
	
func _on_structure_loaded(s: StructureInfo) -> void:
	structure = StructureInstance.new(s, s.packed_scene.instantiate());
	add_child(structure.instance);
	_ready();
	apply_region(region)

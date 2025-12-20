class_name HexBase
extends Node3D

var grid_id: Vector2i;
var cube_id: Vector3i;

var meshes: Array[MeshInstance3D] = [];
var region_instance: RegionInstance;
var region: RegionInfo;

var structure: StructureInstance;
var scene_info: SceneInfo;
var static_body: StaticBody3D;

var collision_scene: PackedScene = preload("res://scenes/hex_collision.tscn");

func _ready() -> void:
	meshes.assign(find_children("*", "MeshInstance3D", true, false))
	
	if scene_info.has_collision:
		static_body = collision_scene.instantiate();
		add_child(static_body)

func apply_region(reg: RegionInfo) -> void:
	region = reg;
	for mesh in meshes:
		if reg && reg.material:
			mesh.material_override = reg.material;
			
func is_walkable(_player: PlayerController) -> bool:
	return scene_info.is_walkable;

func set_structure(s: StructureInfo) -> void:
	s.queue(_on_structure_loaded)
	
func _on_structure_loaded(s: StructureInfo) -> void:
	structure = StructureInstance.new(s, s.get_instance());
	add_child(structure.instance);
	_ready();
	apply_region(region)

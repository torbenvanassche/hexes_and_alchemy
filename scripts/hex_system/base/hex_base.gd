class_name HexBase
extends Node3D

var grid_id: Vector2i;
var cube_id: Vector3i;
var can_generate: bool = true;

var meshes: Array[MeshInstance3D] = [];
var region_instance: RegionInstance;
var region: RegionInfo;

var structure_root_tile: Vector3i;

var structure: StructureInstance;
var static_body: StaticBody3D;
var scene_instance: SceneInstance;

var ground_mesh: MeshInstance3D;

var collision_scene: PackedScene = preload("res://scenes/hex_collision.tscn");

func _ready() -> void:
	ground_mesh = _get_meshes()[0];
		
func _get_meshes() -> Array[MeshInstance3D]:
	meshes.assign(find_children("*", "MeshInstance3D", true, false))
	return meshes

func apply_region(reg: RegionInfo) -> void:
	region = reg

	if not reg or not reg.material:
		return

	var structure_meshes := []
	if structure and structure.instance:
		structure_meshes = structure.instance.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if structure_meshes.has(mesh) and structure.structure_info.structure_material:
			mesh.material_override = structure.structure_info.structure_material
		else:
			mesh.material_override = reg.material

func is_walkable(_player: PlayerController = Manager.instance.player_instance) -> bool:
	return scene_instance && scene_instance.scene_info && scene_instance.scene_info.is_walkable;

func set_structure(s: StructureInfo) -> void:
	var required_tiles = SceneManager.get_active_scene().node.get_tiles_in_radius(cube_id, s.required_space_radius);
	required_tiles.all(func(f: HexBase) -> void: f.can_generate = false);
	required_tiles = required_tiles.filter(func(f: HexBase) -> bool: return not f.is_walkable());
	s.queue(_on_structure_loaded.bind(required_tiles));
	
##When the structure finishes loading, add the instance to the scene and validate adjacent tiles
func _on_structure_loaded(s: StructureInfo, required_tiles: Array[HexBase]) -> void:
	structure = StructureInstance.new(s, s.get_instance().node);
	add_child(structure.instance);
	structure.instance.rotate_y(deg_to_rad(60 * randi_range(0, 5)))
	_ready();
	
	for t in required_tiles:
		SceneManager.get_active_scene().node.replace(t, scene_instance.scene_info.get_instance().node, region);
	apply_region(region)

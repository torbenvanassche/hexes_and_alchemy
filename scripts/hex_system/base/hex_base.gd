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
var scene_info: SceneInfo;
var static_body: StaticBody3D;

var ground_mesh: MeshInstance3D;

var collision_scene: PackedScene = preload("res://scenes/hex_collision.tscn");

func _ready() -> void:
	ground_mesh = _get_meshes()[0];
		
func _get_meshes() -> Array[MeshInstance3D]:
	meshes.assign(find_children("*", "MeshInstance3D", true, false))
	return meshes

func apply_region(reg: RegionInfo) -> void:
	region = reg;
	for mesh in meshes:
		if reg && reg.material:
			mesh.material_override = reg.material;
			
func is_walkable(_player: PlayerController = Manager.instance.player_instance) -> bool:
	return scene_info && scene_info.is_walkable;

func set_structure(s: StructureInfo) -> void:
	var required_tiles = SceneManager.hex_grid.get_tiles_in_radius(cube_id, s.required_space_radius);
	required_tiles.all(func(f: HexBase) -> void: f.can_generate = false);
	required_tiles = required_tiles.filter(func(f: HexBase) -> bool: return not f.is_walkable());
	s.queue(_on_structure_loaded.bind(required_tiles));
	
func _on_structure_loaded(s: StructureInfo, required_tiles: Array[HexBase]) -> void:
	structure = StructureInstance.new(s, s.get_instance());
	add_child(structure.instance);
	structure.instance.rotate_y(deg_to_rad(60 * randi_range(0, 5)))
	_ready();
	
	for t in required_tiles:
		SceneManager.hex_grid.replace(t, scene_info.get_instance(), region);
	apply_region(region)

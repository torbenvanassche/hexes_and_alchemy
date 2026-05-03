class_name HexBase
extends Node3D

var grid_id: Vector2i;
var cube_id: Vector3i;
var can_generate: bool = true;

var region_instance: RegionInstance;
var region: RegionInfo;

var structure_root_tile: Vector3i;

var structure: StructureInstance;
var static_body: StaticBody3D;
var scene_instance: SceneInstance;

var collision_scene: PackedScene = preload("res://scenes/hex_collision.tscn");
const UNEXPLORED_MATERIAL = preload("uid://bgsi1yhfo1pe2")

var ground_hex_mesh: MeshInstance3D;
var is_explored: bool = false:
	set(value):
		is_explored = value;
		set_explored(is_explored)

func _ready() -> void:
	ground_hex_mesh = find_child("hex_*", true) as MeshInstance3D;
	set_explored(false)

func set_explored(b: bool) -> void:
	(ground_hex_mesh as MeshInstance3D).material_override = null if b else UNEXPLORED_MATERIAL;
	(ground_hex_mesh as MeshInstance3D).layers = 1 if b else 2;
	if structure:
		for s: MeshInstance3D in structure.instance.find_children("*", "MeshInstance3D", true, false):
			s.visible = b;

func apply_region(reg: RegionInfo) -> void:
	region = reg

	if not reg or not reg.material:
		return

	var structure_meshes := []
	if structure and structure.instance:
		structure_meshes = structure.instance.find_children("*", "MeshInstance3D", true, false)
	for mesh in get_meshes():
		var material := reg.material
		if structure_meshes.has(mesh) and not structure.structure_info.use_parent_material:
			material = structure.structure_info.structure_material
		mesh.set_surface_override_material(0, material)
		
func get_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D]
	meshes.assign(find_children("*", "MeshInstance3D", true, false))
	for m in meshes:
		if m.owner.name == "hidden_hex":
			meshes.erase(m);
	return meshes;

func is_walkable(_player: PlayerController = Manager.instance.player_instance) -> bool:
	return scene_instance && scene_instance.scene_info && scene_instance.scene_info.is_walkable;

func set_structure(s: StructureInfo) -> void:
	var required_tiles: Array[SceneInstance] = SceneManager.get_active_scene().node.get_tiles_in_radius(cube_id, s.required_space_radius);
	required_tiles.all(func(f: SceneInstance) -> void: f.node.can_generate = false);
	required_tiles = required_tiles.filter(func(f: SceneInstance) -> bool: return not f.node.is_walkable());
	s.queue(_on_structure_loaded.bind(required_tiles));
	
##When the structure finishes loading, add the instance to the scene and validate adjacent tiles
func _on_structure_loaded(s: StructureInfo, required_tiles: Array[SceneInstance]) -> void:
	structure = StructureInstance.new(s.get_instance().node, s);
	if structure.instance:
		if structure.instance is Interaction:
			(structure.instance as Interaction).structure_instance = structure;
		add_child(structure.instance);
		if s.randomize_rotation:
			structure.instance.rotate_y(deg_to_rad(60 * randi_range(0, 5)))
	
	for t in required_tiles:
		SceneManager.get_active_scene().node.replace(t, scene_instance.scene_info.get_instance(), region);
	apply_region(region)
	
	if not is_explored:
		set_explored(false);

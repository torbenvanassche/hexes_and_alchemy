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
static var _debug_drop_valid_material: StandardMaterial3D;
static var _debug_drop_invalid_material: StandardMaterial3D;
signal structure_loaded(structure_info: StructureInfo, structure_node: Node)

var ground_hex_mesh: MeshInstance3D;
var is_explored: bool = false:
	set(value):
		if is_explored == value:
			return
		
		is_explored = value;
		if ground_hex_mesh != null:
			set_explored(is_explored)
		
var blocked: bool = false;
var movement_cost: float = 1.0;

func _ready() -> void:
	ground_hex_mesh = find_child("hex_*", true) as MeshInstance3D;
	set_explored(false)

func set_drop_debug_tint(can_drop: bool) -> void:
	if ground_hex_mesh == null:
		ground_hex_mesh = find_child("hex_*", true) as MeshInstance3D;
	if ground_hex_mesh == null:
		return

	ground_hex_mesh.material_overlay = _get_drop_debug_material(can_drop)

func clear_drop_debug_tint() -> void:
	if ground_hex_mesh == null:
		ground_hex_mesh = find_child("hex_*", true) as MeshInstance3D;
	if ground_hex_mesh == null:
		return

	ground_hex_mesh.material_overlay = null

func _get_drop_debug_material(can_drop: bool) -> StandardMaterial3D:
	if can_drop:
		if _debug_drop_valid_material == null:
			_debug_drop_valid_material = StandardMaterial3D.new()
			_debug_drop_valid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_debug_drop_valid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_debug_drop_valid_material.albedo_color = Color(0.2, 1.0, 0.35, 0.35)
		return _debug_drop_valid_material

	if _debug_drop_invalid_material == null:
		_debug_drop_invalid_material = StandardMaterial3D.new()
		_debug_drop_invalid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_drop_invalid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_debug_drop_invalid_material.albedo_color = Color(1.0, 0.2, 0.25, 0.35)
	return _debug_drop_invalid_material

func set_explored(b: bool) -> void:
	if ground_hex_mesh == null:
		return
	
	(ground_hex_mesh as MeshInstance3D).material_override = null if b else UNEXPLORED_MATERIAL;
	(ground_hex_mesh as MeshInstance3D).layers = 1 if b else 2;
	if structure:
		var quest_objective := structure.instance as QuestObjective;
		if quest_objective:
			quest_objective.visibility_changed.emit();
		for s: MeshInstance3D in structure.instance.find_children("*", "MeshInstance3D", true, false):
			s.visible = b;

func apply_region(reg: RegionInfo) -> void:
	region = reg

	if not reg or not reg.material:
		return

	if ground_hex_mesh == null:
		ground_hex_mesh = find_child("hex_*", true) as MeshInstance3D
	if ground_hex_mesh != null:
		ground_hex_mesh.set_surface_override_material(0, reg.material)

func is_traversable(method: HexInfo.TraversalTag = HexInfo.TraversalTag.WALK) -> bool:
	if blocked:
		return false
	return (scene_instance.scene_info as HexInfo).traversal_tags.has(method);

func set_structure(s: StructureInfo, immediate: bool = false) -> void:
	var required_tiles: Array[SceneInstance] = SceneManager.get_active_scene().node.get_tiles_in_radius(cube_id, s.required_space_radius);
	for required_tile in required_tiles:
		required_tile.node.can_generate = false

	var footprint_replacements: Array[SceneInstance] = [];
	if s.replace_non_traversable_hex:
		footprint_replacements.assign(required_tiles.filter(
			func(f: SceneInstance) -> bool:
				return f.node.cube_id != cube_id and not f.node.is_traversable()
		))
	if immediate:
		_on_structure_loaded(s, footprint_replacements)
	else:
		s.queue(_on_structure_loaded.bind(footprint_replacements));
	
##When the structure finishes loading, add the instance to the scene and validate adjacent tiles
func _on_structure_loaded(s: StructureInfo, required_tiles: Array[SceneInstance]) -> void:
	if region_instance != null:
		region_instance.structures[cube_id] = s;
	structure_root_tile = cube_id;

	structure = StructureInstance.new(s.get_instance().node, s);
	if structure.instance:
		if structure.instance is Interaction:
			(structure.instance as Interaction).hex = self;
		add_child(structure.instance);
		var placement_rotation := _get_structure_placement_rotation(s)
		if bool(placement_rotation.get("has_rotation", false)):
			structure.instance.rotation.y = float(placement_rotation["rotation_y"])
		elif s.randomize_rotation:
			var grid := SceneManager.get_active_scene().node as HexGrid
			var rng := grid.create_rng("structure_rotation:%s:%s" % [cube_id, s.resource_path]) if grid != null else null
			var rotation_step := rng.randi_range(0, 5) if rng != null else randi_range(0, 5)
			structure.instance.rotate_y(deg_to_rad(60 * rotation_step))
	
	for t in required_tiles:
		SceneManager.get_active_scene().node.replace(t, scene_instance.scene_info.get_instance(), region);
	apply_region(region)
	
	if not is_explored:
		set_explored(false);
	
	structure_loaded.emit(s, structure.instance)

func _get_structure_placement_rotation(s: StructureInfo) -> Dictionary:
	var placeable := s as PlaceableStructureInfo
	if placeable == null:
		return { "has_rotation": false }
	return placeable.get_placement_rotation_y(self)

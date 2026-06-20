class_name StructureInfo extends SceneInfo

##Defines how many times this can appear for a region, size is defined on the X-axis
@export var max_per_region_size: Curve = Curve.new();

##The space required for this structure to generate
@export var required_space_radius: int = 0;

##Minimum distance from structure to nearest adjacent structure
@export var minimum_distance_from_other_structures: int = 2;

##How common this item is in the spawning algorithm
@export var spawn_weight: float = 1;

@export var randomize_rotation: bool = true;

@export var is_quest_target: bool = true;

##Optional custom material for the node, if not set it will default to use the material of the region it belongs to.
@export var structure_material: StandardMaterial3D;
@export var use_parent_material: bool = true;

func initialize() -> void:
	self.type = Type.STRUCTURE;
	super();

func get_display_name() -> String:
	var translation_key := "STRUCTURE_%s_NAME" % [id.to_upper()]
	var translated := tr(translation_key)
	if translated == translation_key:
		return id.capitalize()
	return translated
	
func get_max_count(tile_count: int) -> int:
	return round(max_per_region_size.sample(tile_count))

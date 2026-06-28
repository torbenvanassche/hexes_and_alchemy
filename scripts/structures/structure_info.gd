class_name StructureInfo extends SceneInfo

##Defines how many times this can appear for a region, size is defined on the X-axis
@export var max_per_region_size: Curve = Curve.new();

##The space required for this structure to generate
@export var required_space_radius: int = 0;

##Minimum distance from structure to nearest adjacent structure
@export var minimum_distance_from_other_structures: int = 1;

##How common this item is in the spawning algorithm
@export var spawn_weight: float = 1;

##Whether blocked terrain inside the structure footprint should be converted to the center tile type
@export var replace_non_traversable_hex: bool = true;

##How far from the structure footprint terrain can be converted to preserve a walkable passage
@export var passage_repair_radius: int = 2;

@export var randomize_rotation: bool = true;

@export var random_rotation_requires_walkable_neighbor: bool = false;

@export var is_quest_target: bool = true;

@export var translation_key_name: String;

func initialize() -> void:
	self.type = Type.STRUCTURE;
	super();

func get_display_name() -> String:
	if translation_key_name == "":
		return id.capitalize()
	var translated := tr(translation_key_name)
	if translated == translation_key_name:
		return id.capitalize()
	return translated
	
func get_max_count(tile_count: int) -> int:
	return round(max_per_region_size.sample(tile_count))

class_name StructureInfo extends SceneInfo

##Defines how many times this can appear for a region, size is defined on the X-axis
@export var max_per_region_size: Curve = Curve.new();

##The space required for this structure to generate
@export var required_space_radius: int = 0;

##Minimum distance from structure to nearest adjacent structure
@export var minimum_distance_from_other_structures: int = 4;

##How common this item is in the spawning algorithm
@export var spawn_weight: float = 1;

##The script that defines interaction with the player. This must contain an `execute` function
@export var interaction_script: Script;

@export var interaction_data: Dictionary[String, Variant];

##Optional custom material for the node, if not set it will default to use the material of the region it belongs to.
@export var structure_material: StandardMaterial3D;

func initialize() -> void:
	self.type = Type.STRUCTURE;
	super();
	
func get_max_count(tile_count: int) -> int:
	return round(max_per_region_size.sample(tile_count))

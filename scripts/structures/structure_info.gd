class_name StructureInfo extends SceneInfo

@export var max_per_region_size: Curve = Curve.new();
@export var required_space_radius: int = 0;
@export var minimum_distance_from_other_structures: int = 4;
@export var spawn_weight: float = 1;

func initialize() -> void:
	self.type = Type.STRUCTURE;
	super();
	
func get_max_count(tile_count: int) -> int:
	return round(max_per_region_size.sample(tile_count))

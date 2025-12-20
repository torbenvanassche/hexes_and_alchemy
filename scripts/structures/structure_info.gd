class_name StructureInfo extends SceneInfo

@export var max_per_region_size: Curve = Curve.new();

func initialize() -> void:
	self.type = Type.STRUCTURE;
	is_walkable = false;
	super();
	
func get_max_count(tile_count: int) -> int:
	return round(max_per_region_size.sample(tile_count))

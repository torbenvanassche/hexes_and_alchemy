class_name RegionInfo
extends Resource

var id: String
@export var noise: FastNoiseLite

@export var priority: int = 0
@export var activation_threshold: float = 0.5
@export var structure_fail_weight: float = 1;
@export var region_weight: float = 1.0
@export var material: StandardMaterial3D;

@export var structures: Dictionary[StructureInfo, float] = {};
@export var scene_multipliers: Dictionary[HexInfo, float] = {}

func initialize() -> void:
	id = resource_path.get_file().trim_suffix(".tres");

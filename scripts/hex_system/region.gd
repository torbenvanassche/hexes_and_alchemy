class_name RegionInfo
extends Resource

var id: String
@export var noise: FastNoiseLite

@export var priority: int = 0
@export var activation_threshold: float = 0.5
@export var region_weight: float = 1.0
@export var material: StandardMaterial3D;

@export var scene_multipliers: Dictionary[SceneInfo, float] = {}

func initialize() -> void:
	id = resource_path.get_file().trim_suffix(".tres");

class_name RegionInfo
extends Resource

@export var name: String;
@export var noise: FastNoiseLite;
@export var region_weight: float = 1.0;
@export var scene_multipliers: Dictionary[SceneInfo, float];

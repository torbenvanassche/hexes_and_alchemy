class_name RegionInfo
extends Resource

var id: String
@export_group("Noise")
@export var noise: FastNoiseLite
@export var noise_min: float = -1.0
@export var noise_max: float = 1.0
@export var noise_scale: float = 1.0

@export_group("Generation")
@export var priority: int = 0
@export var structure_fail_weight: float = 1;
@export var region_weight: float = 1.0

@export_group("Visuals")
@export var material: StandardMaterial3D;

@export_group("Content")
@export var structures: Dictionary[StructureInfo, float] = {};
@export var scene_multipliers: Dictionary[HexInfo, float] = {}

func initialize() -> void:
	id = resource_path.get_file().trim_suffix(".tres");

func get_display_name() -> String:
	var translation_key := "REGION_%s_NAME" % [id.to_upper()]
	var translated := tr(translation_key)
	if translated == translation_key:
		return id.capitalize()
	return translated

func matches(x: int, y: int) -> bool:
	if noise == null:
		return true

	var n := noise.get_noise_2d(float(x) * noise_scale,float(y) * noise_scale)
	return n >= noise_min and n <= noise_max

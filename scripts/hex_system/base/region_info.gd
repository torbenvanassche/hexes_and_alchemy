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
@export_range(0.0, 1.0, 0.01) var structure_density: float = 1.0
@export var region_weight: float = 1.0

@export_group("Distance Bias")
@export var min_generation_distance: int = 0
@export var max_generation_distance: int = -1
@export var distance_weight_start: int = 0
@export var distance_weight_end: int = 0
@export var near_distance_weight: float = 1.0
@export var far_distance_weight: float = 1.0

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

func get_generation_weight(distance: int = -1) -> float:
	if distance >= 0:
		if distance < min_generation_distance:
			return 0.0
		if max_generation_distance >= 0 and distance > max_generation_distance:
			return 0.0

	var distance_factor := 1.0
	if distance >= 0:
		distance_factor = _get_distance_weight(distance)

	return maxf(0.0, region_weight * distance_factor)

func _get_distance_weight(distance: int) -> float:
	if distance_weight_end <= distance_weight_start:
		return far_distance_weight if distance >= distance_weight_start else near_distance_weight

	var t := inverse_lerp(float(distance_weight_start), float(distance_weight_end), float(distance))
	return lerpf(near_distance_weight, far_distance_weight, clampf(t, 0.0, 1.0))

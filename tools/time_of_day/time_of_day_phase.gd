class_name TimeOfDayPhase extends Resource

@export var phase: TimeOfDay.Phase
@export var display_name: String;
@export_range(0.0, 1.0) var end_time: float

@export var color: Color
@export var light_energy: float = 1.0
@export_group("Shadows")
@export_range(0.0, 64.0, 0.1) var shadow_max_distance: float = 20.0
@export_range(0.0, 1.0, 0.01) var shadow_fade_start: float = 0.95
@export_range(0.0, 8.0, 0.01) var shadow_blur: float = 1.2
@export_range(0.0, 5.0, 0.01) var shadow_softness: float = 0.35
@export_range(0.0, 1.0, 0.01) var shadow_opacity: float = 0.9
@export_range(0.0, 64.0, 0.1) var shadow_pancake_size: float = 10.0

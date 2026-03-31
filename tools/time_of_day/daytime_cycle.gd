class_name TimeOfDay extends Node

enum Phase {
	DAWN,
	MORNING,
	AFTERNOON,
	DUSK,
	NIGHT
}

@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment

@export var sun_min_angle: float = -180
@export var sun_max_angle: float = 260.0

@export var phases: Array[TimeOfDayPhase]
var current_phase: TimeOfDayPhase = null
signal phase_changed(new_phase: TimeOfDayPhase)

@export var duration: int = 10
var days: int = 0;
@onready var day_timer: Timer = Timer.new()

signal day_ended()

func _ready() -> void:
	day_timer.wait_time = duration
	day_timer.timeout.connect(_on_day_ended)
	day_timer.autostart = true
	add_child(day_timer)

	current_phase = get_current_phase()

func _process(_delta: float) -> void:
	_update_phase()
	_update_sun_rotation()
	_update_lighting()
	
func _on_day_ended() -> void:
	day_ended.emit()
	days += 1;

func get_current_time_percentage() -> float:
	return 1.0 - (day_timer.time_left / duration)

func _update_phase() -> void:
	var new_phase := get_current_phase()
	if new_phase != current_phase:
		current_phase = new_phase
		phase_changed.emit(current_phase)

func get_current_phase() -> TimeOfDayPhase:
	var t := get_current_time_percentage()
	for phase in phases:
		if t < phase.end_time:
			return phase
	return phases.back()

func get_next_phase(current: TimeOfDayPhase) -> TimeOfDayPhase:
	var index := phases.find(current)
	if index == -1:
		return current
	return phases[(index + 1) % phases.size()]

func get_phase_blend() -> float:
	var t := get_current_time_percentage()

	var prev_end := 0.0
	for phase in phases:
		if t < phase.end_time:
			var interval := phase.end_time - prev_end
			if interval <= 0:
				return 0.0
			return (t - prev_end) / interval
		prev_end = phase.end_time
	return 0.0

func _update_sun_rotation() -> void:
	if not sun:
		return

	var t := get_current_time_percentage()
	var angle := lerpf(sun_min_angle, sun_max_angle, t)

	sun.rotation_degrees.x = angle

func _update_lighting() -> void:
	if current_phase == null or not sun:
		return

	var next_phase := get_next_phase(current_phase)
	var blend := get_phase_blend()
	var angle := sun.rotation_degrees.x

	var base_color := current_phase.color.lerp(next_phase.color, blend)
	var base_energy := lerpf(current_phase.light_energy, next_phase.light_energy, blend)
	
	var horizon_min := -10.0
	var horizon_max := 90.0

	var height_factor := clampf((angle - horizon_min) / (horizon_max - horizon_min), 0.0, 1.0)

	sun.light_energy = base_energy
	sun.light_color = base_color

	if environment and environment.environment:
		var env := environment.environment

		var night_ambient := Color(0.05, 0.07, 0.12)
		var day_ambient := base_color * 0.3

		var ambient := night_ambient.lerp(day_ambient, height_factor)

		env.ambient_light_color = ambient
		env.ambient_light_energy = lerpf(0.2, 1.0, height_factor)

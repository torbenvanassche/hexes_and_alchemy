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

@export var phases: Array[TimeOfDayPhase]
var current_phase: TimeOfDayPhase = null
signal phase_changed(new_phase: TimeOfDayPhase)

@export var duration: float = 120.0
var days: int = 0
var _time: float = 0.0

signal day_ended()

func _ready() -> void:
	current_phase = get_current_phase()

func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		_time -= duration
		days += 1
		day_ended.emit()

	_update_phase()
	_update_sun_rotation()
	_update_lighting()

func get_current_time_percentage() -> float:
	return _time / duration

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
	return 1.0

func _update_sun_rotation() -> void:
	if not sun:
		return
	var t := get_current_time_percentage()
	sun.rotation_degrees.x = lerpf(-90.0, 270.0, t)

func _update_lighting() -> void:
	if current_phase == null or not sun:
		return
	var next_phase := get_next_phase(current_phase)
	var blend := get_phase_blend()

	var base_color := current_phase.color.lerp(next_phase.color, blend)
	var base_energy := lerpf(current_phase.light_energy, next_phase.light_energy, blend)

	var angle := sun.rotation_degrees.x
	var t_arc := (angle + 90.0) / 360.0
	var height_factor := clampf(sin(t_arc * PI), 0.0, 1.0)

	sun.light_color = base_color
	sun.light_energy = base_energy if height_factor > 0.0 else 0.0

	if environment and environment.environment:
		var env := environment.environment
		var night_ambient := Color(0.02, 0.03, 0.08)
		var day_ambient := base_color * 0.3
		env.ambient_light_color = night_ambient.lerp(day_ambient, height_factor)
		env.ambient_light_energy = lerpf(0.15, 1.2, height_factor)

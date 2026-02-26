extends Interaction

enum RotationAxis { X, Y, Z }

@export var axis: RotationAxis = RotationAxis.Z
@export var max_angle: float = 0.0
@export var duration: float = 1.0
@export var interpolate_rotation: bool = true

var start_angle: float
var at_max: bool = false
var tween: Tween

func can_interact() -> bool:
	return true;

func _ready() -> void:
	super()
	start_angle = _get_axis_rotation()

func interact() -> void:
	var target_angle := max_angle if not at_max else start_angle
	target_angle = deg_to_rad(target_angle)
	at_max = not at_max

	if tween:
		tween.kill()

	if interpolate_rotation:
		tween = create_tween()
		tween.tween_method(
			_set_axis_rotation,
			_get_axis_rotation(),
			target_angle,
			duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_set_axis_rotation(target_angle)

func _get_axis_rotation() -> float:
	match axis:
		RotationAxis.X:
			return rotation.x
		RotationAxis.Y:
			return rotation.y
		RotationAxis.Z:
			return rotation.z
	return 0.0

func _set_axis_rotation(value: float) -> void:
	match axis:
		RotationAxis.X:
			rotation.x = value
		RotationAxis.Y:
			rotation.y = value
		RotationAxis.Z:
			rotation.z = value

class_name WSD extends Control

@export var element: TextureRect;
var _target: Node3D;

func _process(_delta: float):
	if is_instance_valid(_target) and _target.is_inside_tree():
		var point := (_target as Interaction).get_prompt_position() if _target is Interaction else _target.global_position
		# This remains a fixed-size HUD icon; only its anchor follows the world.
		var camera := Manager.instance.spring_arm_camera.camera
		element.global_position = (camera.unproject_position(point) - element.size / 2).round()
		element.visible = element.texture != null and not camera.is_position_behind(point)
	else:
		element.visible = false;

func show_rect(target: Node3D = null):
	_target = target;
	element.visible = _target != null;
	handle_rect()

func handle_rect():
	if is_instance_valid(_target):
		var coords := InputManager.get_input_icon("primary_action");
		if coords.size() < 2:
			element.texture = null
			element.hide()
			return
		var texture := InputManager.get_input_texture()
		texture.region = InputManager.get_rect(Vector2i(coords[0], coords[1]))
		# Clamp filtering to this cell instead of sampling adjacent atlas icons.
		texture.filter_clip = true
		element.texture = texture

func _ready():
	InputManager.input_mode_changed.connect(handle_rect);

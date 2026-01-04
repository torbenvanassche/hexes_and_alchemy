class_name WSD extends Control

@export var element: TextureRect;
var _target: Node3D;

func _process(_delta: float):
	if _target:
		element.global_position = Manager.instance.spring_arm_camera.camera.unproject_position(_target.global_position) - element.size / 2;
		element.visible = !Manager.instance.spring_arm_camera.camera.is_position_behind(_target.global_position)
	else:
		element.visible = false;

func show_rect(target: Node3D = null):
	_target = target;
	element.visible = _target != null;
	handle_rect()

func handle_rect():
	if _target:
		element.texture = InputManager.get_input_texture();
		var coords := InputManager.get_input_icon("primary_action");
		(element.texture as AtlasTexture).region = InputManager.get_rect(Vector2i(coords[0], coords[1]));

func _ready():
	InputManager.input_mode_changed.connect(handle_rect);

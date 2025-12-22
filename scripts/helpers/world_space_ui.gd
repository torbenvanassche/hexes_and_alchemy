class_name WSD extends Control

@export var element: TextureRect;
var _target: Node3D;

func _process(_delta: float):
	if _target:
		element.global_position = Manager.instance.camera_controller.camera.unproject_position(_target.global_position) - element.size / 2;
		element.visible = !Manager.instance.camera_controller.camera.is_position_behind(_target.global_position)
	else:
		element.visible = false;

func show_rect(target: Node3D = null):
	_target = target;
	element.visible = true;

func handle_rect():
	if element.texture:
		var icon: Array = InputManager.get_input_icon("primary_action");
		(element.texture as AtlasTexture).region = Rect2(icon[0], icon[1], 64, 64);

func _ready():
	InputManager.input_mode_changed.connect(handle_rect);

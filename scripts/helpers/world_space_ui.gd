class_name WSD extends Control

@export var clearance := 18.0
@export var edge_padding := 12.0

@onready var _badge: PanelContainer = $Badge
@onready var _prompt: ActionPrompt = $Badge/Action
var _target: Interaction

func _ready() -> void:
	set_process(false)

func set_target(target: Interaction) -> void:
	_target = target
	if is_instance_valid(target):
		_prompt.configure("primary_action", target.prompt_label_key)
		set_process(true)
	else:
		_badge.hide()
		set_process(false)

func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		set_target(null)
		return
	if not _target.show_interaction_prompt or not _target.can_interact():
		_badge.hide()
		return
	var camera_controller := Manager.instance.spring_arm_camera
	if camera_controller == null or camera_controller.camera == null or WorldLoading.blocks_input or Manager.instance.controller_ui_active():
		_badge.hide()
		return
	var camera := camera_controller.camera
	var point := _target.get_prompt_position()
	var viewport_rect := get_viewport_rect()
	var anchor := camera.unproject_position(point)
	if camera.is_position_behind(point) or not viewport_rect.has_point(anchor):
		_badge.hide()
		return
	_badge.show()
	_badge.size = _badge.get_combined_minimum_size()
	var bounds := viewport_rect.grow(-edge_padding)
	var origin := anchor - Vector2(_badge.size.x * 0.5, _badge.size.y + clearance)
	_badge.position = origin.clamp(bounds.position, (bounds.end - _badge.size).max(bounds.position)).round()

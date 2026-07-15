class_name DraggableControl
extends Control

@export_group("Identity")
@export var id: String = "";

const LOCKED_ICON := preload("res://sprites/ui/icons/locked.png")
const UNLOCKED_ICON := preload("res://sprites/ui/icons/unlocked.png")

@onready var vp := get_viewport()
@onready var top_bar: ColorRect = $NinePatchRect/VBoxContainer/topbar;
@onready var lock_button: Button = $NinePatchRect/VBoxContainer/topbar/MarginContainer2/HBoxContainer/LockButton;
@onready var close_button: Button = $NinePatchRect/VBoxContainer/topbar/MarginContainer2/HBoxContainer/CloseButton;
@onready var title_margin: MarginContainer = $NinePatchRect/VBoxContainer/topbar/MarginContainer2/MarginContainer;
@onready var title: Label = $NinePatchRect/VBoxContainer/topbar/MarginContainer2/MarginContainer/Title;
@onready var v_box_container: VBoxContainer = $NinePatchRect/VBoxContainer
@onready var content_panel: Control = $NinePatchRect/VBoxContainer/contentPanel;
@onready var npr: NinePatchRect = $NinePatchRect;
@onready var resize_handle_x: Control = $NinePatchRect/ResizeHandleX
@onready var resize_handle_y: Control = $NinePatchRect/ResizeHandleY
@onready var resize_handle_xy: Control = $NinePatchRect/ResizeHandleXY

@export_enum("fullscreen", "display", "no_header", "none") var display_mode: String = "display"
@export_enum("mouse", "center", "override") var position_options: String = "center";
var initial_position: Vector2;

@export_group("Layout")
@export var store_position: bool = false;
@export var override_position: Vector2;
@export var topbar_height: int = 50;
@export var topbar_transparent: bool = false;
@export var show_title: bool = true;

@export_group("Behavior")
@export var resizable: bool = true;
@export var enforce_content_minimum_size: bool = true;
@export var blocks_camera_scroll := true
@export var can_lock := false
var close_locked := false
var scene_instance: SceneInstance

@export_group("Content")
@export var content: Control;

signal close_requested();
signal change_title(name: String);

var dragging := false
var stored_position:Vector2;
var resizing := false
var resize_start_mouse := Vector2.ZERO
var resize_start_size := Vector2.ZERO
var stored_size := Vector2.ZERO
var resize_axis := Vector2.ONE
var _fit_request_id := 0
var _is_fitting := false

func _ready() -> void:
	visible = false
	_prepare_floating_layout()
	lock_button.toggled.connect(_set_close_locked)
	close_button.pressed.connect(close_window.bind(true));
	close_requested.connect(close_window)
	top_bar.gui_input.connect(handle_input)

	resize_handle_x.gui_input.connect(_handle_resize_input.bind(Vector2(1, 0)))
	resize_handle_y.gui_input.connect(_handle_resize_input.bind(Vector2(0, 1)))
	resize_handle_xy.gui_input.connect(_handle_resize_input.bind(Vector2(1, 1)))

	change_title.connect(_change_title)

	_change_title(id);
	_update_lock_availability()
	_set_close_locked(close_locked)
	
	top_bar.custom_minimum_size.y = topbar_height
	_update_resize_handles()
	
func _prepare_floating_layout() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END

func _fit_to_content() -> void:
	if _is_fitting:
		return
	_is_fitting = true
	size = _clamp_window_size(_get_content_fit_size())
	_is_fitting = false

func _get_content_fit_size() -> Vector2:
	var fit_size := custom_minimum_size
	var content_size := v_box_container.get_combined_minimum_size()
	if content != null:
		content_size = content.get_combined_minimum_size() + _get_content_panel_margins()
		if top_bar.visible:
			content_size.y += top_bar.get_combined_minimum_size().y
	fit_size = fit_size.max(content_size)
	return fit_size

func _get_content_panel_margins() -> Vector2:
	return Vector2(
		content_panel.get_theme_constant("margin_left") + content_panel.get_theme_constant("margin_right"),
		content_panel.get_theme_constant("margin_top") + content_panel.get_theme_constant("margin_bottom")
	)

func request_fit_to_content(wait_frames: int = 2) -> void:
	_fit_request_id += 1
	_fit_to_content_deferred(_fit_request_id, max(0, wait_frames))

func fit_to_content_settled(wait_frames: int = 2) -> void:
	_fit_request_id += 1
	await _fit_to_content_deferred(_fit_request_id, max(0, wait_frames))

func fit_to_content_after_draw() -> void:
	_fit_request_id += 1
	var request_id := _fit_request_id
	await RenderingServer.frame_post_draw
	if request_id != _fit_request_id:
		return
	_fit_to_content()

func _fit_to_content_deferred(request_id: int, wait_frames: int) -> void:
	for _i in range(wait_frames + 1):
		await get_tree().process_frame
		if request_id != _fit_request_id:
			return
		_fit_to_content()
	
func on_enter() -> void:
	if scene_instance != null:
		SceneManager.promote_scene_instance(scene_instance)
	visible = false
	_prepare_floating_layout()
	match display_mode:
		"fullscreen":
			top_bar.visible = false;
			size = get_viewport_rect().size;
		"display":
			top_bar.visible = true;
			size = custom_minimum_size
		"no_header":
			top_bar.visible = false;
			size = custom_minimum_size
		"none":
			top_bar.visible = false;
			npr.self_modulate = Color.TRANSPARENT;
			size = custom_minimum_size
	
	match position_options:
		"mouse":
			initial_position = get_tree().root.get_viewport().get_mouse_position();
		"center":
			initial_position = get_viewport_rect().size / 2
		"override":
			initial_position = override_position;
	if topbar_transparent:
		top_bar.self_modulate = Color.TRANSPARENT;
	title.visible = show_title;
	_update_resize_handles()

	for c: Control in Helpers.flatten_children(content_panel, true):
		if is_instance_valid(c) and c.has_method("on_enter"):
			c.on_enter();

	await get_tree().process_frame;

	if resizable and store_position and stored_size != Vector2.ZERO:
		size = _clamp_window_size(stored_size)
	else:
		await fit_to_content_settled(2)

	if store_position:
		position = stored_position;
	else:
		position = initial_position - size / 2;

	var previous_modulate := modulate
	var hidden_layout_modulate := modulate
	hidden_layout_modulate.a = 0.0
	modulate = hidden_layout_modulate
	visible = true;
	await get_tree().process_frame;
	_fit_to_content()
	if store_position:
		position = stored_position;
	else:
		position = initial_position - size / 2;
	modulate = previous_modulate
	if scene_instance != null:
		SceneManager.promote_scene_instance(scene_instance)

func _change_title(s: String) -> void:
	title.text = tr(s);

func handle_input(event: InputEvent) -> void:
	if resizing:
		return
	if event is InputEventMouseButton:
		if event.pressed and scene_instance != null:
			SceneManager.promote_scene_instance(scene_instance)
		dragging = event.pressed
	elif dragging and event is InputEventMouseMotion:
		position += event.relative
		stored_position = position;
	else:
		return
	vp.set_input_as_handled()

func _handle_resize_input(event: InputEvent, axis: Vector2) -> void:
	if not resizable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and scene_instance != null:
			SceneManager.promote_scene_instance(scene_instance)
		resizing = event.pressed
		if resizing:
			dragging = false
			resize_start_mouse = get_global_mouse_position()
			resize_start_size = size
			resize_axis = axis
		else:
			_store_window_size()
		vp.set_input_as_handled()

func _input(event: InputEvent) -> void:
	if resizing and event is InputEventMouseMotion:
		var delta := get_global_mouse_position() - resize_start_mouse
		size = _clamp_window_size(resize_start_size + delta * resize_axis)
		_store_window_size()
		vp.set_input_as_handled()

func close_window(force_close: bool = false) -> void:
	if not force_close and not can_close():
		return
	if force_close:
		_set_close_locked(false)
	if store_position:
		stored_position = position;
	if scene_instance != null and scene_instance.scene_info != null and scene_instance.scene_info.allow_multiple_instances:
		scene_instance.hide()
		return
	SceneManager.remove_scene(DataManager.instance.node_to_info(self), false);

func can_close() -> bool:
	return not can_lock or not close_locked
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") && visible:
		vp.set_input_as_handled()
		close_requested.emit()

func _clamp_window_size(target_size: Vector2, include_content_minimum: bool = true) -> Vector2:
	var min_size := custom_minimum_size
	if enforce_content_minimum_size and include_content_minimum:
		min_size = min_size.max(_get_content_fit_size())
	var clamped := Vector2(
		maxf(target_size.x, min_size.x),
		maxf(target_size.y, min_size.y)
	)
	if custom_maximum_size.x > 0.0:
		clamped.x = minf(clamped.x, custom_maximum_size.x)
	if custom_maximum_size.y > 0.0:
		clamped.y = minf(clamped.y, custom_maximum_size.y)
	return clamped

func _store_window_size() -> void:
	if store_position or resizable:
		stored_size = size

func _update_resize_handles() -> void:
	resize_handle_x.visible = resizable
	resize_handle_y.visible = resizable
	resize_handle_xy.visible = resizable

func _set_close_locked(locked: bool) -> void:
	close_locked = can_lock and locked
	lock_button.button_pressed = close_locked
	lock_button.icon = LOCKED_ICON if close_locked else UNLOCKED_ICON
	lock_button.tooltip_text = "WINDOW_KEEP_OPEN" if not close_locked else "WINDOW_ALLOW_CLOSE"

func _update_lock_availability() -> void:
	lock_button.visible = can_lock
	title_margin.add_theme_constant_override("margin_left", 80 if can_lock else 40)

class_name DraggableControl
extends Control

@export var id: String = "";

@onready var vp := get_viewport()
@onready var top_bar: ColorRect = $NinePatchRect/VBoxContainer/topbar;
@onready var close_button: Button = $NinePatchRect/VBoxContainer/topbar/MarginContainer2/HBoxContainer/Button;
@onready var title: Label = $NinePatchRect/VBoxContainer/topbar/MarginContainer2/HBoxContainer/MarginContainer/Title;
@onready var content_panel: Control = $NinePatchRect/VBoxContainer/content;
@onready var npr: NinePatchRect = $NinePatchRect;

@export_enum("fullscreen", "display", "no_header", "none") var display_mode: String = "display"
@export_enum("mouse", "center", "override") var position_options: String = "center";
var initial_position: Vector2;

@export var store_position: bool = false;
@export var override_position: Vector2;
@export var override_size: Vector2 = Vector2(0, 0);
@export var topbar_height: int = 50;
@export var topbar_transparent: bool = false;
@export var show_title: bool = true;

signal close_requested();
signal change_title(name: String);

var dragging := false
var stored_position:Vector2;

func _ready() -> void:
	close_button.pressed.connect(close_window);
	close_requested.connect(close_window)
	top_bar.gui_input.connect(handle_input)
	change_title.connect(_change_title)
	_change_title(id);
	
	if override_size != Vector2.ZERO:
		self.set_deferred("size", override_size)
		top_bar.custom_minimum_size = Vector2(override_size.x, topbar_height)
		content_panel.custom_minimum_size = Vector2(override_size.x, override_size.y - top_bar.size.y)
	
func on_load() -> void:
	match display_mode:
		"fullscreen":
			top_bar.visible = false;
			size =get_viewport_rect().size;
		"display":
			top_bar.visible = true;
			pass
		"no_header":
			top_bar.visible = false;
			pass
		"none":
			top_bar.visible = false;
			npr.self_modulate = Color.TRANSPARENT;
			pass
	
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

	await get_tree().process_frame;
	position = initial_position - size / 2;
	
	if store_position:
		position = stored_position;

func _change_title(s: String) -> void:
	title.text = s;

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		dragging = event.pressed
	elif dragging and event is InputEventMouseMotion:
		position += event.relative
	else:
		return
	vp.set_input_as_handled()

func close_window() -> void:
	if store_position:
		stored_position = position;
	SceneManager.remove_scene(DataManager.instance.node_to_info(self), false);
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") && visible:
		vp.set_input_as_handled()
		close_requested.emit()

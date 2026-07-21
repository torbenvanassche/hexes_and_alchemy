@tool
extends EditorPlugin

var dock: Control
var scroll_container: ScrollContainer

func _enter_tree() -> void:
	set_input_event_forwarding_always_enabled()
	scroll_container = ScrollContainer.new()
	scroll_container.name = "Settlement Designer"
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	dock = preload("res://addons/settlement_designer/settlement_designer_dock.gd").new()
	dock.set("editor_plugin", self)
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(dock)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, scroll_container)

func _exit_tree() -> void:
	if dock != null and dock.has_method("cleanup_worldspace_handles"):
		dock.call("cleanup_worldspace_handles")
	if scroll_container != null:
		remove_control_from_docks(scroll_container)
		scroll_container.queue_free()
	elif dock != null:
		dock.queue_free()

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if dock != null and dock.has_method("handle_3d_gui_input"):
		var handled: bool = bool(dock.call("handle_3d_gui_input", viewport_camera, event))
		return AFTER_GUI_INPUT_STOP if handled else AFTER_GUI_INPUT_PASS
	return AFTER_GUI_INPUT_PASS

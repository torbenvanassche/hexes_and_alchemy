@tool
extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
	dock = preload("res://addons/terrain_tile_setup/terrain_tile_setup_dock.gd").new()
	dock.set("editor_plugin", self)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree() -> void:
	if dock != null:
		if dock.has_method("cleanup_guides"):
			dock.call("cleanup_guides")
		remove_control_from_docks(dock)
		dock.queue_free()

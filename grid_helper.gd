@tool
extends Node3D

@export var prefab: PackedScene
@export var grid_size := Vector2i(10, 10)

@export var pointy_top := false
@export var spacing := 0.25   # same as HexGrid._spacing
@export var inner_radius := 1.0  # same as HexGrid.RADIUS_IN
@export var grid_offset := Vector2i.ZERO

@export var regenerate := false:
	set(value):
		if value:
			generate()
			regenerate = false
			
func get_spacing() -> Vector2:
	if pointy_top:
		return Vector2(3.0 * inner_radius / 2.0 + spacing, sqrt(3.0) * inner_radius + spacing)
	else:
		return Vector2(sqrt(3.0) * inner_radius + spacing, 3.0 * inner_radius / 2.0 + spacing)

func generate() -> void:
	if prefab == null:
		push_warning("No prefab assigned")
		return

	var scene_root := get_tree().edited_scene_root
	if scene_root == null:
		return

	for c in get_children():
		c.queue_free()

	var cell_spacing := get_spacing()

	for gy in range(grid_size.y):
		for gx in range(grid_size.x):
			var x := gx + grid_offset.x
			var y := gy + grid_offset.y

			var instance := prefab.instantiate()
			add_child(instance)

			instance.owner = scene_root

			var pos := Vector3.ZERO

			if pointy_top:
				pos.x = x * cell_spacing.x
				pos.z = y * cell_spacing.y + (x & 1) * (cell_spacing.y / 2.0)
			else:
				pos.x = x * cell_spacing.x + (y & 1) * (cell_spacing.x / 2.0)
				pos.z = y * cell_spacing.y

			instance.position = pos

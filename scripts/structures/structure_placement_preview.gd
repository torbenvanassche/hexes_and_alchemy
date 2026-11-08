class_name StructurePlacementPreview
extends RefCounted

var _preview_node: Node3D
var _preview_placeable: PlaceableStructureInfo

func update(placeable: PlaceableStructureInfo, hovered_hex: HexBase, hovered_hex_can_drop: bool, placement_rotation_y: float) -> void:
	if hovered_hex == null or not hovered_hex_can_drop:
		clear();
		return;

	if _preview_node == null or _preview_placeable != placeable:
		clear();
		if placeable.packed_scene == null:
			return;

		_preview_node = placeable.packed_scene.instantiate() as Node3D;
		_preview_placeable = placeable;
		if _preview_node == null:
			return;
		# Preview instances must never register services, quests or buildables.
		var nodes: Array[Node] = [_preview_node]
		nodes.append_array(_preview_node.find_children("*", "Node", true, false))
		for node: Node in nodes:
			if node.get_script() != null: node.set_script(null)
		_preview_node.process_mode = Node.PROCESS_MODE_DISABLED;
		_disable_preview_collision(_preview_node);
		_apply_preview_modulate(_preview_node);

		var active_scene := SceneManager.get_active_scene();
		if active_scene != null and active_scene.node != null:
			active_scene.node.add_child(_preview_node);

	_preview_node.visible = true;
	_preview_node.global_position = (
		hovered_hex.global_position
		+ placeable.get_placement_offset(hovered_hex, placement_rotation_y)
	);
	_preview_node.rotation.y = 0.0 if is_nan(placement_rotation_y) else placement_rotation_y;

func clear() -> void:
	_preview_placeable = null;
	if _preview_node != null and is_instance_valid(_preview_node):
		_preview_node.queue_free();
	_preview_node = null;

func _apply_preview_modulate(root: Node) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = preload("res://materials/kay_fantasy_default.tres")
		mesh.transparency = 0.35;

func _disable_preview_collision(root: Node) -> void:
	for area: Area3D in root.find_children("*", "Area3D", true, false):
		area.monitoring = false;
		area.monitorable = false;
		area.collision_layer = 0;
		area.collision_mask = 0;
	for body: CollisionObject3D in root.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0;
		body.collision_mask = 0;
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		shape.disabled = true;

class_name Settlement extends Node3D

@export var spawn_position: Node3D;
@export var is_active_settlement: bool = false;
@export var level: int = 1;
@export var upgrade_requirements: Array[SettlementUpgradeInfo] = []
@export var structure_invalid_range: int = 3;
@export_group("Settlement Reveal")
@export_range(1, 32, 1) var reveal_search_range: int = 8;
@export var show_reveal_debug_shape: bool = false;
@export var reveal_debug_color: Color = Color(0.1, 0.7, 1.0, 0.25);
@export var reveal_debug_height: float = 0.08;
@export var reveal_debug_rotation_degrees: float = 30.0;
@export var reveal_debug_hex_scale: float = 1.12;

var collision_shapes: Array[CollisionShape3D] = []
var interactions: Array[Interaction] = []
var interactions_by_type: Dictionary[StringName, Array] = {};
var buildables: Array[Buildable] = []

signal level_changed(new_level: int)

func _ready() -> void:
	collision_shapes.assign(find_children("*", "CollisionShape3D", true, false))
	Manager.instance.settlements.append(self)
	
	interactions.assign(find_children("*", "Interaction", true, false))
	_register_interactions()

	buildables.assign(find_children("*", "Buildable", true, false))
	for buildable in buildables:
		if not buildable.step_changed.is_connected(_on_buildable_step_changed):
			buildable.step_changed.connect(_on_buildable_step_changed)
	refresh_service_states()
	
	if is_active_settlement:
		Manager.instance.set_active_settlement(self);
		Manager.instance.spawn_in_settlement();
	visibility_changed.connect(_toggle_collision)
	_ready_deferred.call_deferred();
	
func _ready_deferred() -> void:
	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return

	var origin_hex := _get_settlement_origin_hex(grid)
	if origin_hex == null:
		return

	var reveal_hexes := _get_settlement_reveal_hexes(grid, origin_hex)
	for hex in reveal_hexes:
		hex.is_explored = true

	_render_reveal_debug_shape(grid, reveal_hexes)
	
func _toggle_collision() -> void:
	for collision in collision_shapes:
		collision.disabled = not self.is_visible_in_tree();

func _register_interactions() -> void:
	interactions_by_type.clear()
	for interaction: Interaction in interactions:
		register_interaction(interaction)

func register_interaction(interaction: Interaction) -> void:
	if interaction == null:
		return
	interaction.settlement = self
	if interaction.has_method("refresh_service_state"):
		interaction.refresh_service_state()
	var type_name: StringName = _get_interaction_type(interaction)
	if not interactions_by_type.has(type_name):
		interactions_by_type[type_name] = []
	var services: Array = interactions_by_type[type_name]
	services.append(interaction)

func contains_interaction(interaction: Interaction) -> bool:
	return interaction != null and interactions.has(interaction)

func get_service(type_name: StringName) -> Interaction:
	var services: Array[Interaction] = get_services(type_name)
	return services[0] if not services.is_empty() else null

func get_services(type_name: StringName) -> Array[Interaction]:
	var services: Array[Interaction] = []
	if not interactions_by_type.has(type_name):
		return services
	var stored_services: Array = interactions_by_type[type_name]
	for service in stored_services:
		var interaction: Interaction = service as Interaction
		if interaction != null:
			services.append(interaction)
	return services

func has_service(type_name: StringName) -> bool:
	for service in get_services(type_name):
		if service.has_method("is_service_enabled") and not bool(service.is_service_enabled()):
			continue
		if not service.visible:
			continue
		return true
	return false

func get_next_upgrade() -> SettlementUpgradeInfo:
	return get_upgrade_for_level(level + 1)

func get_upgrade_for_level(target_level: int) -> SettlementUpgradeInfo:
	for upgrade: SettlementUpgradeInfo in upgrade_requirements:
		if upgrade != null and upgrade.target_level == target_level:
			return upgrade
	return null

func can_upgrade(source_inventory: ContentGroup) -> bool:
	var upgrade := get_next_upgrade()
	if upgrade == null:
		return false
	if not _has_required_services(upgrade):
		return false
	return source_inventory != null and source_inventory.has_all(upgrade.item_cost)

func try_upgrade(source_inventory: ContentGroup) -> bool:
	var upgrade := get_next_upgrade()
	if upgrade == null or not can_upgrade(source_inventory):
		return false
	for item: ItemInfo in upgrade.item_cost.keys():
		source_inventory.remove(item, int(upgrade.item_cost[item]))
	level = upgrade.target_level
	refresh_service_states()
	level_changed.emit(level)
	return true

func get_missing_service_requirements(upgrade: SettlementUpgradeInfo) -> Array[StringName]:
	var missing: Array[StringName] = []
	if upgrade == null:
		return missing
	for service_name in upgrade.required_services:
		if not has_service(service_name):
			missing.append(service_name)
	return missing

func _has_required_services(upgrade: SettlementUpgradeInfo) -> bool:
	return get_missing_service_requirements(upgrade).is_empty()

func refresh_service_states() -> void:
	for interaction: Interaction in interactions:
		if interaction != null and interaction.has_method("refresh_service_state"):
			interaction.refresh_service_state()
	for buildable: Buildable in buildables:
		if buildable != null:
			buildable.refresh_step_state(self)

func _on_buildable_step_changed(_buildable: Buildable) -> void:
	refresh_service_states()
	level_changed.emit(level)

func _get_interaction_type(interaction: Interaction) -> StringName:
	var script: Script = interaction.get_script() as Script
	if script != null:
		var global_name: String = String(script.get_global_name())
		if not global_name.is_empty():
			return StringName(global_name)
	return StringName(interaction.name)

func _get_settlement_origin_hex(grid: HexGrid) -> HexBase:
	var parent_hex := get_parent() as HexBase
	if parent_hex != null:
		return parent_hex
	return grid.get_hex_at_world_position(global_position)

func _get_settlement_reveal_hexes(grid: HexGrid, origin_hex: HexBase) -> Array[HexBase]:
	var blocked_edges := _get_settlement_boundary_edges(grid)
	var result: Array[HexBase] = []
	var frontier: Array[Vector3i] = [origin_hex.cube_id]
	var visited: Dictionary[Vector3i, bool] = {
		origin_hex.cube_id: true
	}

	while not frontier.is_empty():
		var current := frontier.pop_front() as Vector3i
		var current_hex := grid.get_hex_at_cube_id(current)
		if current_hex != null:
			result.append(current_hex)

		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			var next := current + direction
			if visited.has(next):
				continue
			if GridUtils.cube_distance(origin_hex.cube_id, next) > reveal_search_range:
				continue
			if blocked_edges.has(_get_boundary_edge_key(current, next)):
				continue

			var next_hex := grid.get_hex_at_cube_id(next)
			if next_hex == null:
				continue

			visited[next] = true
			frontier.append(next)

	return result

func _get_settlement_boundary_edges(grid: HexGrid) -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for boundary_node in _get_boundary_nodes():
		var node_3d := boundary_node as Node3D
		if node_3d == null:
			continue

		var current_hex := grid.get_hex_at_world_position(node_3d.global_position)
		var adjacent_world := node_3d.global_transform * (Vector3.LEFT * 2.0)
		var adjacent_hex := grid.get_hex_at_world_position(adjacent_world)
		if current_hex == null or adjacent_hex == null:
			continue

		result[_get_boundary_edge_key(current_hex.cube_id, adjacent_hex.cube_id)] = true
	return result

func _get_boundary_nodes() -> Array[Node]:
	var result: Array[Node] = []
	var boundary_roots: Array[NodePath] = [NodePath("walls"), NodePath("entrances")]
	for root_path in boundary_roots:
		var root := get_node_or_null(root_path)
		if root == null:
			continue
		for child in root.get_children():
			if child is Node3D:
				result.append(child)
	return result

func _get_boundary_edge_key(a: Vector3i, b: Vector3i) -> String:
	var a_key := _get_cube_key(a)
	var b_key := _get_cube_key(b)
	if a_key < b_key:
		return "%s|%s" % [a_key, b_key]
	return "%s|%s" % [b_key, a_key]

func _get_cube_key(cube_id: Vector3i) -> String:
	return "%s,%s,%s" % [cube_id.x, cube_id.y, cube_id.z]

func _render_reveal_debug_shape(grid: HexGrid, reveal_hexes: Array[HexBase]) -> void:
	var existing := get_node_or_null("settlement_reveal_debug")
	if existing != null:
		existing.queue_free()

	if not show_reveal_debug_shape:
		return

	var debug_root := Node3D.new()
	debug_root.name = "settlement_reveal_debug"
	add_child(debug_root)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "reveal_shape"
	debug_root.add_child(mesh_instance)

	var material := StandardMaterial3D.new()
	material.albedo_color = reveal_debug_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var polygons := _get_merged_debug_polygons(grid, reveal_hexes)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for polygon in polygons:
		_append_debug_polygon_mesh(polygon, vertices, indices)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material

func _get_merged_debug_polygons(grid: HexGrid, reveal_hexes: Array[HexBase]) -> Array[PackedVector2Array]:
	var merged_polygons: Array[PackedVector2Array] = []
	var hex_polygon := _get_debug_hex_polygon(grid)

	for hex in reveal_hexes:
		var polygon := _get_debug_hex_polygon_at(hex, hex_polygon)
		merged_polygons = _merge_debug_polygon(merged_polygons, polygon)

	return merged_polygons

func _merge_debug_polygon(
	merged_polygons: Array[PackedVector2Array],
	polygon: PackedVector2Array
) -> Array[PackedVector2Array]:
	if merged_polygons.is_empty():
		var first_result: Array[PackedVector2Array] = []
		first_result.append(polygon)
		return first_result

	var result: Array[PackedVector2Array] = []
	var pending := polygon
	var merged_pending := false

	for existing in merged_polygons:
		var merged := Geometry2D.merge_polygons(existing, pending)
		if merged.size() == 1:
			pending = merged[0] as PackedVector2Array
			merged_pending = true
		else:
			result.append(existing)

	result.append(pending)
	if merged_pending:
		return result

	var unmerged_result := merged_polygons.duplicate()
	unmerged_result.append(polygon)
	return unmerged_result

func _get_debug_hex_polygon_at(hex: HexBase, polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon:
		var local_point := to_local(Vector3(
			hex.global_position.x + point.x,
			reveal_debug_height,
			hex.global_position.z + point.y
		))
		result.append(Vector2(local_point.x, local_point.z))
	return result

func _append_debug_polygon_mesh(
	polygon: PackedVector2Array,
	vertices: PackedVector3Array,
	indices: PackedInt32Array
) -> void:
	var base_index := vertices.size()
	for point in polygon:
		vertices.append(Vector3(point.x, reveal_debug_height, point.y))

	var polygon_indices := Geometry2D.triangulate_polygon(polygon)
	for index in polygon_indices:
		indices.append(base_index + index)

func _get_debug_hex_polygon(grid: HexGrid) -> PackedVector2Array:
	var world_polygon := GridUtils.get_hex_polygon(Vector3.ZERO, HexGrid.RADIUS_IN * reveal_debug_hex_scale, grid.pointy_top)
	var local_polygon := PackedVector2Array()
	var rotation := deg_to_rad(reveal_debug_rotation_degrees)
	for point in world_polygon:
		local_polygon.append(point.rotated(rotation))
	return local_polygon

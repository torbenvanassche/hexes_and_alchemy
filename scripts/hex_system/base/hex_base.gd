class_name HexBase
extends Node3D

var grid_id: Vector2i;
var cube_id: Vector3i;
var can_generate: bool = true;

var region_instance: RegionInstance;
var region: RegionInfo;

var structure_root_tile: Vector3i;

var structure: StructureInstance;
var static_body: StaticBody3D;
var scene_instance: SceneInstance;

const UNEXPLORED_MATERIAL = preload("uid://bgsi1yhfo1pe2")
signal structure_loaded(structure_info: StructureInfo, structure_node: Node)

var ground_hex_mesh: MeshInstance3D;
var is_explored: bool = false:
	set(value):
		if is_explored == value:
			return
		
		is_explored = value;
		if ground_hex_mesh != null:
			set_explored(is_explored)
		
var blocked: bool = false;
var movement_cost: float = 1.0;

func _ready() -> void:
	ground_hex_mesh = find_child("hex_*", true) as MeshInstance3D;
	set_explored(false)

func set_explored(b: bool) -> void:
	if ground_hex_mesh == null:
		return
	
	(ground_hex_mesh as MeshInstance3D).material_override = null if b else UNEXPLORED_MATERIAL;
	(ground_hex_mesh as MeshInstance3D).layers = 1 if b else 2;
	if structure:
		var quest_objective := structure.instance as QuestObjective;
		if quest_objective:
			quest_objective.visibility_changed.emit();
		for s: MeshInstance3D in structure.instance.find_children("*", "MeshInstance3D", true, false):
			s.visible = b;

func apply_region(reg: RegionInfo) -> void:
	region = reg

	if not reg or not reg.material:
		return

	if ground_hex_mesh == null:
		ground_hex_mesh = find_child("hex_*", true) as MeshInstance3D
	if ground_hex_mesh != null:
		ground_hex_mesh.set_surface_override_material(0, reg.material)

func is_traversable(method: HexInfo.TraversalTag = HexInfo.TraversalTag.WALK) -> bool:
	if blocked:
		return false
	return (scene_instance.scene_info as HexInfo).traversal_tags.has(method);

func set_structure(s: StructureInfo, immediate: bool = false, placement_rotation_y: float = NAN, remove_if_passage_repair_failed: bool = false) -> bool:
	var required_tiles: Array[SceneInstance] = SceneManager.get_active_scene().node.get_tiles_in_radius(cube_id, s.required_space_radius);
	for required_tile in required_tiles:
		required_tile.node.can_generate = false

	var footprint_replacements: Array[SceneInstance] = [];
	if s.replace_non_traversable_hex:
		footprint_replacements.assign(required_tiles.filter(
			func(f: SceneInstance) -> bool:
				return f.node.cube_id != cube_id and not f.node.is_traversable()
		))
	if immediate:
		_on_structure_loaded(s, footprint_replacements, placement_rotation_y, remove_if_passage_repair_failed, false)
		return structure != null
	else:
		var was_cached := s.is_cached
		s.queue(_on_structure_loaded.bind(footprint_replacements, placement_rotation_y, remove_if_passage_repair_failed, not was_cached));
		return structure != null if was_cached else true
	
##When the structure finishes loading, add the instance to the scene and validate adjacent tiles
func _on_structure_loaded(s: StructureInfo, required_tiles: Array[SceneInstance], placement_rotation_y: float = NAN, remove_if_passage_repair_failed: bool = false, unregister_async_failure: bool = false) -> void:
	if region_instance != null:
		region_instance.structures[cube_id] = s;
	structure_root_tile = cube_id;

	structure = StructureInstance.new(s.get_instance().node, s);
	if structure.instance:
		if structure.instance is Interaction:
			(structure.instance as Interaction).hex = self;
		add_child(structure.instance);
		var placement_rotation := _get_structure_placement_rotation(s, placement_rotation_y)
		if bool(placement_rotation.get("has_rotation", false)):
			structure.instance.rotation.y = float(placement_rotation["rotation_y"])
		elif s.randomize_rotation:
			var grid := SceneManager.get_active_scene().node as HexGrid
			var rng := grid.create_rng("structure_rotation:%s:%s" % [cube_id, s.resource_path]) if grid != null else null
			var rotation_y := _get_random_structure_rotation_y(s, rng)
			structure.instance.rotation.y = rotation_y
	
	for t in required_tiles:
		SceneManager.get_active_scene().node.replace(t, scene_instance.scene_info.get_instance(), region);
	apply_region(region)

	if not _repair_passage_around_structure(s) and remove_if_passage_repair_failed:
		_remove_structure_after_failed_passage_repair(s, unregister_async_failure)
	
	if not is_explored:
		set_explored(false);
	
	if structure != null:
		structure_loaded.emit(s, structure.instance)

func _repair_passage_around_structure(s: StructureInfo) -> bool:
	if s.passage_repair_radius <= 0:
		return true

	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return true

	var footprint := _get_structure_footprint_coords(s)
	var perimeter := _get_walkable_structure_perimeter(grid, footprint)
	if perimeter.size() < 2:
		return true

	var connected := _get_connected_perimeter(grid, perimeter, footprint, s.passage_repair_radius)
	if connected.size() == perimeter.size():
		return true

	var attempts := perimeter.size()
	while connected.size() < perimeter.size() and attempts > 0:
		attempts -= 1

		var target := _get_first_unconnected_perimeter(perimeter, connected)
		var path := _find_passage_repair_path(grid, connected, target, footprint, s.passage_repair_radius)
		if path.is_empty():
			return false

		_carve_passage_path(grid, path)
		connected = _get_connected_perimeter(grid, perimeter, footprint, s.passage_repair_radius)

	return connected.size() == perimeter.size()

func _get_structure_footprint_coords(s: StructureInfo) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		result.append(cube_id)
		return result

	for sI: SceneInstance in grid.get_tiles_in_radius(cube_id, s.required_space_radius):
		var tile := sI.node as HexBase
		if tile != null:
			result.append(tile.cube_id)

	if result.is_empty():
		result.append(cube_id)
	return result

func _get_walkable_structure_perimeter(grid: HexGrid, footprint: Array[Vector3i]) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for coord: Vector3i in footprint:
		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			var neighbor_coord := coord + direction
			if footprint.has(neighbor_coord) or result.has(neighbor_coord):
				continue

			var neighbor := grid.get_hex_at_cube_id(neighbor_coord)
			if neighbor != null and neighbor.structure == null and neighbor.is_traversable(HexInfo.TraversalTag.WALK):
				result.append(neighbor_coord)
	return result

func _get_connected_perimeter(grid: HexGrid, perimeter: Array[Vector3i], blocked_coords: Array[Vector3i], repair_radius: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if perimeter.is_empty():
		return result

	var origin := perimeter[0]
	var frontier: Array[Vector3i] = [origin]
	var visited: Array[Vector3i] = [origin]
	while not frontier.is_empty():
		var current := frontier.pop_front() as Vector3i
		if perimeter.has(current) and not result.has(current):
			result.append(current)

		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			var next := current + direction
			if visited.has(next) or blocked_coords.has(next):
				continue
			if not _is_within_passage_repair_range(next, blocked_coords, repair_radius):
				continue

			var next_hex := grid.get_hex_at_cube_id(next)
			if next_hex == null or next_hex.structure != null or not next_hex.is_traversable(HexInfo.TraversalTag.WALK):
				continue

			visited.append(next)
			frontier.append(next)

	return result

func _get_first_unconnected_perimeter(perimeter: Array[Vector3i], connected: Array[Vector3i]) -> Vector3i:
	for coord: Vector3i in perimeter:
		if not connected.has(coord):
			return coord
	return perimeter[0]

func _find_passage_repair_path(grid: HexGrid, starts: Array[Vector3i], target: Vector3i, blocked_coords: Array[Vector3i], repair_radius: int) -> Array[Vector3i]:
	var frontier: Array[Vector3i] = []
	var cost_so_far: Dictionary[Vector3i, float] = {}
	var came_from: Dictionary[Vector3i, Vector3i] = {}

	for start: Vector3i in starts:
		frontier.append(start)
		cost_so_far[start] = 0.0

	while not frontier.is_empty():
		var current := _pop_lowest_cost_coord(frontier, cost_so_far)
		if current == target:
			return _reconstruct_passage_path(came_from, current)

		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			var next := current + direction
			if blocked_coords.has(next):
				continue
			if not _is_within_passage_repair_range(next, blocked_coords, repair_radius):
				continue

			var next_hex := grid.get_hex_at_cube_id(next)
			if next_hex == null:
				continue
			if next_hex.structure != null and next != target:
				continue

			var step_cost := 1.0 if next_hex.is_traversable(HexInfo.TraversalTag.WALK) else 8.0
			var new_cost := float(cost_so_far[current]) + step_cost
			if not cost_so_far.has(next) or new_cost < float(cost_so_far[next]):
				cost_so_far[next] = new_cost
				came_from[next] = current
				if not frontier.has(next):
					frontier.append(next)

	return []

func _is_within_passage_repair_range(coord: Vector3i, footprint: Array[Vector3i], repair_radius: int) -> bool:
	for footprint_coord: Vector3i in footprint:
		if GridUtils.cube_distance(coord, footprint_coord) <= repair_radius:
			return true
	return false

func _pop_lowest_cost_coord(frontier: Array[Vector3i], cost_so_far: Dictionary[Vector3i, float]) -> Vector3i:
	var best_index := 0
	var best_cost := float(cost_so_far[frontier[0]])
	for i in range(1, frontier.size()):
		var coord := frontier[i]
		var cost := float(cost_so_far[coord])
		if cost < best_cost:
			best_cost = cost
			best_index = i

	var result := frontier[best_index]
	frontier.remove_at(best_index)
	return result

func _reconstruct_passage_path(came_from: Dictionary[Vector3i, Vector3i], target: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = [target]
	var current := target
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

func _carve_passage_path(grid: HexGrid, path: Array[Vector3i]) -> void:
	for coord: Vector3i in path:
		var tile := grid.get_hex_at_cube_id(coord)
		if tile == null or tile.is_traversable(HexInfo.TraversalTag.WALK):
			continue

		tile.can_generate = false
		var replacement := scene_instance.scene_info.get_instance()
		grid.replace(tile.scene_instance, replacement, region)

func _remove_structure_after_failed_passage_repair(s: StructureInfo, unregister_async_failure: bool) -> void:
	if region_instance != null:
		region_instance.structures.erase(cube_id)
		if unregister_async_failure:
			region_instance.unregister_failed_structure_generation.call_deferred(s)
	if structure != null and is_instance_valid(structure.instance):
		structure.instance.queue_free()
	structure = null

func _get_structure_placement_rotation(s: StructureInfo, placement_rotation_y: float = NAN) -> Dictionary:
	var placeable := s as PlaceableStructureInfo
	if placeable == null:
		return { "has_rotation": false }
	return placeable.get_placement_rotation_y(self, placement_rotation_y)

func has_walkable_random_rotation(s: StructureInfo) -> bool:
	if s == null or not s.random_rotation_requires_walkable_neighbor:
		return true
	return not _get_walkable_neighbor_rotations().is_empty()

func _get_random_structure_rotation_y(s: StructureInfo, rng: RandomNumberGenerator = null) -> float:
	if s.random_rotation_requires_walkable_neighbor:
		var walkable_rotations := _get_walkable_neighbor_rotations(structure.instance)
		if not walkable_rotations.is_empty():
			var index := rng.randi_range(0, walkable_rotations.size() - 1) if rng != null else randi_range(0, walkable_rotations.size() - 1)
			return walkable_rotations[index]

		Debug.warn("%s has no walkable neighbor rotation at %s." % [s.id, cube_id])
		return 0.0

	var rotation_step := rng.randi_range(0, 5) if rng != null else randi_range(0, 5)
	return deg_to_rad(60 * rotation_step)

func _get_walkable_neighbor_rotations(structure_node: Node3D = null) -> Array[float]:
	var rotations: Array[float] = []
	var grid := SceneManager.get_active_scene().node as HexGrid
	if grid == null:
		return rotations

	var front_direction := _get_structure_front_direction(structure_node)
	if front_direction == Vector2.ZERO:
		front_direction = Vector2.RIGHT

	for direction: Vector3i in DataManager.instance.CUBE_DIRS:
		var neighbor := grid.get_hex_at_cube_id(cube_id + direction)
		if neighbor == null or not neighbor.is_traversable(HexInfo.TraversalTag.WALK):
			continue

		var neighbor_direction := neighbor.global_position - global_position
		var neighbor_direction_2d := Vector2(neighbor_direction.x, neighbor_direction.z).normalized()
		rotations.append(-front_direction.angle_to(neighbor_direction_2d))

	return rotations

func _get_structure_front_direction(structure_node: Node3D) -> Vector2:
	if structure_node == null:
		return Vector2.ZERO

	var front_anchor := structure_node.get_node_or_null("walkable_front_anchor") as Node3D
	if front_anchor == null:
		return Vector2.ZERO

	var front_offset := front_anchor.position
	var front_direction := Vector2(front_offset.x, front_offset.z)
	if front_direction.length_squared() <= 0.0001:
		return Vector2.ZERO

	return front_direction.normalized()

class_name StarterLayoutPlan
extends RefCounted
## Pre-instantiation land/height constraints. Natural terrain outside the small
## pads and connecting corridors remains untouched.
var home := Vector2i.ZERO
var locations: Dictionary[StructureInfo, Vector3i] = {}
var cells: Dictionary[Vector2i, bool] = {}

func build(grid: MainGrid, budget: GenerationBudget) -> void:
	home = _home_coordinate(grid)
	var origin := GridUtils.offset_to_cube(home, grid.pointy_top)
	var initial_chunks: Dictionary[Vector2i, bool] = {}
	for coordinate: Vector2i in grid._get_initial_chunk_coords(): initial_chunks[coordinate] = true
	var required := grid._get_required_structures()
	# The village is the largest pad; place it first, then the resource clearings.
	if grid.nearby_settlement != null:
		required.erase(grid.nearby_settlement)
		required.push_front(grid.nearby_settlement)
	var directions: Array[Vector3i] = []
	directions.assign(DataManager.instance.CUBE_DIRS)
	var rng := grid.create_rng("starter_layout_v2")
	for index in range(directions.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value := directions[index]
		directions[index] = directions[other]
		directions[other] = value
	for structure: StructureInfo in required:
		if structure == null: continue
		var minimum := grid.settlement_min_walk_distance if structure == grid.nearby_settlement else 9
		var maximum := grid.settlement_max_walk_distance if structure == grid.nearby_settlement else grid.required_structure_max_walk_distance
		var target := mini(maximum, maxi(minimum, 11))
		var pad_radius := structure.required_space_radius + 1
		var best := Vector3i.MAX
		var best_cost := INF
		for distance in range(target, maxi(0, minimum - 1), -1):
			for direction: Vector3i in directions:
				var candidate := origin + direction * distance
				if _conflicts(candidate, structure): continue
				var proposed := _pad_and_corridor(origin, candidate, pad_radius)
				var cost := 0.0
				var valid := true
				for coordinate: Vector3i in proposed:
					await budget.checkpoint()
					var offset := GridUtils.cube_to_offset(coordinate, grid.pointy_top)
					if not initial_chunks.has(grid.grid_to_chunk_coords(offset)):
						valid = false
						break
					var region := grid._get_region_for_grid_id(offset)
					cost += 4.0 if region == DataManager.instance.get_ocean_descriptor() else 0.0
					cost += grid.get_generated_elevation_units(offset)
				if valid and cost < best_cost:
					best_cost = cost
					best = candidate
			if best != Vector3i.MAX: break
		if best == Vector3i.MAX: continue
		locations[structure] = best
		grid.loading_progress.report(0.02 + 0.07 * float(locations.size()) / maxi(1, required.size()), "LOADING_PREPARING")
		for coordinate: Vector3i in _pad_and_corridor(origin, best, pad_radius):
			cells[GridUtils.cube_to_offset(coordinate, grid.pointy_top)] = true
	# Commit only once planning is complete, so candidate cost is independent of
	# the order in which the candidates were evaluated.
	for coordinate: Vector2i in cells:
		await budget.checkpoint()
		var region := grid._get_region_for_grid_id(coordinate)
		if region == DataManager.instance.get_ocean_descriptor():
			region = grid._get_protected_land_region(GridUtils.cube_distance(origin, GridUtils.offset_to_cube(coordinate, grid.pointy_top)), rng)
		if region == null: continue
		grid.generated_regions[coordinate] = region
		grid.generated_elevations[coordinate] = 0

func _conflicts(candidate: Vector3i, structure: StructureInfo) -> bool:
	for other: StructureInfo in locations:
		var clearance := structure.required_space_radius + other.required_space_radius + 3
		if GridUtils.cube_distance(candidate, locations[other]) <= clearance: return true
	return false

func _pad_and_corridor(origin: Vector3i, target: Vector3i, radius: int) -> Array[Vector3i]:
	var result: Dictionary[Vector3i, bool] = {}
	var current := origin
	while current != target:
		# A seed-selected ray gives a continuous corridor without rounding cracks.
		_add_disc(result, current, 1)
		var best := current
		var distance := GridUtils.cube_distance(current, target)
		for direction: Vector3i in DataManager.instance.CUBE_DIRS:
			if GridUtils.cube_distance(current + direction, target) < distance:
				best = current + direction
				break
		current = best
	_add_disc(result, target, radius)
	return result.keys()

func _add_disc(result: Dictionary[Vector3i, bool], center: Vector3i, radius: int) -> void:
	for x in range(-radius, radius + 1):
		for y in range(maxi(-radius, -x - radius), mini(radius, -x + radius) + 1):
			result[center + Vector3i(x, y, -x - y)] = true

func _home_coordinate(grid: HexGrid) -> Vector2i:
	var spacing := GridUtils.get_spacing(grid.RADIUS_IN, grid._spacing, grid.pointy_top)
	var positions: Dictionary[Vector2i, Vector2] = {}
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for y in grid.chunk_size.y:
		for x in grid.chunk_size.x:
			var position := Vector2(x * spacing.x, y * spacing.y)
			if grid.pointy_top: position.y += (x & 1) * spacing.y / 2.0
			else: position.x += (y & 1) * spacing.x / 2.0
			positions[Vector2i(x, y)] = position
			minimum = minimum.min(position)
			maximum = maximum.max(position)
	var best := Vector2i.ZERO
	var best_distance := INF
	for coordinate: Vector2i in positions:
		var distance := positions[coordinate].distance_squared_to((minimum + maximum) * 0.5)
		if distance < best_distance:
			best = coordinate
			best_distance = distance
	return best

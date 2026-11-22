class_name KnownTradeRoutes
extends RefCounted

var _nav := AStar2D.new()
var _revision := -1
var _grid_id := 0

func invalidate() -> void:
	_revision = -1

func route(grid: MainGrid, stops: TransportStops, start: HexBase, finish: HexBase) -> Array[HexBase]:
	if start == null or finish == null: return []
	if not start.is_explored or not finish.is_explored: return []
	stops.ensure_all(grid)
	var source := grid.pathfinder
	if _revision != source.revision or _grid_id != grid.get_instance_id():
		_rebuild(grid, stops)
	var from_id: int = source.cube_to_id.get(start.cube_id, -1)
	var to_id: int = source.cube_to_id.get(finish.cube_id, -1)
	if not _nav.has_point(from_id) or not _nav.has_point(to_id): return []
	var result: Array[HexBase] = []
	for point: int in _nav.get_id_path(from_id, to_id):
		result.append(grid.get_hex_at_cube_id(source.id_to_cube[point]))
	return result

func _rebuild(grid: MainGrid, stops: TransportStops) -> void:
	var inside := stops.interiors(grid)
	var source := grid.pathfinder
	_nav = AStar2D.new()
	for coord: Vector3i in source.cube_to_id:
		var hex := grid.get_hex_at_cube_id(coord)
		if hex == null or inside.has(coord) or not hex.is_explored or not hex.is_traversable(HexInfo.TraversalTag.WALK): continue
		var point: int = source.cube_to_id[coord]
		_nav.add_point(point, source.get_point_position(point), hex.movement_cost)
	for point: int in _nav.get_point_ids():
		for neighbor: int in source.get_point_connections(point):
			if _nav.has_point(neighbor) and stops.permits_edge(source.id_to_cube[point], source.id_to_cube[neighbor]) and not _nav.are_points_connected(point, neighbor):
				_nav.connect_points(point, neighbor)
	_revision = grid.pathfinder.revision
	_grid_id = grid.get_instance_id()

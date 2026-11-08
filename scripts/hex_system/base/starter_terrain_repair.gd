class_name StarterTerrainRepair
extends RefCounted
## Last-resort starter land repair, run before random structure scattering.
## Does not change seeds or distance limits, and leaves occupied tiles intact.

static func repair(grid: MainGrid, origin: HexBase) -> int:
	if origin == null: return 0
	var radius := grid.player_settlement.required_space_radius + 4
	if grid.nearby_settlement != null:
		radius = maxi(radius, grid.settlement_min_walk_distance + grid.nearby_settlement.required_space_radius + 2)
	var land_info := origin.scene_instance.scene_info as HexInfo
	if land_info == null or origin is HexSlope or not origin.is_traversable(): return 0
	var changed := 0
	for instance: SceneInstance in grid.get_tiles_in_radius(origin.cube_id, radius):
		if grid.startup_budget != null: await grid.startup_budget.checkpoint()
		var hex := instance.node as HexBase
		if hex.structure != null: continue
		if hex.is_traversable() and not hex is HexSlope and hex.elevation_units == origin.elevation_units:
			continue
		var coordinate := hex.grid_id
		var region := hex.region if hex.is_traversable() else origin.region
		var explored := hex.is_explored
		var info := hex.scene_instance.scene_info as HexInfo
		if hex is HexSlope or not hex.is_traversable(): info = land_info
		grid.replace(instance, info.get_instance(), region)
		var replacement := grid.get_hex_at_grid_id(coordinate)
		replacement.generated_elevation_units = origin.elevation_units
		replacement.set_elevation(origin.elevation_units, grid.elevation_unit_height)
		replacement.is_explored = explored
		grid.generated_regions[coordinate] = region
		grid.generated_elevations[coordinate] = origin.elevation_units
		changed += 1
	return changed

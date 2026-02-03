class_name RegionInstance
extends RefCounted

var info: RegionInfo
var hexes: Dictionary[Vector3i, HexBase] = {}
var structures: Dictionary[Vector3i, StructureInfo] = {}
var hex_grid: HexGrid;

var structure_caps: Dictionary[StructureInfo, int] = {}
var structure_counts: Dictionary[StructureInfo, int] = {}

func _init(p_info: RegionInfo, grid: HexGrid) -> void:
	hex_grid = grid;
	info = p_info

func add_hex(hex: HexBase) -> void:
	hexes[hex.cube_id] = hex
	hex.region_instance = self;
	hex.apply_region(info)

func has_hex(coord: Vector3i) -> bool:
	return hexes.has(coord)

func merge_from(other: RegionInstance) -> void:
	for coord in other.hexes:
		add_hex(other.hexes[coord])
		
func remove_hex(coord: Vector3i) -> void:
	hexes.erase(coord);
	
func render_debug_region() -> void:
	var clr := Color(randf_range(0, 1), randf_range(0, 1), randf_range(0, 1));
	for hex: HexBase in hexes.values():
		var mat := StandardMaterial3D.new();
		mat.albedo_color = clr;
		hex.ground_mesh.material_override = mat;
		
func _required_distance(a: StructureInfo, b: StructureInfo) -> int:
	return (
		max(a.required_space_radius, b.required_space_radius)
		+ max(a.minimum_distance_from_other_structures, b.minimum_distance_from_other_structures)
		+ 1
	)
		
func _pick_structure() -> StructureInfo:
	var total_weight := 0.0
	var candidates: Array[StructureInfo] = []
	var cumulative: Array[float] = []

	for s: StructureInfo in structure_caps.keys():
		if structure_counts[s] >= structure_caps[s]:
			continue

		var weight := info.structures[s] * s.spawn_weight
		if weight <= 0.0:
			continue

		total_weight += weight
		candidates.append(s)
		cumulative.append(total_weight)

	if total_weight == 0.0:
		return null

	var r := randf() * total_weight
	for i in cumulative.size():
		if r <= cumulative[i]:
			return candidates[i]

	return null

func _compute_structure_caps() -> void:
	structure_caps.clear()
	var region_size := hexes.size()

	for s: StructureInfo in info.structures.keys():
		var cap := s.get_max_count(region_size)
		if cap > 0:
			structure_caps[s] = cap
			
	structure_counts.clear()
	for s in structure_caps.keys():
		structure_counts[s] = 0

func _can_place_structure_at(pos: Vector3i, candidate: StructureInfo) -> bool:
	var chunk_coords := hex_grid.grid_to_chunk_coords(hex_grid.tiles[pos].grid_id)
	if chunk_coords == Vector2i(0, 0) && hex_grid.skip_spawn_chunk:
		return false
		
	if Manager.instance.player_instance && pos == Manager.instance.player_instance.get_hex().cube_id:
		return false;
	
	for region_list in hex_grid.region_instances.values():
		for region_instance: RegionInstance in region_list:
			for other_pos: Vector3i in region_instance.structures.keys():
				var other := region_instance.structures[other_pos]

				var dist := GridUtils.cube_distance(pos, other_pos)
				var min_dist := _required_distance(candidate, other)
				if dist <= min_dist:
					return false
	return true

func generate_structures_for_region() -> void:
	if info.structures.is_empty():
		return

	_compute_structure_caps()

	var available_hexes: Array[Vector3i] = hexes.keys()
	available_hexes.shuffle()

	var max_total := 0
	for cap in structure_caps.values():
		max_total += cap

	var target_count := mini(max_total, hexes.size())
	var placed_total := 0

	while placed_total < target_count and not available_hexes.is_empty():
		var structure := _pick_structure()
		if structure == null:
			break

		var placed := false

		for attempt in 5:
			var hex_id: Vector3i = available_hexes.pick_random()
			var hex := hex_grid.get_hex_at_world_position(hex_id)

			if not hex or not hex.can_generate:
				continue

			if not _can_place_structure_at(hex_id, structure):
				continue

			structures[hex_id] = structure
			hex.set_structure(structure)

			structure_counts[structure] += 1
			available_hexes.erase(hex_id)

			placed_total += 1
			placed = true
			break

		if not placed:
			structure_counts[structure] = structure_caps[structure]

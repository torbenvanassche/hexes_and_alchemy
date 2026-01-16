class_name RegionInstance
extends RefCounted

var info: RegionInfo
var hexes: Dictionary[Vector3i, HexBase] = {}
var structures: Dictionary[Vector3i, StructureInfo] = {}
var hex_grid: HexGrid;

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
		
func _count_structures(inst: RegionInstance, pInfo: StructureInfo) -> int:
	var count := 0
	for s in inst.structures.values():
		if s == pInfo:
			count += 1
	return count

func _pick_structure() -> StructureInfo:
	var total_weight := info.structure_fail_weight
	var cumulative: Array[float] = [total_weight]
	var candidates: Array[StructureInfo] = [null]

	for s: StructureInfo in info.structures.keys():
		var max_allowed := s.get_max_count(hexes.size())
		var current := _count_structures(self, s)

		if max_allowed > 0 and current > max_allowed:
			continue

		var weight := info.structures[s] * s.spawn_weight
		if weight <= 0.0:
			continue

		total_weight += weight
		candidates.append(s)
		cumulative.append(total_weight)

	if total_weight <= 0.0:
		return null

	var r := randf() * total_weight
	for i in cumulative.size():
		if r <= cumulative[i]:
			return candidates[i]

	return null

func _can_place_structure_at(candidate_id: Vector3i, candidate: StructureInfo) -> bool:
	for region_info: RegionInfo in hex_grid.region_instances.keys():
		for region_instance: RegionInstance in hex_grid.region_instances[region_info]:
			for structure_position in region_instance.structures.keys():
				var structureInfo: StructureInfo = region_instance.structures[structure_position];
				var required_distance: int = (candidate.required_space_radius + structureInfo.required_space_radius + max(candidate.minimum_distance_from_other_structures, structureInfo.minimum_distance_from_other_structures))
				if GridUtils.cube_distance(structure_position, candidate_id) < required_distance:
					return false
	return true
	
func generate_structures_for_region() -> void:
	if info.structures.is_empty():
		return

	var available_hexes: Array[Vector3i] = hexes.keys()
	available_hexes.shuffle()

	while not available_hexes.is_empty():
		var structure := _pick_structure()
		if structure == null:
			break

		var hex_id := available_hexes.pop_back() as Vector3i;
		var hex := hex_grid.get_hex_at_world_position(hex_id);
		if hex_grid.chunks[Vector2i(0,0)].hexes.has(hex):
			continue
		
		if hex && hex.can_generate && _can_place_structure_at(hex_id, structure):
			structures[hex_id] = structure
			hex_grid.get_hex_at_world_position(hex_id).set_structure(structure);

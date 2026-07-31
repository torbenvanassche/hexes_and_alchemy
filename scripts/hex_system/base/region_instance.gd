class_name RegionInstance
extends RefCounted

var info: RegionInfo
var hexes: Dictionary[Vector3i, HexBase] = {}
var structures: Dictionary[Vector3i, StructureInfo] = {}
var hex_grid: HexGrid;

var structure_caps: Dictionary[StructureInfo, int] = {}
var structure_counts: Dictionary[StructureInfo, int] = {}

var _cached_seed_key := ""
var _seed_key_dirty := true

func _init(p_info: RegionInfo, grid: HexGrid) -> void:
	hex_grid = grid;
	info = p_info

func add_hex(hex: HexBase) -> void:
	hexes[hex.cube_id] = hex
	hex.region_instance = self;
	hex.apply_region(info)
	_seed_key_dirty = true

func has_hex(coord: Vector3i) -> bool:
	return hexes.has(coord)

func merge_from(other: RegionInstance) -> void:
	for coord in other.hexes:
		add_hex(other.hexes[coord])
	for coord in other.structures:
		structures[coord] = other.structures[coord]
	_seed_key_dirty = true
		
func remove_hex(coord: Vector3i) -> void:
	hexes.erase(coord);
	_seed_key_dirty = true
		
func _required_distance(a: StructureInfo, b: StructureInfo) -> int:
	return (
		max(a.required_space_radius, b.required_space_radius)
		+ max(a.minimum_distance_from_other_structures, b.minimum_distance_from_other_structures)
		+ 1
	)
		
func _pick_structure(rng: RandomNumberGenerator) -> StructureInfo:
	var fail_weight := maxf(0.0, info.structure_fail_weight)
	var total_weight := fail_weight
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

	var r := rng.randf() * total_weight
	if r <= fail_weight:
		return null

	for i in cumulative.size():
		if r <= cumulative[i]:
			return candidates[i]

	return null

func _get_seed_key() -> String:
	if not _seed_key_dirty:
		return _cached_seed_key

	var keys: Array[Vector3i] = hexes.keys()
	keys.sort_custom(_sort_hex_ids)

	var coord_hash := 0
	for key: Vector3i in keys:
		coord_hash = int((coord_hash * 31 + key.x * 73856093 + key.y * 19349663 + key.z * 83492791) % 2147483647)

	_cached_seed_key = "%s:%s:%s" % [info.resource_path, hexes.size(), coord_hash]
	_seed_key_dirty = false
	return _cached_seed_key

func _sort_hex_ids(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z

func _shuffle_hexes(values: Array[Vector3i], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var swap_idx := rng.randi_range(0, i)
		var temp := values[i]
		values[i] = values[swap_idx]
		values[swap_idx] = temp

func _compute_structure_caps(region_size: int = -1) -> void:
	structure_caps.clear()
	if region_size < 0:
		region_size = _get_structure_generation_hexes().size()

	for s: StructureInfo in info.structures.keys():
		var cap := s.get_max_count(region_size)
		if cap > 0:
			structure_caps[s] = cap
			
	structure_counts.clear()
	for s in structure_caps.keys():
		structure_counts[s] = 0
	for structure in structures.values():
		if structure_counts.has(structure):
			structure_counts[structure] += 1

func _can_place_structure_at(pos: Vector3i, candidate: StructureInfo) -> bool:	
	var hex := hexes[pos]
	if hex == null:
		return false;

	if not hex_grid.can_generate_structures_on_hex(hex):
		return false;

	if not hex.can_generate:
		return false;

	if not _has_clear_generation_space(pos, candidate):
		return false;

	if not hex.has_walkable_random_rotation(candidate):
		return false;
	
	if Manager.instance.player_instance:
		var player_hex := Manager.instance.player_instance.get_hex();
		if not player_hex:
			Debug.err("Player hex was not found.")
			return false;
		
		if hex.cube_id == player_hex.cube_id:
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

func try_place_required_structure_at(pos: Vector3i, candidate: StructureInfo) -> bool:
	if candidate == null or not hexes.has(pos):
		return false
	if not _can_place_structure_at(pos, candidate):
		return false

	var hex := hexes[pos]
	structures[pos] = candidate
	if not hex.set_structure(candidate, true, NAN, true):
		structures.erase(pos)
		return false
	return true

func _has_clear_generation_space(center: Vector3i, candidate: StructureInfo) -> bool:
	var footprint := hex_grid.get_tiles_in_radius(center, candidate.required_space_radius);
	var expected_tile_count := 1 + 3 * candidate.required_space_radius * (candidate.required_space_radius + 1);
	if footprint.size() != expected_tile_count:
		return false;

	for scene_instance: SceneInstance in footprint:
		var tile := scene_instance.node as HexBase;
		if tile == null:
			return false;

		if not hex_grid.can_generate_structures_on_hex(tile):
			return false;

		if not tile.can_generate or tile.structure != null:
			return false;

	return true;

func _get_structure_generation_hexes() -> Array[Vector3i]:
	var generation_hexes: Array[Vector3i] = []
	for hex_id: Vector3i in hexes.keys():
		var hex := hexes[hex_id]
		if hex != null and hex_grid.can_generate_structures_on_hex(hex):
			generation_hexes.append(hex_id)
	return generation_hexes

func create_structure_generation_job(candidate_hexes: Array[Vector3i] = []) -> Dictionary:
	if info.structures.is_empty():
		return {}

	var generation_hexes := _get_structure_generation_hexes()
	_compute_structure_caps(generation_hexes.size())
	var rng := hex_grid.create_rng("structures:%s" % _get_seed_key())

	var available_hexes: Array[Vector3i] = []
	if candidate_hexes.is_empty():
		available_hexes = generation_hexes
	else:
		for hex_id in candidate_hexes:
			if not hexes.has(hex_id):
				continue
			var candidate_hex := hexes[hex_id] as HexBase
			if candidate_hex != null and hex_grid.can_generate_structures_on_hex(candidate_hex):
				available_hexes.append(hex_id)
	if available_hexes.is_empty():
		return {}
	available_hexes.sort_custom(_sort_hex_ids)
	_shuffle_hexes(available_hexes, rng)

	var max_total := 0
	for cap in structure_caps.values():
		max_total += cap

	var existing_total := 0
	for count in structure_counts.values():
		existing_total += count

	var density := clampf(info.structure_density, 0.0, 1.0)
	var expected_total := float(min(max_total, generation_hexes.size())) * density
	var target_total := int(floor(expected_total))
	var fractional_target := expected_total - float(target_total)
	if fractional_target > 0.0 and rng.randf() < fractional_target:
		target_total += 1

	var target_count := maxi(0, target_total - existing_total)
	if target_count <= 0:
		return {}

	return {
		"rng": rng,
		"available_hexes": available_hexes,
		"remaining_slots": target_count,
	}

func process_structure_generation_job(job: Dictionary) -> bool:
	if job.is_empty():
		return true

	var remaining_slots := int(job["remaining_slots"])
	var available_hexes := job["available_hexes"] as Array[Vector3i]
	if remaining_slots <= 0 or available_hexes.is_empty():
		return true

	job["remaining_slots"] = remaining_slots - 1
	var rng := job["rng"] as RandomNumberGenerator
	var structure := _pick_structure(rng)
	if structure == null:
		return int(job["remaining_slots"]) <= 0

	var placed := false
	var start_index := rng.randi_range(0, available_hexes.size() - 1)
	for offset in available_hexes.size():
		var hex_id: Vector3i = available_hexes[(start_index + offset) % available_hexes.size()]
		var hex := hexes[hex_id] as HexBase

		if hex == null or not hex.can_generate:
			continue
		if not _can_place_structure_at(hex_id, structure):
			continue

		structures[hex_id] = structure
		if not hex.set_structure(structure, false, NAN, true):
			structures.erase(hex_id)
			continue

		structure_counts[structure] += 1
		available_hexes.erase(hex_id)
		placed = true
		break

	if not placed:
		structure_counts[structure] = structure_caps[structure]

	return int(job["remaining_slots"]) <= 0 or available_hexes.is_empty()

func generate_structures_for_region(candidate_hexes: Array[Vector3i] = []) -> void:
	var job := create_structure_generation_job(candidate_hexes)
	while not process_structure_generation_job(job):
		pass

func get_structured_hexes() -> Array[HexBase]:
	var instances: Array[HexBase] = []
	for hex: HexBase in hexes.values():
		if hex.structure && not hex.structure.instance is Settlement:
			instances.append(hex)
	return instances;

func unregister_failed_structure_generation(structure: StructureInfo) -> void:
	if structure == null or not structure_counts.has(structure):
		return

	structure_counts[structure] = maxi(0, int(structure_counts[structure]) - 1)

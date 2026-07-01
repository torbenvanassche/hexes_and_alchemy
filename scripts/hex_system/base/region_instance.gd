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
	var keys: Array[Vector3i] = hexes.keys()
	keys.sort_custom(
		func(a: Vector3i, b: Vector3i) -> bool:
			if a.x != b.x:
				return a.x < b.x
			if a.y != b.y:
				return a.y < b.y
			return a.z < b.z
	)

	var coord_hash := 0
	for key: Vector3i in keys:
		coord_hash = int((coord_hash * 31 + key.x * 73856093 + key.y * 19349663 + key.z * 83492791) % 2147483647)

	return "%s:%s:%s" % [info.resource_path, hexes.size(), coord_hash]

func _shuffle_hexes(values: Array[Vector3i], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var swap_idx := rng.randi_range(0, i)
		var temp := values[i]
		values[i] = values[swap_idx]
		values[swap_idx] = temp

func _compute_structure_caps() -> void:
	structure_caps.clear()
	var region_size := _get_structure_generation_hexes().size()

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

func generate_structures_for_region() -> void:
	if info.structures.is_empty():
		return

	_compute_structure_caps()
	var rng := hex_grid.create_rng("structures:%s" % _get_seed_key())

	var available_hexes := _get_structure_generation_hexes()
	if available_hexes.is_empty():
		return
	_shuffle_hexes(available_hexes, rng)

	var max_total := 0
	for cap in structure_caps.values():
		max_total += cap

	var existing_total := 0
	for count in structure_counts.values():
		existing_total += count

	var density := clampf(info.structure_density, 0.0, 1.0)
	var expected_total := float(min(max_total, available_hexes.size())) * density
	var target_total := int(floor(expected_total))
	var fractional_target := expected_total - float(target_total)
	if fractional_target > 0.0 and rng.randf() < fractional_target:
		target_total += 1

	var target_count := maxi(0, target_total - existing_total)
	var processed_slots := 0

	while processed_slots < target_count and not available_hexes.is_empty():
		processed_slots += 1
		var structure := _pick_structure(rng)
		if structure == null:
			continue

		var placed := false

		var placement_candidates := available_hexes.duplicate()
		_shuffle_hexes(placement_candidates, rng)
		for hex_id: Vector3i in placement_candidates:
			var hex := hexes[hex_id]

			if not hex or not hex.can_generate:
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

func get_structured_hexes() -> Array[HexBase]:
	var instances: Array[HexBase];
	for hex: HexBase in hexes.values():
		if hex.structure && not hex.structure.instance is Settlement:
			instances.append(hex)
	return instances;

func unregister_failed_structure_generation(structure: StructureInfo) -> void:
	if structure == null or not structure_counts.has(structure):
		return

	structure_counts[structure] = maxi(0, int(structure_counts[structure]) - 1)

class_name DiscoveryRandomizer
extends RefCounted

var sites: Array[QuestObjective] = []
var definitions: Array[DiscoveryDefinition] = []

func register_site(site: QuestObjective) -> void:
	if not sites.has(site): sites.append(site)

func roll_definition(kind: String, rng: RandomNumberGenerator, opening_safe := false, site: QuestObjective = null, grid: MainGrid = null) -> DiscoveryDefinition:
	var candidates: Array[DiscoveryDefinition] = []
	var weights: Array[float] = []
	var total := 0.0
	for definition: DiscoveryDefinition in definitions:
		if definition.site_kind != kind or definition.weight <= 0.0: continue
		if opening_safe and not definition.safe_for_opening: continue
		var weight := definition.weight
		if site != null and grid != null and grid.generation_version >= 2:
			weight = _local_weight(definition, site, grid)
		if weight <= 0.0: continue
		candidates.append(definition)
		weights.append(weight)
		total += weight
	if candidates.is_empty(): return null
	var roll := rng.randf() * total
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0: return candidates[index]
	return candidates.back()

func _local_weight(definition: DiscoveryDefinition, site: QuestObjective, grid: MainGrid) -> float:
	var repeats := 0
	for other: QuestObjective in sites:
		if not is_instance_valid(other) or other == site or other.hex == null or not other.discovery_resolved: continue
		if not grid.is_ancestor_of(other): continue
		var distance := GridUtils.cube_distance(site.hex.cube_id, other.hex.cube_id)
		if distance <= grid.discovery_variation_radius and other.discovery_id == definition.id: repeats += 1
		if definition.is_disruption and distance <= grid.disruption_spacing:
			var previous := get_definition(other.discovery_id)
			if previous != null and previous.is_disruption: return 0.0
	return definition.weight / (1.0 + repeats * grid.discovery_variant_repeat_penalty)

func get_definition(id: String) -> DiscoveryDefinition:
	for definition: DiscoveryDefinition in definitions:
		if definition.id == id: return definition
	return null

func refresh(grid: MainGrid) -> void:
	var changed := false
	for index in range(sites.size() - 1, -1, -1):
		var site := sites[index]
		if not is_instance_valid(site):
			sites.remove_at(index)
			continue
		if site.discovery_resolved or site.hex == null or not site.hex.is_explored: continue
		if not grid.is_ancestor_of(site): continue
		var kind := get_kind(site)
		var definition := roll_definition(kind, grid.create_rng("discovery:%s:%s" % [kind, site.hex.cube_id]), _is_opening_source(site, grid), site, grid)
		site.discovery_resolved = true
		if definition == null: continue
		changed = true
		site.discovery_id = definition.id
		if not definition.initial_state.is_empty(): site.apply_site_state(definition.initial_state)
		var rng := grid.create_rng("discovery_occupation:%s" % site.hex.cube_id)
		match definition.occupation:
			DiscoveryDefinition.Occupation.NONE:
				var spot := site.get_spot_progress()
				if spot != null: spot.resolve_no_occupation(true)
			DiscoveryDefinition.Occupation.PRESENT:
				if not site.occupation_pool.is_empty():
					site.set_occupation(site.occupation_pool[rng.randi_range(0, site.occupation_pool.size() - 1)], true)
		if site.has_method("_update_danger_marker"): site.call("_update_danger_marker")
	if changed: Manager.instance.quests.quest_availability_changed.emit()

static func get_kind(site: QuestObjective) -> String:
	if site == null or site.hex == null or site.hex.structure == null: return ""
	# The content catalog derives StructureInfo.id from its filename. The mine
	# resource is spawnable_mine.tres; keep gameplay definitions independent of it.
	if site is Mineshaft: return "mines"
	return site.hex.structure.structure_info.id

func _is_opening_source(site: QuestObjective, grid: MainGrid) -> bool:
	for structure: StructureInfo in grid._required_starting_structure_coords:
		if get_kind(site) in ["forest", "mines"] and grid._required_starting_structure_coords[structure].has(site.hex.cube_id): return true
	return false

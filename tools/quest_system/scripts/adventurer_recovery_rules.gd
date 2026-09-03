class_name AdventurerRecoveryRules
extends Resource

@export_range(0.0, 60.0, 0.5) var base_rest_seconds := 3.0
@export_range(0.0, 10.0, 0.05) var quest_duration_rest_multiplier := 0.35
@export_range(1.0, 4.0, 0.05) var dangerous_quest_rest_multiplier := 2.0
@export_range(1.0, 3.0, 0.05) var uncertain_quest_rest_multiplier_min := 1.15
@export_range(1.0, 3.0, 0.05) var uncertain_quest_rest_multiplier_max := 1.55
@export_range(0.0, 120.0, 1.0) var maximum_rest_seconds := 30.0
@export var injury_recovery_item: ItemInfo
@export_range(0, 100, 1) var injury_recovery_item_count := 1
@export_range(0.25, 1.0, 0.05) var injury_item_recovery_multiplier := 0.75
@export_group("Dangerous Outcomes")
@export_range(0.0, 1.0, 0.01) var dangerous_outcome_injury_chance := 0.7
@export_range(0.0, 1.0, 0.01) var dangerous_outcome_death_chance := 0.12
@export var injury_pool: Array[AdventurerInjury] = []
@export_range(1, 10, 1) var maximum_persistent_injuries := 3
@export_range(1, 30, 1) var forced_retirement_severity := 5
@export_group("Career")
## Real-time seconds from recruitment until automatic retirement. Zero disables aging.
@export_range(0.0, 7200.0, 10.0) var automatic_retirement_seconds := 900.0

func get_injury_recovery_cost() -> Dictionary[ItemInfo, int]:
	var cost: Dictionary[ItemInfo, int] = {}
	if injury_recovery_item != null and injury_recovery_item_count > 0:
		cost[injury_recovery_item] = injury_recovery_item_count
	return cost

func get_injury_chance() -> float:
	return clampf(dangerous_outcome_injury_chance, 0.0, 1.0)

func get_death_chance() -> float:
	return clampf(dangerous_outcome_death_chance, 0.0, 1.0)

func roll_injury(existing: Array[AdventurerInjury]) -> AdventurerInjury:
	if existing.size() >= maximum_persistent_injuries:
		return null
	var available := injury_pool.filter(func(injury: AdventurerInjury) -> bool:
		return injury != null and not existing.any(func(active: AdventurerInjury) -> bool: return active.id == injury.id)
	)
	return available.pick_random() if not available.is_empty() else null

func calculate_rest_seconds(quest: Quest, recovery_item_used: bool = false) -> float:
	var rest_time := base_rest_seconds
	var profile := quest.get_profile() if quest != null else null
	if profile != null:
		rest_time += maxf(0.0, profile.duration_seconds) * quest_duration_rest_multiplier
		match quest.get_effective_risk_key():
			"QUEST_RISK_DANGEROUS":
				rest_time *= dangerous_quest_rest_multiplier
			"QUEST_RISK_UNCERTAIN":
				var lower_multiplier := minf(uncertain_quest_rest_multiplier_min, uncertain_quest_rest_multiplier_max)
				var upper_multiplier := maxf(uncertain_quest_rest_multiplier_min, uncertain_quest_rest_multiplier_max)
				rest_time *= randf_range(lower_multiplier, upper_multiplier)
	if recovery_item_used:
		rest_time *= injury_item_recovery_multiplier
	return clampf(rest_time, 0.0, maximum_rest_seconds)

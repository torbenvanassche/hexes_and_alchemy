class_name RecruitmentRules
extends Resource

@export var name_pool: AdventurerNamePool
@export_range(1, 10, 1) var candidate_capacity := 5
@export_range(1, 10, 1) var initial_candidate_count := 4
@export_range(1, 20, 1) var operations_per_natural_arrival := 2
@export_range(0, 1000, 1) var manual_refresh_cost := 15
@export_range(0, 1000, 1) var base_hire_cost := 15
@export_range(0, 1000, 1) var rank_hire_cost := 15
@export_range(0, 1000, 1) var trait_hire_cost := 2
@export_range(1, 100, 1) var prestige_per_rank_tier := 5
@export var maximum_candidate_rank: AdventurerRank.Rank = AdventurerRank.Rank.C

func get_initial_pool_size() -> int:
	return mini(initial_candidate_count, candidate_capacity)

func get_next_arrival_operation(completed_operations: int) -> int:
	return maxi(0, completed_operations) + maxi(1, operations_per_natural_arrival)

func advance_arrival_operation(current_operation: int) -> int:
	return current_operation + maxi(1, operations_per_natural_arrival)

func roll_candidate_rank(rng: RandomNumberGenerator, prestige: int) -> AdventurerRank.Rank:
	var unlocked_tiers := floori(float(maxi(0, prestige)) / float(maxi(1, prestige_per_rank_tier)))
	var highest_rank := mini(int(maximum_candidate_rank), unlocked_tiers)
	if rng == null or highest_rank <= int(AdventurerRank.Rank.F):
		return AdventurerRank.Rank.F
	return AdventurerRank.clamp_rank(rng.randi_range(int(AdventurerRank.Rank.F), highest_rank))

func get_hire_cost(candidate_rank: AdventurerRank.Rank, trait_count: int) -> int:
	return maxi(0, base_hire_cost + int(candidate_rank) * rank_hire_cost + maxi(0, trait_count) * trait_hire_cost)

class_name NpcInfo extends SceneInfo

@export var img: Texture;

@export_group("Rank")
@export var starting_rank: AdventurerRank.Rank = AdventurerRank.Rank.F
@export_range(0.0, 1.0, 0.01) var rank_move_speed_bonus_per_tier := 0.05
@export var rank_experience_thresholds: Curve = Curve.new()

@export_group("Equipment")
@export var default_equipment: NpcEquipmentSlots

@export_group("Quest Decisions")
@export var minimum_quest_score: float = 1.0
@export var base_eligible_quest_score: float = 10.0
@export var rank_experience_reward_weight: float = 2.0
@export var offered_currency_reward_weight: float = 0.1
@export var rank_surplus_weight: float = 0.5
@export var distance_penalty_per_tile: float = 0.05

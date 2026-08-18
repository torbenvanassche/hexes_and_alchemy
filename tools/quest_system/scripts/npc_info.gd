class_name NpcInfo extends SceneInfo

@export var img: Texture;

@export_group("Identity")
@export var faction_id: StringName = &""
@export var profession: String = "generalist"
@export var role: String = "adventurer"
@export var operation_roles: Array[String] = ["adventurer"]
@export var traits: Array[AdventurerTraitDefinition] = []
## Quest keys or behaviours this adventurer prefers. Examples: scout, prospect, extract.
@export var preferred_jobs: Array[String] = []
@export var disliked_jobs: Array[String] = []

@export_group("Rank")
@export var starting_rank: AdventurerRank.Rank = AdventurerRank.Rank.F
@export_range(0.0, 1.0, 0.01) var rank_move_speed_bonus_per_tier := 0.05
@export var rank_experience_thresholds: Curve = Curve.new()

@export_group("Equipment")
@export var default_equipment: NpcEquipmentSlots

@export_group("Quest Decisions")
## A job the adventurer dislikes should require a more compelling reward offer.
@export var minimum_quest_score: float = 3.0
@export var base_eligible_quest_score: float = 0.0
@export var rank_experience_reward_weight: float = 1.0
@export var offered_currency_reward_weight: float = 0.1
@export var rank_surplus_weight: float = 0.5
@export var distance_penalty_per_tile: float = 0.05
@export var preferred_job_score_bonus: float = 5.0
@export var disliked_job_score_penalty: float = -4.0

func get_instance() -> SceneInstance:
	var scene_instance := super.get_instance()
	if scene_instance == null:
		return null
	var npc := scene_instance.node as NPC
	if npc != null:
		npc.npc_info = self
	return scene_instance

func get_profession_display_name() -> String:
	return _translate_identity_label("NPC_PROFESSION", profession, "NPC_PROFESSION_GENERALIST")

func get_role_display_name() -> String:
	return _translate_identity_label("NPC_ROLE", role, "NPC_ROLE_ADVENTURER")

func get_operation_roles() -> Array[String]:
	return operation_roles.duplicate() if not operation_roles.is_empty() else ["adventurer"]

func can_perform_role(required_role: String) -> bool:
	return required_role.is_empty() or get_operation_roles().has(required_role)

func get_preferred_jobs_display_names() -> Array[String]:
	var labels: Array[String] = []
	for job_key: String in preferred_jobs:
		var translation_key := "QUEST_TYPE_%s" % job_key.to_upper()
		var translated := tr(translation_key)
		labels.append(job_key.capitalize().replace("_", " ") if translated == translation_key else translated)
	return labels

func get_rank_experience_threshold(target_rank: AdventurerRank.Rank) -> int:
	if rank_experience_thresholds == null or rank_experience_thresholds.get_point_count() == 0:
		return get_fallback_rank_experience_threshold(target_rank)
	return maxi(0, roundi(rank_experience_thresholds.sample(float(int(target_rank)))))

static func get_fallback_rank_experience_threshold(target_rank: AdventurerRank.Rank) -> int:
	var rank_index := int(target_rank)
	return rank_index * rank_index

func get_move_speed(base_move_speed: float, current_rank: AdventurerRank.Rank) -> float:
	return base_move_speed * AdventurerRank.get_speed_multiplier(current_rank, rank_move_speed_bonus_per_tier)

func get_quest_score(
	quest: Quest,
	current_rank: AdventurerRank.Rank,
	distance_in_tiles: float,
	active_traits: Array[AdventurerTraitDefinition]
) -> float:
	if quest == null:
		return 0.0
	var minimum_rank := quest.get_minimum_rank()
	var score := base_eligible_quest_score
	score += float(quest.get_rank_experience_reward()) * rank_experience_reward_weight
	score += float(quest.get_offered_currency_reward()) * offered_currency_reward_weight
	score += maxf(0.0, float(int(current_rank) - int(minimum_rank))) * rank_surplus_weight
	score -= maxf(0.0, distance_in_tiles) * distance_penalty_per_tile
	var job_keys := _get_quest_job_keys(quest)
	for job_key: String in job_keys:
		if preferred_jobs.has(job_key):
			score += preferred_job_score_bonus
		if disliked_jobs.has(job_key):
			score += disliked_job_score_penalty
	var risk_key := quest.get_effective_risk_key()
	for trait_definition: AdventurerTraitDefinition in active_traits:
		if trait_definition != null:
			score += trait_definition.get_quest_score(
				risk_key,
				job_keys,
				quest.get_offered_currency_reward()
			)
	return maxf(0.0, score)

func accepts_quest_score(score: float) -> bool:
	return score >= minimum_quest_score

func _get_quest_job_keys(quest: Quest) -> Array[String]:
	var keys: Array[String] = [quest.quest_key]
	var profile := quest.get_profile()
	if profile != null and profile.get_behaviour() != quest.quest_key:
		keys.append(profile.get_behaviour())
	return keys

func _translate_identity_label(prefix: String, value: String, empty_key: String) -> String:
	if value.is_empty():
		return tr(empty_key) if not empty_key.is_empty() else ""
	var normalized_value := value.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	var translation_key := "%s_%s" % [prefix, normalized_value]
	var translated := tr(translation_key)
	return value.capitalize().replace("_", " ") if translated == translation_key else translated

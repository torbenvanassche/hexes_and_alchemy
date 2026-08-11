class_name NpcInfo extends SceneInfo

@export var img: Texture;

@export_group("Identity")
@export var faction_id: StringName = &""
@export var profession: String = "Generalist"
@export var role: String = "Adventurer"
@export var operation_roles: Array[String] = ["adventurer"]
@export var traits: Array[String] = []
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

func get_instance() -> SceneInstance:
	var scene_instance := super.get_instance()
	if scene_instance == null:
		return null
	var npc := scene_instance.node as NPC
	if npc != null:
		npc.npc_info = self
	return scene_instance

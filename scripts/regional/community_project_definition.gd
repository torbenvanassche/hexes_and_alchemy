class_name CommunityProjectDefinition
extends Resource

@export var id := ""
@export var title_key := ""
@export var resident_name := ""
@export var resident_role_key := ""
@export_multiline var request_key := ""
@export_multiline var complete_key := ""
@export_multiline var benefit_key := ""
@export var benefits: Array[CommunityBenefit] = []
@export var objective_key := "QUEST_REQUEST_FIELDWORK"
@export var exploration_key := "QUEST_REQUEST_EXPLORE_SOURCE"
@export_group("Permanent effects")
@export var duration_site_kinds: Array[String] = []
@export var duration_behaviours: Array[String] = []
@export_range(0.1, 1.0, 0.05) var work_duration_multiplier := 1.0
@export var bonus_quest_keys: Array[String] = []
@export var bonus_items: Dictionary[ItemInfo, int] = {}
@export var crafting_item_ids: Array[String] = []
@export_range(0.1, 1.0, 0.05) var crafting_duration_multiplier := 1.0
@export_group("Project requirements")
@export var site_kind := ""
@export var commission_types: Array[String] = []
@export var materials: Dictionary[ItemInfo, int] = {}
@export var coin_cost := 20
@export var prestige_cost := 2
@export var reputation_reward := 2
@export var recipe_unlock := ""
@export var reward_items: Dictionary[ItemInfo, int] = {}
@export var blueprint: ItemInfo
@export var construction: PlaceableStructureInfo
@export var visual: PackedScene
@export var improvement_position := Vector3.ZERO
@export var improvement_scale := 0.8

func get_title() -> String:
	return tr(title_key)

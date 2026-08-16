class_name RecruitCandidate
extends RefCounted

var id: StringName
var display_name := ""
var profile: NpcInfo
var rank: AdventurerRank.Rank = AdventurerRank.Rank.F
var traits: Array[String] = []
var hire_cost := 0

func _init(
	_candidate_id: StringName = &"",
	_candidate_name: String = "",
	_candidate_profile: NpcInfo = null,
	_candidate_rank: AdventurerRank.Rank = AdventurerRank.Rank.F,
	_candidate_traits: Array[String] = [],
	_candidate_hire_cost: int = 0
) -> void:
	id = _candidate_id
	display_name = _candidate_name
	profile = _candidate_profile
	rank = _candidate_rank
	traits = _candidate_traits.duplicate()
	hire_cost = maxi(0, _candidate_hire_cost)

func get_faction_id() -> StringName:
	return profile.faction_id if profile != null else &""

func get_faction_name() -> String:
	var faction_id := get_faction_id()
	var translation_key := "FACTION_%s_NAME" % String(faction_id).to_upper()
	var translated := tr(translation_key)
	return String(faction_id).capitalize() if translated == translation_key else translated

func get_profession_name() -> String:
	return profile.profession if profile != null else tr("NPC_PROFESSION_GENERALIST")

func get_role_name() -> String:
	return profile.role if profile != null else tr("NPC_ROLE_ADVENTURER")

func get_rank_name() -> String:
	return AdventurerRank.get_display_name(rank)

func get_traits_label() -> String:
	if traits.is_empty():
		return tr("NPC_TRAITS_NONE")
	var labels: Array[String] = []
	for trait_name: String in traits:
		labels.append(trait_name.capitalize())
	return ", ".join(labels)

func get_preferred_jobs_label() -> String:
	if profile == null or profile.preferred_jobs.is_empty():
		return tr("RECRUITMENT_NO_PREFERENCES")
	var labels: Array[String] = []
	for job_key: String in profile.preferred_jobs:
		var translation_key := "QUEST_TYPE_%s" % job_key.to_upper()
		var translated := tr(translation_key)
		labels.append(job_key.capitalize().replace("_", " ") if translated == translation_key else translated)
	return ", ".join(labels)

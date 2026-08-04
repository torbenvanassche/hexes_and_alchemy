class_name GuildReputation
extends Node

## Lightweight, session-wide record of how the guild is seen and how it treats the region.
## This is deliberately independent from settlement level so future guilds can use it too.

@export var reputation: int = 0
@export var notoriety: int = 0
@export var stewardship: int = 0
@export var regional_hazard: int = 0
@export var completed_quests: int = 0
var supported_world_sites: Dictionary[String, bool] = {}

signal changed()

func record_quest(quest: Quest) -> void:
	if quest == null:
		return

	completed_quests += 1
	var profile := quest.get_profile()
	if profile != null:
		reputation += profile.guild_reputation_reward
		notoriety += profile.notoriety_reward
		stewardship += profile.stewardship_change
		regional_hazard = maxi(0, regional_hazard + profile.regional_hazard_change)
	elif quest.quest_key == "scout":
		reputation += 1
		notoriety += 1 if quest.scout_revealed_tiles >= 8 else 0
	if Manager.instance != null and Manager.instance.hub != null:
		Manager.instance.hub.add_prestige(maxi(1, profile.guild_reputation_reward) if profile != null else 1)

	_record_world_site(quest)
	_update_journal_progress(quest)
	changed.emit()

func get_summary() -> String:
	return tr("GUILD_STANDING_SUMMARY") % [reputation, notoriety]

func get_detailed_summary() -> String:
	return tr("GUILD_STANDING_DETAILS") % [
		reputation,
		notoriety,
		stewardship,
		regional_hazard,
		completed_quests,
	]

func _update_journal_progress(quest: Quest) -> void:
	if Manager.instance == null or Manager.instance.journal == null:
		return

	if quest.quest_key == "scout" and quest.scout_revealed_tiles > 0:
		Manager.instance.journal.complete_task("discover_distant_resource_region")
	if quest.quest_key == "deepen":
		Manager.instance.journal.complete_task("deepen_a_mine")
	if completed_quests >= 6:
		Manager.instance.journal.complete_task("complete_regional_contracts")
	if _has_supported_core_sources():
		Manager.instance.journal.complete_task("secure_core_resource_sources")
	if reputation >= 10:
		Manager.instance.journal.complete_task("raise_guild_reputation")
	if notoriety >= 5:
		Manager.instance.journal.complete_task("gain_guild_notoriety")
	if reputation >= 10 and Manager.instance.active_settlement != null and Manager.instance.active_settlement.level >= 3:
		Manager.instance.journal.complete_task("become_guild_authority")

func _record_world_site(quest: Quest) -> void:
	if quest.location == null or quest.location.structure == null or quest.location.structure.structure_info == null:
		return
	var structure_id := quest.location.structure.structure_info.id
	if structure_id in ["farmland", "forest", "mines", "water_source"]:
		supported_world_sites[structure_id] = true

func _has_supported_core_sources() -> bool:
	return ["farmland", "forest", "mines", "water_source"].all(
		func(structure_id: String) -> bool: return supported_world_sites.has(structure_id)
	)

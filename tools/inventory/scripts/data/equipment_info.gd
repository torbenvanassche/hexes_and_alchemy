class_name EquipmentInfo extends ItemInfo

enum Slot { WEAPON, ARMOR, TOOL, ACCESSORY }
enum Tier { STANDARD, FINE, RELIC }

@export var slot: Slot = Slot.WEAPON
@export var tier: Tier = Tier.STANDARD
@export_range(0.01, 100.0, 0.01) var reward_weight := 1.0
@export_range(0.1, 3.0, 0.05) var success_weight_multiplier := 1.0
@export_range(0.1, 3.0, 0.05) var danger_weight_multiplier := 1.0
@export_range(0.1, 3.0, 0.05) var injury_chance_multiplier := 1.0
@export_range(0.1, 3.0, 0.05) var death_chance_multiplier := 1.0
@export_range(0.25, 1.0, 0.05) var quest_duration_multiplier := 1.0
@export_range(1.0, 3.0, 0.05) var loot_quantity_multiplier := 1.0
@export_range(0, 4, 1) var scouting_radius_bonus := 0
## Empty means the outcome modifiers apply to every operation.
@export var effective_quest_types: Array[String] = []
var enchantment_names: Array[String] = []
var enchantment_seed := 0

func applies_to_quest(quest: Quest) -> bool:
	if effective_quest_types.is_empty():
		return true
	if quest == null:
		return false
	if effective_quest_types.has(quest.quest_key):
		return true
	var profile := quest.get_profile()
	return profile != null and effective_quest_types.has(profile.get_behaviour())

func get_slot_name() -> String:
	return tr("NPC_EQUIPMENT_%s" % Slot.keys()[slot])

func get_tooltip_text() -> String:
	var lines: Array[String] = [get_display_name()]
	var description := get_description()
	if not description.is_empty():
		lines.append(description)
	lines.append(tr("EQUIPMENT_SLOT_LINE") % get_slot_name())
	lines.append(tr("EQUIPMENT_TIER_LINE") % tr("EQUIPMENT_TIER_%s" % Tier.keys()[tier]))
	if not enchantment_names.is_empty():
		var translated_enchantments: Array[String] = []
		for enchantment in enchantment_names:
			translated_enchantments.append(tr("EQUIPMENT_ENCHANTMENT_%s" % enchantment.to_upper()))
		lines.append(tr("EQUIPMENT_ENCHANTMENTS_LINE") % ", ".join(translated_enchantments))
	if not is_equal_approx(success_weight_multiplier, 1.0):
		lines.append(tr("EQUIPMENT_SUCCESS_LINE") % roundi((success_weight_multiplier - 1.0) * 100.0))
	if danger_weight_multiplier < 1.0:
		lines.append(tr("EQUIPMENT_DANGER_LINE") % roundi((1.0 - danger_weight_multiplier) * 100.0))
	if injury_chance_multiplier < 1.0:
		lines.append(tr("EQUIPMENT_INJURY_LINE") % roundi((1.0 - injury_chance_multiplier) * 100.0))
	if death_chance_multiplier < 1.0:
		lines.append(tr("EQUIPMENT_DEATH_LINE") % roundi((1.0 - death_chance_multiplier) * 100.0))
	if quest_duration_multiplier < 1.0:
		lines.append(tr("EQUIPMENT_DURATION_LINE") % roundi((1.0 - quest_duration_multiplier) * 100.0))
	if loot_quantity_multiplier > 1.0:
		lines.append(tr("EQUIPMENT_LOOT_LINE") % roundi((loot_quantity_multiplier - 1.0) * 100.0))
	if scouting_radius_bonus > 0:
		lines.append(tr("EQUIPMENT_SCOUTING_LINE") % scouting_radius_bonus)
	if not effective_quest_types.is_empty():
		var labels: Array[String] = []
		for quest_type in effective_quest_types:
			var key := "QUEST_TYPE_%s" % quest_type.to_upper()
			var translated := tr(key)
			labels.append(quest_type.capitalize() if translated == key else translated)
		lines.append(tr("EQUIPMENT_EFFECTIVE_FOR_LINE") % ", ".join(labels))
	return "\n".join(lines)

func get_reward_weight() -> float:
	return maxf(0.01, reward_weight)

func create_randomized_relic() -> EquipmentInfo:
	var result := duplicate(true) as EquipmentInfo
	if result == null or result.tier != Tier.RELIC:
		return result
	result.resource_local_to_scene = true
	result.randomize_relic_effects()
	return result

func randomize_relic_effects() -> void:
	if tier != Tier.RELIC:
		return
	if not has_meta("relic_base_stats"):
		set_meta("relic_base_stats", {
			"unique_id": unique_id,
			"success": success_weight_multiplier,
			"danger": danger_weight_multiplier,
			"injury": injury_chance_multiplier,
			"death": death_chance_multiplier,
			"duration": quest_duration_multiplier,
			"loot": loot_quantity_multiplier,
			"scouting": scouting_radius_bonus,
		})
	var base: Dictionary = get_meta("relic_base_stats")
	success_weight_multiplier = float(base.success)
	danger_weight_multiplier = float(base.danger)
	injury_chance_multiplier = float(base.injury)
	death_chance_multiplier = float(base.death)
	quest_duration_multiplier = float(base.duration)
	loot_quantity_multiplier = float(base.loot)
	scouting_radius_bonus = int(base.scouting)
	enchantment_names.clear()
	enchantment_seed = randi()
	var options := ["precise", "warding", "protective", "life_bound", "swift", "prosperous", "far_seeing"]
	options.shuffle()
	for option: String in options.slice(0, 2):
		var strength := randf_range(0.06, 0.14)
		match option:
			"precise": success_weight_multiplier *= 1.0 + strength
			"warding": danger_weight_multiplier *= 1.0 - strength
			"protective": injury_chance_multiplier *= 1.0 - strength
			"life_bound": death_chance_multiplier *= 1.0 - strength
			"swift": quest_duration_multiplier *= 1.0 - strength
			"prosperous": loot_quantity_multiplier *= 1.0 + strength
			"far_seeing": scouting_radius_bonus += 1
		enchantment_names.append(option)
	unique_id = "%s_enchanted_%s" % [str(base.unique_id), enchantment_seed]
	emit_changed()

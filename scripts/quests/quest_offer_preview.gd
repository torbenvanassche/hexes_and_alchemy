class_name QuestOfferPreview
extends RefCounted

class ScoutSurvey extends RefCounted:
	var day: int
	var minute: int
	var night: bool
	var radius: int

var scout_route := PackedVector2Array()
var scout_name := ""
var scout_round_trip_seconds := 0
var lines: PackedStringArray = []
var provider_names: PackedStringArray = []
var _scout: NPC
var _scout_travel_seconds := 0.0

static func create(quest: Quest, manager: QuestManager) -> QuestOfferPreview:
	var result := QuestOfferPreview.new()
	if quest == null or quest.location == null: return result
	var is_scout := quest.quest_key == "scout"
	var profile := quest.get_profile()
	var objective := quest.get_objective()
	var supplies: Dictionary[ItemInfo, int] = {}
	if objective != null: supplies = objective.get_required_supplies(quest.quest_key)
	var material_value := 0
	for item: ItemInfo in supplies: material_value += item.get_sell_value() * int(supplies[item])
	if not is_scout or quest.offered_currency_reward > 0:
		result.lines.append(TranslationServer.translate("OFFER_BUDGET") % [quest.offered_currency_reward, material_value, profile.guild_currency_reward if profile != null else 0])
	var available_for_assignment: Array[NPC] = []
	var role := Manager.instance.hub.get_required_role_for_quest(quest)
	for home: FactionHome in manager._get_active_roster_homes():
		for instance: SceneInstance in home.get_roster_npcs():
			var npc := instance.node as NPC
			if npc == null or not npc.can_perform_role(role): continue
			var reason := ""
			if not npc.is_rank_at_least(quest.get_minimum_rank()): reason = TranslationServer.translate("OFFER_RANK")
			elif npc.current_quest != null: reason = TranslationServer.translate("OFFER_ASSIGNED")
			elif not npc.is_available_for_quest(): reason = TranslationServer.translate("OFFER_RECOVERING")
			elif objective != null and not objective.has_required_supplies(quest.quest_key, Manager.instance.hub.stockpile): reason = TranslationServer.translate("QUEST_POST_MISSING_SUPPLIES")
			elif not npc.wants_quest(quest):
				var pay := _minimum_pay(npc, quest)
				reason = TranslationServer.translate("OFFER_WAGE") % pay if pay >= 0 else TranslationServer.translate("OFFER_UNINTERESTED")
			else:
				available_for_assignment.append(npc)
				reason = TranslationServer.translate("OFFER_READY")
			result.provider_names.append("%s: %s" % [npc.get_display_name(), reason])
	if result.provider_names.is_empty(): result.provider_names.append(TranslationServer.translate("OFFER_RECRUIT"))
	result.lines.append("
".join(result.provider_names))
	var assignment := QuestPartyPlanner.build(quest, available_for_assignment)
	if assignment == null:
		result.lines.append(TranslationServer.translate("OFFER_WILL_WAIT"))
		return result
	quest.party.assign(assignment.members)
	quest.primary_member = assignment.primary
	quest.support_members.assign(assignment.supports)
	if objective != null:
		var output := PackedStringArray()
		var bonus := Manager.instance.regional.reward_bonus(DiscoveryRandomizer.get_kind(objective), quest.quest_key)
		var ranges := objective.get_quest_profile_reward_preview(quest.quest_key)
		for entry: RewardPreview in ranges:
			var extra := int(bonus.get(entry.item, 0))
			var multiplier := 1.0 if entry.item is EquipmentInfo else quest.get_loot_quantity_multiplier()
			output.append("%s %d–%d" % [entry.item.get_display_name(), floori((entry.minimum + extra) * multiplier), ceili((entry.maximum + extra) * multiplier)])
		if not output.is_empty(): result.lines.append(TranslationServer.translate("OFFER_OUTPUT") % ", ".join(output))
	var work := objective.get_effective_quest_duration(quest, 0.0) if objective != null else 0.0
	var travel := 0.0
	var rest := 0.0
	var grid := Manager.instance.transport.get_grid()
	for npc: NPC in assignment.members:
		var start := grid.get_hex_at_world_position(npc.global_position) if grid != null else null
		var path := npc.get_quest_route(grid, start, quest.location)
		if path.is_empty():
			result.lines.append(TranslationServer.translate("SHIPMENT_NO_ROUTE"))
			return result
		if is_scout and npc == assignment.primary:
			for tile: HexBase in path:
				result.scout_route.append(Vector2(tile.global_position.x, tile.global_position.z))
		var distance := 0.0
		var previous := Vector2(npc.global_position.x, npc.global_position.z)
		for index in range(1, path.size()):
			var position := path[index].global_position
			var next := Vector2(position.x, position.z)
			distance += previous.distance_to(next)
			previous = next
		var seconds := distance / maxf(0.1, npc.get_effective_move_speed())
		travel = maxf(travel, seconds)
		var rules := npc.recovery_rules if npc.recovery_rules != null else AdventurerRecoveryRules.new()
		var estimate := rules.base_rest_seconds + (profile.duration_seconds if profile != null else 0.0) * rules.quest_duration_rest_multiplier
		if quest.get_effective_risk_key() == "QUEST_RISK_DANGEROUS": estimate *= rules.dangerous_quest_rest_multiplier
		elif quest.get_effective_risk_key() == "QUEST_RISK_UNCERTAIN": estimate *= rules.uncertain_quest_rest_multiplier_max
		rest = maxf(rest, minf(rules.maximum_rest_seconds, estimate))
	if is_scout:
		result._scout = assignment.primary
		result._scout_travel_seconds = travel
		result.scout_name = assignment.primary.get_display_name()
		result.scout_round_trip_seconds = ceili(travel * 2.0)
	else:
		result.lines.append(TranslationServer.translate("OFFER_TIMING") % [ceili(travel), ceili(work), ceili(travel), ceili(rest), ceili(travel * 2.0 + work + rest)])
	return result

func get_scout_survey(clock: TimeOfDay, depart_at_dawn: bool) -> ScoutSurvey:
	if not is_instance_valid(_scout):
		return null
	var departure := clock.get_elapsed_seconds()
	if depart_at_dawn:
		departure = clock.get_dawn_time(clock.get_day_number() + 1)
	var survey_time := departure + _scout_travel_seconds
	var phase := clock.get_phase_at(survey_time)
	var result := ScoutSurvey.new()
	result.day = clock.get_day_at(survey_time)
	result.minute = clock.get_clock_minutes_at(survey_time)
	result.night = phase != null and phase.phase == TimeOfDay.Phase.NIGHT
	result.radius = _scout.get_scouting_radius(result.night)
	return result

static func _minimum_pay(npc: NPC, quest: Quest) -> int:
	var original := quest.offered_currency_reward
	var low := original
	var high := 1000
	quest.offered_currency_reward = high
	if not npc.wants_quest(quest):
		quest.offered_currency_reward = original
		return -1
	while low < high:
		var middle := floori(float(low + high) / 2.0)
		quest.offered_currency_reward = middle
		if npc.wants_quest(quest): high = middle
		else: low = middle + 1
	quest.offered_currency_reward = original
	return low

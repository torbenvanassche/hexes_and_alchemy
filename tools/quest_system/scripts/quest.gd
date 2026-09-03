class_name Quest extends Resource

enum QuestState {
	WAITING,
	EN_ROUTE,
	IN_PROGRESS,
	RETURNING,
	COMPLETE,
	FAILED,
	CANCELLED
}

var quest_key: String;
var supplies: ContentGroup;
var location: HexBase;
var offered_currency_reward: int = 0;
var minimum_rank_override: int = -1;
var rank_experience_reward: int = 1;
var scout_revealed_tiles: int = 0
var scout_discovered_structures: Dictionary[String, int] = {}
var outcome: QuestOutcome
var context: Dictionary = {}

var state_machine: StateMachine;

var party: Array[NPC] = []
var primary_member: NPC
var support_members: Dictionary[StringName, NPC] = {}
var party_fates: Dictionary[int, int] = {}

signal completed();
signal outcome_ready(resolved_outcome: QuestOutcome)
signal failed(reason_key: String)
signal cancelled(reason_key: String)

func _init(
	_location: HexBase = null,
	_type_key: String = "",
	_offered_currency_reward: int = 0,
	_minimum_rank_override: int = -1,
	_rank_experience_reward: int = -1
) -> void:
	self.location = _location;
	self.quest_key = _type_key;
	self.offered_currency_reward = maxi(0, _offered_currency_reward);
	self.minimum_rank_override = _minimum_rank_override;
	self.rank_experience_reward = _resolve_rank_experience_reward(_rank_experience_reward);
	supplies = ContentGroup.new();
	if quest_key == "scout":
		outcome = ScoutingQuestOutcome.new()
	
	var states: Array[String] = []
	for s in QuestState.keys():
		states.append(get_state_as_string(QuestState[s]));
	state_machine = StateMachine.new(states);
	set_state(QuestState.WAITING);
	
func is_state(state: QuestState) -> bool:
	return get_state_as_string(state) == state_machine.get_current_state();
	
func add_supply(item: Resource, amount: int = 1) -> int:
	return supplies.add(item, amount, true);
	
func add_to_party(npc: NPC, support_id: StringName = &"") -> bool:
	if npc == null or party.has(npc) or not is_state(QuestState.WAITING) or not npc.is_available_for_quest():
		return false
	party.append(npc);
	if support_id == &"" and primary_member == null:
		primary_member = npc
	elif support_id != &"":
		support_members[support_id] = npc
	npc.assign_quest(self);
	return true

func clear_party_assignments() -> void:
	party.clear()
	primary_member = null
	support_members.clear()

func set_selected_support_ids(ids: Array[String]) -> void:
	var selected: Array[String] = []
	for support_id: String in ids:
		if support_id != "" and not selected.has(support_id):
			selected.append(support_id)
	context["selected_support_ids"] = selected

func get_selected_support_ids() -> Array[String]:
	var selected: Array[String] = []
	var stored: Array = context.get("selected_support_ids", [])
	for value in stored:
		var support_id := str(value)
		if support_id != "" and not selected.has(support_id):
			selected.append(support_id)
	return selected

func has_selected_support(support_id: StringName) -> bool:
	return get_selected_support_ids().has(str(support_id))

func get_selected_support_definitions() -> Array[QuestSupportDefinition]:
	var selected: Array[QuestSupportDefinition] = []
	var profile := get_profile()
	if profile == null:
		return selected
	var selected_ids := get_selected_support_ids()
	for definition: QuestSupportDefinition in profile.get_optional_supports():
		if definition != null and selected_ids.has(str(definition.id)):
			selected.append(definition)
	return selected

func get_danger_weight_multiplier() -> float:
	var multiplier := 1.0
	for definition: QuestSupportDefinition in get_selected_support_definitions():
		multiplier *= maxf(0.0, definition.danger_weight_multiplier)
	for npc in party:
		if npc != null and is_instance_valid(npc):
			multiplier *= npc.get_equipment_danger_multiplier(self)
	return multiplier

func get_success_weight_multiplier() -> float:
	var multiplier := 1.0
	for npc in party:
		if npc != null and is_instance_valid(npc):
			multiplier *= npc.get_equipment_success_multiplier(self)
	return multiplier

func get_duration_multiplier() -> float:
	var multiplier := INF
	for npc in party:
		if npc != null and is_instance_valid(npc):
			multiplier = minf(multiplier, npc.get_equipment_duration_multiplier(self))
	return 1.0 if is_inf(multiplier) else multiplier

func get_loot_quantity_multiplier() -> float:
	var multiplier := 0.0
	for npc in party:
		if npc != null and is_instance_valid(npc):
			multiplier = maxf(multiplier, npc.get_equipment_loot_multiplier(self))
	return 1.0 if multiplier <= 0.0 else multiplier

func apply_loot_quantity_multiplier(rewards: Dictionary[ItemInfo, int]) -> Dictionary[ItemInfo, int]:
	if quest_key == QuestObjective.RECOVER_EQUIPMENT_QUEST_KEY:
		return rewards.duplicate()
	var adjusted: Dictionary[ItemInfo, int] = {}
	var multiplier := get_loot_quantity_multiplier()
	for item: ItemInfo in rewards.keys():
		var base_amount := maxi(0, int(rewards[item]))
		if item is EquipmentInfo:
			adjusted[item] = base_amount
			continue
		var scaled_amount := float(base_amount) * multiplier
		var amount := floori(scaled_amount)
		if randf() < scaled_amount - float(amount):
			amount += 1
		if amount > 0:
			adjusted[item] = amount
	return adjusted

func get_effective_risk_key() -> String:
	var profile := get_profile()
	if profile == null:
		return ""
	var risk_key := profile.risk_key
	var objective := get_objective()
	if objective != null and objective.has_occupation() and objective.is_occupation_revealed():
		risk_key = "QUEST_RISK_DANGEROUS"
	for definition: QuestSupportDefinition in get_selected_support_definitions():
		if definition.risk_key_when_selected != "":
			risk_key = definition.risk_key_when_selected
	if outcome != null and outcome.is_dangerous:
		risk_key = "QUEST_RISK_DANGEROUS"
	return risk_key
		
func get_state_as_string(state: QuestState) -> String:
	return QuestState.keys()[state].to_lower();

func get_objective() -> QuestObjective:
	if location == null or location.structure == null:
		return null
	return location.structure.instance as QuestObjective

func get_minimum_rank() -> AdventurerRank.Rank:
	if minimum_rank_override >= 0:
		return AdventurerRank.clamp_rank(minimum_rank_override)
	var objective := get_objective()
	if objective == null:
		return AdventurerRank.Rank.F
	return objective.get_quest_minimum_rank(quest_key)

func get_rank_experience_reward() -> int:
	return rank_experience_reward

func _resolve_rank_experience_reward(explicit_reward: int) -> int:
	if explicit_reward >= 0:
		return maxi(0, explicit_reward)

	var objective := get_objective()
	if objective == null:
		return 1
	return objective.get_quest_rank_experience_reward(quest_key, minimum_rank_override)

func get_offered_currency_reward() -> int:
	return offered_currency_reward

func get_profile() -> QuestProfile:
	var objective := get_objective()
	return objective.get_profile(quest_key) if objective != null else null

func record_scouted_hex(hex: HexBase) -> void:
	if quest_key != "scout" or hex == null:
		return
	var scouting_outcome := outcome as ScoutingQuestOutcome
	if scouting_outcome == null:
		scouting_outcome = ScoutingQuestOutcome.new()
		outcome = scouting_outcome
	scouting_outcome.record_hex(hex)

func start() -> void:
	for npc in party.duplicate():
		if not npc.arrived.is_connected(_check_party_arrived_at_quest):
			npc.arrived.connect(_check_party_arrived_at_quest, CONNECT_ONE_SHOT);
		if not npc.movement_failed.is_connected(_on_party_movement_failed):
			npc.movement_failed.connect(_on_party_movement_failed, CONNECT_ONE_SHOT);
		npc.set_state(NPC.NPCState.MOVING_TO_QUEST);
		if party.is_empty():
			break
	if party.is_empty():
		return
	set_state(QuestState.EN_ROUTE);
	
func set_state(state: QuestState) -> void:
	state_machine.set_state(get_state_as_string(state));
	
func _check_party_arrived_at_quest() -> void:
	if party.all(func(n: NPC) -> bool: return n.is_state(NPC.NPCState.AT_QUEST)):
		for npc in party:
			if npc != null and npc.movement_failed.is_connected(_on_party_movement_failed):
				npc.movement_failed.disconnect(_on_party_movement_failed)
		if quest_key == "scout":
			set_state(QuestState.IN_PROGRESS);
			return_from_quest()
			return
		var objective := get_objective()
		if objective == null:
			Debug.warn("Quest '%s' no longer has a valid objective." % [quest_key])
			_fail("QUEST_FAILED_MISSING_OBJECTIVE")
			return
		if not objective.quest_has_required_supplies(self):
			Debug.warn("Quest '%s' is missing its required supplies." % [quest_key])
			_fail("QUEST_FAILED_MISSING_SUPPLIES")
			return
		if quest_key == QuestObjective.RECOVER_EQUIPMENT_QUEST_KEY:
			objective.execute_recovery_quest(self)
		else:
			objective.execute_quest(self);
		set_state(QuestState.IN_PROGRESS);
		
func return_completed() -> void:
	if party.all(func(n: NPC) -> bool: return n.is_state(NPC.NPCState.DONE)):
		_resolve_return_outcome()
		set_state(QuestState.COMPLETE);

func _on_party_movement_failed(_failed_npc: NPC) -> void:
	for npc in party:
		if npc != null and npc.movement_failed.is_connected(_on_party_movement_failed):
			npc.movement_failed.disconnect(_on_party_movement_failed)
		if npc != null and npc.arrived.is_connected(_check_party_arrived_at_quest):
			npc.arrived.disconnect(_check_party_arrived_at_quest)
		if npc != null:
			npc.cancel_assigned_quest(self)
	if Manager.instance != null and Manager.instance.quests != null:
		Manager.instance.quests.release_quest_supplies(self)
	clear_party_assignments()
	set_state(QuestState.WAITING)
	if Manager.instance != null and Manager.instance.quests != null:
		Manager.instance.quests.quest_list_changed.emit()
		
func return_from_quest() -> void:
	set_state(QuestState.RETURNING);
	for npc in party:
		if not npc.arrived.is_connected(return_completed):
			npc.arrived.connect(return_completed, CONNECT_ONE_SHOT);
		npc.set_state(NPC.NPCState.RETURNING);

func mark_failed(reason_key: String) -> void:
	if is_state(QuestState.COMPLETE) or is_state(QuestState.FAILED) or is_state(QuestState.CANCELLED):
		return
	context["failure_reason_key"] = reason_key
	set_state(QuestState.FAILED)
	failed.emit(reason_key)

func mark_cancelled(reason_key: String = "QUEST_CANCELLED") -> void:
	if is_state(QuestState.COMPLETE) or is_state(QuestState.FAILED) or is_state(QuestState.CANCELLED):
		return
	context["failure_reason_key"] = reason_key
	set_state(QuestState.CANCELLED)
	cancelled.emit(reason_key)

func _fail(reason_key: String) -> void:
	if Manager.instance != null and Manager.instance.quests != null:
		Manager.instance.quests.fail_quest(self, reason_key)
	else:
		mark_failed(reason_key)
	
func parse_reward() -> void:
	if context.get("reward_claimed", false) or not is_state(QuestState.COMPLETE):
		return
	_resolve_return_outcome()
	if outcome != null and not outcome.is_applied():
		return
	var objective := get_objective()
	var earned_rank_experience := get_rank_experience_reward()
	if objective != null:
		if quest_key == QuestObjective.RECOVER_EQUIPMENT_QUEST_KEY:
			objective.complete_recovery_quest(self)
		else:
			objective.complete_quest(self);
	var valid_party: Array[NPC] = []
	for npc: NPC in party:
		if npc != null and is_instance_valid(npc):
			valid_party.append(npc)
	_resolve_party_fates()
	var survivors: Array[NPC] = []
	for npc in valid_party:
		if _get_party_fate(npc) == NPC.QuestFate.DEAD:
			npc.die_after_quest(self)
		else:
			survivors.append(npc)
	var payment_per_member := floori(float(offered_currency_reward) / float(survivors.size())) if not survivors.is_empty() else 0
	var payment_remainder := offered_currency_reward % survivors.size() if not survivors.is_empty() else 0
	for index in survivors.size():
		var npc := survivors[index]
		var payment := payment_per_member + (1 if index < payment_remainder else 0)
		npc.complete_assigned_quest(self, earned_rank_experience, payment, _get_party_fate(npc) == NPC.QuestFate.INJURED)
	if Manager.instance != null and Manager.instance.reputation != null:
		Manager.instance.reputation.record_quest(self)
	context["reward_resolved"] = true
	context["reward_claimed"] = true
	context["reward_reserved"] = false
	context["supplies_reserved"] = false
	if Manager.instance != null and Manager.instance.quests != null:
		Manager.instance.quests.remove_quest(self);
	completed.emit();

func _resolve_return_outcome() -> void:
	if outcome == null or outcome.is_applied():
		return
	outcome.apply(self)
	if not outcome.is_applied():
		return
	_resolve_party_fates()
	if outcome is ScoutingQuestOutcome:
		var scouting_outcome := outcome as ScoutingQuestOutcome
		scout_revealed_tiles = scouting_outcome.get_revealed_tile_count()
		scout_discovered_structures = scouting_outcome.get_discovered_structure_counts()
	outcome_ready.emit(outcome)

func _resolve_party_fates() -> void:
	if outcome == null or not outcome.is_applied() or not party_fates.is_empty():
		return
	for npc in party:
		if npc == null or not is_instance_valid(npc):
			continue
		var fate := npc.roll_quest_fate(self)
		party_fates[npc.get_instance_id()] = int(fate)
		if fate == NPC.QuestFate.DEAD:
			outcome.append_summary(tr("QUEST_MEMBER_DIED") % npc.get_display_name())
		elif fate == NPC.QuestFate.INJURED:
			outcome.append_summary(tr("QUEST_MEMBER_INJURED") % npc.get_display_name())

func _get_party_fate(npc: NPC) -> NPC.QuestFate:
	if npc == null:
		return NPC.QuestFate.UNHARMED
	return int(party_fates.get(npc.get_instance_id(), int(NPC.QuestFate.UNHARMED))) as NPC.QuestFate

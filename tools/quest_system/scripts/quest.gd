class_name Quest extends Resource

enum QuestState {
	WAITING,
	EN_ROUTE,
	IN_PROGRESS,
	RETURNING,
	COMPLETE
}

var quest_key: String;
var supplies: ContentGroup;
var location: HexBase;
var offered_currency_reward: int = 0;
var minimum_rank_override: int = -1;
var rank_experience_reward: int = 1;

var state_machine: StateMachine;

var party: Array[NPC] = []

signal completed();

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
	
	var states: Array[String] = []
	for s in QuestState.keys():
		states.append(get_state_as_string(QuestState[s]));
	state_machine = StateMachine.new(states);
	set_state(QuestState.WAITING);
	
func is_state(state: QuestState) -> bool:
	return get_state_as_string(state) == state_machine.get_current_state();
	
func add_supply(item: Resource, amount: int = 1) -> void:
	supplies.add(item, amount, true);
	
func add_to_party(npc: NPC) -> void:
	if not party.has(npc):
		npc.assign_quest(self);
		party.append(npc);
		
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

func start() -> void:
	for npc in party:
		npc.arrived.connect(_check_party_arrived_at_quest, CONNECT_ONE_SHOT);
		npc.set_state(NPC.NPCState.MOVING_TO_QUEST);
	set_state(QuestState.EN_ROUTE);
	
func set_state(state: QuestState) -> void:
	state_machine.set_state(get_state_as_string(state));
	
func _check_party_arrived_at_quest() -> void:
	if party.all(func(n: NPC) -> bool: return n.is_state(NPC.NPCState.AT_QUEST)):
		var objective := location.structure.instance as QuestObjective
		if objective == null:
			return
		if not objective.quest_has_required_supplies(self):
			Debug.warn("Quest '%s' is missing its required supplies." % [quest_key])
			return_from_quest()
			return
		objective.execute_quest(self);
		set_state(QuestState.IN_PROGRESS);
		
func return_completed() -> void:
	if party.all(func(n: NPC) -> bool: return n.is_state(NPC.NPCState.DONE)):
		set_state(QuestState.COMPLETE);
		
func return_from_quest() -> void:
	set_state(QuestState.RETURNING);
	for npc in party:
		npc.arrived.connect(return_completed, CONNECT_ONE_SHOT);
		npc.set_state(NPC.NPCState.RETURNING);
	
func parse_reward() -> void:
	var objective := get_objective()
	var rank_experience_reward := get_rank_experience_reward()
	if objective != null:
		objective.complete_quest(self);
	for npc in party:
		if npc != null:
			npc.complete_assigned_quest(self, rank_experience_reward)
	Manager.instance.quests.remove_quest(self);
	completed.emit();

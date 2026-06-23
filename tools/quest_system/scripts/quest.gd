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

var state_machine: StateMachine;

var party: Array[NPC];

signal completed();

func _init(_location: HexBase = null, _type_key: String = "") -> void:
	self.location = _location;
	self.quest_key = _type_key;
	supplies = ContentGroup.new();
	
	var states: Array[String];
	for s in QuestState.keys():
		states.append(get_state_as_string(QuestState[s]));
	state_machine = StateMachine.new(states);
	set_state(QuestState.WAITING);
	
func is_state(state: QuestState) -> bool:
	return get_state_as_string(state) == state_machine.get_current_state();
	
func add_supply(resource: ContentSlotResource) -> void:
	supplies.add(resource);
	
func add_to_party(npc: NPC) -> void:
	if not party.has(npc):
		npc.assign_quest(self);
		party.append(npc);
		
func get_state_as_string(state: QuestState) -> String:
	return QuestState.keys()[state].to_lower();

func start() -> void:
	for npc in party:
		npc.arrived.connect(_check_party_arrived_at_quest, CONNECT_ONE_SHOT);
		npc.set_state(NPC.NPCState.MOVING_TO_QUEST);
	set_state(QuestState.EN_ROUTE);
	
func set_state(state: QuestState) -> void:
	state_machine.set_state(get_state_as_string(state));
	
func _check_party_arrived_at_quest() -> void:
	if party.all(func(n: NPC) -> bool: return n.is_state(NPC.NPCState.AT_QUEST)):
		location.structure.instance.execute_quest(self);
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
	location.structure.instance.complete_quest(self);
	Config.gamestate.remove_quest(self);
	completed.emit();

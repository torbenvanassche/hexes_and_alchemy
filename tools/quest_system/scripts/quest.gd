class_name Quest extends Resource

enum Type {
	FETCH,
	SLAY
}

enum QuestState {
	WAITING,
	EN_ROUTE,
	IN_PROGRESS,
	RETURNING,
	COMPLETE
}

var quest_type: Type;
var supplies: ContentGroup;
var location: HexBase;

var state_machine: StateMachine;

var party: Array[NPC];

signal completed();

func _init(_location: HexBase = null, _type: Type = Type.FETCH, _supplies: ContentGroup = ContentGroup.new()) -> void:
	self.quest_type = _type;
	self.supplies = _supplies;
	self.location = _location;
	
	var states: Array[String];
	for s in QuestState.keys():
		states.append(get_state_as_string(QuestState[s]))
	state_machine = StateMachine.new(states);
	set_state(QuestState.WAITING)
	
func is_state(state: QuestState) -> bool:
	return get_state_as_string(state) == state_machine.get_current_state();
	
func add_supply(resource: ContentSlotResource) -> void:
	supplies.add(resource)
	
func add_to_party(npc: NPC) -> void:
	if not party.has(npc):
		party.append(npc);
		
func get_state_as_string(state: QuestState) -> String:
	var words: PackedStringArray = QuestState.keys()[state].to_lower().split("_")
	for i in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)

func start() -> void:
	for npc in party:
		npc.move_to_quest();
		npc.arrived.connect(_check_party_arrived_at_quest, CONNECT_ONE_SHOT)
	set_state(QuestState.EN_ROUTE)
	
func set_state(state: QuestState) -> void:
	state_machine.set_state(get_state_as_string(state))
	
func _check_party_arrived_at_quest() -> void:
	if party.all(func(n: NPC) -> bool: return n.at_quest):
		location.structure.instance.execute_quest(self);
		set_state(QuestState.IN_PROGRESS)
		
func return_completed() -> void:
	if party.all(func(n: NPC) -> bool: return n.at_home):
		set_state(QuestState.COMPLETE)
		
func return_from_quest() -> void:
	set_state(QuestState.RETURNING)
	for npc in party:
		npc.arrived.connect(return_completed, CONNECT_ONE_SHOT)
		npc.return_home()
	
func parse_reward() -> void:
	location.structure.instance.complete_quest(self);
	completed.emit();

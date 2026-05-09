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

var status: QuestState;
var progress: float;

var party: Array[NPC];

signal update_status();

func _init(_location: HexBase = null, _type: Type = Type.FETCH, _supplies: ContentGroup = ContentGroup.new()) -> void:
	self.quest_type = _type;
	self.supplies = _supplies;
	self.location = _location;
	
func _ready() -> void:
	update_status.connect(func() -> void: Debug.message(get_state_as_string()))
	
func add_supply(resource: ContentSlotResource) -> void:
	supplies.add(resource)
	
func add_to_party(npc: NPC) -> void:
	if not party.has(npc):
		party.append(npc);
		
func get_state_as_string() -> String:
	var words: PackedStringArray = QuestState.keys()[status].to_lower().split("_")
	
	for i in range(words.size()):
		words[i] = words[i].capitalize()
		
	return " ".join(words)

func start() -> void:
	status = QuestState.EN_ROUTE;
	for npc in party:
		npc.move_to_quest();
		npc.arrived_at_quest.connect(_check_party_arrived)
	update_status.emit();
	
func update(state: QuestState) -> void:
	status = state;
	update_status.emit();
	
func _check_party_arrived() -> void:
	if party.all(func(n: NPC) -> bool: return n.on_location):
		location.structure.instance.execute_quest(self);
		update(QuestState.IN_PROGRESS)
	
func parse_reward() -> void:
	location.structure.instance.complete_quest(self);

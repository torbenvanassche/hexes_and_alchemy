class_name Tavern extends SettlementService

@export var adventurer: SceneInfo;
@export var adventurer_spawn: Node3D;
@onready var spawn_interval: Timer = $spawn_interval
var buildable_structure: Buildable;

var npcs: Array[SceneInstance];

func _ready() -> void:
	super()
	Config.gamestate.quest_list_changed.connect(spawn_interval.start)
	spawn_interval.timeout.connect(adventurer.queue.bind(_adventurer_ready))
	buildable_structure = get_parent() as Buildable;

func interact() -> void:
	pass

func can_interact() -> bool:
	return buildable_structure && buildable_structure.current_step == self;
	
func _adventurer_ready(s: SceneInfo) -> void:
	if not can_interact() || npcs.size() >= Config.gamestate.max_npc_per_tavern:
		return;
	var instance := SceneManager.add(s);
	instance.node.global_position = adventurer_spawn.global_position;
	instance.node.tree_exiting.connect(npcs.erase.bind(instance))
	npcs.append(instance);
	Config.gamestate.try_assign_waiting_quests()
	
func get_available_npcs() -> Array[SceneInstance]:
	return npcs.filter(func(x: SceneInstance) -> bool: return (x.node as NPC).current_quest == null);

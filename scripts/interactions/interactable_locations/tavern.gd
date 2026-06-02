class_name Tavern extends Interaction

@export var adventurer: SceneInfo;
@export var adventurer_spawn: Node3D;
@onready var spawn_interval: Timer = $spawn_interval
var buildable_structure: Buildable;

func _ready() -> void:
	Config.gamestate.quest_list_changed.connect(spawn_interval.start)
	spawn_interval.timeout.connect(adventurer.queue.bind(_adventurer_ready))
	buildable_structure = get_parent() as Buildable;

func interact() -> void:
	pass

func can_interact() -> bool:
	return buildable_structure && buildable_structure.current_step == self;
	
func _adventurer_ready(s: SceneInfo) -> void:
	if not can_interact() || Config.gamestate.active_quests.size() != 0:
		return;
	
	var instance := SceneManager.add(s);
	instance.node.global_position = adventurer_spawn.global_position;
	(instance.node as NPC).assign_quest()

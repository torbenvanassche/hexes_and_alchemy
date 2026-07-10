class_name Tavern extends SettlementService

@export var adventurer: SceneInfo;
@export var adventurer_spawn: Node3D;
@export_range(0, 10, 1) var starting_adventurer_count := 2
@onready var spawn_interval: Timer = $spawn_interval
var buildable_structure: Buildable;

var npcs: Array[SceneInstance] = []

signal npc_roster_changed()

func _ready() -> void:
	super()
	Manager.instance.quests.quest_list_changed.connect(spawn_interval.start)
	spawn_interval.timeout.connect(adventurer.queue.bind(_adventurer_ready))
	buildable_structure = get_parent() as Buildable;
	_spawn_starting_adventurers.call_deferred()

func interact() -> void:
	open_additional_ui_windows()

func can_interact() -> bool:
	return buildable_structure == null or buildable_structure.current_step == self;
	
func _adventurer_ready(s: SceneInfo) -> void:
	_create_adventurer(s)

func _create_adventurer(s: SceneInfo) -> SceneInstance:
	if not can_interact() or npcs.size() >= Manager.instance.quests.max_npc_per_tavern:
		return null
	if s == null or adventurer_spawn == null:
		return null
	var npc_scene_instance := SceneManager.add(s)
	if npc_scene_instance == null:
		return null
	npc_scene_instance.node.global_position = adventurer_spawn.global_position
	npc_scene_instance.node.tree_exiting.connect(_remove_adventurer.bind(npc_scene_instance))
	npcs.append(npc_scene_instance)
	Manager.instance.quests.try_assign_waiting_quests()
	npc_roster_changed.emit()
	return npc_scene_instance

func get_available_npcs() -> Array[SceneInstance]:
	return get_roster_npcs().filter(func(x: SceneInstance) -> bool: return (x.node as NPC).current_quest == null);

func get_roster_npcs() -> Array[SceneInstance]:
	return npcs.filter(func(x: SceneInstance) -> bool:
		return x != null and is_instance_valid(x.node) and x.node is NPC
	)

func _spawn_starting_adventurers() -> void:
	if starting_adventurer_count <= 0:
		return;
	adventurer.queue(_spawn_starting_adventurers_ready)

func _spawn_starting_adventurers_ready(s: SceneInfo) -> void:
	for i in starting_adventurer_count:
		if npcs.size() >= Manager.instance.quests.max_npc_per_tavern:
			return
		_create_adventurer(s)

func _remove_adventurer(npc_scene_instance: SceneInstance) -> void:
	npcs.erase(npc_scene_instance)
	npc_roster_changed.emit()

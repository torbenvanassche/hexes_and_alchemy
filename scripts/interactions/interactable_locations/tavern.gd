class_name Tavern extends SettlementService

@export var adventurer: SceneInfo;
@export var adventurer_spawn: Node3D;
@export_group("Starting Roster")
@export var starting_npc_profiles: Array[NpcInfo] = []
@export_range(0, 10, 1) var starting_random_npc_count := 0
@onready var spawn_interval: Timer = $spawn_interval
var buildable_structure: Buildable;

var npcs: Array[SceneInstance] = []

signal npc_roster_changed()

func _ready() -> void:
	super()
	if spawn_interval != null and not spawn_interval.timeout.is_connected(_spawn_random_adventurer):
		spawn_interval.timeout.connect(_spawn_random_adventurer)
	buildable_structure = get_parent() as Buildable;
	_spawn_starting_adventurers.call_deferred()

func interact() -> void:
	open_additional_ui_windows()

func can_interact() -> bool:
	return buildable_structure == null or buildable_structure.current_step == self;
	
func _create_adventurer(s: SceneInfo) -> SceneInstance:
	if Manager.instance == null or Manager.instance.quests == null:
		return null
	if not can_interact() or npcs.size() >= Manager.instance.quests.max_npc_per_tavern:
		return null
	if s == null or adventurer_spawn == null:
		return null
	var npc_scene_instance := SceneManager.add(s)
	if npc_scene_instance == null:
		return null
	npc_scene_instance.node.global_position = adventurer_spawn.global_position
	npc_scene_instance.node.tree_exiting.connect(_remove_adventurer.bind(npc_scene_instance))
	var npc := npc_scene_instance.node as NPC
	if npc != null:
		npc.set_operation_home(adventurer_spawn)
		if not npc.rank_progress_changed.is_connected(_on_npc_roster_activity_changed):
			npc.rank_progress_changed.connect(_on_npc_roster_activity_changed)
		if not npc.activity_changed.is_connected(_on_npc_roster_activity_changed):
			npc.activity_changed.connect(_on_npc_roster_activity_changed)
		if not npc.rest_progress_changed.is_connected(_on_npc_roster_activity_changed):
			npc.rest_progress_changed.connect(_on_npc_roster_activity_changed)
	npcs.append(npc_scene_instance)
	if npc != null and Manager.instance != null and Manager.instance.hub != null:
		Manager.instance.hub.register_npc(npc)
	Manager.instance.quests.try_assign_waiting_quests()
	npc_roster_changed.emit()
	return npc_scene_instance

func get_available_npcs() -> Array[SceneInstance]:
	return get_roster_npcs().filter(func(x: SceneInstance) -> bool:
		var npc := x.node as NPC
		return npc != null and npc.is_available_for_quest()
	)

func get_roster_npcs() -> Array[SceneInstance]:
	return npcs.filter(func(x: SceneInstance) -> bool:
		return x != null and is_instance_valid(x.node) and x.node is NPC
	)

func _spawn_starting_adventurers() -> void:
	if Manager.instance == null or Manager.instance.quests == null:
		return
	for profile: NpcInfo in starting_npc_profiles:
		if npcs.size() >= Manager.instance.quests.max_npc_per_tavern:
			return
		if profile != null:
			_create_adventurer(profile)

	for i in starting_random_npc_count:
		if npcs.size() >= Manager.instance.quests.max_npc_per_tavern:
			return
		if _spawn_random_adventurer() == null:
			break

func _spawn_random_adventurer() -> SceneInstance:
	var spawn_info := _get_random_npc_profile() as SceneInfo
	if spawn_info == null:
		spawn_info = adventurer
	return _create_adventurer(spawn_info)

func _get_random_npc_profile() -> NpcInfo:
	if DataManager.instance == null:
		return null
	var profiles: Array[NpcInfo] = []
	for profile: NpcInfo in DataManager.instance.npcs:
		if profile != null:
			profiles.append(profile)
	return profiles.pick_random() if not profiles.is_empty() else null

func _remove_adventurer(npc_scene_instance: SceneInstance) -> void:
	var npc := npc_scene_instance.node as NPC if npc_scene_instance != null else null
	if npc != null and Manager.instance != null and Manager.instance.hub != null:
		Manager.instance.hub.unregister_npc(npc)
	npcs.erase(npc_scene_instance)
	npc_roster_changed.emit()

func _on_npc_roster_activity_changed(_npc: NPC = null) -> void:
	npc_roster_changed.emit()

class_name FactionHome extends SettlementService

@export var faction_id: StringName = &""
@export var member_scene: SceneInfo
@export var member_spawn: Node3D
@export_range(1, 10, 1) var roster_capacity := 5
@export_group("Starting Roster")
@export var starting_npc_profiles: Array[NpcInfo] = []
@export_range(0, 10, 1) var starting_random_npc_count := 0

var members: Array[SceneInstance] = []
var buildable_structure: Buildable

signal npc_roster_changed()

func _ready() -> void:
	super()
	buildable_structure = get_parent() as Buildable
	_spawn_starting_members.call_deferred()

func interact() -> void:
	open_additional_ui_windows()

func can_interact() -> bool:
	return buildable_structure == null or buildable_structure.current_step == self

func create_member(profile: SceneInfo, recruitment_data: Dictionary = {}) -> SceneInstance:
	if Manager.instance == null or Manager.instance.quests == null:
		return null
	if not can_interact() or members.size() >= roster_capacity:
		return null
	if profile == null or member_spawn == null:
		return null

	var npc_scene_instance := SceneManager.add(profile)
	if npc_scene_instance == null or npc_scene_instance.node == null:
		return null
	npc_scene_instance.node.global_position = member_spawn.global_position
	npc_scene_instance.node.tree_exiting.connect(_remove_member.bind(npc_scene_instance))

	var npc := npc_scene_instance.node as NPC
	if npc != null:
		if not recruitment_data.is_empty():
			npc.configure_recruited_identity(
				str(recruitment_data.get("display_name", "")),
				AdventurerRank.clamp_rank(int(recruitment_data.get("rank", int(AdventurerRank.Rank.F)))),
				_get_recruited_traits(recruitment_data)
			)
		npc.set_operation_home(member_spawn)
		npc.set_recovery_anchor(_get_recovery_anchor())
		_connect_member_signals(npc)
	members.append(npc_scene_instance)
	if npc != null and Manager.instance.hub != null:
		Manager.instance.hub.register_npc(npc)
	Manager.instance.quests.call_deferred("try_assign_waiting_quests")
	npc_roster_changed.emit()
	return npc_scene_instance

func get_available_npcs() -> Array[SceneInstance]:
	return get_roster_npcs().filter(func(instance: SceneInstance) -> bool:
		var npc := instance.node as NPC
		return npc != null and npc.is_available_for_quest()
	)

func can_accept_member(profile: NpcInfo = null) -> bool:
	if not can_interact() or members.size() >= roster_capacity:
		return false
	return profile == null or faction_id == &"" or profile.faction_id == faction_id

func get_member_count() -> int:
	return get_roster_npcs().size()

func get_roster_capacity() -> int:
	return roster_capacity

func get_roster_npcs() -> Array[SceneInstance]:
	return members.filter(func(instance: SceneInstance) -> bool:
		return instance != null and is_instance_valid(instance.node) and instance.node is NPC
	)

func get_display_name() -> String:
	var translation_key := "FACTION_%s_HOME_NAME" % String(faction_id).to_upper()
	var translated := tr(translation_key)
	return String(faction_id).capitalize() if translated == translation_key else translated

func _spawn_starting_members() -> void:
	for profile: NpcInfo in starting_npc_profiles:
		if members.size() >= roster_capacity:
			return
		if profile != null:
			create_member(profile)

	for _index in starting_random_npc_count:
		if members.size() >= roster_capacity:
			return
		if _spawn_random_member() == null:
			break

func _spawn_random_member() -> SceneInstance:
	var profile := _get_random_npc_profile() as SceneInfo
	if profile == null:
		profile = member_scene
	return create_member(profile)

func _get_random_npc_profile() -> NpcInfo:
	if DataManager.instance == null:
		return null
	var profiles: Array[NpcInfo] = []
	for profile: NpcInfo in DataManager.instance.npcs:
		if profile != null and (faction_id == &"" or profile.faction_id == faction_id):
			profiles.append(profile)
	return profiles.pick_random() if not profiles.is_empty() else null

func _get_recovery_anchor() -> Node3D:
	var tavern := get_settlement_service(&"Tavern") as Tavern
	return tavern.get_recreation_anchor() if tavern != null else null

func _get_recruited_traits(recruitment_data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for trait_name in recruitment_data.get("traits", []):
		result.append(str(trait_name))
	return result

func _connect_member_signals(npc: NPC) -> void:
	if not npc.rank_progress_changed.is_connected(_on_member_activity_changed):
		npc.rank_progress_changed.connect(_on_member_activity_changed)
	if not npc.activity_changed.is_connected(_on_member_activity_changed):
		npc.activity_changed.connect(_on_member_activity_changed)
	if not npc.rest_progress_changed.is_connected(_on_member_activity_changed):
		npc.rest_progress_changed.connect(_on_member_activity_changed)

func _remove_member(npc_scene_instance: SceneInstance) -> void:
	var npc := npc_scene_instance.node as NPC if npc_scene_instance != null else null
	if npc != null and Manager.instance != null and Manager.instance.hub != null:
		Manager.instance.hub.unregister_npc(npc)
	members.erase(npc_scene_instance)
	npc_roster_changed.emit()

func _on_member_activity_changed(_npc: NPC = null) -> void:
	npc_roster_changed.emit()

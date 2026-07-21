class_name Mineshaft extends QuestObjective

enum MineState {
	UNSURVEYED,
	POOR_VEIN,
	RICH_VEIN,
	UNSTABLE,
	EXHAUSTED
}

@export var prospect_time: float = 6.0
@export var extract_time: float = 8.0
@export var reinforce_time: float = 5.0
@export var vein_infos: Array[MineVeinInfo] = []

@onready var ready_to_mine: Node3D = get_node_or_null("ready_to_mine") as Node3D
@onready var collapsed: Node3D = get_node_or_null("collapsed") as Node3D
@onready var no_entry: Node3D = get_node_or_null("no_entry") as Node3D

var _quest_running: bool = false
var _pending_reward: Dictionary[ItemInfo, int] = {}
var _last_stable_state: MineState = MineState.POOR_VEIN

func _ready() -> void:
	super()

	var states: Array[String] = []
	for state_name in MineState.keys():
		states.append(state_name)

	state_machine = StateMachine.new(states)
	_set_mine_state(MineState.UNSURVEYED)

func interact() -> void:
	pass

func can_interact() -> bool:
	return not _quest_running and not get_filtered_quest_types().is_empty()

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	_pending_reward.clear()
	var behaviour := get_quest_behaviour(q.quest_key)
	var profile := get_profile(q.quest_key)

	if behaviour == "prospect":
		await get_tree().create_timer(get_quest_duration(q.quest_key, prospect_time)).timeout
		var discovered_state := _roll_discovered_state()
		_set_mine_state(discovered_state)
	elif behaviour == "extract":
		var origin_state := _current_mine_state()
		await get_tree().create_timer(get_quest_duration(q.quest_key, extract_time)).timeout
		_pending_reward = _roll_extract_reward(origin_state, _get_profile_int(profile, "reward_rolls", 1))
		_set_mine_state(_roll_post_extract_state(origin_state, profile))
	elif behaviour == "reinforce":
		await get_tree().create_timer(get_quest_duration(q.quest_key, reinforce_time)).timeout
		_set_mine_state(_last_stable_state)

	q.return_from_quest()
	_quest_running = false

func complete_quest(q: Quest) -> void:
	if get_quest_behaviour(q.quest_key) != "extract":
		return

	if _pending_reward.is_empty():
		Debug.message("The miners came back empty-handed.")
		return

	grant_player_inventory_rewards(_pending_reward)
	_pending_reward.clear()

func _current_mine_state() -> MineState:
	var key := state_machine.get_current_state()
	return MineState[key] as MineState

func _set_mine_state(state: MineState) -> void:
	state_machine.set_state(MineState.keys()[state])
	if state in [MineState.POOR_VEIN, MineState.RICH_VEIN]:
		_last_stable_state = state
	_update_markers(state)
	Manager.instance.quests.quest_availability_changed.emit()

func _update_markers(state: MineState) -> void:
	if ready_to_mine != null:
		ready_to_mine.visible = state in [MineState.POOR_VEIN, MineState.RICH_VEIN]
	if collapsed != null:
		collapsed.visible = state == MineState.UNSTABLE
	if no_entry != null:
		no_entry.visible = state == MineState.EXHAUSTED

func _roll_discovered_state() -> MineState:
	var valid_infos: Array[MineVeinInfo] = []
	var cumulative: Array[float] = []
	var total_weight := 0.0

	for vein_info in vein_infos:
		if vein_info == null or vein_info.prospect_weight <= 0.0:
			continue
		if vein_info.mine_state == MineState.UNSURVEYED or vein_info.mine_state == MineState.EXHAUSTED:
			continue

		total_weight += vein_info.prospect_weight
		valid_infos.append(vein_info)
		cumulative.append(total_weight)

	if total_weight <= 0.0:
		Debug.warn("Mineshaft has no valid prospectable vein info configured.")
		return MineState.POOR_VEIN

	var roll := randf() * total_weight
	for i in cumulative.size():
		if roll <= cumulative[i]:
			return valid_infos[i].mine_state

	return valid_infos[-1].mine_state

func _roll_extract_reward(origin_state: MineState, reward_rolls: int = 1) -> Dictionary[ItemInfo, int]:
	var info := _get_vein_info_for_state(origin_state)
	if info == null:
		return {}
	var reward: Dictionary[ItemInfo, int] = {}
	for i in maxi(1, reward_rolls):
		var loot := info.roll_loot()
		for item: ItemInfo in loot.keys():
			reward[item] = reward.get(item, 0) + loot[item]
	return reward

func _roll_post_extract_state(origin_state: MineState, profile: QuestProfile = null) -> MineState:
	var info := _get_vein_info_for_state(origin_state)
	if info == null:
		return origin_state

	var collapse_chance := clampf(
		info.collapse_chance * _get_profile_float(profile, "collapse_multiplier", 1.0)
			+ _get_profile_float(profile, "collapse_bonus", 0.0),
		0.0,
		1.0
	)
	var exhaust_chance := clampf(
		info.exhaust_chance * _get_profile_float(profile, "exhaust_multiplier", 1.0)
			+ _get_profile_float(profile, "exhaust_bonus", 0.0),
		0.0,
		1.0 - collapse_chance
	)
	var roll := randf()

	if roll < collapse_chance:
		return MineState.UNSTABLE
	if roll < collapse_chance + exhaust_chance:
		return MineState.EXHAUSTED
	return origin_state

func _get_vein_info_for_state(state: MineState) -> MineVeinInfo:
	for vein_info in vein_infos:
		if vein_info != null and vein_info.mine_state == state:
			return vein_info
	return null

func get_quest_profile_reward_preview(quest_type_key: String) -> Array[Dictionary]:
	var behaviour := get_quest_behaviour(quest_type_key)
	if behaviour != "extract":
		return super.get_quest_profile_reward_preview(quest_type_key)

	var info := _get_vein_info_for_state(_current_mine_state())
	if info == null or info.loot_table == null:
		return []

	var profile := get_profile(quest_type_key)
	var reward_rolls := maxi(1, _get_profile_int(profile, "reward_rolls", 1))
	var preview: Array[Dictionary] = []
	var ranges := info.loot_table.get_preview_ranges()

	for item: ItemInfo in ranges.keys():
		if item == null:
			continue
		var amount_range: Vector2i = ranges[item]
		preview.append({
			"item": item,
			"min": amount_range.x * reward_rolls,
			"max": amount_range.y * reward_rolls,
		})

	preview.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var item_a := a.get("item") as ItemInfo
		var item_b := b.get("item") as ItemInfo
		if item_a == null or item_b == null:
			return item_a != null
		return item_a.get_display_name().nocasecmp_to(item_b.get_display_name()) < 0
	)
	return preview

func _get_profile_float(profile: QuestProfile, key: String, fallback: float) -> float:
	if profile == null:
		return fallback
	return profile.get_float_modifier(key, fallback)

func _get_profile_int(profile: QuestProfile, key: String, fallback: int) -> int:
	if profile == null:
		return fallback
	return profile.get_int_modifier(key, fallback)

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
@export_group("Depth")
@export_range(1, 10, 1) var max_depth: int = 3
@export_range(1, 10, 1) var depth: int = 1
## Extra loot tables unlocked at depth 2, depth 3, and so on.
@export var depth_loot_tables: Array[LootTable] = []

@onready var ready_to_mine: Node3D = get_node_or_null("ready_to_mine") as Node3D
@onready var collapsed: Node3D = get_node_or_null("collapsed") as Node3D
@onready var no_entry: Node3D = get_node_or_null("no_entry") as Node3D

var _quest_running: bool = false
var _pending_reward: Dictionary[ItemInfo, int] = {}
var _last_stable_state: MineState = MineState.POOR_VEIN
var reinforced_uses := 0
var temporary_supports := false

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
	return has_visible_quest_activity() or (not _quest_running and not get_filtered_quest_types().is_empty())

func get_filtered_quest_types(active_state: int = state_machine.get_current_state_index()) -> Array[String]:
	var filtered_types: Array[String] = super.get_filtered_quest_types(active_state)
	if depth >= max_depth:
		filtered_types.erase("deepen")
		filtered_types.erase("reopen")
	if reinforced_uses > 0: filtered_types.erase("brace")
	return filtered_types

func get_required_supplies(quest_type_key: String) -> Dictionary[ItemInfo, int]:
	var profile := get_profile(quest_type_key)
	if quest_type_key == "deepen" and profile != null:
		return profile.get_required_supplies_for_level(depth)
	return super.get_required_supplies(quest_type_key)

func has_required_supplies(quest_type_key: String, inventory: ContentGroup) -> bool:
	var profile := get_profile(quest_type_key)
	if quest_type_key == "deepen" and profile != null:
		return profile.has_available_supplies_for_level(inventory, depth)
	return super.has_required_supplies(quest_type_key, inventory)

func assign_required_supplies(quest: Quest, inventory: ContentGroup) -> bool:
	if quest != null and quest.quest_key == "deepen":
		var profile := get_profile(quest.quest_key)
		if profile == null:
			return false
		quest.context["mine_depth"] = depth
		return profile.assign_required_supplies_for_level(quest, inventory, depth)
	return super.assign_required_supplies(quest, inventory)

func quest_has_required_supplies(quest: Quest) -> bool:
	if quest != null and quest.quest_key == "deepen":
		var profile := get_profile(quest.quest_key)
		var quest_depth := int(quest.context.get("mine_depth", depth))
		return profile != null and profile.quest_has_supplies_for_level(quest, quest_depth)
	return super.quest_has_required_supplies(quest)

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	_pending_reward.clear()
	var behaviour := get_quest_behaviour(q.quest_key)
	var profile := get_profile(q.quest_key)

	if behaviour == "prospect":
		if not await q.wait_for_work(get_effective_quest_duration(q, prospect_time), get_tree()):
			_quest_running = false
			return
		var discovered_state := _roll_discovered_state()
		_set_mine_state(discovered_state)
		var outcome := roll_quest_outcome(q)
		if outcome != null: _pending_reward = outcome.roll_loot()
	elif behaviour == "extract":
		var origin_state := _current_mine_state()
		if not await q.wait_for_work(get_effective_quest_duration(q, extract_time), get_tree()):
			_quest_running = false
			return
		_pending_reward = _roll_extract_reward(origin_state, _get_profile_int(profile, "reward_rolls", 1))
		_set_mine_state(_roll_post_extract_state(origin_state, profile, q.get_danger_weight_multiplier()))
		reinforced_uses = maxi(0, reinforced_uses - 1)
		temporary_supports = false
	elif behaviour == "reinforce":
		if not await q.wait_for_work(get_effective_quest_duration(q, reinforce_time), get_tree()):
			_quest_running = false
			return
		_set_mine_state(_last_stable_state)
		reinforced_uses = 3
		temporary_supports = false
	elif behaviour in ["brace", "shore_reopen"]:
		if not await q.wait_for_work(get_effective_quest_duration(q, reinforce_time), get_tree()):
			_quest_running = false
			return
		if behaviour == "brace": reinforced_uses = 3
		else:
			temporary_supports = true
			reinforced_uses = 0
			_set_mine_state(_last_stable_state)
	elif behaviour == "deepen":
		if not await q.wait_for_work(get_effective_quest_duration(q, extract_time), get_tree()):
			_quest_running = false
			return
		depth = mini(max_depth, depth + 1)
		_notify_reward(tr("QUEST_MINE_DEEPENED") % [depth])
		Manager.instance.quests.quest_availability_changed.emit()
	elif behaviour == "reopen":
		if not await q.wait_for_work(get_effective_quest_duration(q, extract_time), get_tree()):
			_quest_running = false
			return
		depth = mini(max_depth, depth + 1)
		_set_mine_state(MineState.UNSURVEYED)
		_notify_reward(tr("QUEST_MINE_REOPENED") % [depth])

	q.return_from_quest()
	_quest_running = false

func complete_quest(q: Quest) -> void:
	if get_quest_behaviour(q.quest_key) not in ["extract", "prospect"]:
		return

	if _pending_reward.is_empty():
		Debug.message("The miners came back empty-handed.")
		return

	grant_player_inventory_rewards(_pending_reward, q)
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
	for table_index in mini(depth - 1, depth_loot_tables.size()):
		var depth_table := depth_loot_tables[table_index]
		if depth_table == null:
			continue
		var depth_loot := depth_table.roll()
		for item: ItemInfo in depth_loot.keys():
			reward[item] = reward.get(item, 0) + depth_loot[item]
	return reward

func _roll_post_extract_state(origin_state: MineState, profile: QuestProfile = null, danger_multiplier := 1.0) -> MineState:
	var info := _get_vein_info_for_state(origin_state)
	if info == null:
		return origin_state

	var collapse_chance := clampf(
		info.collapse_chance * _get_profile_float(profile, "collapse_multiplier", 1.0)
			+ _get_profile_float(profile, "collapse_bonus", 0.0),
		0.0,
		1.0
	)
	collapse_chance = clampf(collapse_chance + 0.04 * float(maxi(0, depth - 1)), 0.0, 1.0)
	if reinforced_uses > 0: collapse_chance *= 0.25
	if temporary_supports: collapse_chance = minf(1.0, collapse_chance + 0.08)
	collapse_chance = clampf(collapse_chance * danger_multiplier, 0.0, 1.0)
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

func get_quest_profile_reward_preview(quest_type_key: String) -> Array[RewardPreview]:
	var behaviour := get_quest_behaviour(quest_type_key)
	if behaviour != "extract":
		return super.get_quest_profile_reward_preview(quest_type_key)

	var info := _get_vein_info_for_state(_current_mine_state())
	if info == null or info.loot_table == null:
		return []

	var profile := get_profile(quest_type_key)
	var reward_rolls := maxi(1, _get_profile_int(profile, "reward_rolls", 1))
	var preview: Array[RewardPreview] = []
	var ranges := info.loot_table.get_preview_ranges()
	for item: ItemInfo in ranges: ranges[item] *= reward_rolls
	for table_index in mini(depth - 1, depth_loot_tables.size()):
		var depth_table := depth_loot_tables[table_index]
		if depth_table == null:
			continue
		for item: ItemInfo in depth_table.get_preview_ranges().keys():
			var depth_range := depth_table.get_preview_ranges()[item] as Vector2i
			var current_range := ranges.get(item, Vector2i.ZERO) as Vector2i
			ranges[item] = current_range + depth_range

	for item: ItemInfo in ranges.keys():
		if item == null:
			continue
		var amount_range: Vector2i = ranges[item]
		preview.append(RewardPreview.new(item, amount_range.x, amount_range.y))

	preview.sort_custom(func(a: RewardPreview, b: RewardPreview) -> bool:
		var item_a := a.item
		var item_b := b.item
		if item_a == null or item_b == null:
			return item_a != null
		return item_a.get_display_name().nocasecmp_to(item_b.get_display_name()) < 0
	)
	return preview

func get_quest_profile_expected_reward(quest_type_key: String) -> String:
	return super.get_quest_profile_expected_reward(quest_type_key)

func get_quest_context_label(quest_type_key: String) -> String:
	var lines: Array[String] = [super.get_quest_context_label(quest_type_key), tr("QUEST_MINE_DEPTH_STATUS") % [depth, max_depth]]
	if reinforced_uses > 0: lines.append(tr("COMMUNITY_MINE_SUPPORTED") % reinforced_uses)
	if temporary_supports: lines.append(tr("COMMUNITY_MINE_TEMPORARY"))
	return "\n".join(lines)

func _get_profile_float(profile: QuestProfile, key: String, fallback: float) -> float:
	if profile == null:
		return fallback
	return profile.get_float_modifier(key, fallback)

func _get_profile_int(profile: QuestProfile, key: String, fallback: int) -> int:
	if profile == null:
		return fallback
	return profile.get_int_modifier(key, fallback)

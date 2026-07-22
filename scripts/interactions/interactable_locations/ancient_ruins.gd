class_name AncientRuins extends QuestObjective

const QUEST_TYPE_INVESTIGATE := "investigate"

enum RuinsState {
	AVAILABLE,
	SURVEYED,
	DANGEROUS,
	SECURED,
	LOOTED
}

@export var investigate_time: float = 8.0

@onready var main_ruins_model: Node3D = get_node_or_null("Root Scene") as Node3D
@onready var surveyed_marker: Node3D = get_node_or_null("surveyed_marker") as Node3D
@onready var danger_marker: Node3D = get_node_or_null("danger_marker") as Node3D
@onready var secured_marker: Node3D = get_node_or_null("secured_marker") as Node3D
@onready var looted_marker: Node3D = get_node_or_null("looted_marker") as Node3D

var _quest_running: bool = false
var _pending_reward: Dictionary[ItemInfo, int] = {}
var _loot_claimed: bool = false

func _ready() -> void:
	super()
	if quest_types.is_empty():
		quest_types = [QUEST_TYPE_INVESTIGATE]
	var states: Array[String] = []
	for state_name in RuinsState.keys():
		states.append(state_name)
	state_machine = StateMachine.new(states)
	_set_ruins_state(RuinsState.AVAILABLE)

func _on_visibility_changed() -> void:
	super._on_visibility_changed()
	if hex.is_explored:
		Manager.instance.journal.complete_task(journal_quest.id)

func can_interact() -> bool:
	if state_machine.get_current_state() == "LOOTED":
		return false
	var lootable := hex.structure.structure_info as LootableStructureInfo
	if lootable != null and lootable.loot_once and _loot_claimed:
		return false
	return has_visible_quest_activity() or (not _quest_running and not get_filtered_quest_types().is_empty())

func interact() -> void:
	pass

func execute_quest(q: Quest) -> void:
	if _quest_running:
		return

	_quest_running = true
	_pending_reward.clear()
	var behaviour := get_quest_behaviour(q.quest_key, "salvage")

	await get_tree().create_timer(get_quest_duration(q.quest_key, investigate_time)).timeout

	var outcome := roll_quest_outcome(q.quest_key)
	if outcome != null:
		_pending_reward = outcome.roll_loot()
		if outcome.has_next_state():
			_set_ruins_state(RuinsState[outcome.next_state] as RuinsState)
		outcome.complete_journal_task()
	else:
		var lootable := hex.structure.structure_info as LootableStructureInfo
		if lootable != null:
			_pending_reward = lootable.roll_loot()
		match behaviour:
			"survey":
				_set_ruins_state(RuinsState.SURVEYED)
			"secure":
				_set_ruins_state(RuinsState.SECURED)
			_:
				_set_ruins_state(RuinsState.LOOTED)

	q.return_from_quest()
	_quest_running = false

func complete_quest(_q: Quest) -> void:
	var lootable := hex.structure.structure_info as LootableStructureInfo
	if lootable == null:
		return

	grant_player_inventory_rewards(_pending_reward)
	_pending_reward.clear()

	if lootable.loot_once:
		_loot_claimed = state_machine.get_current_state() == "LOOTED"
		Manager.instance.quests.quest_availability_changed.emit()

func _set_ruins_state(state: RuinsState) -> void:
	state_machine.set_state(RuinsState.keys()[state])
	_update_markers(state)
	Manager.instance.quests.quest_availability_changed.emit()

func _update_markers(state: RuinsState) -> void:
	var is_looted := state == RuinsState.LOOTED
	show_interaction_prompt = not is_looted
	if main_ruins_model != null:
		main_ruins_model.visible = not is_looted
	if surveyed_marker != null:
		surveyed_marker.visible = state in [RuinsState.SURVEYED, RuinsState.SECURED]
	if danger_marker != null:
		danger_marker.visible = state == RuinsState.DANGEROUS
	if secured_marker != null:
		secured_marker.visible = state == RuinsState.SECURED
	if looted_marker != null:
		looted_marker.visible = state == RuinsState.LOOTED

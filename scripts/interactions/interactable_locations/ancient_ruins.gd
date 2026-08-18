class_name AncientRuins extends QuestObjective

const QUEST_TYPE_SURVEY := "survey"

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
var _pending_behaviour := ""
var _pending_outcome: QuestOutcome
var _pending_reveal_occupation := false
var _loot_claimed: bool = false

func _ready() -> void:
	super()
	if quest_types.is_empty():
		quest_types = [QUEST_TYPE_SURVEY]
	var states: Array[String] = []
	for state_name in RuinsState.keys():
		states.append(state_name)
	state_machine = StateMachine.new(states)
	_set_ruins_state(RuinsState.AVAILABLE)
	_initialize_occupation.call_deferred()

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
	_pending_behaviour = behaviour
	_pending_outcome = null
	_pending_reveal_occupation = behaviour == "survey" and not is_occupation_revealed()

	var duration := get_quest_duration(q.quest_key, investigate_time)
	var occupation := get_occupation()
	if behaviour == "secure" and occupation != null:
		duration = occupation.get_security_duration(duration)
	await get_tree().create_timer(duration).timeout

	var danger_multiplier := 0.0 if state_machine.get_current_state() == "SECURED" else 1.0
	var outcome := roll_quest_outcome(q, danger_multiplier)
	_pending_outcome = outcome
	if outcome != null:
		_pending_reward = outcome.roll_loot()
		_append_monster_report(outcome)
	else:
		var lootable := hex.structure.structure_info as LootableStructureInfo
		if lootable != null:
			_pending_reward = lootable.roll_loot()

	q.return_from_quest()
	_quest_running = false

func complete_quest(_q: Quest) -> void:
	if _pending_reveal_occupation:
		reveal_occupation()
	_apply_pending_result()
	var lootable := hex.structure.structure_info as LootableStructureInfo
	if lootable == null:
		_clear_pending_result()
		return

	grant_player_inventory_rewards(_pending_reward)
	_pending_reward.clear()

	if lootable.loot_once:
		_loot_claimed = state_machine.get_current_state() == "LOOTED"
		Manager.instance.quests.quest_availability_changed.emit()
	_clear_pending_result()

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

func _initialize_occupation() -> void:
	if hex == null:
		return
	var grid := hex.region_instance.hex_grid if hex.region_instance != null else null
	var rng := grid.create_rng("ruins_occupation:%s" % hex.cube_id) if grid != null else null
	ensure_occupation_selected(rng, false)

func _apply_pending_result() -> void:
	if _pending_outcome != null:
		_pending_outcome.complete_journal_task()
		match _pending_behaviour:
			"survey":
				_set_ruins_state(RuinsState.DANGEROUS if has_occupation() else RuinsState.SURVEYED)
			"secure":
				if not _pending_outcome.is_dangerous:
					clear_occupation()
					_set_ruins_state(RuinsState.SECURED)
			"delve":
				if _pending_outcome.is_dangerous:
					_set_ruins_state(RuinsState.DANGEROUS)
				else:
					clear_occupation(false)
					_set_ruins_state(RuinsState.LOOTED)
			_:
				if _pending_outcome.has_next_state():
					_set_ruins_state(RuinsState[_pending_outcome.next_state] as RuinsState)
		return
	match _pending_behaviour:
		"survey":
			_set_ruins_state(RuinsState.DANGEROUS if has_occupation() else RuinsState.SURVEYED)
		"secure":
			clear_occupation()
			_set_ruins_state(RuinsState.SECURED)
		_:
			_set_ruins_state(RuinsState.LOOTED)

func _clear_pending_result() -> void:
	_pending_behaviour = ""
	_pending_outcome = null
	_pending_reveal_occupation = false

func _append_monster_report(outcome: QuestOutcome) -> void:
	if outcome == null or not _pending_reveal_occupation or not has_occupation():
		return
	var occupation := get_occupation()
	if occupation == null:
		return
	outcome.append_summary(tr("QUEST_REPORT_MONSTER_SPOTTED") % [
		occupation.get_display_name(),
		AdventurerRank.get_display_name(occupation.get_difficulty()),
	])

class_name TavernRecruitmentUI
extends MarginContainer

const CANDIDATE_ROW_SCENE := preload("res://scenes/ui/components/recruit_candidate_row.tscn")

@onready var visitor_count: Label = $Margin/Content/PoolSummary/VisitorCount
@onready var next_arrival: Label = $Margin/Content/NextArrival
@onready var candidate_rows: VBoxContainer = $Margin/Content/CandidateScroll/CandidateRows
@onready var empty_label: Label = $Margin/Content/EmptyLabel
@onready var refresh_button: Button = $Margin/Content/Footer/Refresh
@onready var feedback_label: Label = $Margin/Content/Footer/Feedback

var tavern: Tavern
var _refresh_queued := false

func _ready() -> void:
	if not refresh_button.pressed.is_connected(_on_refresh_pressed):
		refresh_button.pressed.connect(_on_refresh_pressed)
	if Manager.instance != null and Manager.instance.hub != null:
		if not Manager.instance.hub.changed.is_connected(_queue_refresh):
			Manager.instance.hub.changed.connect(_queue_refresh)

func setup_interaction(interaction: Interaction) -> void:
	if tavern != null and is_instance_valid(tavern):
		if tavern.recruitment_changed.is_connected(_queue_refresh):
			tavern.recruitment_changed.disconnect(_queue_refresh)
	tavern = interaction as Tavern
	if tavern != null and not tavern.recruitment_changed.is_connected(_queue_refresh):
		tavern.recruitment_changed.connect(_queue_refresh)
	_queue_refresh()

func on_enter() -> void:
	feedback_label.text = ""
	_queue_refresh()

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_apply_refresh.call_deferred()

func _apply_refresh() -> void:
	_refresh_queued = false
	if not is_node_ready() or not is_inside_tree():
		return
	_clear_rows()
	if tavern == null or not is_instance_valid(tavern):
		empty_label.visible = true
		refresh_button.disabled = true
		return
	var candidates := tavern.get_candidates()
	visitor_count.text = tr("RECRUITMENT_VISITOR_COUNT") % [candidates.size(), tavern.get_candidate_capacity()]
	next_arrival.text = tr("RECRUITMENT_NEXT_ARRIVAL") % tavern.get_operations_until_next_arrival()
	empty_label.visible = candidates.is_empty()
	refresh_button.text = tr("RECRUITMENT_REFRESH_BUTTON") % tavern.get_manual_refresh_cost()
	var refresh_block_key := tavern.get_refresh_block_key()
	refresh_button.disabled = not refresh_block_key.is_empty()
	refresh_button.tooltip_text = (
		tr(refresh_block_key)
		if refresh_button.disabled
		else tr("RECRUITMENT_REFRESH_TOOLTIP")
	)
	for candidate: RecruitCandidate in candidates:
		var row := CANDIDATE_ROW_SCENE.instantiate() as RecruitCandidateRowUI
		candidate_rows.add_child(row)
		row.hire_requested.connect(_on_hire_requested)
		row.setup(candidate, tavern)

func _on_hire_requested(candidate: RecruitCandidate) -> void:
	if tavern == null or candidate == null:
		return
	var block_key := tavern.get_hire_block_key(candidate)
	if not block_key.is_empty():
		feedback_label.text = tr(block_key)
		return
	feedback_label.text = tr("RECRUITMENT_HIRE_SUCCESS") % candidate.display_name if tavern.hire_candidate(candidate) else tr("RECRUITMENT_ERROR_HIRE_FAILED")
	_queue_refresh()

func _on_refresh_pressed() -> void:
	if tavern == null:
		return
	var block_key := tavern.get_refresh_block_key()
	if not block_key.is_empty():
		feedback_label.text = tr(block_key)
		return
	if tavern.refresh_candidates():
		feedback_label.text = tr("RECRUITMENT_REFRESH_SUCCESS")
	else:
		feedback_label.text = tr("RECRUITMENT_ERROR_REFRESH_UNAVAILABLE")
	_queue_refresh()

func _clear_rows() -> void:
	for child in candidate_rows.get_children():
		candidate_rows.remove_child(child)
		child.queue_free()

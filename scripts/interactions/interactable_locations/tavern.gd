class_name Tavern extends SettlementService

@export var recreation_anchor: Node3D
@export_group("Recruitment")
@export var recruitment_rules: RecruitmentRules

var buildable_structure: Buildable
var candidates: Array[RecruitCandidate] = []
var _candidate_serial := 0
var _name_serial := 0
var _next_natural_arrival_operation := 0
var _rng := RandomNumberGenerator.new()

signal recruitment_changed()
signal candidate_hired(candidate: RecruitCandidate, npc: NPC)

func _ready() -> void:
	super()
	buildable_structure = get_parent() as Buildable
	_rng.randomize()
	_initialize_recruitment.call_deferred()

func interact() -> void:
	open_additional_ui_windows()

func can_interact() -> bool:
	return buildable_structure == null or buildable_structure.current_step == self

func get_recreation_anchor() -> Node3D:
	return recreation_anchor

func get_candidates() -> Array[RecruitCandidate]:
	_ensure_emergency_recruit()
	return candidates.duplicate()

func get_candidate_capacity() -> int:
	return _get_recruitment_rules().candidate_capacity

func get_manual_refresh_cost() -> int:
	return _get_recruitment_rules().manual_refresh_cost

func get_operations_until_next_arrival() -> int:
	return maxi(0, _next_natural_arrival_operation - _get_completed_operation_count())

func generate_adventurer_name() -> String:
	_name_serial += 1
	var name_pool := _get_recruitment_rules().name_pool
	if name_pool != null:
		var generated_name := name_pool.generate_available_name(_rng, _get_used_adventurer_names(), _name_serial)
		if not generated_name.is_empty():
			return generated_name
	return tr("NPC_GENERATED_NAME_FALLBACK") % _name_serial

func get_hire_block_key(candidate: RecruitCandidate) -> String:
	if candidate == null or not candidates.has(candidate):
		return "RECRUITMENT_ERROR_CANDIDATE_UNAVAILABLE"
	var home := _get_faction_home(candidate.get_faction_id())
	if home == null:
		return "RECRUITMENT_ERROR_NO_FACTION_HOME"
	if not home.can_accept_member(candidate.profile):
		return "RECRUITMENT_ERROR_FACTION_FULL"
	if Manager.instance == null or Manager.instance.hub == null or Manager.instance.hub.currency < candidate.hire_cost:
		return "RECRUITMENT_ERROR_NOT_ENOUGH_CURRENCY"
	return ""

func get_refresh_block_key() -> String:
	if Manager.instance == null or Manager.instance.hub == null:
		return "RECRUITMENT_ERROR_REFRESH_UNAVAILABLE"
	if Manager.instance.hub.currency < _get_recruitment_rules().manual_refresh_cost:
		return "RECRUITMENT_ERROR_NOT_ENOUGH_CURRENCY"
	if _get_recruitable_profiles().is_empty():
		return "RECRUITMENT_ERROR_NO_RECRUITS_AVAILABLE"
	return ""

func hire_candidate(candidate: RecruitCandidate) -> bool:
	if get_hire_block_key(candidate) != "":
		return false
	var home := _get_faction_home(candidate.get_faction_id())
	if home == null or Manager.instance == null or Manager.instance.hub == null:
		return false
	if not Manager.instance.hub.reserve_currency(candidate.hire_cost):
		return false
	var instance := home.create_member(candidate.profile, {
		"display_name": candidate.display_name,
		"rank": int(candidate.rank),
		"traits": candidate.traits,
	})
	if instance == null:
		Manager.instance.hub.add_currency(candidate.hire_cost)
		return false
	var npc := instance.node as NPC
	candidates.erase(candidate)
	candidate_hired.emit(candidate, npc)
	recruitment_changed.emit()
	if Manager.instance.toast != null:
		Manager.instance.toast.notify(tr("RECRUITMENT_HIRED_NOTICE") % [candidate.display_name, candidate.get_faction_name()])
	return true

func refresh_candidates() -> bool:
	if not get_refresh_block_key().is_empty():
		return false
	var rules := _get_recruitment_rules()
	if not Manager.instance.hub.reserve_currency(rules.manual_refresh_cost):
		return false
	var previous_candidates := candidates.duplicate()
	candidates.clear()
	_fill_candidate_pool(rules.candidate_capacity)
	if candidates.is_empty():
		candidates.assign(previous_candidates)
		Manager.instance.hub.add_currency(rules.manual_refresh_cost)
		return false
	recruitment_changed.emit()
	return true

func _initialize_recruitment() -> void:
	var rules := _get_recruitment_rules()
	var completed_operations := _get_completed_operation_count()
	_next_natural_arrival_operation = rules.get_next_arrival_operation(completed_operations)
	_fill_candidate_pool(rules.get_initial_pool_size())
	for home in _get_faction_homes():
		if not home.npc_roster_changed.is_connected(_on_roster_changed):
			home.npc_roster_changed.connect(_on_roster_changed)
	if Manager.instance != null and Manager.instance.reputation != null:
		if not Manager.instance.reputation.changed.is_connected(_on_guild_progress_changed):
			Manager.instance.reputation.changed.connect(_on_guild_progress_changed)
	recruitment_changed.emit()

func _on_roster_changed() -> void:
	if _ensure_emergency_recruit():
		recruitment_changed.emit()

func _on_guild_progress_changed() -> void:
	var rules := _get_recruitment_rules()
	var completed_operations := _get_completed_operation_count()
	var visitor_arrived := false
	while completed_operations >= _next_natural_arrival_operation:
		if candidates.size() < rules.candidate_capacity:
			visitor_arrived = _add_candidate() or visitor_arrived
		_next_natural_arrival_operation = rules.advance_arrival_operation(_next_natural_arrival_operation)
	if visitor_arrived:
		recruitment_changed.emit()
		if Manager.instance != null and Manager.instance.toast != null:
			Manager.instance.toast.notify(tr("RECRUITMENT_NEW_VISITOR_NOTICE"))

func _fill_candidate_pool(target_count: int) -> void:
	while candidates.size() < mini(target_count, _get_recruitment_rules().candidate_capacity):
		if not _add_candidate():
			break

func _add_candidate() -> bool:
	var profile := _select_candidate_profile()
	if profile == null:
		return false
	return _add_candidate_for_profile(profile)

func _add_candidate_for_profile(profile: NpcInfo) -> bool:
	if profile == null:
		return false
	_candidate_serial += 1
	var candidate_rank := _roll_candidate_rank()
	var candidate_traits := profile.traits.duplicate()
	var candidate := RecruitCandidate.new(
		StringName("candidate_%s" % _candidate_serial),
		generate_adventurer_name(),
		profile,
		candidate_rank,
		candidate_traits,
		_get_hire_cost(candidate_rank, candidate_traits.size())
	)
	candidates.append(candidate)
	return true

func _ensure_emergency_recruit() -> bool:
	var total_members := 0
	for home in _get_faction_homes():
		total_members += home.get_member_count()
	if total_members > 0:
		return false
	if candidates.is_empty() and not _add_candidate():
		return false
	var emergency := candidates[0]
	if emergency == null or emergency.hire_cost == 0:
		return false
	emergency.hire_cost = 0
	return true

func _select_candidate_profile() -> NpcInfo:
	var profiles := _get_recruitable_profiles()
	return profiles[_rng.randi_range(0, profiles.size() - 1)] if not profiles.is_empty() else null

func _get_recruitable_profiles(faction_filter: StringName = &"") -> Array[NpcInfo]:
	var profiles: Array[NpcInfo] = []
	if DataManager.instance == null:
		return profiles
	for profile: NpcInfo in DataManager.instance.npcs:
		if profile == null or profile.packed_scene == null:
			continue
		if faction_filter != &"" and profile.faction_id != faction_filter:
			continue
		if _get_faction_home(profile.faction_id) != null:
			profiles.append(profile)
	return profiles

func _get_faction_homes() -> Array[FactionHome]:
	var homes: Array[FactionHome] = []
	var owner_settlement := get_settlement()
	if owner_settlement == null:
		return homes
	for service: Interaction in owner_settlement.get_services(&"FactionHome"):
		var home := service as FactionHome
		if home != null:
			homes.append(home)
	return homes

func _get_faction_home(faction_id: StringName) -> FactionHome:
	var shared_home: FactionHome = null
	for home: FactionHome in _get_faction_homes():
		if home.faction_id == faction_id:
			return home
		if home.faction_id == &"":
			shared_home = home
	return shared_home

func _roll_candidate_rank() -> AdventurerRank.Rank:
	var prestige := Manager.instance.hub.prestige if Manager.instance != null and Manager.instance.hub != null else 0
	return _get_recruitment_rules().roll_candidate_rank(_rng, prestige)

func _get_hire_cost(candidate_rank: AdventurerRank.Rank, trait_count: int) -> int:
	return _get_recruitment_rules().get_hire_cost(candidate_rank, trait_count)

func _get_recruitment_rules() -> RecruitmentRules:
	if recruitment_rules == null:
		recruitment_rules = RecruitmentRules.new()
	return recruitment_rules

func _get_used_adventurer_names() -> Array[String]:
	var used_names: Array[String] = []
	for candidate: RecruitCandidate in candidates:
		if candidate != null and not candidate.display_name.is_empty():
			used_names.append(candidate.display_name)
	for home: FactionHome in _get_faction_homes():
		for member_instance: SceneInstance in home.get_roster_npcs():
			var npc := member_instance.node as NPC
			if npc != null:
				used_names.append(npc.get_display_name())
	return used_names

func _get_completed_operation_count() -> int:
	return Manager.instance.reputation.completed_quests if Manager.instance != null and Manager.instance.reputation != null else 0

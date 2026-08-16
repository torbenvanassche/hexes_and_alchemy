class_name Tavern extends SettlementService

@export var recreation_anchor: Node3D
@export_group("Recruitment")
@export_range(1, 10, 1) var candidate_capacity := 5
@export_range(1, 10, 1) var initial_candidate_count := 4
@export_range(1, 20, 1) var operations_per_natural_arrival := 2
@export_range(0, 1000, 1) var manual_refresh_cost := 15
@export_range(0, 1000, 1) var base_hire_cost := 15
@export_range(0, 1000, 1) var rank_hire_cost := 15
@export_range(0, 1000, 1) var trait_hire_cost := 2
@export_range(1, 100, 1) var prestige_per_rank_tier := 5
@export var maximum_candidate_rank: AdventurerRank.Rank = AdventurerRank.Rank.C

var buildable_structure: Buildable
var candidates: Array[RecruitCandidate] = []
var _candidate_serial := 0
var _next_natural_arrival_operation := 0
var _rng := RandomNumberGenerator.new()

signal recruitment_changed()
signal candidate_hired(candidate: RecruitCandidate, npc: NPC)

const FIRST_NAMES: Array[String] = [
	"Ada", "Bram", "Cora", "Dain", "Elia", "Finn", "Greta", "Hale",
	"Iris", "Joren", "Kessa", "Lio", "Mara", "Nils", "Orla", "Perrin",
	"Rhea", "Soren", "Tamsin", "Ulric", "Vera", "Wren", "Yara", "Zane",
]
const LAST_NAMES: Array[String] = [
	"Ash", "Briar", "Crow", "Dale", "Ember", "Fenn", "Grove", "Holt",
	"Iron", "Keen", "Lark", "Moor", "North", "Reed", "Stone", "Vale",
]

func _ready() -> void:
	super()
	buildable_structure = get_parent() as Buildable
	_initialize_recruitment.call_deferred()

func interact() -> void:
	open_additional_ui_windows()

func can_interact() -> bool:
	return buildable_structure == null or buildable_structure.current_step == self

func get_recreation_anchor() -> Node3D:
	return recreation_anchor

func get_candidates() -> Array[RecruitCandidate]:
	return candidates.duplicate()

func get_candidate_capacity() -> int:
	return candidate_capacity

func get_manual_refresh_cost() -> int:
	return manual_refresh_cost

func get_operations_until_next_arrival() -> int:
	return maxi(0, _next_natural_arrival_operation - _get_completed_operation_count())

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
	if Manager.instance.hub.currency < manual_refresh_cost:
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
	if not Manager.instance.hub.reserve_currency(manual_refresh_cost):
		return false
	var previous_candidates := candidates.duplicate()
	candidates.clear()
	_fill_candidate_pool(candidate_capacity)
	if candidates.is_empty():
		candidates.assign(previous_candidates)
		Manager.instance.hub.add_currency(manual_refresh_cost)
		return false
	recruitment_changed.emit()
	return true

func _initialize_recruitment() -> void:
	_rng.randomize()
	var completed_operations := _get_completed_operation_count()
	_next_natural_arrival_operation = completed_operations + operations_per_natural_arrival
	_fill_candidate_pool(mini(initial_candidate_count, candidate_capacity))
	if Manager.instance != null and Manager.instance.reputation != null:
		if not Manager.instance.reputation.changed.is_connected(_on_guild_progress_changed):
			Manager.instance.reputation.changed.connect(_on_guild_progress_changed)
	recruitment_changed.emit()

func _on_guild_progress_changed() -> void:
	var completed_operations := _get_completed_operation_count()
	var visitor_arrived := false
	while completed_operations >= _next_natural_arrival_operation:
		if candidates.size() < candidate_capacity:
			visitor_arrived = _add_candidate() or visitor_arrived
		_next_natural_arrival_operation += operations_per_natural_arrival
	if visitor_arrived:
		recruitment_changed.emit()
		if Manager.instance != null and Manager.instance.toast != null:
			Manager.instance.toast.notify(tr("RECRUITMENT_NEW_VISITOR_NOTICE"))

func _fill_candidate_pool(target_count: int) -> void:
	while candidates.size() < mini(target_count, candidate_capacity):
		if not _add_candidate():
			break

func _add_candidate() -> bool:
	var profile := _select_candidate_profile()
	if profile == null:
		return false
	_candidate_serial += 1
	var candidate_rank := _roll_candidate_rank()
	var candidate_traits := profile.traits.duplicate()
	var candidate := RecruitCandidate.new(
		StringName("candidate_%s" % _candidate_serial),
		_generate_candidate_name(),
		profile,
		candidate_rank,
		candidate_traits,
		_get_hire_cost(candidate_rank, candidate_traits.size())
	)
	candidates.append(candidate)
	return true

func _select_candidate_profile() -> NpcInfo:
	var priority_faction := _get_unrepresented_empty_faction()
	var profiles := _get_recruitable_profiles(priority_faction)
	if profiles.is_empty() and priority_faction != &"":
		profiles = _get_recruitable_profiles()
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

func _get_unrepresented_empty_faction() -> StringName:
	for home: FactionHome in _get_faction_homes():
		if home.get_member_count() > 0:
			continue
		var already_offered := candidates.any(func(candidate: RecruitCandidate) -> bool:
			return candidate != null and candidate.get_faction_id() == home.faction_id
		)
		if not already_offered:
			return home.faction_id
	return &""

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
	for home: FactionHome in _get_faction_homes():
		if home.faction_id == faction_id:
			return home
	return null

func _roll_candidate_rank() -> AdventurerRank.Rank:
	var prestige := Manager.instance.hub.prestige if Manager.instance != null and Manager.instance.hub != null else 0
	var unlocked_tiers := floori(float(prestige) / float(prestige_per_rank_tier))
	var highest_rank := mini(int(maximum_candidate_rank), unlocked_tiers)
	if highest_rank <= int(AdventurerRank.Rank.F):
		return AdventurerRank.Rank.F
	var rolled_rank := _rng.randi_range(int(AdventurerRank.Rank.F), highest_rank)
	return AdventurerRank.clamp_rank(rolled_rank)

func _get_hire_cost(candidate_rank: AdventurerRank.Rank, trait_count: int) -> int:
	return base_hire_cost + int(candidate_rank) * rank_hire_cost + trait_count * trait_hire_cost

func _generate_candidate_name() -> String:
	for _attempt in 12:
		var candidate_name := "%s %s" % [FIRST_NAMES.pick_random(), LAST_NAMES.pick_random()]
		if not _is_name_in_use(candidate_name):
			return candidate_name
	return "%s %s" % [FIRST_NAMES.pick_random(), _candidate_serial]

func _is_name_in_use(candidate_name: String) -> bool:
	for candidate: RecruitCandidate in candidates:
		if candidate != null and candidate.display_name == candidate_name:
			return true
	for home: FactionHome in _get_faction_homes():
		for member_instance: SceneInstance in home.get_roster_npcs():
			var npc := member_instance.node as NPC
			if npc != null and npc.get_display_name() == candidate_name:
				return true
	return false

func _get_completed_operation_count() -> int:
	return Manager.instance.reputation.completed_quests if Manager.instance != null and Manager.instance.reputation != null else 0

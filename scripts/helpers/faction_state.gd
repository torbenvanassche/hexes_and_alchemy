class_name FactionState
extends RefCounted

var id: StringName
var display_name: String
var roles: Array[String] = []
var responsibilities: Array[String] = []
var definition: FactionDefinition
var members: Array[NPC] = []
var completed_operations := 0
var failed_operations := 0
var last_activity := ""

func _init(_id: StringName, _display_name: String, _roles: Array[String], _responsibilities: Array[String] = []) -> void:
	id = _id
	display_name = _display_name
	roles = _roles
	responsibilities = _responsibilities

func apply_definition(value: FactionDefinition) -> void:
	definition = value
	if definition == null:
		return
	id = definition.id
	display_name = definition.display_name
	roles = definition.roles.duplicate()
	responsibilities = definition.responsibilities.duplicate()

func get_display_name() -> String:
	if definition != null:
		return definition.get_display_name()
	var translation_key := "FACTION_%s_NAME" % id.to_upper()
	var translated := tr(translation_key)
	if translated != translation_key:
		return translated
	return display_name if not display_name.is_empty() else String(id).capitalize()

func get_role_display_names() -> Array[String]:
	if definition != null:
		return definition.get_role_display_names()
	var labels: Array[String] = []
	for role: String in roles:
		var translation_key := "QUEST_ROLE_%s" % role.to_upper()
		var translated := tr(translation_key)
		labels.append(role.capitalize().replace("_", " ") if translated == translation_key else translated)
	return labels

func get_responsibility_display_names() -> Array[String]:
	if definition != null:
		return definition.get_responsibility_display_names()
	var labels: Array[String] = []
	for responsibility: String in responsibilities:
		var translated := tr(responsibility)
		labels.append(responsibility if translated == responsibility else translated)
	return labels

func supports_role(role_name: String) -> bool:
	if definition != null:
		return definition.supports_role(role_name)
	return roles.has(role_name)

func get_recovery_duration(base_duration: float) -> float:
	if definition != null:
		return definition.get_recovery_duration(base_duration)
	return maxf(0.0, base_duration)

func add_member(member: NPC) -> void:
	if member != null and not members.has(member):
		members.append(member)

func remove_member(member: NPC) -> void:
	members.erase(member)

func get_available_member_count() -> int:
	return members.filter(func(member: NPC) -> bool:
		return member != null and is_instance_valid(member) and member.is_available_for_quest()
	).size()

func get_available_members_for_role(role: String) -> Array[NPC]:
	var available: Array[NPC] = []
	for member: NPC in members:
		if member == null or not is_instance_valid(member):
			continue
		if member.is_available_for_quest() and member.can_perform_role(role):
			available.append(member)
	return available

func get_available_member_count_for_role(role: String) -> int:
	return get_available_members_for_role(role).size()

func get_working_member_count() -> int:
	return members.filter(func(member: NPC) -> bool:
		return member != null and is_instance_valid(member) and member.current_quest != null
	).size()

func get_resting_member_count() -> int:
	return members.filter(func(member: NPC) -> bool:
		return (
			member != null
			and is_instance_valid(member)
			and (
				member.is_state(NPC.NPCState.RESTING)
				or member.is_state(NPC.NPCState.RETURNING_HOME)
			)
		)
	).size()

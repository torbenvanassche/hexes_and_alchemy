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
	var translation_key := "FACTION_%s_NAME" % id.to_upper()
	var translated := tr(translation_key)
	return display_name if translated == translation_key else translated

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
		return member != null and is_instance_valid(member) and member.is_state(NPC.NPCState.RESTING)
	).size()

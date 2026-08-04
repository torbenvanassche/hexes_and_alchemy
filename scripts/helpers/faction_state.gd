class_name FactionState
extends RefCounted

var id: StringName
var display_name: String
var roles: Array[String] = []
var responsibilities: Array[String] = []
var members: Array[NPC] = []
var completed_operations := 0
var failed_operations := 0

func _init(_id: StringName, _display_name: String, _roles: Array[String], _responsibilities: Array[String] = []) -> void:
	id = _id
	display_name = _display_name
	roles = _roles
	responsibilities = _responsibilities

func add_member(member: NPC) -> void:
	if member != null and not members.has(member):
		members.append(member)

func remove_member(member: NPC) -> void:
	members.erase(member)

func get_available_member_count() -> int:
	return members.filter(func(member: NPC) -> bool:
		return member != null and is_instance_valid(member) and member.current_quest == null
	).size()

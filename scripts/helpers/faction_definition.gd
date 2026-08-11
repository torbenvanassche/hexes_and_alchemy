class_name FactionDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var roles: Array[String] = []
@export var responsibilities: Array[String] = []
@export var preferred_quest_types: Array[String] = []
@export_range(0.25, 4.0, 0.05) var rest_multiplier := 1.0

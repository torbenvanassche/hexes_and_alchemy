class_name GameConfig
extends Node

const FILE_PATH := "user://settings.ini"

var config := ConfigFile.new()

# Sub-settings
var input: InputSettings

func _ready() -> void:
	_load_or_create()

	input = InputSettings.new(config)

func _load_or_create() -> void:
	if FileAccess.file_exists(FILE_PATH):
		config.load(FILE_PATH)
	else:
		config.save(FILE_PATH)

func save() -> void:
	config.save(FILE_PATH)

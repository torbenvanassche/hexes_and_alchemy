class_name MarketSlotUI extends Control

@onready var content_slot_ui: ContentSlotUI = $"item";

@onready var h_box_container: HBoxContainer = $HBoxContainer
@onready var line_edit: LineEdit = $HBoxContainer/LineEdit
@onready var button: Button = $HBoxContainer/Button


var item_price: int = 0;

func get_slot() -> ContentSlotUI:
	return content_slot_ui;

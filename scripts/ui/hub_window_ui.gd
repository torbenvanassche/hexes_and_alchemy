class_name HubWindowUI
extends Control

signal tab_changed(tab_id: String)

@onready var inventory_button: Button = $VBox/TabButtons/Inventory
@onready var journal_button: Button = $VBox/TabButtons/Journal
@onready var operations_button: Button = $VBox/TabButtons/Operations
@onready var inventory_page: Control = $VBox/PageHost/InventoryPage
@onready var journal_page: Control = $VBox/PageHost/JournalPage
@onready var operations_page: Control = $VBox/PageHost/OperationsPage
@onready var inventory_ui: InventoryUI = $VBox/PageHost/InventoryPage/Margin/Scroll/GridCenter/InventoryHud

var active_tab := "operations"

func _ready() -> void:
	_register_tab_button(inventory_button, "inventory")
	_register_tab_button(journal_button, "journal")
	_register_tab_button(operations_button, "operations")
	_connect_hub_signals()
	_refresh_inventory()
	_show_tab(active_tab)

func on_enter() -> void:
	_connect_hub_signals()
	_refresh_inventory()
	_show_tab(active_tab)

func show_tab(tab_id: String) -> void:
	_show_tab(tab_id)

func _register_tab_button(button: Button, tab_id: String) -> void:
	if button != null and not button.pressed.is_connected(_show_tab.bind(tab_id)):
		button.pressed.connect(_show_tab.bind(tab_id))

func _show_tab(tab_id: String) -> void:
	if not ["inventory", "journal", "operations"].has(tab_id):
		tab_id = "operations"
	active_tab = tab_id
	if inventory_page != null:
		inventory_page.visible = active_tab == "inventory"
	if journal_page != null:
		journal_page.visible = active_tab == "journal"
	if operations_page != null:
		operations_page.visible = active_tab == "operations"
	if inventory_button != null:
		inventory_button.button_pressed = active_tab == "inventory"
	if journal_button != null:
		journal_button.button_pressed = active_tab == "journal"
	if operations_button != null:
		operations_button.button_pressed = active_tab == "operations"
	if active_tab == "journal" and journal_page != null and journal_page.has_method("on_enter"):
		journal_page.on_enter()
	tab_changed.emit(active_tab)

func _connect_hub_signals() -> void:
	if Manager.instance == null or Manager.instance.hub == null:
		return
	if not Manager.instance.hub.changed.is_connected(_refresh_inventory):
		Manager.instance.hub.changed.connect(_refresh_inventory)

func _refresh_inventory() -> void:
	if inventory_ui == null or Manager.instance == null or Manager.instance.hub == null:
		return
	inventory_ui.inventory = Manager.instance.hub.stockpile

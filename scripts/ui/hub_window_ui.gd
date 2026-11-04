class_name HubWindowUI
extends Control

signal tab_changed(tab_id: String)

@onready var inventory_button: Button = $Spread/Contents/Stores
@onready var operations_button: Button = $Spread/Contents/Commissions
@onready var projects_button: Button = $Spread/Contents/Village
@onready var inventory_page: Control = $Spread/PageHost/InventoryPage
@onready var operations_page: Control = $Spread/PageHost/OperationsPage
@onready var projects_page: Control = $Spread/PageHost/ProjectsPage
@onready var inventory_ui: InventoryUI = $Spread/PageHost/InventoryPage/InventoryHud
@onready var people_page: Control = $Spread/PageHost/PeoplePage
@onready var treasury: Label = $Spread/Contents/Treasury

var active_tab := "projects"
var _buttons: Dictionary = {}
var _pages: Dictionary = {}

func _ready() -> void:
	_buttons = {"projects": projects_button, "operations": operations_button, "inventory": inventory_button,
		"people": $Spread/Contents/People, "notes": $Spread/Contents/Notes}
	_pages = {"projects": projects_page, "operations": operations_page, "inventory": inventory_page,
		"people": $Spread/PageHost/PeoplePage, "notes": $Spread/PageHost/NotesPage}
	_register_tab_button(inventory_button, "inventory")
	_register_tab_button(operations_button, "operations")
	_register_tab_button(projects_button, "projects")
	_register_tab_button($Spread/Contents/People, "people")
	_register_tab_button($Spread/Contents/Notes, "notes")
	_connect_hub_signals()
	_refresh_inventory()
	_show_tab(active_tab)

func on_enter() -> void:
	_connect_hub_signals()
	_refresh_inventory()
	_show_tab(active_tab)

func show_tab(tab_id: String) -> void:
	_show_tab(tab_id)

func show_people(faction_id: StringName = &"") -> void:
	_show_tab("people")
	people_page.show_faction(faction_id)

func _register_tab_button(button: Button, tab_id: String) -> void:
	if button != null and not button.pressed.is_connected(_show_tab.bind(tab_id)):
		button.pressed.connect(_show_tab.bind(tab_id))

func _show_tab(tab_id: String) -> void:
	if not ["inventory", "operations", "projects", "people", "notes"].has(tab_id):
		tab_id = "projects"
	active_tab = tab_id
	for key: String in _pages:
		_pages[key].visible = key == active_tab
		_buttons[key].set_pressed_no_signal(key == active_tab)
	if active_tab == "notes" and is_node_ready():
		$Spread/PageHost/NotesPage.on_enter()
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
	treasury.text = tr("CAMPAIGN_TREASURY") % Manager.instance.hub.currency

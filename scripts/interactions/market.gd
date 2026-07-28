class_name Market extends SettlementService

@export var buy_menu: Array[ContentSlotResource] = []
@onready var buy_inventory: Inventory = $BuyInventory
@onready var sell_inventory: Inventory = $SellInventory

var _applied_buy_menu_signature: String = ""

func _ready() -> void:
	super();
	_apply_buy_menu();

func interact() -> void:
	DataManager.instance.get_scene_by_name("market_ui").queue(_open_window)
	
func can_interact() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)

func refresh_service_state() -> void:
	_apply_buy_menu()
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	_setup_ui_window(window_instance)
	var inventory_ui: MarketUI = (window_instance.node as DraggableControl).content as MarketUI;
	inventory_ui.setup(buy_inventory, sell_inventory, Manager.instance.player_instance.inventory);
	window_instance.on_enter.emit();
	open_additional_ui_windows()

func _apply_buy_menu() -> void:
	var resolved_buy_menu := _get_resolved_buy_menu()
	var signature := _get_buy_menu_signature(resolved_buy_menu)
	if signature == _applied_buy_menu_signature:
		return;
	_applied_buy_menu_signature = signature

	if buy_inventory == null:
		return;
	buy_inventory.data.clear();
	buy_inventory.max_slots = resolved_buy_menu.size();
	buy_inventory.unlocked_slots = resolved_buy_menu.size();
	for slot in resolved_buy_menu:
		if slot == null:
			continue;
		var inventory_slot := slot.duplicate(true) as ContentSlotResource;
		if inventory_slot.maxcount <= 0:
			inventory_slot.maxcount = maxi(1, inventory_slot.count);
		inventory_slot.is_unlocked = true;
		buy_inventory.add_slot(inventory_slot);
	buy_inventory.changed.emit()

func _get_resolved_buy_menu() -> Array[ContentSlotResource]:
	var resolved: Array[ContentSlotResource] = []
	resolved.append_array(buy_menu)

	var owner_settlement := get_settlement()
	if owner_settlement == null:
		return resolved

	for upgrade: SettlementUpgradeInfo in owner_settlement.upgrade_requirements:
		if upgrade == null or upgrade.target_level > owner_settlement.level:
			continue
		resolved.append_array(upgrade.market_buy_menu)

	return resolved

func _get_buy_menu_signature(slots: Array[ContentSlotResource]) -> String:
	var parts: Array[String] = []
	for slot in slots:
		if slot == null:
			parts.append("<null>")
			continue
		var content := slot.get_content()
		var content_key := content.resource_path if content != null else "<empty>"
		parts.append("%s:%s:%s" % [content_key, slot.count, slot.maxcount])
	return "|".join(parts)

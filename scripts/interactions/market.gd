class_name Market extends SettlementService

@export var buy_menu: Array[ContentSlotResource] = []
@onready var buy_inventory: Inventory = $BuyInventory
@onready var sell_inventory: Inventory = $SellInventory

func _ready() -> void:
	super();
	_apply_buy_menu();

func interact() -> void:
	DataManager.instance.get_scene_by_name("market_ui").queue(_open_window)
	
func can_interact() -> bool:
	return not window_instance || not SceneManager.is_visible(window_instance)
	
func _open_window(window_info: SceneInfo) -> void:
	window_instance = SceneManager.add(window_info, false);
	_setup_ui_window(window_instance)
	var inventory_ui: MarketUI = (window_instance.node as DraggableControl).content as MarketUI;
	inventory_ui.setup(buy_inventory, sell_inventory, Manager.instance.player_instance.inventory);
	window_instance.on_enter.emit();
	open_additional_ui_windows()

func _apply_buy_menu() -> void:
	if buy_menu.is_empty():
		return;
	if buy_inventory == null:
		return;
	buy_inventory.data.clear();
	buy_inventory.max_slots = buy_menu.size();
	buy_inventory.unlocked_slots = buy_menu.size();
	for slot in buy_menu:
		if slot == null:
			continue;
		var inventory_slot := slot.duplicate(true) as ContentSlotResource;
		if inventory_slot.maxcount <= 0:
			inventory_slot.maxcount = maxi(1, inventory_slot.count);
		inventory_slot.is_unlocked = true;
		buy_inventory.add_slot(inventory_slot);

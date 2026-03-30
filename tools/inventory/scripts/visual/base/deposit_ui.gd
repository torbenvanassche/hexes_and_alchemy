class_name DepositUI extends InventoryUI

@onready var complete_order: Button = $"../../complete_order"

func on_enter() -> void:
	complete_order.disabled = not inventory.is_full();
	if not inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.connect(_on_inventory_changed)
	
func _on_inventory_changed() -> void:
	complete_order.disabled = not inventory.is_full();

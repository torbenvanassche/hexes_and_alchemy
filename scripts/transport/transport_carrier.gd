class_name TransportCarrier
extends Resource

## Swap the carrier definition for a later horse-and-cart upgrade.
@export var name_key := "SHIPMENT_PACKHORSE"
@export_range(1, 100, 1) var capacity := 8
@export_range(0.5, 10.0, 0.1) var travel_speed := 2.2
@export var scene: PackedScene

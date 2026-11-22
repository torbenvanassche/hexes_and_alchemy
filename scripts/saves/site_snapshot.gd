class_name SiteSnapshot
extends RefCounted

## Site persistence contract, separate from world reconstruction order.
const STATE_FIELDS := ["state_machine", "depth", "_last_stable_state", "_pending_reward", "_pending_behaviour", "_pending_outcome", "_pending_reveal_occupation", "_loot_claimed", "lost_equipment", "lost_adventurer_names", "_regrow_timer", "_overgrow_timer", "_wither_timer", "candidates", "_candidate_serial", "_name_serial", "_next_natural_arrival_operation", "_rng", "buy_inventory", "sell_inventory", "transport_stable_tile", "transport_stable_approach"]
const DISCOVERY_FIELDS := ["discovery_id", "discovery_resolved", "salvaged_remnants", "reinforced_uses", "temporary_supports", "protected_uses", "archive_recorded"]

static func capture(node: Node, codec: SaveCodec) -> Dictionary[String, Variant]:
	var fields := codec.fields(node, STATE_FIELDS)
	fields.merge(codec.fields(node, DISCOVERY_FIELDS))
	return fields

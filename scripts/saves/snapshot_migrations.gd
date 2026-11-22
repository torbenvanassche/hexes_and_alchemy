class_name SnapshotMigrations
extends RefCounted

const CURRENT_SCHEMA := 2

static func upgrade(data: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	# New fields are optional in v1; saved reservations and outcomes stay authoritative.
	var version := int(data.get("schema_version", 1))
	if version < 2:
		if data.has("hub") and not data.hub.has("recruitment_prestige"):
			data.hub["recruitment_prestige"] = int(data.hub.get("prestige", 0))
	data["schema_version"] = CURRENT_SCHEMA
	return data

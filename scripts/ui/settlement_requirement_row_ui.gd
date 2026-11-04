class_name SettlementRequirementRowUI
extends HBoxContainer

@onready var state_label: Label = $State
@onready var requirement_label: Label = $Requirement

func setup(text: String, complete: bool) -> void:
	if not is_node_ready():
		call_deferred("setup", text, complete)
		return
	state_label.text = tr("SETTLEMENT_UPGRADE_READY") if complete else tr("SETTLEMENT_UPGRADE_MISSING")
	state_label.modulate = GameUI.SUCCESS if complete else GameUI.WARNING
	requirement_label.text = text

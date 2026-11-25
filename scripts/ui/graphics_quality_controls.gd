extends VBoxContainer

@onready var _selectors: Dictionary[StringName, OptionButton] = {
	&"anti_aliasing": %Antialiasing,
	&"render_scale": %RenderScale,
	&"shadow_quality": %Shadows,
	&"ambient_occlusion_quality": %Occlusion,
	&"vsync": %VSync,
	&"frame_limit": %FrameLimit,
}
@onready var _settings: GraphicsSettings = Manager.instance.graphics

func _ready() -> void:
	for setting: StringName in _selectors:
		var selector := _selectors[setting]
		var choices := _settings.get_options(setting)
		for value: int in choices:
			var label := tr(choices[value])
			if setting == &"render_scale" or (setting == &"frame_limit" and value > 0):
				label = label % value
			selector.add_item(label, value)
		selector.disabled = choices.size() == 1
		selector.item_selected.connect(_on_option_selected.bind(setting, selector))
	if %Occlusion.disabled:
		%Occlusion.tooltip_text = tr("GRAPHICS_AMBIENT_OCCLUSION_UNAVAILABLE")
	%Reset.pressed.connect(_settings.restore_defaults)
	_settings.changed.connect(_sync_selections)
	_sync_selections()

func _sync_selections() -> void:
	for setting: StringName in _selectors:
		var selector := _selectors[setting]
		selector.select(selector.get_item_index(_settings.get_choice(setting)))

func _on_option_selected(index: int, setting: StringName, selector: OptionButton) -> void:
	_settings.set_choice(setting, selector.get_item_id(index))

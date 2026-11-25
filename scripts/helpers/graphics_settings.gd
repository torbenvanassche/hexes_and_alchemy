class_name GraphicsSettings extends RefCounted

signal changed

enum AntiAliasing { OFF, FXAA, SMAA, TAA, MSAA_2X, MSAA_4X }
enum Occlusion { OFF, LOW, BALANCED, HIGH }

const SECTION := "graphics"
const SHADOW_SIZES := [2048, 4096, 8192]
const SHADOW_FILTERS := [
	RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
]
const OPTIONS := {
	&"anti_aliasing": {
		AntiAliasing.OFF: "GRAPHICS_OFF", AntiAliasing.FXAA: "GRAPHICS_AA_FXAA",
		AntiAliasing.SMAA: "GRAPHICS_AA_SMAA", AntiAliasing.TAA: "GRAPHICS_AA_TAA",
		AntiAliasing.MSAA_2X: "GRAPHICS_AA_MSAA_2X", AntiAliasing.MSAA_4X: "GRAPHICS_AA_MSAA_4X",
	},
	&"render_scale": {60: "%d%%", 75: "%d%%", 85: "%d%%", 100: "%d%%"},
	&"shadow_quality": {0: "GRAPHICS_QUALITY_LOW", 1: "GRAPHICS_QUALITY_BALANCED", 2: "GRAPHICS_QUALITY_HIGH"},
	&"ambient_occlusion_quality": {
		Occlusion.OFF: "GRAPHICS_OFF", Occlusion.LOW: "GRAPHICS_QUALITY_LOW",
		Occlusion.BALANCED: "GRAPHICS_QUALITY_BALANCED", Occlusion.HIGH: "GRAPHICS_QUALITY_HIGH",
	},
	&"vsync": {0: "GRAPHICS_OFF", 1: "GRAPHICS_ON"},
	&"frame_limit": {0: "GRAPHICS_UNLIMITED", 30: "GRAPHICS_FPS_VALUE", 60: "GRAPHICS_FPS_VALUE",
		90: "GRAPHICS_FPS_VALUE", 120: "GRAPHICS_FPS_VALUE", 144: "GRAPHICS_FPS_VALUE"},
}
const DEFAULTS := {
	&"anti_aliasing": AntiAliasing.TAA,
	&"render_scale": 100,
	&"shadow_quality": 2,
	&"ambient_occlusion_quality": Occlusion.BALANCED,
	&"vsync": 1,
	&"frame_limit": 0,
}

var _config: ConfigFile
var _window: Window
var _environment: Environment
var _renderer: StringName
var _values: Dictionary = {}

func _init(config: ConfigFile, window: Window, environment: Environment) -> void:
	_config = config
	_window = window
	_environment = environment
	_renderer = RenderingServer.get_current_rendering_method()
	for setting: StringName in DEFAULTS:
		var fallback := _get_saved_default(setting)
		var saved := int(_config.get_value(SECTION, setting, fallback))
		_values[setting] = saved if OPTIONS[setting].has(saved) else DEFAULTS[setting]
		_apply_setting(setting)

func _get_saved_default(setting: StringName) -> int:
	# Preserve the choices made with the previous TAA and ambient occlusion switches.
	match setting:
		&"anti_aliasing":
			return AntiAliasing.TAA if _config.get_value(SECTION, "temporal_aa", true) else AntiAliasing.OFF
		&"ambient_occlusion_quality":
			return Occlusion.BALANCED if _config.get_value(SECTION, "ambient_occlusion", true) else Occlusion.OFF
	return DEFAULTS[setting]

func get_options(setting: StringName) -> Dictionary:
	var choices: Dictionary = OPTIONS[setting].duplicate()
	if setting == &"anti_aliasing":
		if _renderer != &"forward_plus":
			choices.erase(AntiAliasing.TAA)
		if _renderer == &"gl_compatibility":
			choices.erase(AntiAliasing.FXAA)
			choices.erase(AntiAliasing.SMAA)
	elif setting == &"ambient_occlusion_quality" and _renderer != &"forward_plus":
		for quality in [Occlusion.LOW, Occlusion.BALANCED, Occlusion.HIGH]:
			choices.erase(quality)
	return choices

func get_choice(setting: StringName) -> int:
	var value: int = _values[setting]
	var available := get_options(setting)
	return value if available.has(value) else available.keys()[0]

func set_choice(setting: StringName, value: int) -> void:
	if not get_options(setting).has(value) or _values[setting] == value:
		return
	_set_value(setting, value)
	changed.emit()

func restore_defaults() -> void:
	var updated := false
	for setting: StringName in DEFAULTS:
		var value: int = DEFAULTS[setting]
		if _values[setting] != value:
			_set_value(setting, value)
			updated = true
	if updated:
		changed.emit()

func _set_value(setting: StringName, value: int) -> void:
	_values[setting] = value
	_config.set_value(SECTION, setting, value)
	_apply_setting(setting)

func _apply_setting(setting: StringName) -> void:
	var value := get_choice(setting)
	match setting:
		&"anti_aliasing":
			_apply_anti_aliasing(value)
		&"render_scale":
			_window.scaling_3d_scale = float(value) / 100.0
		&"shadow_quality":
			RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZES[value], false)
			RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTERS[value])
		&"ambient_occlusion_quality":
			_apply_occlusion(value)
		&"vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value == 1 else DisplayServer.VSYNC_DISABLED)
		&"frame_limit":
			Engine.max_fps = value

func _apply_anti_aliasing(mode: int) -> void:
	_window.use_taa = mode == AntiAliasing.TAA
	match mode:
		AntiAliasing.FXAA: _window.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		AntiAliasing.SMAA: _window.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		_: _window.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	match mode:
		AntiAliasing.MSAA_2X: _window.msaa_3d = Viewport.MSAA_2X
		AntiAliasing.MSAA_4X: _window.msaa_3d = Viewport.MSAA_4X
		_: _window.msaa_3d = Viewport.MSAA_DISABLED

func _apply_occlusion(quality: int) -> void:
	if _environment == null:
		return
	_environment.ssao_enabled = quality != Occlusion.OFF
	if not _environment.ssao_enabled:
		return
	var preset := RenderingServer.ENV_SSAO_QUALITY_MEDIUM
	match quality:
		Occlusion.LOW: preset = RenderingServer.ENV_SSAO_QUALITY_LOW
		Occlusion.HIGH: preset = RenderingServer.ENV_SSAO_QUALITY_HIGH
	const PREFIX := "rendering/environment/ssao/"
	RenderingServer.environment_set_ssao_quality(
		preset, quality != Occlusion.HIGH and ProjectSettings.get_setting(PREFIX + "half_size", true),
		ProjectSettings.get_setting(PREFIX + "adaptive_target", 0.5),
		ProjectSettings.get_setting(PREFIX + "blur_passes", 2),
		ProjectSettings.get_setting(PREFIX + "fadeout_from", 50.0),
		ProjectSettings.get_setting(PREFIX + "fadeout_to", 300.0)
	)

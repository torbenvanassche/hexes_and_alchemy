extends PanelContainer

var _target: WeakRef
var _text := ""
var _uppercase := false

func _process(_delta: float) -> void:
	if visible and (_target == null or not is_instance_valid(_target.get_ref()) or not _target.get_ref().is_visible_in_tree()):
		dismiss(false)

func _ready() -> void:
	for character in "1234567890qwertyuiopasdfghjkl-zxcvbnm_.'":
		var button := Button.new()
		button.text = character
		button.theme_type_variation = &"KeyboardKey"
		$Content/Keys.add_child(button)
		button.pressed.connect(func() -> void: _append(button.text))
	$Content/Actions/Space.pressed.connect(_append.bind(" "))
	$Content/Actions/Delete.pressed.connect(func() -> void:
		_text = _text.left(maxi(0, _text.length() - 1))
		_refresh())
	$Content/Actions/Shift.pressed.connect(func() -> void:
		_uppercase = not _uppercase
		for button: Button in $Content/Keys.get_children():
			button.text = button.text.to_upper() if _uppercase else button.text.to_lower())
	$Content/Actions/Done.pressed.connect(dismiss.bind(true))

func open_for(target: LineEdit) -> void:
	_target = weakref(target)
	_text = target.text
	_refresh()
	show()
	$Content/Keys.get_child(0).grab_focus()

func _append(character: String) -> void:
	var target := _target.get_ref() as LineEdit
	if target == null: return
	if target.max_length == 0 or _text.length() < target.max_length:
		_text += character
	_refresh()

func _refresh() -> void:
	$Content/Preview.text = _text + "▏"

func dismiss(apply: bool) -> void:
	hide()
	var target := _target.get_ref() as LineEdit if _target != null else null
	if is_instance_valid(target):
		if apply:
			target.text = _text
			target.text_changed.emit(_text)
		target.grab_focus()
	_target = null

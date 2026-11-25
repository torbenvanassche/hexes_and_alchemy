extends CanvasLayer

var _last_focus: WeakRef
var _last_root: WeakRef
var _focus_history: Dictionary[int, WeakRef] = {}
var _focus_paths: Dictionary[int, NodePath] = {}
var _focus_keys: Dictionary[int, String] = {}
var _scroll_remainder := 0.0

func active_root() -> Node:
	if $Keyboard.visible: return $Keyboard
	for index in range(SceneManager.ui_stack.size() - 1, -1, -1):
		var scene: SceneInfo = SceneManager.ui_stack[index]
		var instances := scene.get_live_instances()
		for instance_index in range(instances.size() - 1, -1, -1):
			if SceneManager.is_visible(instances[instance_index]): return instances[instance_index].node
	return null

func focusable_controls(root: Node) -> Array[Control]:
	var controls: Array[Control] = []
	_collect_controls(root, controls)
	return controls

func restore_focus(root: Node) -> Control:
	var key: String = _focus_keys.get(root.get_instance_id(), "")
	if not key.is_empty():
		for control: Control in focusable_controls(root):
			if str(control.get_meta("controller_focus_key", "")) == key: return control
	var path: NodePath = _focus_paths.get(root.get_instance_id(), NodePath())
	var control := root.get_node_or_null(path) as Control if not path.is_empty() else null
	if control != null and control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled): return control
	return null

func _collect_controls(node: Node, controls: Array[Control]) -> void:
	if node.is_queued_for_deletion(): return
	if node is Control and not node.is_visible_in_tree(): return
	if node is Control and node.focus_mode == Control.FOCUS_ALL and not (node is BaseButton and node.disabled):
		controls.append(node)
	for child in node.get_children(): _collect_controls(child, controls)

func _process(delta: float) -> void:
	var controller := InputManager.is_device(InputManager.InputDevice.CONTROLLER)
	var root := active_root()
	var owner := get_viewport().gui_get_focus_owner()
	var placement := WorldPlacement.structure != null
	$Bar.visible = controller and not WorldLoading.blocks_input and is_instance_valid(Manager.instance)
	$Details.visible = false
	$Bar/Prompts/Navigation.visible = root != null
	$Bar/Prompts/Scroll.visible = root != null and _scroll_target(owner, root) != null
	if not controller:
		ContentSlotUI.cancel_controller_transfer()
		return
	if root == null:
		ContentSlotUI.cancel_controller_transfer()
		if placement:
			$Bar/Prompts/Confirm.configure("primary_action", "PLACEMENT_PLACE")
			$Bar/Prompts/Back.configure("cancel", "UI_BACK")
			$Bar/Prompts/Previous.configure("camera_rotate_left", "UI_ROTATE_LEFT")
			$Bar/Prompts/Next.configure("camera_rotate_right", "UI_ROTATE_RIGHT")
			$Bar/Prompts/Special.hide()
		else:
			$Bar/Prompts/Confirm.configure("primary_action", "UI_INTERACT")
			$Bar/Prompts/Back.configure("pause", "KEYBIND_PAUSE")
			$Bar/Prompts/Previous.configure("inventory", "GUILD_JOURNAL_STORES")
			$Bar/Prompts/Next.configure("journal", "GUILD_JOURNAL_TITLE")
			$Bar/Prompts/Special.configure("hub", "GUILD_JOURNAL_VILLAGE")
			$Bar/Prompts/Special.show()
		return
	$Bar/Prompts/Previous.configure("ui_focus_prev", "UI_PREVIOUS_CONTROL")
	$Bar/Prompts/Next.configure("ui_focus_next", "UI_NEXT_CONTROL")
	$Bar/Prompts/Back.configure("cancel", "UI_CANCEL_TRANSFER" if ContentSlotUI.controller_transfer_active() else "UI_BACK")
	if _last_root == null or _last_root.get_ref() != root:
		if _last_root != null and is_instance_valid(_last_root.get_ref()) and _last_focus != null:
			_focus_history[_last_root.get_ref().get_instance_id()] = _last_focus
		_last_root = weakref(root)
		var saved: WeakRef = _focus_history.get(root.get_instance_id())
		if saved != null and is_instance_valid(saved.get_ref()) and saved.get_ref().is_visible_in_tree():
			saved.get_ref().grab_focus()
			owner = saved.get_ref()
	if owner != null:
		_last_focus = weakref(owner)
		if root.is_ancestor_of(owner):
			_focus_paths[root.get_instance_id()] = root.get_path_to(owner)
			_focus_keys[root.get_instance_id()] = str(owner.get_meta("controller_focus_key", ""))
		var tooltip := tr(owner.tooltip_text)
		if owner is LineEdit and owner.get_parent() is SpinBox:
			tooltip = tr("UI_ADJUST_VALUE") % [InputManager.action_label("ui_left"), InputManager.action_label("ui_right"), InputManager.action_label("ui_focus_prev"), InputManager.action_label("ui_focus_next")] + ("\n" + tooltip if not tooltip.is_empty() else "")
		if not tooltip.is_empty():
			$Details/Text.text = tooltip
			$Details.show()
	var slot := owner as ContentSlotUI
	var accept_key := "UI_CONFIRM"
	if slot != null and slot.can_drag:
		accept_key = "UI_TRANSFER_TO" if ContentSlotUI.controller_transfer_active() else "UI_PICK_UP"
		if slot is EquipmentSlotUI and not ContentSlotUI.controller_transfer_active(): accept_key = "UI_EQUIP"
	if owner is LineEdit: accept_key = "UI_EDIT_TEXT"
	$Bar/Prompts/Confirm.configure("ui_accept", "UI_REBIND_WAIT" if InputManager.is_remapping else accept_key)
	$Bar/Prompts/Special.visible = slot is PlaceableContentSlotUI and slot.can_drag and slot._get_dragged_placeable() != null and not ContentSlotUI.controller_transfer_active()
	if $Bar/Prompts/Special.visible: $Bar/Prompts/Special.configure("ui_slot_place", "PLACEMENT_PLACE")
	# Right stick scrolls long descriptions and lists without changing selection.
	if not InputManager.is_remapping:
		var scroll := _scroll_target(owner, root)
		if scroll != null:
			var axis := Input.get_action_strength("ui_scroll_down") - Input.get_action_strength("ui_scroll_up")
			if absf(axis) > 0.1:
				_scroll_remainder += axis * 600.0 * delta
				var pixels := int(_scroll_remainder)
				scroll.scroll_vertical += pixels
				_scroll_remainder -= pixels

func _scroll_target(owner: Node, root: Node) -> ScrollContainer:
	var node := owner
	while node != null:
		if node is ScrollContainer: return node
		if node == root: break
		node = node.get_parent()
	for child in root.find_children("*", "ScrollContainer", true, false):
		if child.is_visible_in_tree(): return child
	return null

func _input(event: InputEvent) -> void:
	if InputManager.is_remapping or not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	var root := active_root()
	if root == null: return
	var owner := get_viewport().gui_get_focus_owner()
	if $Keyboard.visible and event.is_action_pressed("cancel"):
		$Keyboard.dismiss(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel") and ContentSlotUI.controller_transfer_active():
		ContentSlotUI.cancel_controller_transfer()
		get_viewport().set_input_as_handled()
		return
	# Shoulder traversal is independent of spatial navigation and reaches every field.
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls := focusable_controls(root)
		if not controls.is_empty():
			var index := controls.find(owner)
			var direction := 1 if event.is_action_pressed("ui_focus_next") else -1
			controls[posmod(index + direction, controls.size())].grab_focus()
		get_viewport().set_input_as_handled()
		return
	# SpinBox delegates focus to its LineEdit, whose arrows otherwise edit text.
	if owner is LineEdit and owner.get_parent() is SpinBox:
		var spin := owner.get_parent() as SpinBox
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if spin.editable:
				spin.value += spin.step * (-1 if event.is_action_pressed("ui_left") else 1)
			get_viewport().set_input_as_handled()
	elif owner is LineEdit and owner.editable and event.is_action_pressed("ui_accept"):
		$Keyboard.open_for(owner)
		get_viewport().set_input_as_handled()

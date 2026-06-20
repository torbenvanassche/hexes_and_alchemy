class_name InputDisplayer extends Button

@export var action_name: Label;
@export var action_image: TextureRect;
@export var rebinding_text: Label;

@export var action_texture: Texture2D;

func set_key(string: String, event: InputEvent) -> void:
	var texture := AtlasTexture.new()
	var entry: Array = []
	if event is InputEventKey:
		texture.atlas = InputManager.keyboard_image
		entry = InputManager.keys.keyboard.get(string)
	elif event is InputEventMouseButton:
		texture.atlas = InputManager.keyboard_image
		entry = InputManager.keys.mouse.get(string)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		texture.atlas = InputManager.controller_image
		entry = InputManager.keys.controller.get(string)
	action_image.texture = texture
	if entry:
		rebinding_text.visible = false;
		action_image.visible = true;
		var tex_region := Rect2(entry[0] * InputManager.keys.rect_size[0], entry[1] * InputManager.keys.rect_size[1], InputManager.keys.rect_size[0], InputManager.keys.rect_size[1]);
		(action_image.texture as AtlasTexture).region = tex_region;

func set_label(string: String) -> void:
	action_name.text = tr(string);
	
func set_rebinding() -> void:
	rebinding_text.visible = true;
	action_image.visible = false;

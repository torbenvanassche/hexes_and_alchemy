class_name InputDisplayer extends Button

@export var action_name: Label;
@export var action_image: TextureRect;
@export var rebinding_text: Label;

@export var action_texture: Texture2D;

func set_key(string: String, event: InputEvent) -> void:
	action_image.texture = InputManager.get_input_texture()
	var entry: Array;
	if event is InputEventKey:
		entry = InputManager.keys.keyboard.get(string)
	elif event is InputEventMouseButton:
		string = string.trim_suffix(" (double click)")
		entry = InputManager.keys.mouse.get(string);
	if entry:
		rebinding_text.visible = false;
		action_image.visible = true;
		var tex_region := Rect2(entry[0] * InputManager.keys.rect_size[0], entry[1] * InputManager.keys.rect_size[1], InputManager.keys.rect_size[0], InputManager.keys.rect_size[1]);
		(action_image.texture as AtlasTexture).region = tex_region;

func set_label(string: String) -> void:
	action_name.text = string;
	
func set_rebinding() -> void:
	rebinding_text.visible = true;
	action_image.visible = false;

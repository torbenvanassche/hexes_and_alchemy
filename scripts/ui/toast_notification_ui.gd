class_name ToastNotificationUI
extends PanelContainer

@onready var accent: ColorRect = $Margin/Content/Accent
@onready var icon: TextureRect = $Margin/Content/Icon
@onready var message: RichTextLabel = $Margin/Content/Message

var default_accent_color := GameUI.MUTED

func setup(
	text: String,
	accent_color: Color = Color.TRANSPARENT,
	texture: Texture2D = null,
	icon_color: Color = Color.WHITE
) -> void:
	message.text = text
	accent.color = accent_color if accent_color != Color.TRANSPARENT else default_accent_color
	icon.texture = texture
	icon.modulate = icon_color
	icon.visible = texture != null

extends Node2D
class_name Main

const TITLE_TEXT: String = "Risk‑lite (Godot 4.4.1)"
const CONSOLE_GREETING: String = "Project initialized. Press R to reload the scene."

@onready var _title_label: Label = $TitleLabel
@onready var _background: ColorRect = $Background

func _ready() -> void:
	if _background:
		_background.set_anchors_preset(Control.LayoutPreset.PRESET_FULL_RECT)
		_background.offset_left = 0
		_background.offset_top = 0
		_background.offset_right = 0
		_background.offset_bottom = 0

	if _title_label:
		_title_label.set_anchors_preset(Control.LayoutPreset.PRESET_FULL_RECT)
		_title_label.offset_left = 0
		_title_label.offset_top = 0
		_title_label.offset_right = 0
		_title_label.offset_bottom = 0
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_title_label.text = TITLE_TEXT

	print(CONSOLE_GREETING)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

extends Area2D
class_name Territory

## ===== Сигналы =====
signal territory_clicked(territory: Territory)
signal units_changed(territory: Territory, new_units: int)
signal controller_changed(territory: Territory, new_controller_id: int)

## ===== Экспортируемые параметры =====
@export var territory_id: int = -1
@export var controller_id: int = 0 ## 0 — человек, 1 — ИИ_1, 2 — ИИ_2
@export var start_units: int = 10
@export var allow_clicks: bool = true
@export var rect_size: Vector2 = Vector2(200, 120)
@export var growth_per_tick: int = 1 ## для будущего спавна/прироста

## ===== Константы =====
const CONTROLLER_HUMAN: int = 0
const CONTROLLER_AI_1: int = 1
const CONTROLLER_AI_2: int = 2

const CONTROLLER_COLORS: Array[Color] = [
	Color(0.20, 0.65, 1.00, 1.0), ## HUMAN — голубой
	Color(1.00, 0.45, 0.20, 1.0), ## AI_1 — оранжевый
	Color(0.40, 0.90, 0.40, 1.0)  ## AI_2 — зелёный
]
const FALLBACK_COLOR: Color = Color(0.6, 0.6, 0.6, 1.0)

## ===== Узлы =====
@onready var _color_rect: ColorRect = $ColorRect
@onready var _unit_label: Label = $UnitLabel
@onready var _shape: CollisionShape2D = $CollisionShape2D

## ===== Состояние =====
var _units: int = 0

func _ready() -> void:
	_apply_rect_size()
	_units = start_units
	_update_label()
	_apply_controller_color()
	self.input_event.connect(_on_area_input_event)

func _apply_rect_size() -> void:
	## Совмещаем коллизию с визуалом: ColorRect рисуется от (0,0),
	## у RectangleShape2D центр — посередине; поэтому сдвигаем CollisionShape2D.
	if _shape and _shape.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = _shape.shape as RectangleShape2D
		rect_shape.size = rect_size
		_shape.position = rect_size * 0.5

	if _color_rect:
		_color_rect.size = rect_size
		_color_rect.position = Vector2.ZERO

	if _unit_label:
		_unit_label.set_anchors_preset(Control.LayoutPreset.PRESET_FULL_RECT)
		_unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_unit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_unit_label.text = str(_units)

func _update_label() -> void:
	if _unit_label:
		_unit_label.text = str(_units)

func _apply_controller_color() -> void:
	var color: Color = FALLBACK_COLOR
	if controller_id >= 0 and controller_id < CONTROLLER_COLORS.size():
		color = CONTROLLER_COLORS[controller_id]
	if _color_rect:
		_color_rect.color = color

## ===== Публичный API =====
func get_units() -> int:
	return _units

func set_units(value: int) -> void:
	var new_val: int = max(0, value)
	if new_val != _units:
		_units = new_val
		_update_label()
		units_changed.emit(self, _units)

func add_units(delta: int) -> void:
	set_units(_units + delta)

func get_controller_id() -> int:
	return controller_id

func set_controller_id(new_controller_id: int) -> void:
	if new_controller_id != controller_id:
		controller_id = new_controller_id
		_apply_controller_color()
		controller_changed.emit(self, controller_id)

## Служебно: прямой цвет (если GameManager захочет)
func set_controller_color(custom_color: Color) -> void:
	if _color_rect:
		_color_rect.color = custom_color

## ===== Ввод =====
func _on_area_input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if not allow_clicks:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			territory_clicked.emit(self)

## ===== Утилита для будущего роста =====
func grow_once() -> void:
	add_units(growth_per_tick)

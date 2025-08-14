extends Node
class_name GameManager

## -------------------------------
## Настройки/константы (MVP)
## -------------------------------
const PLAYER_HUMAN: int = 0
const PLAYER_AI_1: int = 1
const PLAYER_AI_2: int = 2

const SEND_FRACTION_DEFAULT: float = 0.5
const MIN_SENT_UNITS: int = 1

enum SelectionPhase { IDLE, SOURCE_SELECTED }

## -------------------------------
## Сигналы для UI
## -------------------------------
signal current_player_changed(player_id: int)
signal gm_status(text: String)
signal gm_log(text: String)

## -------------------------------
## Ссылки/экспорт
## -------------------------------
@export var map_path: NodePath
@export var ui_path: NodePath ## Укажем в инспекторе на UIRoot/HUD

var _map: Map
var _territories: Array[Territory] = []
var _rows: int = 0
var _cols: int = 0

var _phase: int = SelectionPhase.IDLE
var _source_id: int = -1
var _current_player: int = PLAYER_HUMAN ## Шаг 5 будет переключать ход
var _game_over: bool = false

func _controller_name(controller_id: int) -> String:
	var names := {
		PLAYER_HUMAN: "Человек",
		PLAYER_AI_1: "ИИ‑1",
		PLAYER_AI_2: "ИИ‑2",
	}
	return names.get(controller_id, str(controller_id))

func _ready() -> void:
	# Найдём карту
	if map_path == NodePath():
		push_warning("GameManager: map_path не задан.")
		return
	var node := get_node(map_path)
	if node == null:
		push_warning("GameManager: по map_path узел не найден.")
		return
	_map = node as Map
	if _map == null:
		push_warning("GameManager: узел по map_path не является Map.")
		return
	_map.map_territory_clicked.connect(_on_map_territory_clicked)

	# Найдём HUD (опционально, но желательно)
	if ui_path != NodePath():
		var ui_node := get_node(ui_path)
		if ui_node and ui_node is UI:
			(ui_node as UI).set_game_manager(self)

	# Ждём 1 кадр, чтобы Map гарантированно сгенерировала сетку
	await get_tree().process_frame
	_cache_map_state()

	# Инициализация UI
	current_player_changed.emit(_current_player)
	gm_status.emit("ожидаю выбор источника")
	gm_log.emit("Игра стартовала. Игрок: Человек. Отправка = 50%.")

func get_current_player_id() -> int:
	return _current_player

func _cache_map_state() -> void:
	_territories.clear()
	_rows = _map.rows
	_cols = _map.cols
	var total: int = _rows * _cols
	_territories.resize(total)
	for id in range(total):
		var t: Territory = _map.get_territory_by_id(id)
		if t != null:
			_territories[id] = t

func _on_map_territory_clicked(id: int) -> void:
	if _game_over:
		return
	if id < 0 or id >= _territories.size():
		return
	var clicked: Territory = _territories[id]
	if clicked == null:
		return

	match _phase:
		SelectionPhase.IDLE:
			_handle_pick_source(clicked)
		SelectionPhase.SOURCE_SELECTED:
			_handle_pick_target(clicked)

func _handle_pick_source(src: Territory) -> void:
	if src.get_controller_id() != PLAYER_HUMAN:
		gm_status.emit("выбран чужой источник — недопустимо")
		gm_log.emit("Отказ: территория id=%d не под контролем игрока" % src.territory_id)
		return

	var units: int = src.get_units()
	var to_send: int = _compute_send_amount(units)
	if to_send < MIN_SENT_UNITS:
		gm_status.emit("недостаточно юнитов в источнике")
		gm_log.emit("Отказ: мало юнитов на id=%d (units=%d)" % [src.territory_id, units])
		return

	_source_id = src.territory_id
	_phase = SelectionPhase.SOURCE_SELECTED
	gm_status.emit("выбери цель (соседнюю территорию)")
	gm_log.emit("Источник выбран: id=%d (units=%d), планируем отправить=%d" %
		[src.territory_id, units, to_send])

func _handle_pick_target(dst: Territory) -> void:
	if _source_id == -1:
		_phase = SelectionPhase.IDLE
		return

	var src: Territory = _territories[_source_id]
	if dst.territory_id == _source_id:
		_phase = SelectionPhase.IDLE
		_source_id = -1
		gm_status.emit("выбор источника отменён")
		gm_log.emit("Отмена выбора источника")
		return

	var neighbors: Array[int] = _map.get_neighbors(_source_id)
	if dst.territory_id not in neighbors:
		gm_status.emit("цель не является соседом")
		gm_log.emit("Отказ: цель id=%d не сосед источника id=%d" %
			[dst.territory_id, _source_id])
		return

	var available: int = src.get_units()
	var to_send: int = _compute_send_amount(available)
	if to_send < MIN_SENT_UNITS:
		_phase = SelectionPhase.IDLE
		_source_id = -1
		gm_status.emit("недостаточно юнитов для атаки")
		gm_log.emit("Атака отменена: мало юнитов на источнике id=%d" % src.territory_id)
		return

	_resolve_battle(src, dst, to_send)

	_phase = SelectionPhase.IDLE
	_source_id = -1
	gm_status.emit("ожидаю выбор источника")
	_check_victory()

func _compute_send_amount(available: int) -> int:
	if available <= 0:
		return 0
	var half: int = int(floor(float(available) * SEND_FRACTION_DEFAULT))
	if half < MIN_SENT_UNITS and available > 0:
		half = MIN_SENT_UNITS
	return clamp(half, 0, available)

func _resolve_battle(src: Territory, dst: Territory, attackers: int) -> void:
	var src_units_before: int = src.get_units()
	var dst_units_before: int = dst.get_units()
	var src_ctrl: int = src.get_controller_id()
	var dst_ctrl: int = dst.get_controller_id()

	src.set_units(src_units_before - attackers)

	if attackers > dst_units_before:
		var remain: int = attackers - dst_units_before
		dst.set_units(remain)
		dst.set_controller_id(src_ctrl)
		gm_log.emit("Захват: %d -> %d ; атак=%d, защ=%d, остаток на цели=%d" %
			[src.territory_id, dst.territory_id, attackers, dst_units_before, remain])
	else:
		var defenders_left: int = dst_units_before - attackers
		dst.set_units(defenders_left)
		gm_log.emit("Без захвата: %d -> %d ; атак=%d, защ=%d, у цели осталось=%d" %
			[src.territory_id, dst.territory_id, attackers, dst_units_before, defenders_left])

func _check_victory() -> void:
	var found_ctrls := {}
	for t in _territories:
		if t == null:
			continue
		found_ctrls[t.get_controller_id()] = true

	if found_ctrls.size() == 1:
		var only_ctrl: int = -1
		for k in found_ctrls.keys():
			only_ctrl = int(k)
		var winner_name := _controller_name(only_ctrl)
		gm_log.emit("=== ПОБЕДА! Контроллер %s владеет всеми территориями ===" % winner_name)
		gm_status.emit("победа: %s" % winner_name)
		_game_over = true
		for t in _territories:
			if t != null:
				t.allow_clicks = false
				t.input_pickable = false

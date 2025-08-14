extends Node
class_name GameManager

const Map = preload("res://scenes/map.gd")
const Territory = preload("res://scenes/territory.gd")

## -------------------------------
## Настройки/константы (MVP)
## -------------------------------

## Идентификаторы контроллеров
const PLAYER_HUMAN: int = 0
const PLAYER_AI_1: int = 1
const PLAYER_AI_2: int = 2

## Доля юнитов, отправляемых при атаке (MVP: 50%)
const SEND_FRACTION_DEFAULT: float = 0.5

## Минимум юнитов, которые реально отправим (чтобы клик имел эффект)
const MIN_SENT_UNITS: int = 1

## Фазы выбора
enum SelectionPhase { IDLE, SOURCE_SELECTED }

## -------------------------------
## Ссылки/экспорт
## -------------------------------

@export var map_path: NodePath  ## Укажи в инспекторе путь до узла карты (Map)

## Типизированные ссылки; ожидаем, что у тебя class_name Map/Territory уже объявлены
var _map: Map
var _territories: Array[Territory] = []
var _rows: int = 0
var _cols: int = 0

## Состояние выбора
var _phase: int = SelectionPhase.IDLE
var _source_id: int = -1

## -------------------------------
## Жизненный цикл
## -------------------------------


func _ready() -> void:
	_map = get_node(map_path) as Map

	## Подпишемся на клики карты
	_map.map_territory_clicked.connect(_on_map_territory_clicked)

	## ВАЖНО: Ждём один кадр, чтобы Map успела сгенерировать сетку в своём _ready().
	## Почему нужен await:
	## - Узлы-«соседи» (Map и GameManager) вызывают _ready() по порядку в дереве.
	## - Мы не хотим зависеть от порядка; ожидание одного кадра гарантирует, что
	##   Map уже инстанцировала Territory и построила смежность.
	await get_tree().process_frame

	_cache_map_state()

	print("GameManager готов. Территорий: ", _territories.size())


## Собираем ссылки на все территории и их размерность
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


## -------------------------------
## Обработка кликов по территории
## -------------------------------


func _on_map_territory_clicked(id: int) -> void:
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


## Выбор источника: только территория игрока и с достаточными юнитами
func _handle_pick_source(src: Territory) -> void:
	if src.get_controller_id() != PLAYER_HUMAN:
		print("Источник отклонён: это не территория игрока.")
		return

	var units: int = src.get_units()
	var to_send: int = _compute_send_amount(units)
	if to_send < MIN_SENT_UNITS:
		print("Источник отклонён: недостаточно юнитов для отправки.")
		return

	_source_id = src.territory_id
	_phase = SelectionPhase.SOURCE_SELECTED
	print("Источник выбран → id=", _source_id, ", юнитов=", units, ", отправим при атаке=", to_send)


## Выбор цели и атака (если соседи)
func _handle_pick_target(dst: Territory) -> void:
	if _source_id == -1:
		_phase = SelectionPhase.IDLE
		return

	var src: Territory = _territories[_source_id]
	if dst.territory_id == _source_id:
		## Нажали снова по источнику — сброс выбора
		_phase = SelectionPhase.IDLE
		_source_id = -1
		print("Выбор источника отменён.")
		return

	## Проверка соседства по карте
	var neighbors: Array[int] = _map.get_neighbors(_source_id)
	if dst.territory_id not in neighbors:
		print("Цель отклонена: территория не является соседом источника.")
		return

	## Готовим атаку
	var available: int = src.get_units()
	var to_send: int = _compute_send_amount(available)
	if to_send < MIN_SENT_UNITS:
		print("Атака отменена: недостаточно юнитов для отправки.")
		_phase = SelectionPhase.IDLE
		_source_id = -1
		return

	_resolve_battle(src, dst, to_send)

	## Сброс выбора и проверка победы
	_phase = SelectionPhase.IDLE
	_source_id = -1
	_check_victory()


## Считаем, сколько юнитов отправить (MVP: 50% от имеющихся, минимум 1)
func _compute_send_amount(available: int) -> int:
	if available <= 0:
		return 0
	var half: int = int(floor(float(available) * SEND_FRACTION_DEFAULT))
	if half < MIN_SENT_UNITS and available > 0:
		half = MIN_SENT_UNITS
	## В этом MVP источник может оставить 0 — это допустимо в наших правилах.
	return clamp(half, 0, available)


## -------------------------------
## БОЙ (правила из ТЗ)
## -------------------------------
## Правила:
## - если атакующих строго больше защитников → территория переходит к атакующему,
##   защитники погибают, на новой территории остаётся (атакующие - защитники)
## - если атакующих меньше или РАВНО → все атакующие погибают,
##   защитники теряют столько же, сколько пришло атакующих (могут стать 0)
func _resolve_battle(src: Territory, dst: Territory, attackers: int) -> void:
	var src_units_before: int = src.get_units()
	var dst_units_before: int = dst.get_units()
	var src_ctrl: int = src.get_controller_id()
	var dst_ctrl: int = dst.get_controller_id()

	print("--- БОЙ ---")
	print(
		"Источник id=",
		src.territory_id,
		" (ctrl=",
		src_ctrl,
		", units=",
		src_units_before,
		")",
		" → Цель id=",
		dst.territory_id,
		" (ctrl=",
		dst_ctrl,
		", units=",
		dst_units_before,
		")",
		" ; отправляем=",
		attackers
	)

	## Списываем атакующих у источника
	src.set_units(src_units_before - attackers)

	if attackers > dst_units_before:
		## Захват
		var remain: int = attackers - dst_units_before
		dst.set_units(remain)
		dst.set_controller_id(src_ctrl)
		print("Захват! Новые units цели=", remain, ", новый контроллер=", src_ctrl)
	else:
		## Без захвата: атакующие погибли, защитник теряет столько же
		var defenders_left: int = dst_units_before - attackers
		dst.set_units(defenders_left)
		## Владелец НЕ меняется
		print(
			"Без захвата. У защитника осталось=", defenders_left, ", контроллер прежний=", dst_ctrl
		)


## -------------------------------
## Победа
## -------------------------------
func _check_victory() -> void:
	var found_ctrls := {}
	for t in _territories:
		if t == null:
			continue
		found_ctrls[t.get_controller_id()] = true
	var unique_count: int = found_ctrls.size()

	if unique_count == 1:
		var only_ctrl: int = -1
		for k in found_ctrls.keys():
			only_ctrl = int(k)
		print("=== ПОБЕДА! Контроллер ", only_ctrl, " владеет всеми территориями. ===")
		## Экран победы сделаем на Шаге 6 (сценой/панелью).

# scenes/game_manager.gd
extends Node
class_name GameManager

# --- Константы и настройки ---
const PLAYER_HUMAN := 0
const PLAYER_AI_1 := 1
const PLAYER_AI_2 := 2
const SEND_FRACTION_DEFAULT := 0.5
const MIN_SENT_UNITS := 1
enum SelectionPhase { IDLE, SOURCE_SELECTED }

# --- Экспортируемая ссылка на карту ---
@export var map_path: NodePath

# --- Внутреннее состояние ---
var _map: Map
var _territories: Array[Territory] = []
var _phase: SelectionPhase = SelectionPhase.IDLE
var _source_id: int = -1

# --- Жизненный цикл ---
func _ready() -> void:
	_map = get_node_or_null(map_path) as Map
	if _map == null:
		push_warning("GameManager: узел по map_path не найден или не Map")
		return

	_map.map_territory_clicked.connect(_on_map_territory_clicked)
	await get_tree().process_frame
	_cache_map_state()
	print("GameManager готов. Территорий: %d" % _territories.size())


# --- Сбор ссылок на все территории ---
func _cache_map_state() -> void:
	_territories.clear()
	var total := _map.rows * _map.cols
	for id in range(total):
		_territories.append(_map.get_territory_by_id(id))


# --- Обработка кликов по территориям ---
func _on_map_territory_clicked(id: int) -> void:
	print("Клик по территории id=", id)
	if id < 0 or id >= _territories.size():
		return

	var clicked := _territories[id]
	if clicked == null:
		return

	match _phase:
		SelectionPhase.IDLE:
			_handle_pick_source(clicked)
		SelectionPhase.SOURCE_SELECTED:
			_handle_pick_target(clicked)


# --- Выбор источника ---
func _handle_pick_source(src: Territory) -> void:
	if src.get_controller_id() != PLAYER_HUMAN:
		print("Источник отклонён: территория не игрока")
		return

	var units := src.get_units()
	var to_send := _compute_send_amount(units)
	if to_send < MIN_SENT_UNITS:
		print("Источник отклонён: недостаточно юнитов")
		return

	_source_id = src.territory_id
	_phase = SelectionPhase.SOURCE_SELECTED
	print(
		"Источник выбран → id=%d, юнитов=%d, отправим=%d"
		% [_source_id, units, to_send]
	)


# --- Выбор цели и атака ---
func _handle_pick_target(dst: Territory) -> void:
	if _source_id == -1:
		_phase = SelectionPhase.IDLE
		return

	var src := _territories[_source_id]
	if dst.territory_id == _source_id:
		_phase = SelectionPhase.IDLE
		_source_id = -1
		print("Выбор источника отменён")
		return

	var neighbors := _map.get_neighbors(_source_id)
	if dst.territory_id not in neighbors:
		print("Цель отклонена: территория не сосед")
		return

	var available := src.get_units()
	var to_send := _compute_send_amount(available)
	if to_send < MIN_SENT_UNITS:
		print("Атака отменена: недостаточно юнитов")
		_phase = SelectionPhase.IDLE
		_source_id = -1
		return

	_resolve_battle(src, dst, to_send)
	_phase = SelectionPhase.IDLE
	_source_id = -1
	_check_victory()


# --- Расчёт отправляемых юнитов ---
func _compute_send_amount(available: int) -> int:
	if available <= 0:
		return 0
	var half := int(floor(float(available) * SEND_FRACTION_DEFAULT))
	if half < MIN_SENT_UNITS and available > 0:
		half = MIN_SENT_UNITS
	return clamp(half, 0, available)


# --- Бой ---
func _resolve_battle(src: Territory, dst: Territory, attackers: int) -> void:
	var src_units_before := src.get_units()
	var dst_units_before := dst.get_units()
	var src_ctrl := src.get_controller_id()
	var dst_ctrl := dst.get_controller_id()

	print("--- БОЙ ---")
	print(
		"Источник id=%d (ctrl=%d, units=%d) → Цель id=%d (ctrl=%d, units=%d); отправляем=%d"
		% [src.territory_id, src_ctrl, src_units_before, dst.territory_id, dst_ctrl, dst_units_before, attackers]
	)

	src.set_units(src_units_before - attackers)

	if attackers > dst_units_before:
		var remain := attackers - dst_units_before
		dst.set_units(remain)
		dst.set_controller_id(src_ctrl)
		print("Захват! Новые units цели=%d, новый контроллер=%d" % [remain, src_ctrl])
	else:
		var defenders_left := dst_units_before - attackers
		dst.set_units(defenders_left)
		print("Без захвата. У защитника осталось=%d, контроллер прежний=%d" % [defenders_left, dst_ctrl])


# --- Проверка победы ---
func _check_victory() -> void:
	var found_ctrls := {}
	for t in _territories:
		if t:
			found_ctrls[t.get_controller_id()] = true

	if found_ctrls.size() == 1:
		var only_ctrl := found_ctrls.keys()[0]
		print("=== ПОБЕДА! Контроллер %s владеет всеми территориями. ===" % only_ctrl)

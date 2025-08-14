extends Node
class_name GameManager

# -------------------------------
# Подключаем пользовательские типы
# -------------------------------
const Map = preload("res://scenes/map.gd")
const Territory = preload("res://scenes/territory.gd")

# -------------------------------
# Константы и настройки
# -------------------------------
const PLAYER_HUMAN: int = 0
const PLAYER_AI_1: int = 1
const PLAYER_AI_2: int = 2
const SEND_FRACTION_DEFAULT: float = 0.5
const MIN_SENT_UNITS: int = 1

enum SelectionPhase { IDLE, SOURCE_SELECTED }

# -------------------------------
# Экспортируемая ссылка на карту
# -------------------------------
@export var map_path: NodePath

# -------------------------------
# Внутреннее состояние
# -------------------------------
var _map: Map
var _territories: Array[Territory] = []
var _rows: int = 0
var _cols: int = 0
var _phase: int = SelectionPhase.IDLE
var _source_id: int = -1

# -------------------------------
# Жизненный цикл
# -------------------------------
func _ready() -> void:
	# Находим и приводим карту
	_map = get_node(map_path) as Map
	if _map == null:
		push_warning("GameManager: узел по map_path не найден или не Map")
		return

	# Подписываемся на сигнал клика по территории
	_map.map_territory_clicked.connect(_on_map_territory_clicked)
	print("Сигнал map_territory_clicked подключен")

	# Ждём кадр, чтобы карта успела создать территории
	await get_tree().process_frame

	_cache_map_state()
	print("GameManager готов. Территорий: ", _territories.size())


# -------------------------------
# Сбор ссылок на все территории
# -------------------------------
func _cache_map_state() -> void:
	_territories.clear()
	_rows = _map.rows
	_cols = _map.cols
	var total := _rows * _cols
	_territories.resize(total)
	for id in range(total):
		var t: Territory = _map.get_territory_by_id(id)
		if t:
			_territories[id] = t


# -------------------------------
# Обработка кликов по территориям
# -------------------------------
func _on_map_territory_clicked(id: int) -> void:
	print("Клик по территории: ", id)
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


# -------------------------------
# Выбор источника
# -------------------------------
func _handle_pick_source(src: Territory) -> void:
        print("Попытка выбрать источник id=", src.territory_id)
        if src.controller_id != PLAYER_HUMAN:
                print("Источник отклонён: это не территория игрока.")
                return

        var units: int = src.get_units()
        var to_send: int = _compute_send_amount(units)
	if to_send < MIN_SENT_UNITS:
		print("Источник отклонён: недостаточно юнитов.")
		return

	_source_id = src.territory_id
	_phase = SelectionPhase.SOURCE_SELECTED
	print(
		"Источник выбран → id=", _source_id,
		", юнитов=", units,
		", отправим=", to_send
	)


# -------------------------------
# Выбор цели и атака
# -------------------------------
func _handle_pick_target(dst: Territory) -> void:
	print("Попытка выбрать цель id=", dst.territory_id)
	if _source_id == -1:
		_phase = SelectionPhase.IDLE
		return

        var src: Territory = _territories[_source_id]
	if dst.territory_id == _source_id:
		_phase = SelectionPhase.IDLE
		_source_id = -1
		print("Выбор источника отменён.")
		return

	var neighbors: Array[int] = _map.get_neighbors(_source_id)
	if dst.territory_id not in neighbors:
		print("Цель отклонена: территория не сосед.")
		return

        var available: int = src.get_units()
        var to_send: int = _compute_send_amount(available)
	if to_send < MIN_SENT_UNITS:
		print("Атака отменена: недостаточно юнитов.")
		_phase = SelectionPhase.IDLE
		_source_id = -1
		return

	print(
		"Атакуем цель id=", dst.territory_id,
		" из источника id=", _source_id,
		", отправляем=", to_send
	)
	_resolve_battle(src, dst, to_send)
	print("Бой завершён")

	_phase = SelectionPhase.IDLE
	_source_id = -1
	_check_victory()


# -------------------------------
# Расчёт отправляемых юнитов
# -------------------------------
func _compute_send_amount(available: int) -> int:
	if available <= 0:
		return 0
	var half := int(floor(float(available) * SEND_FRACTION_DEFAULT))
	if half < MIN_SENT_UNITS and available > 0:
		half = MIN_SENT_UNITS
	return clamp(half, 0, available)


# -------------------------------
# Бой
# -------------------------------
func _resolve_battle(src: Territory, dst: Territory, attackers: int) -> void:
        var src_units_before: int = src.get_units()
        var dst_units_before: int = dst.get_units()
        var src_ctrl: int = src.controller_id
        var dst_ctrl: int = dst.controller_id

	print("--- БОЙ ---")
	print(
		"Источник id=", src.territory_id, " (ctrl=", src_ctrl, ", units=", src_units_before, ")",
		" → Цель id=", dst.territory_id, " (ctrl=", dst_ctrl, ", units=", dst_units_before, ")",
		"; отправляем=", attackers
	)

	src.set_units(src_units_before - attackers)

        if attackers > dst_units_before:
                var remain: int = attackers - dst_units_before
                dst.set_units(remain)
                dst.set_controller_id(src_ctrl)
                print("Захват! Новые units цели=", remain, ", новый контроллер=", src_ctrl)
        else:
                var defenders_left: int = dst_units_before - attackers
                dst.set_units(defenders_left)
                print("Без захвата. У защитника осталось=", defenders_left, ", контроллер прежний=", dst_ctrl)

	print(
		"Итог боя: units источника=", src.get_units(),
		", units цели=", dst.get_units()
	)


# -------------------------------
# Проверка победы
# -------------------------------
func _check_victory() -> void:
        print("Проверка победы...")
        var found_ctrls: Dictionary = {}
        for t in _territories:
                if t:
                        found_ctrls[t.controller_id] = true

        if found_ctrls.size() == 1:
                var only_ctrl: int = -1
                for k in found_ctrls.keys():
                        only_ctrl = int(k)
                print("=== ПОБЕДА! Контроллер ", only_ctrl, " владеет всеми территориями. ===")

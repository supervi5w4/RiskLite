extends Node
class_name AIController

## Простой ИИ для игроков 1 и 2.
## Он не лезет в карту напрямую, а просит GameManager выполнить атаку,
## передавая: source_id, target_id, количество атакующих.

## ===== Экспортируемые параметры (настраиваются в инспекторе при желании) =====
@export var think_delay_sec: float = 0.6 ## Пауза перед ходом ИИ (чисто визуально)
@export var min_surplus_to_attack: int = 2 ## Минимальный "профицит" юнитов на источнике, чтобы вообще думать об атаке
@export var send_fraction: float = 0.5 ## Доля юнитов, которой ИИ атакует (по умолчанию совпадает с игроком)

## ===== Внутренние ссылки =====
var _gm: GameManager
var _map: Map

func setup(gm: GameManager, map: Map) -> void:
	_gm = gm
	_map = map

## Главная точка входа — вызывается GameManager, когда наступает ход указанного ИИ.
## Возвращает true, если сделал попытку атаки (даже если она оказалась "без захвата").
## Внутри используется await(Timer) — см. комментарий ниже.
func play_turn(ai_player_id: int) -> void:
	if _gm == null or _map == null:
		return

	## 1) Небольшая пауза — чтобы игрок видел, что "ходит ИИ".
	##    Зачем await: Timer на 1-shot вернёт сигнал timeout через think_delay_sec секунд.
	##    Мы ждём этот сигнал и продолжаем выполнение в этой же корутине.
	var timer: SceneTreeTimer = get_tree().create_timer(max(0.0, think_delay_sec))
	await timer.timeout

	## 2) Соберём все территории ИИ
	var my_territories: Array[Territory] = []
	var total: int = _map.rows * _map.cols
	for id in range(total):
		var t: Territory = _map.get_territory_by_id(id)
		if t and t.get_controller_id() == ai_player_id:
			my_territories.append(t)

	## 3) Выбираем лучшую "источник" по простому критерию: больше всего юнитов
	my_territories.sort_custom(func(a: Territory, b: Territory) -> bool:
		return a.get_units() > b.get_units()
	)

	## 4) Перебираем кандидатов и ищем выгодную цель: самый слабый сосед‑враг,
	##    при этом отправляем ровно int(fraction * units) и атакуем только если это > защитника.
	for src in my_territories:
		var units: int = src.get_units()
		if units < min_surplus_to_attack:
			continue

		var send_count: int = int(floor(float(units) * send_fraction))
		if send_count < 1:
			send_count = 1
		if send_count >= units:
			send_count = units  ## допустим и 100%, но GameManager ещё раз проверит

		var neighbors: Array[int] = _map.get_neighbors(src.territory_id)
		var best_target: Territory = null
		var best_target_units: int = 0x3fffffff

		for nid in neighbors:
			var nb: Territory = _map.get_territory_by_id(nid)
			if nb == null:
				continue
			if nb.get_controller_id() == ai_player_id:
				continue ## свой — пропускаем
			var du: int = nb.get_units()
			## Берём самого слабого противника
			if du < best_target_units:
				best_target_units = du
				best_target = nb

		if best_target == null:
			continue

		## Избегаем самоубийства: атакуем только если отправляемых строго больше защитников
		if send_count > best_target_units:
			_gm.ai_request_attack(src.territory_id, best_target.territory_id, send_count)
			return

	## Если не нашли выгодной цели — "пасс"
	_gm.ai_request_pass(ai_player_id)

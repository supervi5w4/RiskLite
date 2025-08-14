extends Control
class_name UI

## HUD показывает текущего игрока, статус и лог событий.
## Он подписывается на сигналы GameManager, путь к которому задаёт сам GameManager через set_game_manager().

## ===== Экспорт-параметры =====
@export var restart_action: StringName = &"restart" ## Действие в InputMap для перезапуска (R по Шагу 0)

## ===== Узлы =====
@onready var _label_player: Label = %CurrentPlayerLabel
@onready var _label_status: Label = %StatusLabel
@onready var _btn_restart: Button = %RestartButton
@onready var _log_box: RichTextLabel = %LogBox

## Ссылка на менеджер (устанавливается GameManager-ом)
var _gm: Node = null

func _ready() -> void:
	if _btn_restart:
		_btn_restart.pressed.connect(_on_restart_pressed)

## Вызывается GameManager-ом для установки связей сигналов
func set_game_manager(gm: Node) -> void:
	_gm = gm
	## Подписки на сигналы (см. GameManager.gd)
	if _gm and _gm.has_signal("gm_status"):
		_gm.gm_status.connect(_on_gm_status)
	if _gm and _gm.has_signal("gm_log"):
		_gm.gm_log.connect(_on_gm_log)
	if _gm and _gm.has_signal("current_player_changed"):
		_gm.current_player_changed.connect(_on_player_changed)

	## Инициализация текста
	_set_player_text(_gm.call("get_current_player_id") if _gm else -1)
	_set_status_text("ожидаю выбор источника")

func _on_restart_pressed() -> void:
	## Перезапустим текущую сцену; также можно нажать горячую клавишу R
	get_tree().reload_current_scene()

## ===== Обработчики сигналов от GameManager =====
func _on_player_changed(player_id: int) -> void:
	_set_player_text(player_id)

func _on_gm_status(text: String) -> void:
	_set_status_text(text)

func _on_gm_log(text: String) -> void:
	if _log_box:
		_log_box.append_text(text + "\n")
		_log_box.scroll_to_line(_log_box.get_line_count() - 1)

## ===== Утилиты =====
func _set_player_text(player_id: int) -> void:
	var who := "—"
	if player_id == 0:
		who = "Человек"
	elif player_id == 1:
		who = "ИИ‑1"
	elif player_id == 2:
		who = "ИИ‑2"
	if _label_player:
		_label_player.text = "Текущий игрок: " + who

func _set_status_text(text: String) -> void:
	if _label_status:
		_label_status.text = "Статус: " + text

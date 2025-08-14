extends Node2D
class_name Map

signal map_territory_clicked(id: int)

# Подключаем скрипт Territory и сцену
const Territory = preload("res://scenes/territory.gd")
const TerritoryScene: PackedScene = preload("res://scenes/territory.tscn")

# Константы игроков из GameManager для назначения контроллеров
const GameManager = preload("res://scenes/game_manager.gd")
const PLAYER_CYCLE: Array[int] = [
	GameManager.PLAYER_HUMAN,
	GameManager.PLAYER_AI_1,
	GameManager.PLAYER_AI_2,
]

var territories: Array[Territory] = []
var adjacency: Dictionary = {}
var rows: int = 2
var cols: int = 5

func _ready() -> void:
	territories.clear()
	adjacency.clear()

	var gap: float = 20.0

	for i in range(rows * cols):
		var territory: Territory = TerritoryScene.instantiate()
		territory.territory_id = i
		territory.controller_id = PLAYER_CYCLE[i % PLAYER_CYCLE.size()]
		territory.start_units = 10
		territory.allow_clicks = true
		territory.clicked.connect(_on_territory_clicked)

		var rect: Vector2 = territory.rect_size
		var col: int = i % cols
		var row: int = i / cols
		territory.position = Vector2(
			col * (rect.x + gap),
			row * (rect.y + gap)
		)

		territories.append(territory)
		add_child(territory)

	# Создаём словарь соседей
	for i in range(rows * cols):
		var neighbors: Array[int] = []
		var col: int = i % cols
		var row: int = i / cols

		if col > 0:
			neighbors.append(i - 1)
		if col < cols - 1:
			neighbors.append(i + 1)
		if row > 0:
			neighbors.append(i - cols)
		if row < rows - 1:
			neighbors.append(i + cols)

		adjacency[i] = neighbors

func _on_territory_clicked(id: int) -> void:
	print("Клик по территории id=%d" % id)
	map_territory_clicked.emit(id)

func get_territory_by_id(id: int) -> Territory:
	if id >= 0 and id < territories.size():
		return territories[id]
	return null

func get_neighbors(id: int) -> Array[int]:
	if id in adjacency:
		return adjacency[id]
	return []

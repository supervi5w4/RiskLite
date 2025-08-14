extends Node2D
class_name Map

signal map_territory_clicked(id: int)

const Territory = preload("res://scenes/territory.gd")
const TerritoryScene: PackedScene = preload("res://scenes/territory.tscn")

var territories: Array[Territory] = []
var adjacency: Dictionary
var rows: int
var cols: int

func _ready() -> void:
	territories = []
	adjacency = {}
	rows = 2
	cols = 5

	var gap: float = 20.0

        for i in range(rows * cols):
                var territory: Territory = TerritoryScene.instantiate()
                territory.territory_id = i
                territory.controller_id = i % 3
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
        print("Клик по территории id=", id)
        map_territory_clicked.emit(id)


func get_territory_by_id(id: int) -> Territory:
	if id >= 0 and id < territories.size():
		return territories[id]
	return null


func get_neighbors(id: int) -> Array[int]:
	if id in adjacency:
		return adjacency[id]
	return []

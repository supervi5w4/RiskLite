extends Node2D

const TerritoryScene: PackedScene = preload("res://scenes/territory.tscn")

var territories: Array[Territory]
var adjacency: Dictionary

func _ready() -> void:
        territories = []
        adjacency = {}

        var gap: float = 20.0
        var cols: int = 5
        var rows: int = 2
        for i in range(rows * cols):
                var territory: Territory = TerritoryScene.instantiate()
                territory.territory_id = i
                territory.controller_id = i % 3
                territory.start_units = 10

                var rect: Vector2 = territory.rect_size
                var col: int = i % cols
                var row: int = i / cols
                territory.position = Vector2(col * (rect.x + gap), row * (rect.y + gap))

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

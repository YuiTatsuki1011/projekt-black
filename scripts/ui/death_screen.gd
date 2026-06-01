extends CanvasLayer
class_name DeathScreen

@export var player_path: NodePath = NodePath("../Player")

@onready var root: Control = $Root


func _ready() -> void:
	root.visible = false
	var player := get_node_or_null(player_path)
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)


func _on_player_died() -> void:
	root.visible = true

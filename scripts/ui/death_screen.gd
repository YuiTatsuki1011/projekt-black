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
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("request_run_failure"):
		current_scene.call("request_run_failure", self)
		return

	root.visible = true

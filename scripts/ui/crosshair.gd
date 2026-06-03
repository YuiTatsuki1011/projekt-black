extends Node2D
class_name Crosshair

const CIRCLE_SEGMENTS := 32

@onready var actual_aim_circle: Line2D = get_node_or_null("ActualAimCircle") as Line2D

var _player: Node


func _ready() -> void:
	_resolve_player()
	if actual_aim_circle != null:
		actual_aim_circle.closed = true


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()
	_update_actual_aim_circle()


func _resolve_player() -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		_player = current_scene.get_node_or_null("Player")


func _update_actual_aim_circle() -> void:
	if actual_aim_circle == null:
		return
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	if _player == null or not _player.has_method("get_firearm_aim_info"):
		actual_aim_circle.visible = false
		return

	var info: Dictionary = _player.call("get_firearm_aim_info")
	if not bool(info.get("visible", false)):
		actual_aim_circle.visible = false
		return

	actual_aim_circle.visible = true
	actual_aim_circle.global_position = info.get("actual_aim_position", global_position)
	_set_circle_points(maxf(float(info.get("spread_radius", 5.0)), 2.0))


func _set_circle_points(radius: float) -> void:
	var points := PackedVector2Array()
	for index in CIRCLE_SEGMENTS:
		var angle := TAU * float(index) / float(CIRCLE_SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	actual_aim_circle.points = points

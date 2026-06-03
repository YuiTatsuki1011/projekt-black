extends Node2D

const MARKER_NAME := "LastSeenPlayerMarker"

@export var visible_time: float = 4.0

var _hide_timer: float = 0.0


func _ready() -> void:
	z_index = 15
	_build_visual()
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return

	_hide_timer -= delta
	if _hide_timer <= 0.0:
		visible = false


func show_sighting(marker_position: Vector2) -> void:
	global_position = marker_position
	_hide_timer = visible_time
	visible = true


func hide_sighting() -> void:
	_hide_timer = 0.0
	visible = false


func _build_visual() -> void:
	if get_child_count() > 0:
		return

	var body := Polygon2D.new()
	body.name = "GhostBody"
	body.color = Color(0.55, 0.66, 0.72, 0.28)
	body.polygon = PackedVector2Array([
		Vector2(-7.0, -14.0),
		Vector2(7.0, -14.0),
		Vector2(10.0, 12.0),
		Vector2(-10.0, 12.0),
	])
	add_child(body)

	var head := Polygon2D.new()
	head.name = "GhostHead"
	head.color = Color(0.66, 0.75, 0.8, 0.24)
	head.polygon = PackedVector2Array([
		Vector2(-5.0, -24.0),
		Vector2(5.0, -24.0),
		Vector2(6.0, -15.0),
		Vector2(-6.0, -15.0),
	])
	add_child(head)

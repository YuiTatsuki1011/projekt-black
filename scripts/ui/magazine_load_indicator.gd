extends Control
class_name MagazineLoadIndicator

@export var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var width := maxf(3.0, minf(size.x, size.y) * 0.08)
	draw_arc(center, radius, -PI * 0.5, PI * 1.5, 40, Color(0.02, 0.025, 0.03, 0.76), width, true)
	if progress <= 0.0:
		return

	draw_arc(
		center,
		radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * progress,
		40,
		Color(0.48, 0.92, 0.66, 0.96),
		width,
		true
	)

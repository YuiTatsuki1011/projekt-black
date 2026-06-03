extends Control
class_name StealthVignetteOverlay

@export var edge_color: Color = Color(0.0, 0.0, 0.0, 0.62)
@export var edge_fraction: float = 0.18
@export var min_edge_thickness: float = 128.0
@export var gradient_steps: int = 40


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(color: Color, fraction: float, min_thickness: float, steps: int) -> void:
	edge_color = color
	edge_fraction = fraction
	min_edge_thickness = min_thickness
	gradient_steps = steps
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var thickness := minf(
		maxf(minf(size.x, size.y) * edge_fraction, min_edge_thickness),
		maxf(size.x, size.y) * 0.5
	)
	var steps := maxi(gradient_steps, 4)
	for index in range(steps):
		var start_ratio := float(index) / float(steps)
		var end_ratio := float(index + 1) / float(steps)
		var strip_size := (end_ratio - start_ratio) * thickness + 1.0
		var color := edge_color
		color.a *= pow(1.0 - start_ratio, 2.15)

		draw_rect(Rect2(0.0, start_ratio * thickness, size.x, strip_size), color)
		draw_rect(Rect2(0.0, size.y - end_ratio * thickness, size.x, strip_size), color)
		draw_rect(Rect2(start_ratio * thickness, 0.0, strip_size, size.y), color)
		draw_rect(Rect2(size.x - end_ratio * thickness, 0.0, strip_size, size.y), color)

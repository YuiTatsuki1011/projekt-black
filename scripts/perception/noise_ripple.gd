extends Line2D
class_name NoiseRipple

const SEGMENTS := 48

var _duration: float = 0.5
var _elapsed: float = 0.0
var _base_color: Color = Color(1.0, 1.0, 1.0, 0.42)


func setup(radius: float, duration: float = 0.5, color: Color = Color(1.0, 1.0, 1.0, 0.42)) -> void:
	_duration = maxf(duration, 0.01)
	_base_color = color
	width = 2.0
	closed = true
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_NONE
	end_cap_mode = Line2D.LINE_CAP_NONE
	default_color = _base_color
	z_index = 90
	points = _make_circle_points(maxf(radius, 1.0))
	scale = Vector2(0.08, 0.08)


func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.08, 1.0, progress)
	default_color = Color(_base_color.r, _base_color.g, _base_color.b, _base_color.a * (1.0 - progress))
	if progress >= 1.0:
		queue_free()


func _make_circle_points(radius: float) -> PackedVector2Array:
	var circle_points := PackedVector2Array()
	for index in SEGMENTS:
		var angle := TAU * float(index) / float(SEGMENTS)
		circle_points.append(Vector2(cos(angle), sin(angle)) * radius)
	return circle_points

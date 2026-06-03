extends CanvasLayer
class_name RunResultScreen

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var title_label: Label = $Root/Panel/Margin/Rows/Title
@onready var subtitle_label: Label = $Root/Panel/Margin/Rows/Subtitle
@onready var detail_label: Label = $Root/Panel/Margin/Rows/Details


func _ready() -> void:
	root.visible = false


func show_result(title: String, subtitle: String, stats: Dictionary) -> void:
	root.visible = true
	title_label.text = title
	subtitle_label.text = subtitle
	detail_label.text = _build_detail_text(stats)

	var extracted: bool = bool(stats.get("extracted", false))
	if extracted:
		title_label.add_theme_color_override("font_color", Color(0.58, 1.0, 0.68, 1.0))
		dim.color = Color(0.0, 0.035, 0.025, 0.68)
	else:
		title_label.add_theme_color_override("font_color", Color(0.95, 0.18, 0.12, 1.0))
		dim.color = Color(0.06, 0.0, 0.0, 0.72)


func hide_result() -> void:
	root.visible = false


func _build_detail_text(stats: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("RUN TIME        %s" % _format_time(int(stats.get("elapsed_seconds", 0))))
	lines.append("ENEMIES KILLED  %d" % int(stats.get("enemies_killed", 0)))
	lines.append("QUEST STATUS    %s" % str(stats.get("quest_status", "UNKNOWN")))

	var item_stacks: int = int(stats.get("item_stacks", 0))
	var item_units: int = int(stats.get("item_units", 0))
	if bool(stats.get("extracted", false)):
		lines.append("SECURED ITEMS   %d STACKS / %d UNITS" % [item_stacks, item_units])
	else:
		lines.append("SECURED ITEMS   0")
		lines.append("LOST ITEMS      %d STACKS / %d UNITS" % [item_stacks, item_units])

	return "\n".join(lines)


func _format_time(total_seconds: int) -> String:
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

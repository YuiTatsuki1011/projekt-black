extends CanvasLayer
class_name MissionStatusHud

@onready var root: Control = $Root
@onready var objective_label: Label = $Root/Panel/Margin/Rows/ObjectiveLabel
@onready var status_label: Label = $Root/Panel/Margin/Rows/StatusLabel
@onready var message_label: Label = $Root/MessageLabel
@onready var complete_root: Control = $Root/CompleteRoot
@onready var complete_title: Label = $Root/CompleteRoot/Title
@onready var complete_subtitle: Label = $Root/CompleteRoot/Subtitle

var _message_tween: Tween


func _ready() -> void:
	root.visible = true
	message_label.visible = false
	complete_root.visible = false


func set_objective_text(text: String) -> void:
	objective_label.text = text


func set_status_text(text: String) -> void:
	status_label.text = text


func show_message(text: String, duration: float = 2.0) -> void:
	if _message_tween != null:
		_message_tween.kill()

	message_label.text = text
	message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	message_label.visible = true
	_message_tween = create_tween()
	_message_tween.tween_interval(maxf(duration, 0.1))
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.35)
	_message_tween.tween_callback(func() -> void:
		message_label.visible = false
		message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


func show_complete(title: String, subtitle: String) -> void:
	complete_title.text = title
	complete_subtitle.text = subtitle
	complete_root.visible = true


func hide_complete() -> void:
	complete_root.visible = false

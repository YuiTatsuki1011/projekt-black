extends Area2D
class_name ExtractionPoint

const INTERACTABLE_GROUP := "interactables"

@export var extraction_label: String = "EXTRACT"

@onready var label: Label = $Label
@onready var prompt: Label = $Prompt
@onready var pad: Polygon2D = $Pad


func _ready() -> void:
	add_to_group(INTERACTABLE_GROUP)
	label.text = extraction_label


func interact(_interactor: Node) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("request_extraction"):
		return
	current_scene.call("request_extraction", self)


func set_extraction_ready(is_ready: bool) -> void:
	if pad != null:
		pad.color = Color(0.14, 0.44, 0.28, 0.88) if is_ready else Color(0.34, 0.28, 0.1, 0.82)
	prompt.text = "F" if is_ready else "LOCKED"

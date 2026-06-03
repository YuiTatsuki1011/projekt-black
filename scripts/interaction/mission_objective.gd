extends Area2D
class_name MissionObjective

const INTERACTABLE_GROUP := "interactables"

@export var objective_id: StringName = &"prototype_cache"
@export var objective_label: String = "DATA CACHE"
@export var completed_label: String = "CACHE SECURED"

@onready var label: Label = $Label
@onready var prompt: Label = $Prompt
@onready var plate: Polygon2D = $Plate

var _completed: bool = false


func _ready() -> void:
	add_to_group(INTERACTABLE_GROUP)
	_refresh_visuals()


func interact(_interactor: Node) -> void:
	if _completed:
		_show_level_message("Objective already secured.")
		return

	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("complete_mission_objective"):
		return

	var was_completed := bool(current_scene.call("complete_mission_objective", objective_id, self))
	if was_completed:
		_completed = true
		_refresh_visuals()


func _refresh_visuals() -> void:
	label.text = completed_label if _completed else objective_label
	prompt.visible = not _completed
	if plate != null:
		plate.color = Color(0.18, 0.42, 0.32, 1.0) if _completed else Color(0.2, 0.36, 0.48, 1.0)


func _show_level_message(message: String) -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("show_mission_message"):
		current_scene.call("show_mission_message", message)

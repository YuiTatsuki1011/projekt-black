extends Area2D
class_name SpawnButton

@export var spawn_scene: PackedScene
@export var button_label: String = "SPAWN"
@export var spawn_parent_path: NodePath = NodePath("../Enemies")
@export var target_path: NodePath = NodePath("../Player")

@onready var spawn_marker: Marker2D = $SpawnMarker
@onready var label: Label = $Label


func _ready() -> void:
	label.text = button_label


func interact(_interactor: Node) -> void:
	if spawn_scene == null:
		return

	var spawn_parent := get_node_or_null(spawn_parent_path)
	if spawn_parent == null:
		spawn_parent = get_tree().current_scene

	var spawned_node := spawn_scene.instantiate()
	spawn_parent.add_child(spawned_node)

	if spawned_node is Node2D:
		var spawned_2d := spawned_node as Node2D
		spawned_2d.global_position = spawn_marker.global_position

	var target := get_node_or_null(target_path) as Node2D
	if target != null and spawned_node.has_method("set_target"):
		spawned_node.call("set_target", target)

	_flash_label()


func _flash_label() -> void:
	label.modulate = Color(1.0, 0.88, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 0.25)

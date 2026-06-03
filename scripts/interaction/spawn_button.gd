extends Area2D
class_name SpawnButton

const INTERACTABLE_GROUP := "interactables"

@export var spawn_scene: PackedScene
@export var button_label: String = "SPAWN"
@export var spawn_parent_path: NodePath = NodePath("../Enemies")
@export var target_path: NodePath = NodePath("../Player")
@export var spawn_offset: Vector2 = Vector2(300.0, 18.0)
@export var spawn_separation_radius: float = 28.0
@export var spawn_search_step: float = 24.0
@export var spawn_search_rings: int = 4
@export_flags_2d_physics var spawn_blocker_mask: int = 11

@onready var spawn_marker: Marker2D = get_node_or_null("SpawnMarker") as Marker2D
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group(INTERACTABLE_GROUP)
	label.text = button_label
	if spawn_marker != null:
		spawn_marker.position = spawn_offset


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
		spawned_2d.global_position = _find_safe_spawn_position(_get_spawn_position(), spawned_node)

	var target := get_node_or_null(target_path) as Node2D
	if target != null and spawned_node.has_method("set_target"):
		spawned_node.call("set_target", target)

	_flash_label()


func _get_spawn_position() -> Vector2:
	if spawn_marker != null:
		return spawn_marker.global_position

	return global_position + spawn_offset


func _find_safe_spawn_position(base_position: Vector2, spawned_node: Node) -> Vector2:
	var best_position := base_position
	var best_blocker_count := _get_spawn_blocker_count(base_position, spawned_node)
	if best_blocker_count <= 0:
		return base_position

	for ring in range(1, spawn_search_rings + 1):
		var ring_radius := spawn_search_step * float(ring)
		var candidate_count := maxi(8, ring * 8)
		for candidate_index in range(candidate_count):
			var angle := TAU * float(candidate_index) / float(candidate_count)
			var candidate_position := base_position + Vector2.RIGHT.rotated(angle) * ring_radius
			var blocker_count := _get_spawn_blocker_count(candidate_position, spawned_node)
			if blocker_count <= 0:
				return candidate_position
			if blocker_count < best_blocker_count:
				best_blocker_count = blocker_count
				best_position = candidate_position

	return best_position


func _get_spawn_blocker_count(spawn_position: Vector2, spawned_node: Node) -> int:
	if spawn_separation_radius <= 0.0:
		return 0

	var shape := CircleShape2D.new()
	shape.radius = spawn_separation_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, spawn_position)
	query.collision_mask = spawn_blocker_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if spawned_node is CollisionObject2D:
		query.exclude = [(spawned_node as CollisionObject2D).get_rid()]

	var blocker_count := get_world_2d().direct_space_state.intersect_shape(query, 8).size()
	var spawn_parent := spawned_node.get_parent()
	if spawn_parent != null:
		var separation_distance_squared := spawn_separation_radius * spawn_separation_radius
		for child in spawn_parent.get_children():
			if child == spawned_node or not child is Node2D:
				continue

			var child_2d := child as Node2D
			if spawn_position.distance_squared_to(child_2d.global_position) <= separation_distance_squared:
				blocker_count += 1

	return blocker_count


func _flash_label() -> void:
	label.modulate = Color(1.0, 0.88, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 0.25)

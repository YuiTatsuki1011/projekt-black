extends Area2D
class_name ItemContainer

@export var container_label: String = "LOOT BOX"
@export var inventory_screen_path: NodePath = NodePath("../InventoryScreen")

@onready var label: Label = $Label
@onready var inventory: Node = $Inventory


func _ready() -> void:
	label.text = container_label


func interact(_interactor: Node) -> void:
	var inventory_screen := get_node_or_null(inventory_screen_path)
	if inventory_screen == null:
		var current_scene := get_tree().current_scene
		if current_scene != null:
			inventory_screen = current_scene.get_node_or_null("InventoryScreen")

	if inventory_screen == null or not inventory_screen.has_method("open_external_inventory"):
		return

	inventory_screen.open_external_inventory(self)


func get_inventory() -> Node:
	return inventory


func get_container_label() -> String:
	return container_label

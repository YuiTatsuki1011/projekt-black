extends Area2D
class_name ItemContainer

@export var container_label: String = "LOOT BOX"
@export var inventory_screen_path: NodePath = NodePath("../InventoryScreen")
@export var requires_search: bool = true
@export var layout_search_time: float = 1.35
@export var item_identify_time: float = 1.0

@onready var label: Label = $Label
@onready var inventory: Node = $Inventory

var _layout_searched: bool = false
var _unknown_entries_initialized: bool = false


func _ready() -> void:
	label.text = container_label


func interact(_interactor: Node) -> void:
	prepare_for_search()
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


func prepare_for_search() -> void:
	if not requires_search or _unknown_entries_initialized:
		return
	if inventory != null and inventory.has_method("set_all_entries_identified"):
		inventory.call("set_all_entries_identified", false)
	_unknown_entries_initialized = true


func is_layout_searched() -> bool:
	return not requires_search or _layout_searched


func mark_layout_searched() -> void:
	_layout_searched = true


func get_layout_search_time() -> float:
	return maxf(layout_search_time, 0.01)


func get_item_identify_time() -> float:
	return maxf(item_identify_time, 0.01)

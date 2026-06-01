extends Area2D
class_name ItemGrantButton

@export var item_id: StringName = &"pistol_ammo"
@export var quantity: int = 12
@export var button_label: String = "AMMO"
@export var target_inventory_path: NodePath = NodePath("../Player/Inventory")

@onready var label: Label = $Label


func _ready() -> void:
	label.text = button_label


func interact(interactor: Node) -> void:
	var target_inventory: Node = get_node_or_null(target_inventory_path)
	if target_inventory == null and interactor != null:
		target_inventory = interactor.get_node_or_null("Inventory")
	if target_inventory == null or not target_inventory.has_method("add_item"):
		return

	target_inventory.add_item(item_id, quantity)
	_flash_label()


func _flash_label() -> void:
	label.modulate = Color(0.72, 0.92, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color.WHITE, 0.25)

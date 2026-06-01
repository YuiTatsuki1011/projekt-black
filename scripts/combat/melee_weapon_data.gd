extends Resource
class_name MeleeWeaponData

@export var weapon_id: StringName = &"field_knife"
@export var display_name: String = "Field Knife"
@export var combo_damages: PackedInt32Array = PackedInt32Array([34, 48, 68])
@export var stamina_cost: float = 30.0
@export var min_stamina_to_use: float = 15.0
@export var lunge_speed: float = 250.0
@export var lunge_time: float = 0.13
@export var strike_time: float = 0.11
@export var recovery_time: float = 0.2
@export var combo_reset_time: float = 0.75


func get_combo_count() -> int:
	return maxi(combo_damages.size(), 1)


func get_combo_damage(combo_index: int) -> int:
	if combo_damages.is_empty():
		return 0

	var index: int = clampi(combo_index, 0, combo_damages.size() - 1)
	return combo_damages[index]

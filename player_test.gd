extends Node2D

@export var fire_spell: SpellData  # drag fire_spell.tres here
@onready var caster: SpellCaster = $SpellCaster
 
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		caster.cast(fire_spell, get_global_mouse_position())

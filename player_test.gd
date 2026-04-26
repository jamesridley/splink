extends Node2D

@export var fire_spell: SpellData  # drag fire_spell.tres here
@export var earth_spell: SpellData
@onready var caster: SpellCaster = $SpellCaster
 
#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.pressed:
		#caster.cast(fire_spell, get_global_mouse_position())


func _on_spell_caster_ui_spell_cast(spell_name: String, intensity: float, cast_location: Vector2, spell_coords: Array) -> void:
	if spell_name == "fire":
		caster.cast(fire_spell, cast_location)
	elif spell_name == "earth":
		caster.cast(earth_spell,cast_location)

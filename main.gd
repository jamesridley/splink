extends Node2D
class_name Main

@export var starting_level: Level
@onready var camera_2d: Camera2D = $Camera2D
@onready var caster: SpellCaster = $SpellCaster
@export var fire_spell: SpellData  # drag fire_spell.tres here
@export var earth_spell: SpellData
@export var win_screen: PackedScene

@onready var spell_caster_ui: Control = $CanvasLayer/SpellCasterUi

var current_level: Level

func _ready() -> void:
	# Hide & disconnect every level up front so only one is live at a time.
	for child in get_children():
		if child is Level:
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.visible = false
			child.finished.connect(_on_level_finished)

	var first := starting_level if starting_level else _first_level()
	if first:
		_activate(first)

func _activate(level: Level) -> void:
	if current_level:
		current_level.finished.disconnect(_on_level_finished)
		current_level.set_process.call_deferred(false)
		current_level.visible = false
	
	camera_2d.target = level.spawn.get_child(0)
	spell_caster_ui.resetInk()

	current_level = level
	current_level.process_mode = Node.PROCESS_MODE_INHERIT
	current_level.visible = true
	current_level.reset()
	current_level.finished.connect(_on_level_finished)

func _on_level_finished(next_level: Node) -> void:
	if next_level is Level:
		_activate(next_level)
	else:
		# No next level — game complete. Hook in your end-screen logic here.
		print("All levels complete")
		var win = win_screen.instantiate()
		camera_2d.add_child(win)

func _first_level() -> Level:
	for child in get_children():
		if child is Level:
			return child
	return null

func _on_spell_caster_ui_spell_cast(spell_name: String, intensity: float, cast_location: Vector2, spell_coords: Array) -> void:
	if spell_name == "fire":
		caster.cast(fire_spell, cast_location)
	elif spell_name == "earth":
		caster.cast(earth_spell,cast_location)

extends Node2D
class_name EarthSpellPillar

@export var rise_speed: float = 200.0  # pixels per second
@export var pillar: Node2D

func _ready() -> void:
	var target_y := global_position.y
	var screen_bottom := get_viewport_rect().size.y
	print("[Pillar] target_y=", target_y, " screen_bottom=", screen_bottom, " distance=", screen_bottom - target_y)
	pillar.global_position.y = screen_bottom
	var distance := screen_bottom - target_y
	var duration := distance / rise_speed
	print("[Pillar] duration=", duration)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(pillar, "global_position:y", target_y, duration)

extends Node2D
class_name Level

@export var next_lvl: Node
@export var spawn: Node2D
signal finished(next_level)

func _ready() -> void:
	# Auto-connect every Goal under this level
	for goal in find_children("*", "Goal", true, false):
		goal.goal_reached.connect(on_goal_reached)

func reset() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and spawn:
		player.global_position = spawn.global_position

func on_goal_reached() -> void:
	print("got goal reached signal")
	finished.emit(next_lvl)

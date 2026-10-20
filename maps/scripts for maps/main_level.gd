extends Node3D

@onready var enemy : PackedScene = preload("res://mobs/balloon.tscn")

var enemies_to_spawn : int = 3
var can_spawn : bool = true

func _process(delta):
	game_manager()

func game_manager() -> void:
	if enemies_to_spawn > 0 and can_spawn:
		$spawnTimer.start()
		var tempEnemy = enemy.instantiate()
		$Path.add_child(tempEnemy)
		
		enemies_to_spawn -= 1
		
		can_spawn = false

func _on_timer_timeout() -> void:
	can_spawn = true

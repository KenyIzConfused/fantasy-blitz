extends Node3D

@onready var MUSHROOM : PackedScene = preload("res://mobs/mushroom.tscn")
@onready var BALLOON : PackedScene = preload("res://mobs/balloon.tscn")
@onready var BOULDER: PackedScene = preload("res://mobs/boulder.tscn")

@onready var enemies: Array[PackedScene] = [MUSHROOM, BALLOON, BOULDER]

var enemies_to_spawn : int = 20
var can_spawn : bool = true

func _process(delta):
	game_manager()

func game_manager() -> void:
	if enemies_to_spawn > 0 and can_spawn:
		$spawnTimer.start()
		var enemy = enemies.pick_random()
		var tempEnemy = enemy.instantiate()
		$Path.add_child(tempEnemy)
		
		enemies_to_spawn -= 1
		
		can_spawn = false

func _on_timer_timeout() -> void:
	can_spawn = true

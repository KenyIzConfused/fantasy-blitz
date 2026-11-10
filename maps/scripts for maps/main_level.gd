extends Node3D

## Enemy spawner + wave system for test.tscn.
##
## Wave 1 spawns BASE_ENEMIES; every following wave doubles the count
## (wave N = BASE_ENEMIES * 2^(N-1)). The wave number and its enemy count are
## broadcast on the "level_bridge" group so the HUD (prototype_level.gd) can
## display them:
##   get_tree().call_group("level_bridge", "on_wave_started", wave, count)

const MUSHROOM: PackedScene = preload("res://mobs/mushroom.tscn")
const BALLOON: PackedScene = preload("res://mobs/balloon.tscn")
const BOULDER: PackedScene = preload("res://mobs/boulder.tscn")

@onready var enemies: Array[PackedScene] = [MUSHROOM, BALLOON, BOULDER]

const BASE_ENEMIES := 5      ## Size of wave 1; wave N = BASE_ENEMIES * 2^(N-1)
const SPAWN_INTERVAL := 1.2  ## Seconds between individual enemies
const WAVE_BREAK := 3.0      ## Calm seconds between waves
const FIRST_WAVE_DELAY := 2.0

## Exactly one stat grows per wave, alternating: even waves add HP, odd waves
## (from wave 3 on) add speed.
const HEALTH_PER_HP_WAVE := 10
const SPEED_PER_SPEED_WAVE := 1

var wave: int = 0
var _to_spawn: int = 0
var _spawning: bool = false
var _break_time_left: float = FIRST_WAVE_DELAY

@onready var spawn_timer: Timer = $spawnTimer


func _ready() -> void:
	spawn_timer.wait_time = SPAWN_INTERVAL


func _process(delta: float) -> void:
	if _spawning:
		# The wave is over once everything has spawned and been cleared
		# (killed or escaped the map).
		if _to_spawn <= 0 and get_tree().get_nodes_in_group("Enemy").is_empty():
			_spawning = false
			_break_time_left = WAVE_BREAK
		return

	_break_time_left -= delta
	if _break_time_left <= 0.0:
		_start_wave()


## Begin the next wave, doubling the previous wave's enemy count.
func _start_wave() -> void:
	wave += 1
	_to_spawn = BASE_ENEMIES * int(pow(2.0, float(wave - 1)))
	_spawning = true
	spawn_timer.start()
	get_tree().call_group("level_bridge", "on_wave_started", wave, _to_spawn)


func _on_timer_timeout() -> void:
	if _to_spawn <= 0:
		spawn_timer.stop()
		return

	var enemy_scene: PackedScene = enemies.pick_random()
	var enemy := enemy_scene.instantiate()
	_apply_wave_stats(enemy)
	$Path.add_child(enemy)

	_to_spawn -= 1
	if _to_spawn <= 0:
		spawn_timer.stop()


## Boost exactly one stat per wave: even waves add HP, odd waves (from 3) add speed.
func _apply_wave_stats(mob: Node) -> void:
	var hp_steps := floori(wave / 2.0)
	var speed_steps := floori((wave - 1) / 2.0)
	for child in mob.get_children():
		if child.has_method("take_damage"):
			child.set("health", int(child.get("health")) + hp_steps * HEALTH_PER_HP_WAVE)
			child.set("speed", int(child.get("speed")) + speed_steps * SPEED_PER_SPEED_WAVE)
			break

extends Node3D

## Enemy spawner + wave director for a level.
##
## A level is TOTAL_WAVES waves. Enemy count grows linearly, and each wave the
## mobs get tougher and a little faster. Events are broadcast on the
## "level_bridge" group so the HUD / level script can react:
##   get_tree().call_group("level_bridge", "on_wave_started", wave, count)
##   get_tree().call_group("level_bridge", "on_level_cleared")

const MUSHROOM: PackedScene = preload("res://mobs/mushroom.tscn")
const BALLOON: PackedScene = preload("res://mobs/balloon.tscn")
const BOULDER: PackedScene = preload("res://mobs/boulder.tscn")

@onready var enemies: Array[PackedScene] = [MUSHROOM, BALLOON, BOULDER]

## --- difficulty tuning -------------------------------------------------------

## Waves in a level; clearing the last one wins.
const TOTAL_WAVES := 10
const BASE_ENEMIES := 4      ## Enemies in wave 1.
const ENEMIES_PER_WAVE := 2  ## Extra enemies added each following wave.
const BASE_HEALTH := 15      ## Mob health in wave 1.
const HEALTH_PER_WAVE := 12  ## Health added each wave.
const BASE_SPEED := 2.0      ## Mob speed in wave 1 (units/second).
const SPEED_PER_WAVE := 0.2  ## Speed added each wave.
const MAX_SPEED := 5.0       ## Speed cap so mobs never outrun every tower.

const SPAWN_INTERVAL := 1.0    ## Seconds between individual enemies.
const WAVE_BREAK := 4.0        ## Calm seconds between waves.
const FIRST_WAVE_DELAY := 3.0  ## Grace period before wave 1.

var wave: int = 0
var _to_spawn: int = 0
var _spawning: bool = false
var _finished: bool = false
var _boss_pending: int = 0
var _break_time_left: float = FIRST_WAVE_DELAY

@onready var spawn_timer: Timer = $spawnTimer


func _ready() -> void:
	spawn_timer.wait_time = SPAWN_INTERVAL


func _process(delta: float) -> void:
	if _finished:
		return

	if _spawning:
		# A wave is over once everything has spawned and been cleared
		# (killed or escaped the map).
		if _to_spawn <= 0 and get_tree().get_nodes_in_group("Enemy").is_empty():
			_spawning = false
			if wave >= TOTAL_WAVES:
				_finished = true
				get_tree().call_group("level_bridge", "on_level_cleared")
			else:
				_break_time_left = WAVE_BREAK
		return

	_break_time_left -= delta
	if _break_time_left <= 0.0:
		_start_wave()


## Begin the next wave. Enemy count grows linearly with the wave number.
func _start_wave() -> void:
	wave += 1
	_to_spawn = BASE_ENEMIES + (wave - 1) * ENEMIES_PER_WAVE
	# The final wave leads with a single heavily-buffed "boss" mob.
	_boss_pending = 1 if wave == TOTAL_WAVES else 0
	_spawning = true
	spawn_timer.start()
	get_tree().call_group("level_bridge", "on_wave_started", wave, _to_spawn)


func _on_timer_timeout() -> void:
	# The final wave's boss spawns first.
	if _boss_pending > 0:
		_boss_pending -= 1
		_spawn_enemy(true)
		return

	if _to_spawn <= 0:
		spawn_timer.stop()
		return

	_spawn_enemy(false)
	_to_spawn -= 1
	if _to_spawn <= 0:
		spawn_timer.stop()


func _spawn_enemy(is_boss: bool) -> void:
	var enemy_scene: PackedScene = enemies.pick_random()
	var enemy := enemy_scene.instantiate()
	_apply_wave_stats(enemy)
	if is_boss:
		_apply_boss(enemy)
	$Path.add_child(enemy)


## Make one mob the wave's boss: bigger, much tankier and a little slower.
func _apply_boss(mob: Node) -> void:
	for child in mob.get_children():
		if child.has_method("take_damage"):
			(child as Node3D).scale = Vector3(1.6, 1.6, 1.6)
			child.set("health", int(child.get("health")) * 4)
			child.set("speed", float(child.get("speed")) * 0.7)
			break


## Give a freshly spawned mob the health and speed for the current wave.
func _apply_wave_stats(mob: Node) -> void:
	var health := BASE_HEALTH + (wave - 1) * HEALTH_PER_WAVE
	var speed := minf(BASE_SPEED + (wave - 1) * SPEED_PER_WAVE, MAX_SPEED)
	for child in mob.get_children():
		if child.has_method("take_damage"):
			child.set("health", health)
			child.set("speed", speed)
			break

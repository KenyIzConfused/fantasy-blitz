extends StaticBody3D

## Archer tower (ballista). Watches its Area3D for enemies, turns in place to
## face the most-advanced one, and fires an arrow projectile on a cooldown.
##
## It never moves: only the round base under the weapon is yawed to aim the
## ballista. The base is radial, so the spin is invisible.

## Arrow scene fired by this tower.
const ARROW: PackedScene = preload("res://tower/arrow.tscn")

## Damage each arrow deals.
const ARROW_DAMAGE: int = 25

## Seconds between shots.
const COOLDOWN: float = 0.7

## How fast the ballista swings toward its target (higher = snappier).
const TURN_SPEED: float = 8.0

## --- upgrades ----------------------------------------------------------------
const BASE_COST := 100         ## Build cost; also the cost of the first upgrade.
const BASE_RANGE := 6.0        ## Attack range (metres) at level 1.
const MAX_LEVEL := 5           ## Highest upgrade level.
const DAMAGE_PER_LEVEL := 15   ## Extra damage each level.
const RANGE_PER_LEVEL := 0.5   ## Extra range (metres) each level.

## The round base node that carries (and aims) the ballista weapon.
@onready var _weapon: Node3D = $Base

## Per-instance copy of the range sphere so upgrades don't affect other towers.
var _range_shape: SphereShape3D

## Current upgrade level (1 = as built).
var level: int = 1

var current_targets: Array = []
var curr: CharacterBody3D = null
var can_shoot: bool = true

## Yaw the weapon is turning toward; held while idle.
var _target_yaw: float = 0.0


func _ready() -> void:
	$shootCooldown.one_shot = true
	$shootCooldown.wait_time = COOLDOWN
	# Duplicate the detector sphere so upgrading THIS tower is per-instance.
	_range_shape = ($mobDetector/CollisionShape3D.shape as SphereShape3D).duplicate()
	$mobDetector/CollisionShape3D.shape = _range_shape
	_range_shape.radius = get_range()


func _process(delta: float) -> void:
	if is_instance_valid(curr):
		var to_target: Vector3 = curr.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			# The ballista barrel points along the model's local -Z axis.
			_target_yaw = atan2(-to_target.x, -to_target.z)
		if can_shoot:
			shoot()
			can_shoot = false
			$shootCooldown.start()
	else:
		_clear_arrows()

	_weapon.rotation.y = lerp_angle(_weapon.rotation.y, _target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


## Fire one arrow that homes on the current target.
func shoot() -> void:
	var temp_arrow: CharacterBody3D = ARROW.instantiate()
	temp_arrow.target = curr
	temp_arrow.arrow_damage = get_damage()
	$arrowContainer.add_child(temp_arrow)
	temp_arrow.global_position = $Base/MeshInstance3D/Aim.global_position


## Remove any in-flight arrows once nothing is in range.
func _clear_arrows() -> void:
	for arrow: Node in $arrowContainer.get_children():
		arrow.queue_free()


## Lock onto the enemy that has travelled furthest along the path.
func choose_target(_current_targets: Array) -> void:
	var current_target: CharacterBody3D = null
	for i in _current_targets:
		if current_target == null:
			current_target = i
		elif i.get_parent().get_progress() > current_target.get_parent().get_progress():
			current_target = i
	curr = current_target


func _on_mob_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("Enemy"):
		current_targets.append(body)
		choose_target(current_targets)


func _on_mob_detector_body_exited(body: Node3D) -> void:
	if body.is_in_group("Enemy"):
		current_targets.erase(body)
		choose_target(current_targets)


func _on_shoot_cooldown_timeout() -> void:
	can_shoot = true


## --- upgrades (called by the HUD when the Upgrade button is pressed) ---------

func get_level() -> int:
	return level


func get_damage() -> int:
	return ARROW_DAMAGE + (level - 1) * DAMAGE_PER_LEVEL


func get_range() -> float:
	return BASE_RANGE + (level - 1) * RANGE_PER_LEVEL


## Gold for the next level, or 0 when already at MAX_LEVEL.
func upgrade_cost() -> int:
	return 0 if level >= MAX_LEVEL else BASE_COST * level


func upgrade() -> void:
	if level >= MAX_LEVEL:
		return
	level += 1
	if _range_shape != null:
		_range_shape.radius = get_range()

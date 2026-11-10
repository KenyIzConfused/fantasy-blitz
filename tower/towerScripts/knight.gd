extends StaticBody3D

## Knight tower (cannon). Detects enemies in range, turns in place to face the
## most-advanced one and fires a heavy blast on a short cooldown. Unlike the
## archer it deals damage instantly (no travelling projectile) with a small
## splash, making it the close-range bruiser of the three towers.
##
## It never moves: only the "Model" node is yawed to aim the cannon.

## Damage each blast deals to the locked target.
const DAMAGE: int = 60

## Seconds between blasts.
const COOLDOWN: float = 0.6

## Extra splash radius around the locked target.
const SPLASH_RADIUS: float = 1.5

## How fast the cannon swings toward its target (higher = snappier).
const TURN_SPEED: float = 10.0

## --- upgrades ----------------------------------------------------------------
const BASE_COST := 200         ## Build cost; also the cost of the first upgrade.
const BASE_RANGE := 3.0        ## Attack range (metres) at level 1.
const MAX_LEVEL := 5           ## Highest upgrade level.
const DAMAGE_PER_LEVEL := 25   ## Extra damage each level.
const RANGE_PER_LEVEL := 0.4   ## Extra range (metres) each level.

@onready var _model: Node3D = $Model

## Per-instance copy of the range sphere so upgrades don't affect other towers.
var _range_shape: SphereShape3D

## Current upgrade level (1 = as built).
var level: int = 1

var current_targets: Array = []
var curr: CharacterBody3D = null
var can_shoot: bool = true

## Yaw the cannon is turning toward; held while idle.
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
			# The cannon points along the model's local -Z axis.
			_target_yaw = atan2(-to_target.x, -to_target.z)
		if can_shoot:
			fire()
			can_shoot = false
			$shootCooldown.start()

	_model.rotation.y = lerp_angle(_model.rotation.y, _target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


## Blast the locked target and any nearby enemies inside SPLASH_RADIUS.
func fire() -> void:
	_damage(curr)
	for enemy: Node3D in current_targets:
		if enemy == curr or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(curr.global_position) <= SPLASH_RADIUS:
			_damage(enemy)


func _damage(enemy: Node3D) -> void:
	if is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.take_damage(get_damage())


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
	return DAMAGE + (level - 1) * DAMAGE_PER_LEVEL


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
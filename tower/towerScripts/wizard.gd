extends StaticBody3D

## Wizard tower. Mirrors `archer.gd` behaviour (Area3D range detector, a
## cooldown, target tracking) but stays put at its tile and turns in place:
##   * Its POSITION never changes - it does not chase or translate.
##   * The visual model rotates smoothly on the Y axis to face the enemy it is
##     attacking, and keeps that facing while idle.
##   * Animations crossfade: "idle" when nothing is in range, "attack" while
##     firing, blended over BLEND_TIME seconds so transitions look smooth.
##
## The Wizard GLB exposes "attack" and "idle" in its AnimationPlayer.

## Damage dealt per cast.
const SHOT_DAMAGE: int = 40

## Cooldown between casts (seconds).
const ATTACK_COOLDOWN: float = 1.0

## Extra splash radius around the locked target.
const SPLASH_RADIUS: float = 1.5

## How quickly the model turns to face a target (higher = snappier).
const TURN_SPEED: float = 8.0

## Crossfade time used when switching between idle and attack clips.
const BLEND_TIME: float = 0.25

## --- upgrades ----------------------------------------------------------------
const BASE_COST := 150         ## Build cost; also the cost of the first upgrade.
const BASE_RANGE := 5.0        ## Attack range (metres) at level 1.
const MAX_LEVEL := 5           ## Highest upgrade level.
const DAMAGE_PER_LEVEL := 20   ## Extra damage each level.
const RANGE_PER_LEVEL := 0.5   ## Extra range (metres) each level.

@onready var _model: Node3D = $Model

## Per-instance copy of the range sphere so upgrades don't affect other towers.
var _range_shape: SphereShape3D

## Current upgrade level (1 = as built).
var level: int = 1

var current_targets: Array = []
var curr: CharacterBody3D = null
var can_shoot: bool = true

## Yaw the model is turning toward; held while idle so the wizard keeps facing.
var _target_yaw: float = 0.0


func _ready() -> void:
	$shootCooldown.one_shot = true
	$shootCooldown.wait_time = ATTACK_COOLDOWN
	# Duplicate the detector sphere so upgrading THIS tower is per-instance.
	_range_shape = ($mobDetector/CollisionShape3D.shape as SphereShape3D).duplicate()
	$mobDetector/CollisionShape3D.shape = _range_shape
	_range_shape.radius = get_range()
	_setup_blends()
	_play_anim("idle")


func _process(delta: float) -> void:
	var has_target: bool = is_instance_valid(curr)
	if has_target:
		# Aim at the target: only yaw matters, so flatten the direction.
		var to_target: Vector3 = curr.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			# The WIZARD.glb model faces its local -Z axis, so aim the model's
			# -Z at the target: atan2 of the negated horizontal direction.
			_target_yaw = atan2(-to_target.x, -to_target.z)
		if can_shoot:
			shoot()
			can_shoot = false
			$shootCooldown.start()
		_play_anim("attack")
	else:
		_play_anim("idle")

	# Smooth, in-place rotation. Applies while attacking AND while idle.
	_model.rotation.y = lerp_angle(_model.rotation.y, _target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


## Plays the wizard's "attack" clip and damages the locked target plus any
## nearby enemies inside SPLASH_RADIUS.
func shoot() -> void:
	_play_anim("attack")
	_damage_target(curr)
	for enemy: Node3D in current_targets:
		if enemy == curr or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(curr.global_position) <= SPLASH_RADIUS:
			_damage_target(enemy)


## Pick the most-progressed enemy on the path as the current target.
func choose_target(_current_targets: Array) -> void:
	var temp_array: Array = _current_targets
	var current_target: CharacterBody3D = null
	for i in temp_array:
		if current_target == null:
			current_target = i
		else:
			if i.get_parent().get_progress() > current_target.get_parent().get_progress():
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


## --- animation helpers -------------------------------------------------------

## Set up symmetric crossfade times so idle<->attack switches fade together.
func _setup_blends() -> void:
	var anim_player: AnimationPlayer = _get_animation_player()
	if anim_player == null:
		return
	anim_player.set_blend_time("idle", "attack", BLEND_TIME)
	anim_player.set_blend_time("attack", "idle", BLEND_TIME)


## Play an animation with a crossfade. No-op if it is already playing so
## repeated per-frame calls do not restart the clip.
func _play_anim(anim_name: String) -> void:
	var anim_player: AnimationPlayer = _get_animation_player()
	if anim_player == null or not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation == anim_name and anim_player.is_playing():
		return
	anim_player.play(anim_name, BLEND_TIME)


## Walk the hierarchy to find the GLB's AnimationPlayer.
func _get_animation_player() -> AnimationPlayer:
	if has_node("Model/MeshInstance3D"):
		var result: AnimationPlayer = _find_animation_player($Model/MeshInstance3D)
		if result != null:
			return result
	return _find_animation_player(self)


func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var nested: AnimationPlayer = _find_animation_player(child)
		if nested != null:
			return nested
	return null


## --- upgrades (called by the HUD when the Upgrade button is pressed) ---------

func get_level() -> int:
	return level


func get_damage() -> int:
	return SHOT_DAMAGE + (level - 1) * DAMAGE_PER_LEVEL


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


func _damage_target(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("take_damage"):
		enemy.take_damage(get_damage())
extends Control

## Dedicated end-of-run VICTORY modal, SEPARATE from the defeat screen.
##
## Clash-of-Clans-style star rating: winning always earns at least 1 star, and
## each enemy you let through costs one - so a flawless defense is 3 stars, one
## leak is 2, two or more is 1. The stars pop in one at a time on reveal.
##
## Runs while the SceneTree is paused (process_mode = ALWAYS) so its buttons
## stay clickable. Hidden until show_victory() is called.

@onready var _wave_value: Label = %WaveValue
@onready var _kills_value: Label = %KillsValue
@onready var _stars: Array[TextureRect] = [%Star1, %Star2, %Star3]
@onready var _star_label: Label = %StarLabel
@onready var _retry_button: TextureButton = %RetryButton
@onready var _main_menu_button: TextureButton = %MainMenuButton

const MAX_STARS := 3
const _DIM := Color(0.24, 0.24, 0.28, 0.6)   ## Unearned star colour.
const _LIT := Color.WHITE                     ## Earned star colour.


func _ready() -> void:
	visible = false
	_retry_button.pressed.connect(_on_retry_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_reset_stars()


## Reveal the win modal with the run's stats and the earned star count.
## The caller pauses the tree.
func show_victory(wave_reached: int, enemies_defeated: int, stars: int) -> void:
	_wave_value.text = str(wave_reached)
	_kills_value.text = str(enemies_defeated)
	var earned := clampi(stars, 1, MAX_STARS)
	_star_label.text = "%d / %d Stars" % [earned, MAX_STARS]
	show()
	# Wait one frame so the star rects have their final size, then pop them in.
	_play_star_reveal.call_deferred(earned)


func _reset_stars() -> void:
	for star in _stars:
		star.modulate = _DIM
		star.scale = Vector2.ONE


## Fade the earned stars in one by one with a springy pop, COC-style.
func _play_star_reveal(stars: int) -> void:
	_reset_stars()
	for i in _stars.size():
		var star := _stars[i]
		if i >= stars:
			continue
		star.pivot_offset = star.size * 0.5
		star.modulate = _LIT
		star.scale = Vector2(0.2, 0.2)
		var tween := create_tween()
		tween.tween_interval(0.16 * i)
		tween.tween_property(star, "scale", Vector2(1.28, 1.28), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "scale", Vector2.ONE, 0.12)


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/Title_Screen.tscn")
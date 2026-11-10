extends Control

## Defeat / game-over modal, shown when all lives are lost. Skull crest, a big
## "DEFEAT" title, run stats (wave reached, enemies defeated) and Retry / Main
## Menu buttons. Runs while the tree is paused (process_mode = ALWAYS) so its
## buttons stay clickable. Hidden until show_defeat() is called.
## Winning uses its own dedicated screen (UI/Victory_Screen.tscn).

@onready var _wave_value: Label = %WaveValue
@onready var _kills_value: Label = %KillsValue
@onready var _retry_button: TextureButton = %RetryButton
@onready var _main_menu_button: TextureButton = %MainMenuButton


func _ready() -> void:
	visible = false
	_retry_button.pressed.connect(_on_retry_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)


## Fill in the run's stats and reveal the defeat modal. The caller pauses the tree.
func show_defeat(wave_reached: int, enemies_defeated: int) -> void:
	_wave_value.text = str(wave_reached)
	_kills_value.text = str(enemies_defeated)
	show()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/Title_Screen.tscn")
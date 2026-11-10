extends Control

## End-of-run modal: shown on both DEFEAT (all lives lost) and VICTORY (all
## waves cleared). Skull crest, a big title, run stats (wave reached, enemies
## defeated) and Retry / Main Menu buttons. Runs while the tree is paused
## (process_mode = ALWAYS) so its buttons stay clickable. Hidden until
## show_defeat() / show_victory() is called.

@onready var _title: Label = $Frame/Column/DefeatLabel
@onready var _wave_value: Label = %WaveValue
@onready var _kills_value: Label = %KillsValue
@onready var _retry_button: TextureButton = %RetryButton
@onready var _main_menu_button: TextureButton = %MainMenuButton

const _DEFEAT_COLOR := Color(1, 0.4, 0.2, 1)
const _VICTORY_COLOR := Color(0.45, 1, 0.4, 1)


func _ready() -> void:
	visible = false
	_retry_button.pressed.connect(_on_retry_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)


## Show the game-over modal with the run's stats (the caller pauses the tree).
func show_defeat(wave_reached: int, enemies_defeated: int) -> void:
	_present("DEFEAT", _DEFEAT_COLOR, wave_reached, enemies_defeated)


## Show the win modal with the run's stats (the caller pauses the tree).
func show_victory(wave_reached: int, enemies_defeated: int) -> void:
	_present("VICTORY!", _VICTORY_COLOR, wave_reached, enemies_defeated)


func _present(title: String, color: Color, wave_reached: int, enemies_defeated: int) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_wave_value.text = str(wave_reached)
	_kills_value.text = str(enemies_defeated)
	show()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/Title_Screen.tscn")
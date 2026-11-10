extends Control

## Title screen controller. Wires up the three menu buttons and owns what
## each one does. The button visuals are baked textures on TitleButton nodes.
const map = preload("res://maps/playablemaps/test_prototype_gameplay_ui.tscn")

@onready var _start_button: TextureButton = %StartButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _exit_button: TextureButton = %ExitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_start_button.grab_focus()
	## Set the custom crystal mouse cursor (grey-crystal style, CC-BY inspired).
	Input.set_custom_mouse_cursor(
		preload("res://assets/generated/cursor_crystal.png"),
		Input.CURSOR_ARROW,
		Vector2(4, 4)
	)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(map)
	print("Title screen: Start Game pressed")


func _on_settings_pressed() -> void:
	# TODO: open the settings menu / panel.
	print("Title screen: Settings pressed")


func _on_exit_pressed() -> void:
	get_tree().quit()

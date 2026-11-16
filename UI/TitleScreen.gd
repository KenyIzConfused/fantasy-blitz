extends Control

## Title screen controller. Wires up the three menu buttons and owns what
## each one does. The button visuals are baked textures on TitleButton nodes.
const map = preload("res://maps/playablemaps/test_prototype_gameplay_ui.tscn")

@onready var _start_button: TextureButton = %StartButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _exit_button: TextureButton = %ExitButton
@onready var _settings_panel: SettingsPanel = $SettingsPanel


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_start_button.grab_focus()
	## Set the custom crystal mouse cursor (grey-crystal style, CC-BY inspired).
	Input.set_custom_mouse_cursor(
		preload("res://assets/generated/cursor_crystal.png"),
		Input.CURSOR_ARROW,
		Vector2(1, 1)
	)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(map)
	print("Title screen: Start Game pressed")


func _on_settings_pressed() -> void:
	_settings_panel.open()


## Esc closes the settings panel when it is open (the panel also handles this
## itself; the guard here keeps the two from ever double-acting).
func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel.is_open() and event.is_action_pressed("ui_cancel"):
		_settings_panel.close()
		get_viewport().set_input_as_handled()


func _on_exit_pressed() -> void:
	get_tree().quit()

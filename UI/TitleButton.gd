class_name TitleButton
extends TextureButton

## Chunky wooden title-menu button with a springy hover / press animation.
## The button art is baked into the texture, so feedback is done with a
## scale + tint tween instead of separate hover/pressed textures.

const _HOVER_SCALE := 1.06
const _PRESS_SCALE := 0.95
const _HOVER_TINT := Color(1.12, 1.12, 1.12, 1.0)
const _PRESS_TINT := Color(0.92, 0.92, 0.92, 1.0)


var _tween: Tween


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	resized.connect(_update_pivot)
	_update_pivot()
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	focus_entered.connect(_on_hover_start)
	focus_exited.connect(_on_hover_end)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _on_hover_start() -> void:
	_animate(_HOVER_SCALE, _HOVER_TINT)


func _on_hover_end() -> void:
	_animate(1.0, Color.WHITE)


func _on_button_down() -> void:
	_animate(_PRESS_SCALE, _PRESS_TINT)


func _on_button_up() -> void:
	_animate(_HOVER_SCALE, _HOVER_TINT)


func _animate(target_scale: float, target_tint: Color) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", target_tint, 0.12)

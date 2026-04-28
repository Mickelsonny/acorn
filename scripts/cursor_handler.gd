extends Node

var main_cursor := preload("res://assets/cursors/main_cursor.png")
var hover_cursor := preload("res://assets/cursors/hover_cursor.png")
var click_cursor := preload("res://assets/cursors/click_cursor.png")
var unavailable_cursor := preload("res://assets/cursors/unavailable_cursor.png")

var hotspot := Vector2.ZERO
var previous_state := Input.CURSOR_ARROW

func _ready() -> void:
	Input.set_custom_mouse_cursor(main_cursor, Input.CURSOR_ARROW, hotspot)
	Input.set_custom_mouse_cursor(hover_cursor, Input.CURSOR_POINTING_HAND, hotspot)
	Input.set_custom_mouse_cursor(click_cursor, Input.CURSOR_IBEAM, hotspot) # Random
	Input.set_custom_mouse_cursor(unavailable_cursor, Input.CURSOR_FORBIDDEN, hotspot) # Random

func set_main() -> void:
	previous_state = Input.CURSOR_ARROW
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func set_hover() -> void:
	previous_state = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func set_unavailable() -> void:
	previous_state = Input.CURSOR_FORBIDDEN
	Input.set_default_cursor_shape(Input.CURSOR_FORBIDDEN)
	
func set_click() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_IBEAM)
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			set_click()
		else:
			# Revert to previous state on release
			Input.set_default_cursor_shape(previous_state)

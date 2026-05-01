extends Node

@onready var shake_tree_area2d: Area2D = $Area2D
@onready var animated_sprite2d: AnimatedSprite2D = $AnimatedSprite2D

var within_shake_range: bool = false
var within_cursor_range: bool = false

func shake_tree() -> void:
	animated_sprite2d.play("shake")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	shake_tree_area2d.body_entered.connect(_on_body_entered)
	shake_tree_area2d.body_exited.connect(_on_body_exited)
	shake_tree_area2d.mouse_entered.connect(_on_mouse_entered)
	shake_tree_area2d.mouse_exited.connect(_on_mouse_exited)

func _unhandled_input(event: InputEvent) -> void:
	if within_shake_range and within_cursor_range:
		if !animated_sprite2d.is_playing() and event.is_action_pressed("shake"):
			shake_tree()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		within_shake_range = true
		_update_cursor_state()

func _on_body_exited(body: Node2D) 	-> void:
	if body.is_in_group("player"):
		within_shake_range = false
		_update_cursor_state()

func _on_mouse_entered() -> void:
	within_cursor_range = true
	_update_cursor_state()

func _on_mouse_exited() -> void:
	within_cursor_range = false
	_update_cursor_state()

func _update_cursor_state() -> void:
	if within_cursor_range and within_shake_range:
		CursorHandler.set_hover()
	elif within_cursor_range and not within_shake_range:
		CursorHandler.set_unavailable()
	else:
		CursorHandler.set_main()

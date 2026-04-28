extends Node

@onready var shake_tree_area2d: Area2D = $Area2D
@onready var animated_sprite2d: AnimatedSprite2D = $AnimatedSprite2D

enum FruitState {FRUITLESS, RIPE, UNRIPE}

const REGROW_MIN_SECONDS := 15.0
const REGROW_MAX_SECONDS := 45.0

var current_state: FruitState
var regrow_sequence: int = 0 # Prevents multiple old/new regrow timers from messing with each other

var within_shake_range: bool = false
var within_cursor_range: bool = false

func update_state_and_texture(desired_state: FruitState, desiredStateName: String) -> void:
	current_state = desired_state
	
	# Update tree texture; automatically frame 0
	animated_sprite2d.animation = desiredStateName
	animated_sprite2d.stop()
	
	_schedule_regrow()

func set_fruit_state(desired_state: FruitState, caused_by_shake: bool) -> void:
	# Return just in case for non-player calls
	if animated_sprite2d.is_playing():
		return
	
	var currentStateName = FruitState.keys()[current_state].to_lower()
	var desiredStateName = FruitState.keys()[desired_state].to_lower()
	
	# If initializing, don't play shake animation
	if caused_by_shake:
		animated_sprite2d.play(currentStateName)
	
		animated_sprite2d.animation_finished.connect(func() -> void:
			update_state_and_texture(desired_state, desiredStateName)
		, CONNECT_ONE_SHOT)
	else:
		update_state_and_texture(desired_state, desiredStateName)

func _schedule_regrow() -> void:
	if current_state == FruitState.RIPE:
		return

	regrow_sequence += 1
	var scheduled_sequence = regrow_sequence
	var regrow_delay = randf_range(REGROW_MIN_SECONDS, REGROW_MAX_SECONDS)

	get_tree().create_timer(regrow_delay).timeout.connect(func() -> void:
		if scheduled_sequence != regrow_sequence:
			return

		if current_state == FruitState.FRUITLESS:
			set_fruit_state(FruitState.UNRIPE, false)
		elif current_state == FruitState.UNRIPE:
			set_fruit_state(FruitState.RIPE, false)
	, CONNECT_ONE_SHOT)

func shake_tree() -> void:
	var currentStateName = FruitState.keys()[current_state].to_lower()
	animated_sprite2d.play(currentStateName)

	# Only if it's ripe does the state need to update
	if current_state == FruitState.RIPE:
		animated_sprite2d.animation_finished.connect(func() -> void:
			update_state_and_texture(FruitState.FRUITLESS, "fruitless")
		, CONNECT_ONE_SHOT) # 4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Randomly determine the fruit tree's starting state when first spawned in
	var random_fruit_state = FruitState.values().pick_random()
	set_fruit_state(random_fruit_state, false)
	
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

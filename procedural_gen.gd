extends Node2D

@export var width = 600
@export var height = 200
@onready var tileMapLayer = $TileMapLayer

var temperature = {}
var moisture = {}
var altitude = {}
var biome = {}
var fastNoiseLite = FastNoiseLite.new()

func generate_map(period, octave):
	fastNoiseLite.seed = randi()
	fastNoiseLite.frequency = 1.0 / period
	fastNoiseLite.fractal_octaves = octave
	
	var gridName = {}
	for x in width:
		for y in height:
			# Returns the value of the noise at a specific position (in this case, x and y) multiplied by 2
			var rand: float = 2 * (abs(fastNoiseLite.get_noise_2d(x, y)))
			# Vector2 of the position as the key
			gridName[Vector2(x, y)] = rand
	
	return gridName

func set_tile(width, height):
	for x in width:
		for y in height:
			# The altitude, temperature, and moisture at a certain position
			var pos = Vector2(x, y)
			var alt = altitude[pos]
			var temp = temperature[pos]
			var moist = moisture[pos]
			
			# Test
			if alt < 0.2:
				tileMapLayer.set_cell(pos, 0, Vector2(0, 12))
			else:
				tileMapLayer.set_cell(pos, 0, Vector2(0, 0))

# Helper comparison function for biome deciding
func in_between(val, start, end):
	if start <= val and val < end:
		return true

# Function to better visualize the procedurally generated world when pressing space bar/enter
func _input(event):
	if event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	temperature = generate_map(300, 5)
	moisture = generate_map(300, 5)
	altitude = generate_map(150, 5)
	
	set_tile(width, height)

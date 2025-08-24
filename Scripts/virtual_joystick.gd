# virtual_joystick.gd
extends Control

@export var radius := 100.0
@export var deadzone := 0.1

var touch_index := -1
var center := Vector2.ZERO
var output := Vector2.ZERO

func _ready():
	center = size / 2

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and get_global_rect().has_point(event.position):
			touch_index = event.index
		elif event.index == touch_index:
			touch_index = -1
			output = Vector2.ZERO
			_update_output()
	
	if event is InputEventScreenDrag and event.index == touch_index:
		var touch_pos = event.position - global_position
		var vector = touch_pos - center
		var length = vector.length()
		
		if length <= deadzone * radius:
			output = Vector2.ZERO
		else:
			output = vector.normalized() * min(length / radius, 1.0)
		
		_update_output()

func _update_output():
	# Setze die joystick_output Variable des Players
	var player = get_parent().get_parent()
	if player and player.has_method("set_joystick_output"):
		player.joystick_output = output

func _draw():
	if touch_index != -1:
		draw_circle(center, radius, Color(1, 1, 1, 0.2))
		draw_line(center, center + output * radius, Color.WHITE, 3.0)

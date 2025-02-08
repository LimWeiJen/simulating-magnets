extends Node3D

@export var mouse_sensitivity = 0.005
@export var zoom_sensitivity = 2

var moving_screen = false

@export var camera: Camera3D
@export var plane: Plane
@export var arrow: Node3D

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$Camera3D.fov -= zoom_sensitivity
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$Camera3D.fov += zoom_sensitivity
	if event is InputEventMouseButton and event.as_text() == "Middle Mouse Button":
		if event.pressed:
			moving_screen = true
		else:
			moving_screen = false

func _unhandled_input(event):
	if event is InputEventMouseMotion and moving_screen:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x -= event.relative.y * mouse_sensitivity

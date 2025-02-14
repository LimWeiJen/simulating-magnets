extends Node3D

@export var mouse_sensitivity = 0.005
@export var zoom_sensitivity = 2

var moving_screen = false

@export var camera: Camera3D
@export var plane: Plane
@export var arrow: Node3D

@onready var magnetic_field_calculator = get_parent()

func _process(delta):
	$"../CanvasLayer/HSlider3".value = 180 - $Camera3D.fov
	$"../CanvasLayer/Label5".text = "Position: " + str(int(arrow.global_position.x*10)) + "," + str(int(arrow.global_position.z*10))

func _input(event):
	if event is InputEventMagnifyGesture:
		$Camera3D.fov += event.factor * zoom_sensitivity
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
	if event is InputEventMouseButton and event.as_text() == "Left Mouse Button":
		var is_moving_current = false
		for current in magnetic_field_calculator.currents:
			if (current as Current).is_following_mouse:
				is_moving_current = true
		if event.pressed and not is_moving_current:
			moving_screen = true
		else:
			moving_screen = false

func _unhandled_input(event):
	if event is InputEventMouseMotion and moving_screen:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x -= event.relative.y * mouse_sensitivity

func _on_h_slider_3_value_changed(value):
	$Camera3D.fov = 180 - value

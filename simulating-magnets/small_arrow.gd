extends Node3D

class_name Arrow

@export var color: Color = Color("ba1616")
@export var hue = 0

func _process(_delta):
	color.h = hue

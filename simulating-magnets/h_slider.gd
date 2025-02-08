extends HSlider

@export var plane: MeshInstance3D

func _on_value_changed(value):
	plane.global_position.y = value * 0.01

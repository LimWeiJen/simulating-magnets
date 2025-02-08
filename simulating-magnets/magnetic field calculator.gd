extends Node3D

@export var currents: Array[Current]

@export var arrow: Node3D

const u = 4 * PI # ignored 10^-7, ie scaled by 10^7

@export var camera: Camera3D
@export var plane: Plane

var current = preload("res://current.tscn")

var total_current = 0
var selected_current: Current = null

func set_arrow_pos():
	plane.d = $"CanvasLayer/HSlider".value * 0.01
	var position2D = get_viewport().get_mouse_position()
	var dropPlane  = plane
	var position3D = dropPlane.intersects_ray(camera.project_ray_origin(position2D),camera.project_ray_normal(position2D))
	if position3D:
		arrow.global_position = position3D

func rotate_arrow_towards(arr, dir: Vector3):
	arr.look_at(arr.global_position + dir, Vector3.UP)

func scale_arrow_according_to(arr, dir: Vector3):
	arr.scale = Vector3.ONE * min(dir.length(), 100) * 0.002

func set_arrow_transparency(arr, dir: Vector3):
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("30488b")
	mat.albedo_color.a = (dir.length() / 100)
	arr.get_node("MeshInstance3D").mesh = arr.get_node("MeshInstance3D").mesh.duplicate()
	arr.get_node("MeshInstance3D2").mesh = arr.get_node("MeshInstance3D2").mesh.duplicate()
	arr.get_node("MeshInstance3D").mesh.surface_set_material(0, mat.duplicate())
	arr.get_node("MeshInstance3D2").mesh.surface_set_material(0, mat.duplicate())

func as_vector_2(vec: Vector3):
	return Vector2(vec.x, vec.z)

func magnetic_field_strength(current_pos: Vector3, current_val: float, target_pos: Vector3, rotate_to_x = false, rotate_to_z = false) -> Vector3:
	if rotate_to_z:
		var res_in_magnitude = (u * current_val) / (2 * PI * target_pos.distance_to(Vector3(target_pos.x, current_pos.y, current_pos.z)))
		var res_in_dir = (Vector3(target_pos.x, current_pos.y, current_pos.z) - target_pos).normalized()
		var rotated = res_in_dir.rotated(Vector3.LEFT, deg_to_rad(90))
		return rotated * res_in_magnitude
	elif rotate_to_x:
		var res_in_magnitude = (u * current_val) / (2 * PI * target_pos.distance_to(Vector3(current_pos.x, current_pos.y, target_pos.z)))
		var res_in_dir = (Vector3(current_pos.x, current_pos.y, target_pos.z) - target_pos).normalized()
		var rotated = res_in_dir.rotated(Vector3.BACK, deg_to_rad(90))
		return rotated * res_in_magnitude
	else:
		var res_in_magnitude = (u * current_val) / (2 * PI * target_pos.distance_to(Vector3(current_pos.x, target_pos.y, current_pos.z)))
		var res_in_dir = (Vector3(current_pos.x, target_pos.y, current_pos.z) - target_pos).normalized()
		var rotated = res_in_dir.rotated(Vector3.UP, deg_to_rad(90))
		return rotated * res_in_magnitude

# Called when the node enters the scene tree for the first time.
func _ready():
	rotate_arrow_towards(arrow,
	magnetic_field_strength(
		Vector3.ZERO,
		5,
		Vector3(0, -sqrt(2), 0)
	))

func update_dynamic_arrow():
	arrow.visible = len(currents) != 0
	
	if selected_current and selected_current.is_following_mouse:
		arrow.visible = false
	
	set_arrow_pos()
	
	var resultant_field = Vector3.ZERO
	
	for current in currents:
		resultant_field += magnetic_field_strength(
			current.global_position,
			current.curr_val,
			arrow.global_position,
			current.rotate_to_x,
			current.rotate_to_z
		)
	
	rotate_arrow_towards(arrow, resultant_field)
	scale_arrow_according_to(arrow, resultant_field)
	
	$CanvasLayer/Label2.text = "Magnetic Field Strength: " + str(resultant_field.length()) + "x10^7 T"

func update_current_dir_display():
	if not selected_current: return
	if selected_current.rotate_to_x:
		$CanvasLayer/Button3.text = "Direction: X"
	elif selected_current.rotate_to_z:
		$CanvasLayer/Button3.text = "Direction: Z"
	else:
		$CanvasLayer/Button3.text = "Direction: Y"
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	update_current_dir_display()
	update_dynamic_arrow()
	if selected_current:
		$CanvasLayer/Label.text = "Current: " + str(selected_current.curr_val) + "A"
		$CanvasLayer/HSlider2.value = selected_current.curr_val
		selected_current.get_node("Selected").visible = not selected_current.is_within_editable_distance()
	for arr in $Plane.get_children():
		var resultant_field = Vector3.ZERO
		for current in currents:
			if selected_current != current:
				current.get_node("Selected").visible = false
			resultant_field += magnetic_field_strength(
				current.global_position,
				current.curr_val,
				arr.global_position,
				current.rotate_to_x,
				current.rotate_to_z
			)
		rotate_arrow_towards(arr, resultant_field)
		set_arrow_transparency(arr, resultant_field)

func _on_button_pressed():
	var cur = current.instantiate()
	add_child(cur)
	cur.arrow = arrow
	cur.camera = camera
	cur.curr_index = total_current
	total_current += 1
	currents.append(cur)
	selected_current = cur

func _on_h_slider_2_value_changed(value):
	selected_current.curr_val = value

func _on_button_2_pressed():
	for i in len(currents):
		if currents[i].curr_index == selected_current.curr_index:
			currents.remove_at(i)
			selected_current.queue_free()
			selected_current = currents[0]
			break

func _on_button_3_pressed():
	if selected_current.rotate_to_x:
		selected_current.rotate_to_x = false
		selected_current.rotate_to_z = true
		$CanvasLayer/Button3.text = "Direction: Z"
	elif selected_current.rotate_to_z:
		selected_current.rotate_to_z = false
		selected_current.rotate_to_x = false
		$CanvasLayer/Button3.text = "Direction: Y"
	else:
		selected_current.rotate_to_x = true
		selected_current.rotate_to_z = false
		$CanvasLayer/Button3.text = "Direction: X"

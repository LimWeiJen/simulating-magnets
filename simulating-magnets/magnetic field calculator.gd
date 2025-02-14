extends Node3D

@export var currents: Array[Current]

@export var arrow: Node3D

const u = 4 * PI # ignored 10^-7, ie scaled by 10^7

@export var camera: Camera3D
@export var plane: Plane

var current = preload("res://current/standing current/current.tscn")
var circular_current = preload("res://current/circular current/circular current.tscn")
var solenoidal_current = preload("res://current/circular coil/circular coil.tscn")

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
	mat.albedo_color = Color("30488b")
	mat.albedo_color.v = (dir.length() / 500)
	arr.get_node("Arrow").mesh = arr.get_node("Arrow").mesh.duplicate()
	arr.get_node("Arrow").mesh.surface_set_material(0, mat.duplicate())

func set_arrow_sound(dir: Vector3):
	$AudioStreamPlayer.volume_db = min(dir.length() * 0.1 - 10, 5)

func as_vector_2(vec: Vector3):
	return Vector2(vec.x, vec.z)

func circular_magnetic_field_strength(target_pos: Vector3, center: Vector3, r: float, normal: Vector3, I: float) -> Vector3:
	# Define the magnetic constant μ0 (in SI units, μ0 = 4π × 10⁻⁷ T·m/A)
	var mu0 = 4.0 * PI
	# Pre-factor from Biot-Savart law: (μ0 I)/(4π)
	var factor = mu0 * I / (4.0 * PI)
	
	# Initialize the magnetic field vector
	var B = Vector3()
	
	# Normalize the provided normal so it really is a unit vector.
	var n = normal.normalized()
	
	# To parameterize the circle, we need two perpendicular unit vectors (u and v) lying in the plane.
	# We start with an arbitrary vector that is not parallel to n.
	var arbitrary = Vector3(0, 1, 0)
	if abs(n.dot(arbitrary)) > 0.99:
		arbitrary = Vector3(1, 0, 0)
	
	# u and v will form an orthonormal basis for the plane of the loop.
	var u = n.cross(arbitrary).normalized()
	var v = n.cross(u).normalized()
	
	# Choose the number of steps in the integration (more steps → better accuracy).
	var steps = 128
	var dtheta = 2.0 * PI / steps
	
	# Loop over the circle
	for i in range(steps):
		var theta = i * dtheta
		# Calculate the position of the current element on the loop.
		# The point on the circle is: center + r*(u*cos(theta) + v*sin(theta))
		var pos = center + r * (u * cos(theta) + v * sin(theta))
		
		# The differential length element (dL) along the loop is the derivative with respect to theta:
		# dL/dtheta = -r*u*sin(theta) + r*v*cos(theta)
		# Multiply by dtheta to get the actual segment.
		var dL = r * (-u * sin(theta) + v * cos(theta)) * dtheta
		
		# The vector from the current element to the target position.
		var R = target_pos - pos
		var R_mag = R.length()
		# Avoid division by zero if the target is exactly on the current element.
		if R_mag == 0:
			continue
		
		# Compute the differential magnetic field contribution using the Biot–Savart law.
		var dB = factor * (dL.cross(R)) / pow(R_mag, 3)
		
		# Sum up the contributions.
		B += dB
	return B

func solenoid_magnetic_field_strength(target_pos: Vector3, solenoid: Current, direction: Vector3) -> Vector3:
	var B = Vector3.ZERO
	for coil in solenoid.get_children():
		if coil.name.begins_with("Border"):
			B += circular_magnetic_field_strength(target_pos, coil.global_position, 0.1, direction, solenoid.curr_val)
	return B

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
		if selected_current != current:
			current.get_node("Selected").visible = false
		if current.is_circular:
			var direction = Vector3.UP
			if current.rotate_to_x:
				direction = Vector3.FORWARD
			elif current.rotate_to_z:
				direction = Vector3.LEFT
			resultant_field += circular_magnetic_field_strength(
				arrow.global_position,
				current.global_position,
				0.5,
				direction,
				current.curr_val
			)
		elif current.is_solenoid:
			var direction = Vector3.BACK
			if current.rotate_to_x:
				direction = Vector3.DOWN
			elif current.rotate_to_z:
				direction = Vector3.RIGHT
			resultant_field += solenoid_magnetic_field_strength(
				arrow.global_position,
				current,
				direction
			)
		else:
			resultant_field += magnetic_field_strength(
				current.global_position,
				current.curr_val,
				arrow.global_position,
				current.rotate_to_x,
				current.rotate_to_z
			)
	
	rotate_arrow_towards(arrow, resultant_field)
	scale_arrow_according_to(arrow, resultant_field)
	set_arrow_sound(resultant_field)
	
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
			if current.is_circular:
				var direction = Vector3.UP
				if current.rotate_to_x:
					direction = Vector3.FORWARD
				elif current.rotate_to_z:
					direction = Vector3.LEFT
				resultant_field += circular_magnetic_field_strength(
					arr.global_position,
					current.global_position,
					0.5,
					direction,
					current.curr_val
				)
			elif current.is_solenoid:
				var direction = Vector3.BACK
				if current.rotate_to_x:
					direction = Vector3.DOWN
				elif current.rotate_to_z:
					direction = Vector3.RIGHT
				resultant_field += solenoid_magnetic_field_strength(
					arr.global_position,
					current,
					direction
				)
			else:
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
			if len(currents) >= 1:
				selected_current = currents[0]
			else:
				selected_current = null
			break

func _on_button_3_pressed():
	if selected_current.rotate_to_x:
		selected_current.rotate_to_x = false
		selected_current.rotate_to_z = true
		$CanvasLayer/Button3.text = "Direction: Z"
		selected_current.global_position.x = 0
	elif selected_current.rotate_to_z:
		selected_current.rotate_to_z = false
		selected_current.rotate_to_x = false
		$CanvasLayer/Button3.text = "Direction: Y"
		selected_current.global_position.y = 0
	else:
		selected_current.rotate_to_x = true
		selected_current.rotate_to_z = false
		$CanvasLayer/Button3.text = "Direction: X"
		selected_current.global_position.z = 0


func _on_button_4_pressed():
	var cur = circular_current.instantiate()
	add_child(cur)
	cur.arrow = arrow
	cur.camera = camera
	cur.curr_index = total_current
	total_current += 1
	currents.append(cur)
	selected_current = cur


func _on_button_5_pressed():
	var cur = solenoidal_current.instantiate()
	add_child(cur)
	cur.arrow = arrow
	cur.camera = camera
	cur.curr_index = total_current
	total_current += 1
	currents.append(cur)
	selected_current = cur

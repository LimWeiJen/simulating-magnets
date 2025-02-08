extends MeshInstance3D

class_name Current

@export var curr_val = 5
@export var arrow: Node3D

var is_following_mouse = false
var curr_index = 0

var rotate_to_x = false
var rotate_to_z = false

var camera: Camera3D

func as_vector_2(vec: Vector3):
	return Vector2(vec.x, vec.z)

func get_mouse_pos(p: Plane):
	var position2D = get_viewport().get_mouse_position()
	var position3D = p.intersects_ray(camera.project_ray_origin(position2D),camera.project_ray_normal(position2D))
	return position3D

func is_within_editable_distance():
	var from = camera.project_ray_origin(get_viewport().get_mouse_position())
	var to = from + camera.project_ray_normal(get_viewport().get_mouse_position()) * 1000
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if result and result.collider == get_node("StaticBody3D"):
		return true
	return false

func _input(event):
	if event is InputEventMouseButton and event.as_text() == "Left Mouse Button":
		if event.is_pressed() and is_within_editable_distance():
			is_following_mouse = true
			arrow.visible = false
			get_parent().selected_current = self
		elif not event.is_pressed():
			is_following_mouse = false
			arrow.visible = true

# Called when the node enters the scene tree for the first time.
func _process(_delta):
	for arrow in get_children():
		if curr_val < 0:
			arrow.rotation.x = PI
		else:
			arrow.rotation.x = 0
	
	if rotate_to_x:
		rotation.x = PI/2
		rotation.y = 0
		rotation.z = 0
	elif rotate_to_z:
		rotation.x = 0
		rotation.y = 0
		rotation.z = PI/2
	else:
		rotation.x = 0
		rotation.y = 0
		rotation.z = 0
	
	$Outline.visible = is_within_editable_distance()
	
	if is_following_mouse:
		if rotate_to_z:
			var mouse_pos = get_mouse_pos(Plane(1, 0, 0, 0))
			if mouse_pos:
				global_position.y = mouse_pos.y
				global_position.z = mouse_pos.z
		elif rotate_to_x:
			var mouse_pos = get_mouse_pos(Plane(0, 0, 1, 0))
			if mouse_pos:
				global_position.x = mouse_pos.x
				global_position.y = mouse_pos.y
		else:
			var mouse_pos = get_mouse_pos(Plane(0, 1, 0, 0))
			if mouse_pos:
				global_position.x = mouse_pos.x
				global_position.z = mouse_pos.z

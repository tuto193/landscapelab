extends AbstractPlayer


var interface : XRInterface

func _ready():
	interface = XRServer.find_interface("OpenXR")
	if interface and interface.is_initialized():
		print("OpenXR initialised successfully")
		$VRViewport.use_xr = true
	else:
		print("OpenXR not initialised, please check if your headset is connected")


func _process(delta):
	# Place checked ground
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(0, 5000, 0), Vector3(0, -5000, 0), 4294967295, [get_rid()]))
	
	if result:
		transform.origin.y = result.position.y


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pc_move_left"):
		transform.origin.x -= 2.0
	elif event.is_action_pressed("pc_move_right"):
		transform.origin.x += 2.0
	elif event.is_action_pressed("pc_move_up"):
		transform.origin.z -= 2.0
	elif event.is_action_pressed("pc_move_down"):
		transform.origin.z += 2.0


func get_world_position():
	return position_manager.to_world_coordinates(position)


func set_world_position(world_position):
	var new_pos = position_manager.to_engine_coordinates(world_position)
	position.x = new_pos.x
	position.z = new_pos.z

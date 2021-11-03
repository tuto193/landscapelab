extends Spatial
tool

#
# A windmill which acts according to a specified wind direction and speed.
#

onready var rotor = get_node("Mesh/Rotor")

export(float) var speed = 0.1 # Rotation speed in radians
export(float) var wind_direction = 0 setget set_wind_direction, get_wind_direction # Rotation of wind in degrees

export var mesh_hub_height := 135
export var mesh_rotor_diameter := 100

export(Vector3) var forward_for_rotation = Vector3(1, 0, 0)

var weather_manager: WeatherManager setget set_weather_manager


func set_weather_manager(new_weather_manager):
	weather_manager = new_weather_manager
	
	_apply_new_wind_speed(weather_manager.wind_speed)
	weather_manager.connect("wind_speed_changed", self, "_apply_new_wind_speed")
	
	_apply_new_wind_direction(weather_manager.wind_direction)
	weather_manager.connect("wind_direction_changed", self, "_apply_new_wind_direction")


func _apply_new_wind_speed(wind_speed):
	speed = wind_speed / 15.0


func _apply_new_wind_direction(wind_direction):
	set_wind_direction(-wind_direction)


func _ready():
	# Orient the windmill according to the scenario's wind direction
	# This assumes that a wind direction of 90° means that the wind is blowing from west to east.
	# FIXME: Should be set from the outside (e.g. using another layer)
	set_wind_direction(315.0)
	
	# If is_inside_tree() in set_wind_direction() returned false, we need to catch up on
	#  setting the wind direction now.
	update_rotation()
	
	# Randomize speed a little
	speed += (randf() - 0.5) * (speed * 0.5)
	
	# Start at a random rotation
	rotor.transform.basis = rotor.transform.basis.rotated(forward_for_rotation, randf() * PI * 2.0)
	
	$BlinkTimer.connect("timeout", self, "_toggle_blink")
	
	set_hub_height(135)
	set_rotor_diameter(100)

# Saves the specified wind direction and updates the model's rotation
# Called whenever the exported wind_direction is changed
func set_wind_direction(var dir):
	wind_direction = dir
	
	if is_inside_tree():
		update_rotation()


# Returns the current wind direction which this windmill has saved
func get_wind_direction():
	return wind_direction


# Correctly orients the model depending on the public wind_direction - automatically called when the wind direction is changed
func update_rotation():
	var direction = get_wind_direction()
	rotation_degrees.y = direction


# Updates the rotation of the rotor to make them rotate with the exported speed variable
func _process(delta):
	if delta > 0.8: return  # Avoid skipping
	rotor.transform.basis = rotor.transform.basis.rotated(forward_for_rotation, -speed * delta)


func _toggle_blink():
	$Mesh/Hub/Hub/Blink.visible = !$Mesh/Hub/Hub/Blink.visible


func set_hub_height(height: float):
	$Mesh/Mast.scale.y = height / mesh_hub_height
	$Mesh/Rotor.translation.y = height
	$Mesh/Hub.translation.y = height
	


func set_rotor_diameter(diameter: float):
	$Mesh/Rotor.scale.z = diameter / mesh_rotor_diameter
	$Mesh/Rotor.scale.y = diameter / mesh_rotor_diameter
	
	$Mesh/Hub.scale.z = diameter / mesh_rotor_diameter
	$Mesh/Hub.scale.y = diameter / mesh_rotor_diameter

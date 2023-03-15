extends WorldEnvironment

@onready var light = get_node("DirectionalLight3D")

var FOG_BEGIN = Settings.get_setting("sky", "fog-begin")
var FOG_END = Settings.get_setting("sky", "fog-end")
var MAX_SUN_INTENSITY = Settings.get_setting("sky", "max-sun-intensity")

var clouds

var current_time = 12
var current_season = 0

var wind_speed = 0
var wind_direction = 0

# Godot's default values - they look pretty good
var base_horizon_color = Color(139.0 / 255.0, 175.0 / 255.0, 207.0 / 255.0, 1.0) 
var base_top_color = Color(54.0 / 255.0, 80.0 / 255.0, 141.0 / 255.0, 1)

var sun_change_thread = Thread.new()

# FIXME: The sky is no longer available as before 

func _on_Sky_texture_sky_updated():
	pass#$Sky_texture.copy_to_environment(environment)


#func _ready():
##	$Sky_texture.connect("sky_updated",Callable(self,"_on_Sky_texture_sky_updated"))
##	$Sky_texture.set_time_of_day(7.0, get_node("DirectionalLight3D"), self, deg_to_rad(10.0), 1.5)
#
#	environment.fog_depth_begin = float(FOG_BEGIN)
#	environment.fog_depth_end = float(FOG_END)


func apply_visibility(new_visibility):
	environment.fog_density = new_visibility * 0.0001


func apply_rain_enabled(enabled):
	$RainParticles.emitting = enabled


func apply_rain_drop_size(rain_drop_size):
	$RainParticles.scale_x = rain_drop_size.x
	$RainParticles.scale_y = rain_drop_size.y


func apply_rain_density(rain_density):
	$RainParticles.amount = rain_density


func apply_cloudiness(new_cloudiness):
	environment.sky.get_material().set_shader_parameter("cloud_coverage", new_cloudiness * 0.01)


func apply_wind_speed(new_wind_speed):
	wind_speed = new_wind_speed
	apply_wind()


func apply_wind_direction(new_wind_direction):
	wind_direction = new_wind_direction
	apply_wind()


func apply_wind():
	var rotated_vector = Vector2.UP.rotated(deg_to_rad(wind_direction))
	#var wind_vector = rotated_vector * wind_speed * 5.0
#	$CloudDome.cloud_speed = wind_vector
	# FIXME: the angle should also be applied - it rotates with the camera however
	# $Rain.process_material.angle = 
	$RainParticles.wind_force_east = rotated_vector.x * wind_speed * 0.3
	$RainParticles.wind_force_north = rotated_vector.y * wind_speed  * 0.3


func apply_datetime(date_time: TimeManager.DateTime):
	if $PythonWrapper.has_python_node():
		# TODO: Replace with real lon/lat values
		var altitude_azimuth = $PythonWrapper.get_python_node().get_sun_altitude_azimuth(
			48.0, 15.0, date_time.time, date_time.day, date_time.year)

		$Sky_texture.set_sun_altitude_azimuth(altitude_azimuth[0], altitude_azimuth[1],
				get_node("DirectionalLight3D"), self, 1.5)

		if altitude_azimuth[0] < 0:
			environment.ambient_light_energy = 0.75
			$DirectionalLight3D.light_energy = 0
			$CloudDome.cloud_color = Color.WHITE * 0.03 + Color.BLUE * 0.02
			$CloudDome.shade_color = Color.WHITE * 0.06
			environment.fog_color = Color(0.03, 0.04, 0.05)
			environment.fog_sun_amount = 0
			$CloudDome._regen_mesh()
		elif altitude_azimuth[0] < 5:
			$DirectionalLight3D.light_energy = 2
			environment.ambient_light_energy = 3
			environment.fog_color = Color(0.501961, 0.6, 0.701961)
			environment.fog_sun_amount = 1
			$CloudDome.cloud_color = Color.WHITE * 0.5 + Color.ORANGE * altitude_azimuth[0] / 10
			$CloudDome.shade_color = Color.WHITE * 0.4 + Color.ORANGE_RED * altitude_azimuth[0] / 10
			$CloudDome._regen_mesh()
		else:
			$DirectionalLight3D.light_energy = 2
			environment.ambient_light_energy = 3
			environment.fog_color = Color(0.501961, 0.6, 0.701961)
			environment.fog_sun_amount = 1
			$CloudDome.cloud_color = Color.WHITE
			$CloudDome.shade_color = Color(0.568627, 0.698039, 0.878431, 1.0)
			$CloudDome._regen_mesh()
	else:
		logger.warn("Pysolar is unavailable, so the sun position is only approximate!")
		
		$DirectionalLight3D.light_energy = 1.0 - lerp(0.0, 0.05, abs(date_time.time - 12))
		$DirectionalLight3D.light_indirect_energy = 1.0 - lerp(0.0, 0.05, abs(date_time.time - 12))
		$DirectionalLight3D.rotation = Vector3(
			lerp(0.0, 2.0*PI, date_time.time / 24) + PI/2.0, deg_to_rad(90), 0)


func get_middle_of_season(season): # 0 = winter, 1 = spring, 2 = summer, 3 = fall
	return {day = 1, month = 2 + season * 3, year = 2018}
	# Example: Spring -> 1.5.2018


func set_sun_position_for_seasontime(season, hours):
	logger.debug("setting sun position to season: %s and time: %s" % [season, hours])
	var date = get_middle_of_season(season)
	set_sun_position_for_datetime(hours, date.day, date.month, date.year)


func set_sun_position_for_datetime(hours, day, month, year):
	# TODO: can we replace these placeholder values with the actual ones?
	var position_longitude = 15.1
	var position_latitude = 48.1
	var elevation = 100.1
	
	# FIXME: pysolar will be included with a direct python call in a subprocess of via godot-python
	# var url = "/location/sunposition/%04d/%02d/%02d/%02d/%02d/%f/%f/%f.json" % [year, month, day, floor(hours), floor((hours - floor(hours)) * 60), position_longitude, position_latitude, elevation]
	set_sun_position(45, 45)


func set_sun_position(altitude, azimuth):
	# Godot calls the values latitude and longitude for some reason, 
	# but they are actually equivalent to altitude and azimuth
	environment.background_sky.sun_latitude = altitude
	
	# Longitude must be between -180 and 180
	if azimuth > 180: azimuth -= 360
	environment.background_sky.sun_longitude = azimuth
	
	# Change the directional light to reflect sun change
	light.rotation = Vector3(deg_to_rad(-altitude), deg_to_rad(180 - azimuth), 0)
	
	# Also pass the direction as a parameter to the clouds - they require it as 
	# the vector the light is pointing at, which is the forward (-z) vector
	if clouds:
		clouds.set_sun_direction(-light.transform.basis.z)
	
	update_colors(altitude, azimuth)


func set_light_energy(new_energy):
	light.light_energy = new_energy
	#environment.ambient_light_energy = 0.2 + new_energy * 2.2
	
	if clouds:
		clouds.set_sun_energy(new_energy / MAX_SUN_INTENSITY)


func update_colors(altitude, _azimuth):
	var new_horizon_color = base_horizon_color
	var new_top_color = base_top_color
	
	var new_light_energy = MAX_SUN_INTENSITY
	
	if altitude < 20 and altitude > -20: # Sun is close to the horizon
		# Make the horizon red/yellow-ish the closer the sun is to the horizon
		var distance_to_horizon = 1 - abs(altitude) / 20
		var horizon_blend_color = Color(0.7, 0.3, 0, distance_to_horizon)
		
		new_horizon_color = new_horizon_color.blend(horizon_blend_color)
		
		# Make the sky get progressively darker
		var distance_to_black_point = 1 - ((20 + altitude) / 40)
		new_horizon_color = new_horizon_color.darkened(distance_to_black_point)
		
	elif altitude <= -20: # Sun is far down -> make the horizon black
		new_horizon_color = Color(0, 0, 0, 0)
	
	# Also make the top color darker / black when the sun is down
	if altitude < 0 and altitude > -30:
		var distance_to_black_point = abs(altitude) / 30
		new_top_color = base_top_color.darkened(distance_to_black_point)
		new_light_energy = MAX_SUN_INTENSITY - distance_to_black_point * MAX_SUN_INTENSITY
		
	elif altitude <= -30:
		new_top_color = Color(0, 0, 0, 0)
		new_light_energy = 0
	
	# Apply the colors to the sky
	environment.background_sky.ground_horizon_color = new_horizon_color
	environment.background_sky.sky_horizon_color = new_horizon_color
	environment.background_sky.sky_top_color = new_top_color
	
	set_light_energy(new_light_energy)


func _on_time_changed(time):
	current_time = time
	update_time_season()


func _on_season_changed(season):
	current_season = season
	update_time_season()


func update_time_season():
	# Run this in a thread to prevent stutter while waiting for HTTP request
	if sun_change_thread.is_active():
		logger.warn("Attempt to change time/season, but last change hasn't finished - aborting")
		return
	
	sun_change_thread.start(Callable(self,"_bg_set_sun_position_for_seasontime").bind([current_season, current_time]))
	#_bg_set_sun_position_for_seasontime([current_season, current_time])


func _bg_set_sun_position_for_seasontime(data): # Threads can only take one argument, so we need this helper function
	set_sun_position_for_seasontime(data[0], data[1])
	call_deferred("end_thread")


func end_thread():
	sun_change_thread.wait_to_finish()

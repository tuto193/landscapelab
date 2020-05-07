extends Particles


# With 4 rows and a spacing of 0.5, plants are drawn within a 2x2 area.
export var rows = 4 setget set_rows, get_rows
export var spacing = 1.0 setget set_spacing, get_spacing

# Min and max size of plants which this layer should render.
# Should usually correspond to the mesh which is used to draw the plants.
export(float) var min_size
export(float) var max_size

# To allow some movement without having to load new data, not only the area
#  given by rows * spacing is loaded, but this additional map size is added.
# Thus, there's no need to load new data immediately, and it's not a problem if
#  it takes a while to load.
export(float) var additional_map_size = 1000

var time_passed = 0

var load_thread = Thread.new()

var previous_origin

var current_offset_from_shifting = Vector2.ZERO

# Updates the visibility aabb which is used for culling.
func update_aabb():
	var size = rows * spacing
	visibility_aabb = AABB(Vector3(-0.5 * size, -1000.0, -0.5 * size), Vector3(size, 10000.0, size))

func set_rows(new_rows):
	rows = new_rows
	amount = rows * rows
	update_aabb()
	if process_material:
		process_material.set_shader_param("rows", rows)

func get_rows():
	return rows

func set_spacing(new_spacing):
	spacing = new_spacing
	update_aabb()
	if process_material:
		process_material.set_shader_param("spacing", spacing)

func get_spacing():
	return spacing

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Offset.connect("shift_world", self, "_on_shift_world")
	
	set_rows(rows)
	set_spacing(spacing)
	
	previous_origin = global_transform.origin
	var position = Offset.to_world_coordinates(global_transform.origin)
	update_textures(previous_origin, position, current_offset_from_shifting)


# When the world is shifted, this offset needs to be remembered and passed to
#  the shader so that the world -> UV calculation remains correct.
func _on_shift_world(delta_x, delta_z):
	current_offset_from_shifting -= Vector2(delta_x, delta_z)
	
	process_material.set_shader_param("offset", Vector2(-previous_origin.x, -previous_origin.z) + current_offset_from_shifting)
	material_override.set_shader_param("offset", Vector2(-previous_origin.x, -previous_origin.z) + current_offset_from_shifting)


func _process(delta):
	global_transform.origin = PlayerInfo.get_engine_player_position()
	
	time_passed += delta
	
	# If no data is currently loading and we've moved 1/2 of the distance we can
	#  move within the available data, start getting some new data.
	if not load_thread.is_active() \
			and (previous_origin - global_transform.origin).length() \
			> additional_map_size / 4.0:
		
		var position = global_transform.origin
		var world_position = Offset.to_world_coordinates(position)
		var offset = current_offset_from_shifting
		
		load_thread.start(self, "_threaded_update_textures", [position, world_position, offset])


func _input(event):
	if event.is_action("toggle_vegetation") and event.pressed:
		visible = not visible


func _threaded_update_textures(userdata):
	update_textures(userdata[0], userdata[1], userdata[2])


func update_textures(position, world_position, current_offset_from_shifting_before_load):
	var map_size =  rows * spacing * 2
	
	var dhm = Geodot.get_image(
		GeodataPaths.get_absolute("heightmap"),
		GeodataPaths.get_type("heightmap"),
		-world_position[0] - map_size / 2,
		world_position[2] + map_size / 2,
		map_size,
		map_size / 2.0,
		1
	)
	
	var splat = Geodot.get_image(
		GeodataPaths.get_absolute("land-use"),
		GeodataPaths.get_type("land-use"),
		-world_position[0] - map_size / 2,
		world_position[2] + map_size / 2,
		map_size,
		map_size / 10.0,
		0
	)
	
	# Get the most common splatmap values here
	var ids = splat.get_most_common(8)
	
	# Loat the phytocoenosis for these IDs and filter them by the given size
	#  parameters
	var phytocoenosis = Vegetation.get_phytocoenosis_array_for_ids(ids)
	var filtered_phytocoenosis = Vegetation.filter_phytocoenosis_array_by_height(phytocoenosis, min_size, max_size)
	
	var billboards = Vegetation.get_billboard_sheet(filtered_phytocoenosis, max_size)
	
	# If billboards is null, this means that there were 0 plants in all of the
	#  phytocoenosis. Then, we don't need to render anything.
	if not billboards:
		amount = 0
		return
	
	var distribution_sheet = Vegetation.get_distribution_sheet(filtered_phytocoenosis)
	
	# All spritesheets are organized like this:
	# The rows correspond to land-use values
	# The columns correspond to distribution values
	
	var id_row_map_tex = Vegetation.get_id_row_map_texture(ids)
	
	var billboard_tex = ImageTexture.new()
	billboard_tex.create_from_image(billboards)
	
	var distribution_tex = ImageTexture.new()
	distribution_tex.create_from_image(distribution_sheet, ImageTexture.FLAG_REPEAT)
	
	var heightmap_size = Vector2(map_size, map_size)
	
	# Finish the shader so that it can accept new loading requests again
	call_deferred("_update_done",
			id_row_map_tex,
			billboard_tex,
			distribution_tex,
			heightmap_size,
			dhm.get_image_texture(),
			splat.get_image_texture(),
			position,
			current_offset_from_shifting_before_load)


func _update_done(
		id_row_map_tex,
		billboard_tex,
		distribution_tex,
		heightmap_size,
		heightmap,
		splatmap,
		position,
		offset_before_load):
	var new_offset = current_offset_from_shifting - offset_before_load
	
	material_override.set_shader_param("id_to_row", id_row_map_tex)
	material_override.set_shader_param("texture_map", billboard_tex)
	material_override.set_shader_param("distribution_map", distribution_tex)
	
	process_material.set_shader_param("heightmap_size", heightmap_size)
	material_override.set_shader_param("heightmap_size", heightmap_size)
	
	process_material.set_shader_param("heightmap", heightmap)
	material_override.set_shader_param("splatmap", splatmap)
	
	previous_origin = position
	current_offset_from_shifting = new_offset
	
	process_material.set_shader_param("offset", Vector2(-previous_origin.x, -previous_origin.z) + current_offset_from_shifting)
	material_override.set_shader_param("offset", Vector2(-previous_origin.x, -previous_origin.z) + current_offset_from_shifting)
	
	load_thread.wait_to_finish()

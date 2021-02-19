extends Node

#
# Loads vegetation data and provides it wrapped in Godot classes with
# functionality such as generating spritesheets.
# 
# The data is expected to be laid out like this:
# plants.csv
# phytocoenosis.csv
# plant-texutres
# 	billboard1.png
# 	billboard2.png
# ground-textures
# 	Grass
# 		albedo.jpg
# 		normal.jpg
# 		displacement.jpg
# 

const distribution_size = 16

const sprite_size = 1024
const texture_size = 1024

# FIXME: this should be settings and default to neutral paths
var plant_csv_path = "/home/karl/Nextcloud/Boku/new_veg/plants.csv"
var group_csv_path = "/home/karl/Nextcloud/Boku/new_veg/groups.csv"

# FIXME: this should be settings and default to neutral paths
var ground_texture_base_path = "/home/karl/Downloads"
var billboard_base_path = "/home/karl/Downloads/plants"

const BILLBOARD_ENDING = ".png"

var phytocoenosis_by_name = {}
var phytocoenosis_by_id = {}

var plant_image_cache = {}
var plant_image_texture_cache = {}
var ground_image_cache = {}

var ground_image_mutex = Mutex.new()

var plants = {}
var groups = {}

signal new_data


func _ready() -> void:
	load_data_from_csv(plant_csv_path, group_csv_path)


func add_plant(plant: Plant):
	plants[plant.id] = plant


func add_group(group):
	groups[group.id] = group


# Read Plants and Groups from the given CSV files.
func load_data_from_csv(plant_path: String, group_path: String) -> void:
	plants = {}
	groups = {}
	
	_create_plants_from_csv(plant_path)
	_create_groups_from_csv(group_path)
	
	emit_signal("new_data")


func _create_plants_from_csv(csv_path: String) -> void:
	var plant_csv = File.new()
	plant_csv.open(csv_path, File.READ)
	
	if not plant_csv.is_open():
		logger.error("Plants CSV file does not exist, expected it at %s"
				 % [csv_path])
		return
	
	var plant_headings = plant_csv.get_csv_line()
	
	while !plant_csv.eof_reached():
		# Format:
		# ID,FILE,TYPE,SIZE,H_MIN,H_MAX,DENSITY,SPECIES,NAME_DE,NAME_EN,SEASON,SOURCE,LICENSE,AUTHOR,NOTE
		var csv = plant_csv.get_csv_line()
		
		if csv.size() < plant_headings.size():
			logger.warning("Unexpected CSV line (size does not match headings): %s"
					% [csv])
			continue
		
		var id = csv[0]
		var file = csv[1]
		var type = csv[2]
		var size = csv[3]
		var height_min = csv[4]
		var height_max = csv[5]
		var density = csv[6]
		var species = csv[7]
		var name_de = csv[8]
		var name_en = csv[9]
		var season = csv[10]
		var source = csv[11]
		var license = csv[12]
		var author = csv[13]
		var note = csv[14]
		
		if id == "":
			logger.warning("Plant with empty ID in plant CSV line: %s"
					% [csv])
			continue
		else:
			id = int(id)
		
		var plant = Plant.new()
		
		plant.id = id
		plant.billboard_path = file
		plant.type = type
		plant.size_class = parse_size(size)
		plant.height_min = height_min
		plant.height_max = height_max
		plant.density = density
		plant.species = species
		plant.name_de = name_de
		plant.name_en = name_en
		plant.season = parse_season(season)
		plant.source = source
		plant.license = license
		plant.author = author
		plant.note = note
		
		add_plant(plant)


func _create_groups_from_csv(csv_path: String) -> void:
	var group_csv = File.new()
	group_csv.open(csv_path, File.READ)
	
	if not group_csv.is_open():
		logger.error("Groups CSV file does not exist, expected it at %s"
				 % [csv_path])
		return
	
	var headings = group_csv.get_csv_line()
	
	while !group_csv.eof_reached():
		# Format:
		# SOURCE,SNAR_CODE,SNAR_CODEx10,SNAR-Bezeichnung,TXT_DE,TXT_EN,SNAR_GROUP_LAB,LAB_ID (LID),PLANTS,GROUND TEXTURE
		var csv = group_csv.get_csv_line()
		
		if csv.size() < headings.size():
			logger.warning("Unexpected CSV line (size does not match headings): %s"
					% [csv])
			continue
		
		var id = csv[7].strip_edges()
		var name_en = csv[5]
		var plant_ids = csv[8].split(",") if not csv[8].empty() else []
		
		if id == "":
			logger.warning("Group with empty ID in CSV line: %s"
					% [csv])
			continue
		else:
			id = int(id)
		
		if id in groups.keys():
			logger.warning("Duplicate group with ID %s! Skipping..."
					% [id])
			continue
		
		# Parse and loads plants
		var group_plants = []
		for plant_id in plant_ids:
			plant_id = int(plant_id)
			
			if plants.has(plant_id):
				group_plants.append(plants[plant_id])
			else:
				logger.warning("Non-existent plant with ID %s in CSV %s!"
						% [plant_id, csv_path])
		
		var ground_texture_path = csv[9]
		
		var group = Phytocoenosis.new(id, name_en, group_plants, ground_texture_path)
		
		add_group(group)


# Save the current Plant and Group data to CSV files at the given locations.
# If the files exist, their content is replaced by the new data.
func save_to_files(plant_csv_path: String, group_csv_path: String):
	_save_plants_to_csv(plant_csv_path)
	_save_groups_to_csv(group_csv_path)


func _save_plants_to_csv(csv_path):
	var plant_csv = File.new()
	plant_csv.open(csv_path, File.WRITE)
	
	if not plant_csv.is_open():
		logger.error("Plants CSV file at %s could not be created or opened for writing"
				 % [csv_path])
		return
	
	var headings = "ID,FILE,TYPE,SIZE,H_MIN,H_MAX,DENSITY,SPECIES,NAME_DE,NAME_EN,SEASON,SOURCE,LICENSE,AUTHOR,NOTE"
	plant_csv.store_line(headings)
	
	for plant in plants.values():
		# Format:
		# ID,FILE,TYPE,SIZE,H_MIN,H_MAX,DENSITY,SPECIES,NAME_DE,NAME_EN,SEASON,SOURCE,LICENSE,AUTHOR,NOTE
		plant_csv.store_csv_line([
			plant.id,
			plant.billboard_path,
			plant.type,
			reverse_parse_size(plant.size_class),
			plant.height_min,
			plant.height_max,
			plant.density,
			plant.species,
			plant.name_de,
			plant.name_en,
			reverse_parse_season(plant.season),
			plant.source,
			plant.license,
			plant.author,
			plant.note
		])


func _save_groups_to_csv(csv_path: String) -> void:
	var group_csv = File.new()
	group_csv.open(csv_path, File.WRITE)
	
	if not group_csv.is_open():
		logger.error("Groups CSV file at %s could not be created or opened for writing"
				 % [csv_path])
		return
	
	var headings = "SOURCE,SNAR_CODE,SNAR_CODEx10,SNAR-Bezeichnung,TXT_DE,TXT_EN,SNAR_GROUP_LAB,LAB_ID (LID)"
	group_csv.store_line(headings)
	
	for group in groups.values():
		# Format:
		# SOURCE,SNAR_CODE,SNAR_CODEx10,SNAR-Bezeichnung,TXT_DE,TXT_EN,SNAR_GROUP_LAB,LAB_ID (LID),PLANTS
		group_csv.store_csv_line([
			"TODO",
			"TODO",
			"TODO",
			"TODO",
			"TODO",
			group.name,
			"TODO",
			group.id,
			PoolStringArray(group.get_plant_ids()).join(","),
			group.ground_texture_folder
		])


# Returns the Phytocoenosis objects which correspond to the given IDs.
func get_phytocoenosis_array_for_ids(id_array):
	var phytocoenosis_array = []
	
	for group in groups.values():
		if id_array.has(group.id):
			phytocoenosis_array.append(group)
	
	return phytocoenosis_array


# Returns an array with the same phytocoenosis as were given to the function,
#  but with each phytocoenosis' plant array only consisting of plants within the
#  given height range.
func filter_phytocoenosis_array_by_height(phytocoenosis_array, min_height: float, max_height: float):
	var new_array = []
	
	for phytocoenosis in phytocoenosis_array:
		var plants = []
		
		for plant in phytocoenosis.plants:
			if plant.height_max > min_height and plant.height_max < max_height:
				plants.append(plant)
		
		# Append a new Phytocoenosis which is identical to the one in the passed
		#  array, but with the filtered plants
		new_array.append(Phytocoenosis.new(phytocoenosis.id,
				phytocoenosis.name,
				plants,
				phytocoenosis.ground_texture_folder))
	
	return new_array


# Shortcut for get_phytocoenosis_array_for_ids + get_billboard_sheet
func get_billboard_sheet_for_ids(id_array, max_size):
	var phytocoenosis_array = []
	
	for id in id_array:
		phytocoenosis_array.append(groups[id])
	
	return get_billboard_sheet(phytocoenosis_array, max_size)


# Get a spritesheet with all billboards of the phytocoenosis in the given
#  phytocoenosis_array.
# A row of the spritesheet corresponds to one phytocoenosis, with its plants in
#  the columns.
func get_billboard_sheet(phytocoenosis_array: Array, max_size):
	# Array holding the rows of vegetation - each vegetation loaded from the 
	#  given vegetation_names becomes a row in this table
	var billboard_table = Array()
	billboard_table.resize(phytocoenosis_array.size())
	
	var row = 0
	
	for phytocoenosis in phytocoenosis_array:
		billboard_table[row] = []
		
		for plant in phytocoenosis.plants:
			var billboard = plant.get_billboard()
			billboard_table[row].append(billboard)
			
		row += 1
		
	return SpritesheetHelper.create_spritesheet(
			Vector2(sprite_size, sprite_size),
			billboard_table,
			SpritesheetHelper.SCALING.KEEP_ASPECT)


# Returns a 1x? spritesheet with each phytocoenosis' ground texture in the rows.
func get_ground_sheet(phytocoenosis_array, texture_name):
	var texture_table = Array()
	texture_table.resize(phytocoenosis_array.size())
	
	var row = 0
	
	for phytocoenosis in phytocoenosis_array:
		texture_table[row] = [phytocoenosis.get_ground_image(texture_name)]
		
		row += 1
	
	return SpritesheetHelper.create_spritesheet(
			Vector2(texture_size, texture_size),
			texture_table,
			SpritesheetHelper.SCALING.STRETCH)


# Returns a 1x? spritesheet with each phytocoenosis' distribution texture in the
#  rows.
func get_distribution_sheet(phytocoenosis_array, max_size):
	var texture_table = Array()
	texture_table.resize(phytocoenosis_array.size())
	
	var row = 0
	
	for phytocoenosis in phytocoenosis_array:
		texture_table[row] = [generate_distribution(phytocoenosis, max_size)] \
				if phytocoenosis.plants.size() > 0 else null
		
		row += 1
	
	return SpritesheetHelper.create_spritesheet(
			Vector2(distribution_size, distribution_size),
			texture_table)


# To map land-use values to a row from 0-7, we use a 256x1 texture.
# An array would be more straightforward, but shaders don't accept these as
#  uniform parameters.
func get_id_row_map_texture(ids):
	var id_row_map = Image.new()
	id_row_map.create(256, 1, false, Image.FORMAT_R8)
	id_row_map.lock()
	
	# id_row_map.fill doesn't work here - if that is used, the set_pixel calls
	#  later have no effect...
	for i in range(0, 256):
		id_row_map.set_pixel(i, 0, Color(1.0, 0.0, 0.0))
	
	# The pixel at x=id (0-255) is set to the row value (0-7).
	var row = 0
	for id in ids:
		id_row_map.set_pixel(id, 0, Color(row / 255.0, 0.0, 0.0))
		row += 1
	
	id_row_map.unlock()
	
	# Fill all parameters into the shader
	var id_row_map_tex = ImageTexture.new()
	id_row_map_tex.create_from_image(id_row_map, 0)
	
	return id_row_map_tex


# Wraps the result of get_ground_albedo_sheet in an ImageTexture.
func get_ground_sheet_texture(phytocoenosis_array, texture_name):
	var tex = ImageTexture.new()
	tex.create_from_image(get_ground_sheet(phytocoenosis_array, texture_name))
	
	return tex


# Wrapper for get_billboard_sheet, but returns an ImageTexture instead of an
#   Image for direct use in materials.
func get_billboard_texture(phytocoenosis_array, max_size):
	var tex = ImageTexture.new()
	tex.create_from_image(get_billboard_sheet(phytocoenosis_array, max_size))
	
	return tex


# Returns a newly generated distribution map for the plants in the given
#  phytocoenosis.
# This map is a 16x16 image whose R values correspond to the IDs of the plants; the G values are
#  the size scaling factors (between 0 and 1) for each particular plant instance, taking into
#  account its min and max size.
func generate_distribution(phytocoenosis: Phytocoenosis, max_size: float):
	var distribution = Image.new()
	distribution.create(distribution_size, distribution_size,
			false, Image.FORMAT_RG8)
	
	var dice = RandomNumberGenerator.new()
	dice.randomize()
	
	distribution.lock()
	
	for y in range(0, distribution_size):
		for x in range(0, distribution_size):
			var highest_roll = 0
			var highest_roll_id = 0
			
			# Roll a dice for every plant. If it is higher than the previous highest roll,
			#  set the hihgest roll ID to the ID of this plant within the group (the position
			#  in the group's plant array).
			var current_plant_in_group_id = 0
			for plant in phytocoenosis.plants:
				# Roll the dice weighed by the plant density. A small factor is
				#  added because some plants never show up otherwise.
				var roll = dice.randf_range(0.0, plant.density + 0.3)
				
				if roll > highest_roll:
					highest_roll_id = current_plant_in_group_id
					highest_roll = roll
				
				current_plant_in_group_id += 1
			
			# Roll another dice for getting the height of this plant instance
			#  (between the plant's min and max height)
			var plant = phytocoenosis.plants[highest_roll_id]
			var random_height = dice.randf_range(plant.height_min, plant.height_max)
			var scale_factor = random_height / max_size
			
			distribution.set_pixel(x, y, Color(highest_roll_id / 255.0, scale_factor, 0.0, 0.0))
	
	distribution.unlock()
	
	return distribution




class Phytocoenosis:
	var id
	var name
	var plants: Array
	var ground_texture_folder
	
	func _init(id, name, plants = null, ground_texture_folder = null):
		self.id = int(id)
		self.name = name
		
		if ground_texture_folder:
			self.ground_texture_folder = ground_texture_folder
		
		if plants:
			self.plants = plants
	
	func add_plant(plant: Plant):
		plants.append(plant)
	
	func remove_plant(plant: Plant):
		plants.erase(plant)
	
	func get_ground_image(image_name):
		if not ground_texture_folder: return null
		
		var full_path = Vegetation.ground_texture_base_path \
				.plus_file(ground_texture_folder) \
				.plus_file(image_name + ".jpg")
		
		Vegetation.ground_image_mutex.lock()
		if not Vegetation.ground_image_cache.has(full_path):
			var img = Image.new()
			img.load(full_path)
			
			if img.is_empty():
				logger.error("Invalid ground texture path in CSV of phytocoenosis %s: %s"
						 % [name, full_path])
			
			Vegetation.ground_image_cache[full_path] = img
		Vegetation.ground_image_mutex.unlock()
		
		return Vegetation.ground_image_cache[full_path]
	
	func get_ground_texture(image_name):
		var image = get_ground_image(image_name)
		if not image: return null
		
		var tex = ImageTexture.new()
		tex.create_from_image(image, Texture.FLAG_MIPMAPS + Texture.FLAG_FILTER + Texture.FLAG_REPEAT)
		
		return tex
	
	func get_plant_ids():
		var plant_ids = []
		for plant in plants:
			plant_ids.append(plant.id)
		
		return plant_ids


enum Season {SPRING, SUMMER, AUTUMN, WINTER}


func parse_size(size_string: String):
	if size_string == "S": return Plant.Size.S
	elif size_string == "M": return Plant.Size.M
	elif size_string == "L": return Plant.Size.L
	elif size_string == "XL": return Plant.Size.XL
	else: return null


func parse_season(season_string: String):
	if season_string == "SPRING": return Season.SPRING
	elif season_string == "SUMMER": return Season.SUMMER
	elif season_string == "AUTUMN": return Season.AUTUMN
	elif season_string == "WINTER": return Season.WINTER
	else: return null


func reverse_parse_size(size):
	if size == Plant.Size.S: return "S"
	elif size == Plant.Size.M: return "M"
	elif size == Plant.Size.L: return "L"
	elif size == Plant.Size.XL: return "XL"
	else: return "UNKNOWN"


func reverse_parse_season(season):
	if season == Season.SPRING: return "SPRING"
	elif season == Season.SUMMER: return "SUMMER"
	elif season == Season.AUTUMN: return "AUTUMN"
	elif season == Season.WINTER: return "WINTER"
	else: return "UNKNOWN"


class Plant:
	enum Size {S, M, L, XL}
	
	var id: int
	var billboard_path: String
	var type: String
	var size_class#: Size
	var species: String
	var name_en: String
	var name_de: String
	var season#: Season
	var source: String
	var license: String
	var author: String
	var note: String
	
	var height_min: float
	var height_max: float
	var density: float
	
	func _get_full_icon_path():
		return Vegetation.billboard_base_path.plus_file("small-" + billboard_path) + BILLBOARD_ENDING
	
	func _get_full_billboard_path():
		return Vegetation.billboard_base_path.plus_file(billboard_path) + BILLBOARD_ENDING
	
	func _load_into_cache_if_necessary(full_path):
		if not Vegetation.plant_image_cache.has(full_path):
			# Load Image into the Image cache
			var img = Image.new()
			img.load(full_path)
			
			if img.is_empty():
				logger.warning("Invalid billboard path in %s: %s"
						 % [name_en, full_path])
			
			# Godot can crash with extremely large images, so we downscale it to a size appropriate
			#  for further handling.
			var new_size = SpritesheetHelper.get_size_keep_aspect(
				Vector2(texture_size, texture_size), img.get_size())
			img.resize(new_size.x, new_size.y)
			
			Vegetation.plant_image_cache[full_path] = img
			
			# Also load into the ImageTexture cache
			var tex = ImageTexture.new()
			tex.create_from_image(_get_image(full_path), Texture.FLAG_MIPMAPS + Texture.FLAG_FILTER)
			Vegetation.plant_image_texture_cache[full_path] = tex
	
	func _get_image(path):
		if not File.new().file_exists(path):
			logger.warn("Invalid Plant image (file does not exist): %s" % [path])
			return null
		
		_load_into_cache_if_necessary(path)
		return Vegetation.plant_image_cache[path]
	
	func _get_texture(path):
		if not File.new().file_exists(path):
			logger.warn("Invalid Plant image (file does not exist): %s" % [path])
			return null
		
		_load_into_cache_if_necessary(path)
		return Vegetation.plant_image_texture_cache[path]
	
	# Return the billboard of this plant as an unmodified Image.
	func get_billboard():
		return _get_image(_get_full_billboard_path())
	
	# Return an ImageTexture with the billboard of this plant.
	func get_billboard_texture():
		return _get_texture(_get_full_billboard_path())
	
	# Return an icon (a small version of the billboard) for this plant.
	func get_icon():
		return _get_image(_get_full_icon_path())
	
	# Return an ImageTexture with the icon of this plant.
	func get_icon_texture():
		return _get_texture(_get_full_icon_path())
	
	# Return a string in the form "ID: Name (Size Class)"
	func get_title_string():
		return str(self.id) + ": " + self.name_en \
				+ " (" + Vegetation.reverse_parse_size(self.size_class) + ")"

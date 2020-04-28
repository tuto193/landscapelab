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
# phytocoenosis.csv must have the columns:
# Name, ID, Ground texture
# For example:
# Meadow, 1, Grass
#
# plants.csv must have the columns:
# Phytocoenosis Name, Avg height, sigma height, density, billboard
# For example:
# Meadow, 0.8, 0.1, 0.9, billboard1.png
# 

const distribution_size = 16

const sprite_size = 1024
const texture_size = 1024

var base_path = GeodataPaths.get_absolute("vegetation-data")

var phytocoenosis_by_name = {}
var phytocoenosis_by_id = {}


func _ready() -> void:
	_load_data_from_csv()


# Read the CSV files at the path provided by GeodataPaths and save the
#  metadata of all phytocoenosis with their plants.
func _load_data_from_csv() -> void:
	# Load phytocoenosis data
	var phytocoenosis_path = base_path.plus_file("phytocoenosis.csv")
	
	var phyto_csv = File.new()
	phyto_csv.open(phytocoenosis_path, phyto_csv.READ)
	
	if not phyto_csv.is_open():
		logger.error("Phytocoenosis CSV file does not exist, expected it at %s"
				 % [phytocoenosis_path])
		return
	
	var phytocoenosis_headings = phyto_csv.get_csv_line()
	
	while !phyto_csv.eof_reached():
		# Format: Name, ID, Ground texture
		var csv = phyto_csv.get_csv_line()
		phytocoenosis_by_name[csv[0].to_lower()] = Phytocoenosis.new(csv[1], csv[0], csv[2])
	
	# Load plant data
	var plant_path = base_path.plus_file("plants.csv")
	
	var plant_csv = File.new()
	plant_csv.open(plant_path, phyto_csv.READ)
	
	if not plant_csv.is_open():
		logger.error("Plants CSV file does not exist, expected it at %s"
				 % [plant_path])
		return
	
	var plant_headings = plant_csv.get_csv_line()
	
	while !plant_csv.eof_reached():
		# Format: Phytocoenosis Name, Avg height, sigma height, density, billboard
		var csv = plant_csv.get_csv_line()
		var p = phytocoenosis_by_name[csv[0].to_lower()]
		
		p.plants.append(
				Plant.new(p.plants.size(), "", float(csv[1]), float(csv[2]),
				float(csv[3]), csv[4],
				base_path.plus_file("plant-textures")))
	
	# Add a map of ID to phytocoenosis as well, since that is frequently required
	for phytocoenosis in phytocoenosis_by_name.values():
		phytocoenosis_by_id[int(phytocoenosis.id)] = phytocoenosis


func get_phytocoenosis_array_for_ids(id_array):
	var phytocoenosis_array = []
	
	for id in id_array:
		phytocoenosis_array.append(phytocoenosis_by_id[id])
	
	return phytocoenosis_array


func filter_phytocoenosis_array_by_height(phytocoenosis_array, min_height: float, max_height: float):
	var new_array = []
	
	for phytocoenosis in phytocoenosis_array:
		var plants = []
		
		for plant in phytocoenosis.plants:
			if plant.avg_height > min_height and plant.avg_height < max_height:
				plants.append(plant)
		
		# Append a new Phytocoenosis which is identical to the one in the passed
		#  array, but with the filtered plants
		new_array.append(Phytocoenosis.new(phytocoenosis.id,
				phytocoenosis.name,
				phytocoenosis.ground_texture_path,
				plants))
	
	return new_array


func get_billboard_sheet_for_ids(id_array):
	var phytocoenosis_array = []
	
	for id in id_array:
		phytocoenosis_array.append(phytocoenosis_by_id[id])
	
	return get_billboard_sheet(phytocoenosis_array)


# Get a spritesheet with all billboards of the phytocoenosis in the given phytocoenosis_array.
# Each phytocoenosis gets a row, with the individual plant billboards in the columns.
func get_billboard_sheet(phytocoenosis_array):
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
			billboard_table)


func get_ground_albedo_sheet(phytocoenosis_array):
	var texture_table = Array()
	texture_table.resize(phytocoenosis_array.size())
	
	var row = 0
	
	for phytocoenosis in phytocoenosis_array:
		texture_table[row] = [phytocoenosis.get_ground_albedo_image()]
		
		row += 1
	
	return SpritesheetHelper.create_spritesheet(
			Vector2(texture_size, texture_size),
			texture_table)


func get_distribution_sheet(phytocoenosis_array):
	var texture_table = Array()
	texture_table.resize(phytocoenosis_array.size())
	
	var row = 0
	
	for phytocoenosis in phytocoenosis_array:
		texture_table[row] = [generate_distribution(phytocoenosis)] if phytocoenosis.plants.size() > 0 else null
		
		row += 1
	
	return SpritesheetHelper.create_spritesheet(
			Vector2(distribution_size, distribution_size),
			texture_table)


func get_ground_albedo_sheet_texture(phytocoenosis_array):
	var tex = ImageTexture.new()
	tex.create_from_image(get_ground_albedo_sheet(phytocoenosis_array))
	
	return tex


# Wrapper for get_billboard_sheet, but returns an ImageTexture instead of an
#   Image for direct use in materials.
func get_billboard_texture(phytocoenosis_array):
	var tex = ImageTexture.new()
	tex.create_from_image(get_billboard_sheet(phytocoenosis_array))
	
	return tex


func generate_distribution(phytocoenosis: Phytocoenosis):
	var distribution = Image.new()
	distribution.create(distribution_size, distribution_size, false, Image.FORMAT_R8)
	
	var dice = RandomNumberGenerator.new()
	dice.randomize()
	
	distribution.lock()
	
	for y in range(0, distribution_size):
		for x in range(0, distribution_size):
			var highest_roll = 0
			var highest_roll_plant
			
			for plant in phytocoenosis.plants:
				var roll = dice.randf_range(0.0, 1.0)#plant.density)
				
				if roll > highest_roll:
					highest_roll_plant = plant
					highest_roll = roll
			
			# TODO: Edge case with highest_roll_plant being null due to no plants or all densities being 0?
			distribution.set_pixel(x, y, Color((highest_roll_plant.id + 1) / 256.0, 0.0, 0.0))
	
	distribution.unlock()
	
	return distribution




class Phytocoenosis:
	var id
	var name
	var plants: Array
	var ground_texture_path
	
	func _init(id, name, ground_texture_path = null, plants = null):
		self.id = id
		self.name = name
		
		if ground_texture_path:
			self.ground_texture_path = ground_texture_path
		
		if plants:
			self.plants = plants
	
	func add_plant(plant: Plant):
		plants.append(plant)
	
	func get_ground_albedo_image():
		var full_path = Vegetation.base_path.plus_file("ground-textures").plus_file(ground_texture_path).plus_file("albedo.jpg")
		
		var img = Image.new()
		img.load(full_path)
		
		if img.is_empty():
			logger.error("Invalid ground texture path in CSV of phytocoenosis %s: %s"
					 % [name, full_path])
		
		return img


class Plant:
	var id
	var name
	var avg_height
	var sigma_height
	var density
	var billboard_path: String
	var base_path: String
	
	func _init(id, name, avg_height, sigma_height, density, billboard_path, base_path):
		self.id = id
		self.name = name
		self.avg_height = avg_height
		self.sigma_height = sigma_height
		self.density = density
		self.billboard_path = billboard_path
		self.base_path = base_path
	
	# Return the billboard of this plant as an unmodified Image.
	func get_billboard():
		var full_path = base_path.plus_file(billboard_path)
		
		var img = Image.new()
		img.load(full_path)
		
		if img.is_empty():
			logger.error("Invalid billboard path in CSV of phytocoenosis %s: %s"
					 % [name, full_path])
		
		return img


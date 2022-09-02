extends Configurator

const SQLite = preload("res://addons/godot-sqlite/bin/gdsqlite.gdns")

var center := Vector3.ZERO setget set_center
var geopackage
var external_layers = preload("res://Layers/ExternalLayer.gd").new()

const LOG_MODULE := "LAYERCONFIGURATION"

signal geodata_invalid
signal center_changed(x, y)


func set_center(c: Vector3):
	center = c
	emit_signal("center_changed", center.x, center.z)


func _ready():
	set_category("geodata")
	load_gpkg(get_setting("gpkg-path"))


# Gets called from main_ui
func check_default():
	set_category("geodata")
	if(not validate_gpkg(get_setting("gpkg-path"))):
		emit_signal("geodata_invalid")


func load_gpkg(geopackage_path: String):
	if(validate_gpkg(geopackage_path)):
		digest_gpkg(geopackage_path)
	else:
		emit_signal("geodata_invalid")
	
	#define_probing_game_mode()


func define_probing_game_mode():
	var game_mode = GameMode.new()
	
	var acceptable = game_mode.add_game_object_collection_for_feature_layer("Vorstellbar", Layers.geo_layers["features"]["acceptable"])
	var unacceptable = game_mode.add_game_object_collection_for_feature_layer("Nicht vorstellbar", Layers.geo_layers["features"]["unacceptable"])
	
	acceptable.icon_name = "yes_icon"
	acceptable.desired_shape = "SQUARE_BRICK"
	acceptable.desired_color = "GREEN_BRICK"
	
	acceptable.icon_name = "no_icon"
	acceptable.desired_shape = "SQUARE_BRICK"
	acceptable.desired_color = "RED_BRICK"
	
	# TODO: Do we want a score, e.g. more acceptable than unacceptable?
	
	GameSystem.current_game_mode = game_mode


func define_pa3c3_game_mode():
	var game_mode = GameMode.new()
	
	var apv_fh = game_mode.add_game_object_collection_for_feature_layer("APV Frauenhofer", Layers.geo_layers["features"]["apv_fh"])
	
	var apv_creation_condition = VectorExistsCreationCondition.new("APV auf Feld", Layers.geo_layers["features"]["fields"])
	apv_fh.add_creation_condition(apv_creation_condition)
	
	var field_profit_attribute = ImplicitVectorGameObjectAttribute.new(
			"Profitdifferenz LW",
			Layers.geo_layers["features"]["fields"],
			"PRF_DIFF_F"
	)
	apv_fh.add_attribute_mapping(field_profit_attribute)
	
	var power_generation = ImplicitVectorGameObjectAttribute.new(
			"Stromerzeugung kWh",
			Layers.geo_layers["features"]["fields"],
			"FH_2041_AV"
	)
	apv_fh.add_attribute_mapping(power_generation)
	
	var cost = StaticAttribute.new(
			"Kosten",
			-16035.6
	)
	apv_fh.add_attribute_mapping(cost)
	
	var people_fed = StaticAttribute.new(
			"Ernaehrte Personen",
			-1
	)
	apv_fh.add_attribute_mapping(people_fed)
	
	apv_fh.icon_name = "windmill_icon"
	apv_fh.desired_shape = "SQUARE_BRICK"
	apv_fh.desired_color = "BLUE_BRICK"
	
	var profit_lw_score = UpdatingGameScore.new()
	profit_lw_score.name = "Profit Landwirtschaft"
	profit_lw_score.add_contributor(apv_fh, "Profitdifferenz LW")
	profit_lw_score.target = 0.0
	profit_lw_score.display_mode = GameScore.DisplayMode.ICONTEXT
	
	game_mode.add_score(profit_lw_score)
	
	var profit_power_score = UpdatingGameScore.new()
	profit_power_score.name = "Profit Strom"
	profit_power_score.add_contributor(apv_fh, "Stromerzeugung kWh", 0.07)
	profit_power_score.add_contributor(apv_fh, "Kosten")
	profit_power_score.target = 0.0
	profit_power_score.display_mode = GameScore.DisplayMode.ICONTEXT
	
	game_mode.add_score(profit_power_score)
	
	var profit_score = UpdatingGameScore.new()
	profit_score.name = "Profit"
	profit_score.add_contributor(apv_fh, "Profitdifferenz LW")
	profit_score.add_contributor(apv_fh, "Stromerzeugung kWh", 0.07)
	profit_score.add_contributor(apv_fh, "Kosten")
	profit_score.target = 0.0
	profit_score.display_mode = GameScore.DisplayMode.ICONTEXT
	
	game_mode.add_score(profit_score)
	
	var power_score = UpdatingGameScore.new()
	power_score.name = "Stromerzeugung kWh"
	power_score.add_contributor(apv_fh, "Stromerzeugung kWh", 0.07)
	power_score.target = 50000.0
	power_score.display_mode = GameScore.DisplayMode.PROGRESSBAR
	
	game_mode.add_score(power_score)
	
	var power_score_households = UpdatingGameScore.new()
	power_score_households.name = "Versorgte Haushalte"
	power_score_households.add_contributor(apv_fh, "Stromerzeugung kWh", 1.0 / 4500.0)
	power_score_households.target = 100
	power_score_households.display_mode = GameScore.DisplayMode.ICONTEXT
	
	game_mode.add_score(power_score_households)
	
	var food_score = UpdatingGameScore.new()
	food_score.name = "Ernährte Personen"
	food_score.add_contributor(apv_fh, "Ernaehrte Personen")
	food_score.target = 0.0
	food_score.display_mode = GameScore.DisplayMode.ICONTEXT
	
	game_mode.add_score(food_score)
	
	GameSystem.current_game_mode = game_mode


func validate_gpkg(geopackage_path: String):
	if geopackage_path.empty():
		logger.error("User Geopackage path not set! Please set it in user://configuration.ini", LOG_MODULE)
		return false
	
	var file2Check = File.new()
	if !file2Check.file_exists(geopackage_path):
		logger.error(
			"Path to geodataset \"%s\" does not exist, could not load any data!" % [geopackage_path],
			LOG_MODULE
		)
		return false
	
	geopackage = Geodot.get_dataset(geopackage_path)
	if !geopackage.is_valid():
		logger.error("Geodataset is not valid, could not load any data!", LOG_MODULE)
		return false
	
	return true


# Digests the information provided by the geopackage
func digest_gpkg(geopackage_path: String):
	geopackage = Geodot.get_dataset(geopackage_path)
	
	var logstring = "\n"
	
	var rasters = geopackage.get_raster_layers()
	logstring += "Raster layers in GeoPackage:\n"
	
	for raster in rasters:
		logstring += "- " + raster.resource_name + "\n"
	logstring += "\n"
	
	var features = geopackage.get_feature_layers()
	logstring += "Vector layers in GeoPackage:\n"
	
	for feature in features:
		logstring += "- " + feature.resource_name + "\n"
	
	logger.info(logstring, LOG_MODULE)

	logger.info("Opening geopackage as DB ...", LOG_MODULE)
	var db = SQLite.new()
	db.path = geopackage_path
	db.verbose_mode = OS.is_debug_build()
	db.open_db()
	
	# Load vegetation tables outside of the GPKG
	logger.info("Loading Vegetation tables from GPKG ...", LOG_MODULE)
	Vegetation.load_data_from_gpkg(db)
	
	# Load configuration for each layer as specified in GPKG
	logger.info("Starting to load layers ...", LOG_MODULE)
	# Duplication is necessary (SQLite plugin otherwise overwrites with the next query
	var layer_configs: Array = db.select_rows("LL_layer_configuration", "", ["*"]).duplicate()
	
	if layer_configs.empty():
		logger.error("No layer configuration found in the geopackage.", LOG_MODULE)
	
	# Load all geo_layers necessary for the configuration
	get_geolayers(db, geopackage)
	
	for layer_config in layer_configs:
		var layer: Layer
		
		var geo_layers_config = geo_layers_config_for_LL_layer(db, layer_config.id)
		
		# Call the corresponding function using the render-type as string
		layer = call(
			# e.g. load_realistic_terrain_layer(db, layer_config, geo_layers_config)
			"load_%s_layer" % Layer.RenderType.keys()[layer_config.render_type].to_lower(),
			db, layer_config, geo_layers_config
		)
		
		if layer:
			logger.info(
				"Added %s-layer: %s" % [Layer.RenderType.keys()[layer.render_type], layer.name],
				LOG_MODULE
			)
			Layers.add_layer(layer)
	
#	var raster = RasterLayer.new()
#	raster.geo_raster_layer = Layers.geo_layers["rasters"]["basemap"].clone()
#	var test = Layer.new()
#	test.render_type = Layer.RenderType.TWODIMENSIONAL
#	test.render_info = Layer.TwoDimensionalInfo.new()
#	test.render_info.texture_layer = raster
#	test.name = "map"
#	Layers.add_layer(test)
	
	# Loading Scenarios
	logger.info("Starting to load scenarios ...", LOG_MODULE)
	var scenario_configs: Array = db.select_rows("LL_scenarios", "", ["*"]).duplicate()
	for scenario_config in scenario_configs:
		var scenario = Scenario.new()
		scenario.name = scenario_config.name
		
		var layer_ids = db.select_rows(
			"LL_layer_to_scenario", 
			"scenario_id = %d" % [scenario_config.id], 
			["layer_id"] 
		).duplicate()
		
		for id in layer_ids:
			var entry = db.select_rows(
				"LL_layer_configuration", 
				"id = %d" % [id.layer_id], 
				["name"] 
			).duplicate()
			
			if entry.empty():
				logger.error(
					"Tried to find a non-existing layer with id %d for scenario %s" 
					% [id.layer_id, scenario.name],
					LOG_MODULE
				)
				continue
			
			var layer_name = entry[0].name
			scenario.add_visible_layer_name(layer_name)
			#FIXME: Hotfix
			scenario.add_visible_layer_name("map")
		
		Scenarios.add_scenario(scenario)
	
	db.close_db()
	logger.info("Closing geopackage as DB ...", LOG_MODULE)
	
	set_center(get_avg_center())
 

# Load all used geo-layers as defined by configuration
func get_geolayers(db, gpkg):
	var raster_layers = gpkg.get_raster_layers()
	var feature_layers = gpkg.get_feature_layers()
	
	# Load which external data sources concern which LL-layers
	var externals_config = db.select_rows(
		"LL_externalgeolayer_to_layer", "", ["*"]
	).duplicate()
	
	for raster in raster_layers:
		Layers.add_geo_layer(raster, true)
	
	for feature in feature_layers:
		Layers.add_geo_layer(feature, false)
	
	for external_config in externals_config:
		var layer = external_layers.external_to_geolayer_from_type(db, external_config)
		var layer_name = external_config.geolayer_path.get_basename()
		layer_name = layer_name.substr(layer_name.rfind("/") + 1)
		Layers.add_geo_layer(layer, layer is RasterLayer)


# Find the connections of the primitive geolayers to a a specific LL layer
func geo_layers_config_for_LL_layer(db, LL_layer_id):
	# Load necessary raster geolayers from gpkg for the current LL layer
	var rasters_config = db.select_rows(
		"LL_georasterlayer_to_layer", 
		"layer_id = %d" % [LL_layer_id], 
		["geolayer_name, geo_layer_type"] 
	).duplicate()
	
	# Load necessary feature geolayers from gpkg for the current LL layer
	var features_config = db.select_rows(
		"LL_geofeaturelayer_to_layer", 
		"layer_id = %d" % [LL_layer_id], 
		["geolayer_name, ll_reference"] 
	).duplicate()
	
	# Load external feature data sources for the current LL layer
	var external_feature_config = db.select_rows(
		"LL_external_geofeaturelayer_to_layer",
		"layer_id = %d" % [LL_layer_id], 
		["geolayer_path, ll_reference"]
	).duplicate()
	
	# Load external raster data sources for the current LL layer
	var external_raster_config = db.select_rows(
		"LL_external_georasterlayer_to_layer",
		"layer_id = %d" % [LL_layer_id], 
		["geolayer_path, geo_layer_type"]
	).duplicate()
	
	var externals_config = external_feature_config + external_raster_config
	
	# Convert paths in the external config to file-name without extension
	for conf in externals_config:
		var layer_name = conf.geolayer_path.get_basename()
		layer_name = layer_name.substr(layer_name.rfind("/") + 1)
		conf.erase("geolayer_path")
		conf["geolayer_name"] = layer_name
	
	return { "rasters": rasters_config + external_raster_config,
			 "features": features_config + external_feature_config }


# Get the corresponding geolayer for the LL layer by a given type
# e.g. a basic-terrain consists of height and texture 
# => find dhm (digital height model) by type HEIGHT_LAYER, find ortho by type TEXTURE:LAYER
func get_georasterlayer_by_type(db, type: String, candidates: Array) -> Layer:
	var result = db.select_rows(
		"LL_geo_layer_type", 
		"name = '%s'" % [type], 
		["id"]
	)
	
	if result.empty():
		logger.error("Could not find layer-type %s" % [type], LOG_MODULE)
		return null
	
	var id = result[0].id
	
	for layer in candidates: 
		if layer and layer.geo_layer_type == id:
			var raster = RasterLayer.new()
			raster.geo_raster_layer = Layers.geo_layers["rasters"][layer.geolayer_name].clone()
			return raster
	return null


# Get the corresponding geolayer for the LL layer by a given type
# e.g. a basic-terrain consists of height and texture 
# => find dhm (digital height model) by type HEIGHT_LAYER, find ortho by type TEXTURE:LAYER
func get_geofeaturelayer_by_name(db, lname: String, candidates: Array) -> Layer:
	for layer in candidates: 
		if layer.ll_reference == lname:
			var feature = FeatureLayer.new()
			feature.geo_feature_layer = Layers.geo_layers["features"][layer.geolayer_name]
			return feature
	return null


func get_extension_by_key(db, key: String, layer_id) -> String:
	var value = db.select_rows(
		"LL_layer_configuration_extention", 
		"key = '%s' and layer_id = %d" % [key, layer_id], 
		["value"] 
	)
	
	if value.empty():
		logger.error("No extension with key %s." % [key], LOG_MODULE)
		return ""
	
	return value[0].value


func load_realistic_terrain_layer(db, layer_config, geo_layers_config) -> Layer:
	var terrain_layer = Layer.new()
	terrain_layer.render_type = Layer.RenderType.REALISTIC_TERRAIN
	terrain_layer.render_info = Layer.RealisticTerrainRenderInfo.new()
	terrain_layer.render_info.height_layer = get_georasterlayer_by_type(
		db, "HEIGHT_LAYER", geo_layers_config.rasters)
	terrain_layer.render_info.texture_layer = get_georasterlayer_by_type(
		db, "TEXTURE_LAYER", geo_layers_config.rasters)
	terrain_layer.render_info.landuse_layer = get_georasterlayer_by_type(
		db, "LANDUSE_LAYER", geo_layers_config.rasters)
	terrain_layer.render_info.surface_height_layer = get_georasterlayer_by_type(
		db, "SURFACE_HEIGHT_LAYER", geo_layers_config.rasters)
	terrain_layer.name = layer_config.name
	
	return terrain_layer


func load_basic_terrain_layer(db, layer_config, geo_layers_config) -> Layer:
	var terrain_layer = Layer.new()
	terrain_layer.render_type = Layer.RenderType.BASIC_TERRAIN
	terrain_layer.render_info = Layer.BasicTerrainRenderInfo.new()
	terrain_layer.render_info.height_layer = get_georasterlayer_by_type(
		db, "HEIGHT_LAYER", geo_layers_config.rasters)
	terrain_layer.render_info.texture_layer = get_georasterlayer_by_type(
		db, "TEXTURE_LAYER", geo_layers_config.rasters)
	terrain_layer.name = layer_config.name
	
	return terrain_layer


func load_vegetation_layer(db, layer_config, geo_layers_config) -> Layer:
	var vegetation_layer = Layer.new()
	vegetation_layer.render_type = Layer.RenderType.VEGETATION
	vegetation_layer.render_info = Layer.VegetationRenderInfo.new()
	vegetation_layer.render_info.height_layer = get_georasterlayer_by_type(
		db, "HEIGHT_LAYER", geo_layers_config.rasters)
	vegetation_layer.render_info.landuse_layer = get_georasterlayer_by_type(
		db, "LANDUSE_LAYER", geo_layers_config.rasters)
	vegetation_layer.name = layer_config.name
	
	return vegetation_layer


func load_object_layer(db, layer_config, geo_layers_config, extended_as: Layer.ObjectRenderInfo = null) -> Layer:
	if get_extension_by_key(db, "extends_as", layer_config.id) == "WindTurbineRenderInfo":
		# If it is extended as Winturbine we recursively call this function again
		# without extension such that it creates the standard object-layer procedure
		if extended_as == null:
			return load_windmills(db, layer_config, geo_layers_config)

	var object_layer = FeatureLayer.new()
	object_layer.geo_feature_layer = get_geofeaturelayer_by_name(
		db, "objects", geo_layers_config.features)
	object_layer.render_type = Layer.RenderType.OBJECT
	
	if not extended_as:
		object_layer.render_info = Layer.ObjectRenderInfo.new()
	else:
		object_layer.render_info = extended_as
	
	var file_path_object_scene = get_extension_by_key(db, "object", layer_config.id)
	var object_scene
	if file_path_object_scene.ends_with(".tscn"):
		object_scene = load(file_path_object_scene)
	elif file_path_object_scene.ends_with(".obj"):
		# Load the material and mesh
		var material_path = file_path_object_scene.replace(".obj", ".mtl")
		var mesh = ObjParse.parse_obj(file_path_object_scene, material_path)
		
		# Put the resulting mesh into a node
		var mesh_instance = MeshInstance.new()
		mesh_instance.mesh = mesh
		
		# Pack the node into a scene
		object_scene = PackedScene.new()
		object_scene.pack(mesh_instance)
	else:
		logger.error("Not a valid format for object-layer!", LOG_MODULE)
		return FeatureLayer.new()
		
	object_layer.render_info.object = object_scene
	object_layer.render_info.ground_height_layer = get_georasterlayer_by_type(
		db, "HEIGHT_LAYER", geo_layers_config.rasters)
	# FIXME: should come from geopackage -> no hardcoding
	object_layer.ui_info.name_attribute = "Name"
	object_layer.name = layer_config.name
	
	
	return object_layer


func load_windmills(db, layer_config, geo_layers_config) -> Layer:
	var windmill_layer = load_object_layer(
		db, layer_config, geo_layers_config, Layer.WindTurbineRenderInfo.new())
	windmill_layer.render_info.height_attribute_name = get_extension_by_key(
		db, "height_attribute_name", layer_config.id)
	windmill_layer.render_info.diameter_attribute_name = get_extension_by_key(
		db, "diameter_attribute_name", layer_config.id)
	
	return windmill_layer


func load_polygon_layer(db, layer_config, geo_layers_config, extended_as: Layer.PolygonRenderInfo = null) -> Layer:
	if get_extension_by_key(db, "extends_as", layer_config.id) == "BuildingRenderInfo":
		if extended_as == null:
			return load_buildings(db, layer_config, geo_layers_config)
	
	var polygon_layer = FeatureLayer.new()
	polygon_layer.geo_feature_layer = get_geofeaturelayer_by_name(
		db, "polygons", geo_layers_config.features)
	polygon_layer.render_type = Layer.RenderType.POLYGON
	
	if not extended_as:
		polygon_layer.render_info = Layer.PolygonRenderInfo.new()
	else:
		polygon_layer.render_info = extended_as
	
	polygon_layer.render_info.height_attribute_name = get_extension_by_key(
		db, "height_attribute_name", layer_config.id)
	polygon_layer.render_info.ground_height_layer = get_georasterlayer_by_type(
		db, "HEIGHT_LAYER", geo_layers_config.rasters)
	polygon_layer.name = layer_config.name
	
	return polygon_layer


func load_buildings(db, layer_config,geo_layers_config) -> Layer:
	var building_layer = load_polygon_layer(db, layer_config, geo_layers_config, Layer.BuildingRenderInfo.new())
	building_layer.render_info.height_stdev_attribute_name  = get_extension_by_key(
		db, "height_stdev_attribute_name", layer_config.id)
	building_layer.render_info.slope_attribute_name  = get_extension_by_key(
		db, "slope_attribute_name", layer_config.id)
	building_layer.render_info.red_attribute_name = get_extension_by_key(
		db, "red_attribute_name", layer_config.id)
	building_layer.render_info.green_attribute_name = get_extension_by_key(
		db, "green_attribute_name", layer_config.id)
	building_layer.render_info.blue_attribute_name = get_extension_by_key(
		db, "blue_attribute_name", layer_config.id)
	
	return building_layer


func load_path_layer(db, layer_config, geo_layers_config) -> Layer:
	var path_layer = FeatureLayer.new()
	path_layer.geo_feature_layer = get_geofeaturelayer_by_name(
		db, "paths", geo_layers_config.features)
	path_layer.render_type = Layer.RenderType.PATH
	path_layer.render_info = Layer.PathRenderInfo.new()
	path_layer.render_info.line_visualization = get_extension_by_key(
		db, "line_visualization", layer_config.id)
	path_layer.render_info.ground_height_layer = get_georasterlayer_by_type(
		db, "HEIGHT_LAYER", geo_layers_config.rasters)
	path_layer.name = layer_config.name
	
	return path_layer


# Loads a JSON containing paths to Objects in this format:
# {"object_name_1": "res://path/to/object1.tscn", "object_name_2": "path/to/object2.tscn"}
func load_object_JSON(json_string: String) -> Dictionary:
	var json = JSON.parse(json_string)
	var loaded_json = {}
	
	if json.error != OK:
		logger.error(
			"Could not parse JSON - try to validate your JSON entries in the package.",
			LOG_MODULE
		)
		return loaded_json
		
	for entry in json.result:
		loaded_json[entry] = load(json.result[entry])
	
	return loaded_json


func load_connected_object_layer(db, layer_config, geo_layers_config) -> Layer:
	var co_layer = FeatureLayer.new()
	co_layer.geo_feature_layer = get_geofeaturelayer_by_name(
		db, "objects", geo_layers_config.features)
	co_layer.render_type = Layer.RenderType.CONNECTED_OBJECT
	co_layer.render_info = Layer.ConnectedObjectInfo.new()
	co_layer.render_info.selector_attribute_name = get_extension_by_key(
		db, "selector_attribute_name", layer_config.id)
	# FIXME: There might be more appealing ways than storing a json as varchar in the db ...
	# https://imgur.com/9ZJkPvV
	co_layer.render_info.connectors = load_object_JSON(get_extension_by_key(
		db, "connectors", layer_config.id))
	co_layer.render_info.connections = load_object_JSON(get_extension_by_key(
		db, "connections", layer_config.id))
	co_layer.render_info.fallback_connector = load(get_extension_by_key(
		db, "fallback_connector", layer_config.id))
	co_layer.render_info.fallback_connection = load(get_extension_by_key(
		db, "fallback_connection", layer_config.id))
	co_layer.render_info.ground_height_layer = get_georasterlayer_by_type(
		db, "HEIGHT_LAYER", geo_layers_config.rasters)
	co_layer.name = layer_config.name
	
	return co_layer


func load_twodimensional_layer(db, layer_config, geo_layers_config) -> Layer:
	var layer_2d = Layer.new()
	layer_2d.render_type = Layer.RenderType.TWODIMENSIONAL
	layer_2d.render_info = Layer.TwoDimensionalInfo.new()
	layer_2d.render_info.texture_layer = get_georasterlayer_by_type(
		db, "TEXTURE_LAYER", geo_layers_config.rasters)
	layer_2d.name = layer_config.name
	
	return layer_2d


func get_avg_center():
	var center_avg := Vector3.ZERO
	var count := 0
	for layer in Layers.layers:
		if Layers.layers[layer].render_info:
			for geolayer in Layers.layers[layer].render_info.get_geolayers():
				center_avg += geolayer.get_center()
				count += 1
	
	return center_avg / count

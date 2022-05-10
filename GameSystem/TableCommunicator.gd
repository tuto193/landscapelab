extends Node
class_name TableCommunicator

#
# The communication layer between the playing table (via network) and the internal game system.
# Translates the table's **Tokens** to internal **GameObject**s.
#

# Bidirectional dictionaries for mapping tokens (shape + color) to game object collections
var token_to_game_object_collection = {}
var game_object_collection_to_token = {}


func _ready():
	# Inject self into children
	for child in get_children():
		child.set("table_communicator", self)


func get_gamestate_info(request: Dictionary):
	# `request` has "provided_tokens": [{ "shape": .., "color": ...}, ...]
	
	var game_mode = GameSystem.current_game_mode
	
	var response = {
		"keyword": "GAMESTATE_INFO",
		"used_tokens": [],
		"scores": [],
		"existing_tokens": [],
		"start_position_x": 0.0,
		"start_position_y": 0.0,
		"start_extent_x": 0.0,  # height
		"start_extent_y": 0.0,  # width
		"projection_epsg": 0 
	}
	
	var possible_tokens = request["provided_tokens"]
	var current_possible_token_id := 0
	
	# Map possible tokens to game object collections within the current game mode
	for collection in game_mode.game_object_collections.values():
		if current_possible_token_id < possible_tokens.size():
			var shape = possible_tokens[current_possible_token_id]["shape"]
			var color = possible_tokens[current_possible_token_id]["color"]
			
			if not token_to_game_object_collection.has(shape):
				token_to_game_object_collection[shape] = {}
			
			token_to_game_object_collection[shape][color] = collection
			game_object_collection_to_token[collection] = possible_tokens[current_possible_token_id]
			
			response["used_tokens"].append({
				"shape": shape,
				"color": color,
				"icon_svg": "",  # the svg as ascii string
				"disappear_after_seconds": 0.0
			})
			
			current_possible_token_id += 1
		else:
			logger.error("Game Mode would require more possible tokens than provided by this table!")
	
	# Write scores into the response
	for score in game_mode.game_scores.values():
		response["scores"].append({
			"score_id": score.id,
			"name": score.name,
			"initial_value": score.value,
			"target_value": score.target
		})
	
	# Write existing tokens into the response
	for collection in game_mode.game_object_collections.values():
		var token = game_object_collection_to_token[collection]
		
		for game_object in collection.get_all_game_objects():
			response["existing_tokens"].append({
				"object_id": game_object.id,
				"position_x": game_object.get_position().x,
				"position_y": -game_object.get_position().z,
				"shape": token["shape"],
				"color": token["color"],
				"data": []  # optional
			})
	
	return response

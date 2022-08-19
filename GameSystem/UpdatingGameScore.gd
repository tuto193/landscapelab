extends GameScore
class_name UpdatingGameScore


# Overwrite to recalculate score automatically if the game_object_collection changes in some way
func add_contributor(game_object_collection: GameObjectCollection, attribute_name, weight = 1.0):
	.add_contributor(game_object_collection, attribute_name, weight)
	
	# Connect this GameObjectCollection's changed signal if necessary (it's possible to have two
	# contributors with the same underlying game_object_collection, but different attribute_names)
	if not game_object_collection.is_connected("changed", self, "recalculate_score"):
		game_object_collection.connect("changed", self, "recalculate_score")
	
	# Update the score to reflect this new contributor
	recalculate_score()

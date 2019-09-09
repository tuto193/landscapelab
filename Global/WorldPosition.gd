extends Node

#
# This is an interface to be able to get correct WorldPositions (on the global ground) from any node, without knowing
# the path to the tile handler.
#

var _handler = null


# Set the reference to the tile handler.
# The node at the reference must implement the function 'get_ground_coords'.
func set_handler(ref):
	if not ref.has_method("get_ground_coords"):
		logger.error("Handler passed to WorldPosition does not implement get_ground_coords, this is required!")
	
	_handler = ref


# Returns the top-level tile (no tile parent) which is at the given position, or null
#  if there is no tile for that position.
func get_tile_at_position(engine_pos: Array):
	return _handler.get_tile_at_position(engine_pos)


# Get the passed position with the y-coordinate set to be on the ground of the terrain.
func get_position_on_ground(vec : Vector3):
	return _handler.get_ground_coords(vec)

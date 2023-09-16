extends Node2D

@export var DistanceFromScreenEdge : float = 100

func position_node_offscreen(node:Node2D, possible_edges:Array[int]):
	var screenspace2worldspace = get_canvas_transform().affine_inverse()
	var viewportSize = get_viewport().get_visible_rect().size
	var middleScreenPos = screenspace2worldspace * (viewportSize / 2.0)
	
	var spawnCoords : Vector2 = Vector2.ZERO
	# remove borders left and right, so rectangle fits more or less visible area
	viewportSize.x -= 300
	var useEdge = possible_edges.pick_random()
	if useEdge == 0:
		# top edge
		spawnCoords.x = randf_range(0, viewportSize.x) + 150
		spawnCoords.y = 0
	elif useEdge == 1:
		# bottom edge
		spawnCoords.x = randf_range(0, viewportSize.x)  + 150
		spawnCoords.y = viewportSize.y
	elif useEdge == 2:
		# left edge
		spawnCoords.x = 150
		spawnCoords.y = randf_range(0, viewportSize.y)
	else:
		# right edge
		spawnCoords.x = viewportSize.x + 150
		spawnCoords.y = randf_range(0, viewportSize.y)
	
	var spawnPos = screenspace2worldspace * spawnCoords
	var spawnOffset = (spawnPos - middleScreenPos).normalized() * DistanceFromScreenEdge
	node.global_position = spawnPos + spawnOffset


func get_random_position_in_area(rect:Rect2) -> Vector2:
	return Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))

func get_nearest_valid_position(world_pos:Vector2) -> Vector2:
	# this geometry has no restrictions
	return world_pos


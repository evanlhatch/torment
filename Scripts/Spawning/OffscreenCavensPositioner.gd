extends Node2D

@export var DistanceFromScreenEdge : float = 100

func position_node_offscreen(node:Node2D, possible_edges:Array[int]):
	var screenspace2worldspace = get_canvas_transform().affine_inverse()
	var viewportSize = get_viewport().get_visible_rect().size
	var middleScreenPos = screenspace2worldspace * (viewportSize / 2.0)

	var randDirStart : float = 0
	var randDirEnd : float = TAU
	if possible_edges.size() < 4:
		var useEdge = possible_edges.pick_random()
		var hAngle : float = viewportSize.x / viewportSize.y * TAU / 2
		var vAngle : float = (TAU - hAngle * 2) / 2
		match useEdge:
			0:
				# top edge
				randDirStart = vAngle / 2.0 + hAngle + vAngle
				randDirEnd = randDirStart + hAngle
			1:
				# bottom edge
				randDirStart = vAngle / 2.0
				randDirEnd = randDirStart + hAngle
			2:
				# left edge
				randDirStart = vAngle / 2.0 + hAngle
				randDirEnd = randDirStart + vAngle
			3:
				# right edge
				randDirStart = -vAngle / 2.0
				randDirEnd = randDirStart + vAngle
	var randomDir : float = randf_range(randDirStart, randDirEnd)
	var spawnInCavern : NavigationCavern = Global.World.NavigationCaverns.getCavernAtViewAngle(randomDir)
	if spawnInCavern == null:
		# let's try one more time with a different random angle:
		randomDir = randf_range(randDirStart, randDirEnd)
		spawnInCavern = Global.World.NavigationCaverns.getCavernAtViewAngle(randomDir)
		if spawnInCavern == null:
			# still no luck: just take the closest one
			spawnInCavern = Global.World.NavigationCaverns.getNearestCavernInView()
	var dirToCavern : Vector2 = middleScreenPos.direction_to(spawnInCavern.global_position)
	var offsetToBackWall : Vector2 = dirToCavern.rotated(randf_range(-PI * 0.5, PI * 0.5)) * spawnInCavern.Radius * 0.8
	node.global_position = spawnInCavern.global_position + offsetToBackWall

func get_random_position_in_area(rect:Rect2) -> Vector2:
	var randomPosInArea := Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
	var closestCavern : NavigationCavern = Global.World.NavigationCaverns.get_closest_cavern_with_wrapping(randomPosInArea)
	var randomLocationInCavern : Vector2 = closestCavern.get_unwrapped_center(randomPosInArea)
	var rangeInsideCavern : float = closestCavern.Radius * 0.8
	randomLocationInCavern.x += randf_range(-rangeInsideCavern, rangeInsideCavern)
	randomLocationInCavern.y += randf_range(-rangeInsideCavern, rangeInsideCavern)
	return randomLocationInCavern

func get_nearest_valid_position(world_pos:Vector2) -> Vector2:
	var closestCavern : NavigationCavern = Global.World.NavigationCaverns.get_closest_cavern_with_wrapping(world_pos)
	var unwrappedCenter : Vector2 = closestCavern.get_unwrapped_center(world_pos)
	if unwrappedCenter.distance_squared_to(world_pos) < closestCavern.Radius*closestCavern.Radius:
		return world_pos
	var dir_to_world_pos : Vector2 = (world_pos - unwrappedCenter).normalized()
	return unwrappedCenter + dir_to_world_pos * closestCavern.Radius * 0.9


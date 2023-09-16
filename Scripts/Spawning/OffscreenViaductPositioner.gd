extends Node2D

@export var FirstTileOffset : Vector2 = Vector2(-84.0, -64.0)
@export var ViaductWidth : float = 690.0

const VIEWPORT_CENTER : Vector2 = Vector2(480, 270)
const UP_TO_DIAGONAL_ANGLE = deg_to_rad(53.0)
const CW_TURN_ANGLE = deg_to_rad(74.0)
const CCW_TURN_ANGLE = deg_to_rad(106)

var DIR_NE : Vector2
var DIR_NW : Vector2
var DIR_SE : Vector2
var DIR_SW : Vector2
var DIR_ORTHO : Vector2

func _enter_tree():
	DIR_NE = Vector2.UP.rotated(UP_TO_DIAGONAL_ANGLE)
	DIR_NW = Vector2.UP.rotated(-UP_TO_DIAGONAL_ANGLE)
	DIR_SE = Vector2.DOWN.rotated(-UP_TO_DIAGONAL_ANGLE)
	DIR_SW = Vector2.DOWN.rotated(UP_TO_DIAGONAL_ANGLE)
	DIR_ORTHO = DIR_NE.rotated(deg_to_rad(90))

func position_node_offscreen(node:Node2D, possible_edges:Array[int]):
	if possible_edges.is_empty(): return
	var spawnCoords : Vector2 = Vector2.ZERO

	var viewportWorldCenter = get_canvas_transform().affine_inverse() * VIEWPORT_CENTER
	var viaductRefPoint = Geometry2D.line_intersects_line(
		FirstTileOffset, DIR_NE, viewportWorldCenter, DIR_NW)

	var point_north_A = viaductRefPoint + DIR_NE * 500.0
	var point_north_B = point_north_A + DIR_SE * ViaductWidth

	var point_south_A = viaductRefPoint - DIR_NE * 500.0
	var point_south_B = point_south_A + DIR_SE * ViaductWidth

	var useEdge = possible_edges.pick_random()
	match useEdge:
		0, 2:
			# north-east edge (and fallback for left edge)
			spawnCoords = lerp(point_north_A, point_north_B, randf())
		1, 3:
			# south-west edge (and fallback for right edge)
			spawnCoords = lerp(point_south_A, point_south_B, randf())
	node.global_position = spawnCoords


func get_random_position_in_area(rect:Rect2) -> Vector2:
	var randomPos : Vector2 = Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
	randomPos = FirstTileOffset + randomPos.project(DIR_NE)
	randomPos += DIR_SE * randf_range(0, ViaductWidth)
	return randomPos

func get_nearest_valid_position(world_pos:Vector2) -> Vector2:
	var pointOnViaductLine : Vector2 = Geometry2D.get_closest_point_to_segment_uncapped(
		world_pos, FirstTileOffset, FirstTileOffset + DIR_NE)
	var line_to_world_pos : Vector2 = pointOnViaductLine - world_pos
	if line_to_world_pos.dot(DIR_ORTHO) > 0:
		# world_pos is left of the viaduct, return the
		# position on the viaduct line, which is the left border!
		return pointOnViaductLine
	if world_pos.distance_squared_to(pointOnViaductLine) < ViaductWidth*ViaductWidth:
		# world_pos is on the viaduct!
		return world_pos
	# world_pos is right of the viaduct, return the rightmost position
	return pointOnViaductLine + DIR_ORTHO * ViaductWidth * 0.94

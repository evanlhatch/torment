# This is a global utility node just for transforming and comparing directions.
# Directions are used in various sprite animation controls and FX.
extends Node

const DIRECTION_INCREMENT_ANGLE : float = 22.5
const DIRECTION_COUNT = 16

enum Dir {
	S = 0,
	SSE = 1,
	SE = 2,
	SEE = 3,
	E = 4,
	NEE = 5,
	NE = 6,
	NNE = 7,
	N = 8,
	NNW = 9,
	NW = 10,
	NWW = 11,
	W = 12,
	SWW = 13,
	SW = 14,
	SSW = 15
}

func get_opposite_direction(direction : Dir) -> int:
	return wrapi(direction + 8, Dir.S, Dir.SSW)

func get_angle_between_directions(dirA : Dir, dirB : Dir) -> float:
	var leftTurn = (dirA - dirB) + 1 + (0 if (dirA >= dirB) else DIRECTION_COUNT)
	var rightTurn = (dirB - dirA) + 1 + (0 if (dirA <= dirB) else DIRECTION_COUNT)
	return min(leftTurn, rightTurn) * DIRECTION_INCREMENT_ANGLE

func get_direction_from_vector(vector : Vector2) -> int:
	var angle = rad_to_deg(atan2(vector.x, vector.y))
	return wrapi(
		int(round(angle / DIRECTION_INCREMENT_ANGLE)),
		0, DIRECTION_COUNT)

func get_direction_string_from_vector(vector : Vector2, only_eight_dirs : bool = false) -> String:
	var dir_enum = get_direction_from_vector(vector)
	if only_eight_dirs and dir_enum % 2 > 0:
		dir_enum -= 1
	return str(Dir.keys()[dir_enum])

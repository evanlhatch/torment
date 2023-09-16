extends GameObjectComponent2D

@export var MaxSpeed : float = 30.0
@export var ViaductDirection : Vector2 = Vector2(84, -64)
@export var ZeroPosOffset : Vector2 = Vector2(-112.0, -128.0)
@export var MoveThreshold : float = 32.0
@export var MoveOffset : float = -100

var viaduct_dir_norm : Vector2
var target_position : float
var viaduct_position : float
var pos_delta : float

func _ready():
	initGameObjectComponent()
	viaduct_dir_norm = ViaductDirection.normalized()

func get_worldPosition() -> Vector2: return global_position
func set_worldPosition(pos:Vector2): global_position = pos
func get_viaductPosition() -> float: return viaduct_position
func set_viaductPosition(pos:float):
	global_position = ZeroPosOffset + viaduct_dir_norm * pos
	viaduct_position = pos
func set_targetViaductPos(target_pos:float): target_position = target_pos
func get_targetViaductPos() -> float: return target_position


func get_viaduct_pos_of_point(point:Vector2) -> float:
	var edge_point = Geometry2D.get_closest_point_to_segment_uncapped(
		point, ZeroPosOffset + ViaductDirection, ZeroPosOffset - ViaductDirection)
	var progress_vector = edge_point - ZeroPosOffset
	var progress_direction = signf(progress_vector.dot(viaduct_dir_norm))
	return progress_vector.length() * progress_direction


func _process(delta):
	var progress_vector = global_position - ZeroPosOffset
	var progress_direction = signf(progress_vector.dot(viaduct_dir_norm))
	viaduct_position = progress_vector.length() * progress_direction

	pos_delta = target_position - viaduct_position + MoveOffset
	if absf(pos_delta) > MoveThreshold:
		global_position += viaduct_dir_norm * MaxSpeed * delta * signf(pos_delta)

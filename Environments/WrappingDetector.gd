extends Node2D

@export var DistanceThreshold:float = 100

var parentPatch : Node2D

signal NorthLimitReached(patch:Node2D)
signal SouthLimitReached(patch:Node2D)
signal EastLimitReached(patch:Node2D)
signal WestLimitReached(patch:Node2D)


func _ready():
	parentPatch = get_parent()

func _process(delta):
	if get_viewport().get_camera_2d() == null:
		return
	var cameraCenterWorldPosition = get_viewport().get_camera_2d().get_screen_center_position()

	var westCheck = $WestLimit.global_position.x - cameraCenterWorldPosition.x
	if westCheck > 0 and westCheck < DistanceThreshold:
		emit_signal("WestLimitReached", parentPatch)

	var eastCheck = cameraCenterWorldPosition.x - $EastLimit.global_position.x
	if eastCheck > 0 and eastCheck < DistanceThreshold:
		emit_signal("EastLimitReached", parentPatch)

	var southCheck = cameraCenterWorldPosition.y - $SouthLimit.global_position.y
	if southCheck > 0 and southCheck < DistanceThreshold:
		emit_signal("SouthLimitReached", parentPatch)

	var northCheck = $NorthLimit.global_position.y - cameraCenterWorldPosition.y
	if northCheck > 0 and northCheck < DistanceThreshold:
		emit_signal("NorthLimitReached", parentPatch)

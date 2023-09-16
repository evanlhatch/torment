extends GameObjectComponent2D

@export var ActivatedViaSettings : bool = true
var _direction_provider : Node

func _ready():
	initGameObjectComponent()
	_direction_provider = _gameObject.getChildNodeWithMethod("get_aimDirection")
	if not Global.is_world_ready():
		await Global.WorldReady
	if ActivatedViaSettings:
		visible = Global.CurrentSettings["aiming_line"]

func _process(_delta):
	if _direction_provider != null:
		var aim_direction = _direction_provider.get_aimDirection()
		var rotationFromDirection = aim_direction.angle()
		set_rotation(rotationFromDirection)

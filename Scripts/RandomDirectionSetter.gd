extends GameObjectComponent

@export var StartDirection : Vector2 = Vector2.RIGHT
@export var AngleRangeMin : float = -PI
@export var AngleRangeMax : float = PI

func _ready() -> void:
	initGameObjectComponent()
	if _gameObject != null:
		var dirSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
		if is_instance_valid(dirSetter):
			dirSetter.set_targetDirection(StartDirection.rotated(
				randf_range(AngleRangeMin, AngleRangeMax)))

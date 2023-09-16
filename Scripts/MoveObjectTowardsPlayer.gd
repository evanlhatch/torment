extends GameObjectComponent

@export var BaseMovementSpeed : float = 18.0
@export var MinDistanceToPlayer : float = 16.0
@export var ModifierCategories : Array[String] = ["Magic"]

var _targetPosProvider : Node
var _modifiedMovementSpeed

func _enter_tree() -> void:
	initGameObjectComponent()
	if _gameObject != null:
		_modifiedMovementSpeed = createModifiedFloatValue(BaseMovementSpeed, "MovementSpeed")
		if Global.is_world_ready() and Global.World.Player != null:
			_targetPosProvider = Global.World.Player.getChildNodeWithMethod("get_worldPosition")


func applyModifierCategories():
	_modifiedMovementSpeed.setModifierCategories(ModifierCategories)


func _process(delta: float) -> void:
	if is_instance_valid(_targetPosProvider):
		var pos = get_gameobjectWorldPosition()
		var direction : Vector2 = _targetPosProvider.get_worldPosition() - pos
		if direction.length_squared() > (MinDistanceToPlayer * MinDistanceToPlayer):
			_gameObject.global_position = pos + direction.normalized() * _modifiedMovementSpeed.Value() * delta

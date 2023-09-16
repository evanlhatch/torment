extends GameObjectComponent

@export var BulletEmitter : Node

var targetDirectionSetter : Node
var targetPosProvider : Node
var positionProvider : Node
var input_direction : Vector2

const circling_angle = 0.314159
@export var circling_direction : float = 1.0

signal input_dir_changed(dir_vector:Vector2)


func _ready():
	initGameObjectComponent()
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	if (Global.World.Player != null and not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)


func set_target(targetNode : Node):
	targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	

func _process(delta):
	var newInputDir : Vector2 = Vector2.ZERO
	if is_targetProvider_valid():
		var targetPos = targetPosProvider.get_worldPosition()
		var direction_to_player = targetPos - positionProvider.get_worldPosition()
		newInputDir = get_circling_input_dir(direction_to_player, delta)
		newInputDir = newInputDir.normalized()
	_update_direction(newInputDir)


func get_circling_input_dir(direction_to_player:Vector2, delta) -> Vector2:
	var vector_from_player = (-direction_to_player).normalized() * 200.0
	vector_from_player = vector_from_player.rotated(circling_angle * circling_direction)
	return direction_to_player + vector_from_player


func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		input_dir_changed.emit(input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)


func get_facingDirection() -> Vector2:
	return get_aimDirection()


func get_aimDirection() -> Vector2:
	if is_targetProvider_valid():
		var targetPos = targetPosProvider.get_worldPosition()
		return (targetPos - positionProvider.get_worldPosition()).normalized()
	return input_direction.normalized()


func is_targetProvider_valid():
	return targetPosProvider != null and not targetPosProvider.is_queued_for_deletion()

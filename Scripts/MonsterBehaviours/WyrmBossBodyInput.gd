extends GameObjectComponent

@export var DistanceToTarget : float = 20.0
@export var BodySprite : Node
@export var RubbelFX : Node2D

const PI_HALVE : float = PI * 0.5

var healthComponent : Node
var positionProvider : Node
var targetDirectionSetter : Node
var targetFacingSetter : Node
var aoeComponent : Node
var input_direction : Vector2

var _head_height_time : float
var _body_height : float
var _target_pos_provider : Node
var _target_input : Node

var _killed : bool

func _ready():
	initGameObjectComponent()
	healthComponent = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	positionProvider = _gameObject.getChildNodeWithMethod("get_worldPosition")
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	aoeComponent = _gameObject.getChildNodeWithMethod("set_harmless")


func _process(_delta):
	if _killed:
		targetDirectionSetter.set_targetDirection(Vector2.ZERO)
		return
	if not is_instance_valid(_target_pos_provider):
		return
	var target_pos = _target_pos_provider.get_worldPosition()
	var current_pos = positionProvider.get_worldPosition()
	input_direction = target_pos - current_pos
	input_direction = input_direction.limit_length(clamp(input_direction.length() - DistanceToTarget, 0.0, 100.0))
	positionProvider.set_worldPosition(current_pos + input_direction)
	targetDirectionSetter.set_targetDirection(input_direction)

	if _target_input != null:
		_head_height_time = _target_input._head_height_time - 0.2
		_body_height = clamp((cos(_head_height_time) + 0.6) * 1.3, 0.0, 0.9)
		_update_submersion()

func get_inputWalkDir() -> Vector2:
	return input_direction


func get_aimDirection() -> Vector2:
	return input_direction.normalized()


func set_target_element(target_posProvider:Node, target_input:Node):
	_target_pos_provider = target_posProvider
	_target_input = target_input


var _is_submerged : bool
func _update_submersion():
	if not _is_submerged and _body_height < 0.6:
		_is_submerged = true
		aoeComponent.set_harmless(true)
		healthComponent.setInvincibleForTime(10.0)
	elif _is_submerged and _body_height >= 0.6:
		_is_submerged = false
		aoeComponent.set_harmless(false)
		healthComponent.setInvincibleForTime(-1.0)
	BodySprite.material.set_shader_parameter("submerge", _body_height)
	BodySprite.position.y = _body_height * -12.0
	RubbelFX.scale = Vector2.ONE * sin(clamp(_body_height * PI, 0.0, PI_HALVE))


func kill(kill_time:float, byNode:Node):
	_killed = true
	await get_tree().create_timer(kill_time).timeout
	healthComponent.ShowDamageNumbers = false
	healthComponent._modifiedDamageFactor = healthComponent.createModifiedFloatValue(10.0, "DamageFactor")
	healthComponent.applyDamage(healthComponent.get_maxHealth(), byNode, false, -1, true)

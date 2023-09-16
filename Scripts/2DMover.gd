extends GameObjectComponentRigidBody2D

# classnames can't start with a number...
class_name TwoDMover

@export var movementForce : float = 5
@export var maxSpeed : float = 10
@export var weightCap : float = 50
@export var baseKnockbackResistance : float = 0
@export var RankSpeedModifierMethod : String = ""

signal CollisionStarted(otherNode:Node)
signal CollisionEnded(otherNode:Node)

var _targetVelocity:Vector2
var _targetDirection:Vector2
var _facingDirection:Vector2
var _collisionsStarted:Array[Node]
var _collisionsEnded:Array[Node]
var _pushedCounter:float

var _is_jumping:bool
var _jump_target:Vector2

var _baseMass : float
var _modifiedSpeed
var _modifiedMass
var _modifiedKnockbackResistance : ModifiedFloatValue

var _timer:Timer

func _ready():
	initGameObjectComponent()
	connect("body_entered", onRigidBodyEntered)
	connect("body_exited", onRigidBodyExited)
	_baseMass = mass
	if RankSpeedModifierMethod.is_empty():
		_modifiedSpeed = createModifiedFloatValue(maxSpeed, "MovementSpeed")
	else:
		_modifiedSpeed = createModifiedFloatValue(
			maxSpeed, "MovementSpeed",
			Global.World.TormentRank.get_modifier_accessor(RankSpeedModifierMethod))
	_modifiedSpeed.connect("ValueUpdated", movementSpeedWasUpdated)
	_modifiedMass = createModifiedFloatValue(_baseMass, "Mass")
	_modifiedMass.connect("ValueUpdated", massWasUpdated)
	massWasUpdated(_baseMass, _modifiedMass.Value())
	_modifiedKnockbackResistance = createModifiedFloatValue(baseKnockbackResistance, "KnockbackResistance")

func _enter_tree():
	Global.World.TwoDMoverSys.Register2DMover(self)

func _exit_tree():
	_allModifiedValues.clear()
	_modifiedSpeed = null
	_modifiedMass = null
	_modifiedKnockbackResistance = null
	Global.World.TwoDMoverSys.Unregister2DMover(self)

func massWasUpdated(_oldValue:float, newMass:float):
	mass = clamp(newMass, 1.0, weightCap)

func movementSpeedWasUpdated(_oldValue:float, newSpeed:float):
	_targetVelocity = newSpeed * _targetDirection
	var currentSpeed = linear_velocity.length()
	if currentSpeed > newSpeed:
		linear_velocity = linear_velocity / currentSpeed * newSpeed

func onRigidBodyEntered(otherBody:Node):
	_collisionsStarted.append(otherBody)

func onRigidBodyExited(otherBody:Node):
	_collisionsEnded.append(otherBody)

func get_targetVelocity() -> Vector2:
	return _targetVelocity

func get_velocity() -> Vector2:
	return linear_velocity

func set_targetDirection(targetDirection:Vector2):
	_targetDirection = targetDirection
	_targetVelocity = _modifiedSpeed.Value() * _targetDirection
	if _targetVelocity.length_squared() > 0.0:
		set_facingDirection(_targetVelocity)

func get_worldPosition() ->  Vector2:
	return global_position

func set_worldPosition(new_position : Vector2):
	global_position = new_position

func get_facingDirection() -> Vector2:
	return _facingDirection

func set_facingDirection(newFacingDir : Vector2) -> void:
	if not _is_jumping:
		_facingDirection = newFacingDir.normalized()

func can_resist_knockback(knockbackPower:float):
	if _pushedCounter > 0: return true
	return knockbackPower < _modifiedKnockbackResistance.Value()

func add_velocity(add_velocity:Vector2):
	var difference : Vector2 = add_velocity - linear_velocity
	apply_impulse(difference.clamp(-abs(add_velocity), abs(add_velocity)))

func set_pushed_counter(pushedTime:float):
	_pushedCounter = pushedTime


var cached_collision_layer : int
var cached_collision_mask : int
func jump_to(target_position:Vector2, jump_duration:float, wait_at_end:float = 0.0):
	_jump_target = target_position
	cached_collision_layer = collision_layer
	cached_collision_mask = collision_mask

	_is_jumping = true
	var jump_tween = create_tween()
	jump_tween.set_trans(Tween.TRANS_LINEAR)
	jump_tween.tween_property(self, "global_position", target_position, jump_duration)

	await jump_tween.finished
	collision_layer = cached_collision_layer
	collision_mask = cached_collision_mask

	if wait_at_end > 0.0:
		set_up_timer(wait_at_end); await _timer.timeout
	_is_jumping = false

func start_jump_manual():
	cached_collision_layer = collision_layer
	cached_collision_mask = collision_mask
	_is_jumping = true

func end_jump_manual():
	collision_layer = cached_collision_layer
	collision_mask = cached_collision_mask
	_is_jumping = false

func set_up_timer(duration:float):
	if _timer == null:
		_timer = Timer.new()
		add_child(_timer)
	_timer.start(duration)

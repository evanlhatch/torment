extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export_enum("Linear", "Curve") var MovePattern : int
@export var AreaOfEffectNode : Node
@export var ClosestDistanceToPlayer : float = 130.0
@export var FarthestDistanceToPlayer : float = 210.0
@export var DestinationDistThreshold : float = 16.0
@export var SurfaceDuration : float = 3.5
@export var FirewallEmitter : Node
@export var CollisionNode : GameObjectComponentRigidBody2D

@export_group("Curved Movement Parameters")
@export var MovementCurvatureAngle : float = 30.0
@export var MovementCurvatureDistance : float = 300.0

@export_group("Sprite Nodes")
@export var BelowSprite : AnimatedSprite2D
@export var SurfaceSprite : AnimatedSprite2D

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var loitering_counter : float
var underground_state : bool
var stunEffect : Node
var health_component : Node
var default_collision_layer : int

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife
signal AttackTriggered(attack_index:int)

var _targetPosProvider : Node
var _targetPosition : Vector2
var _surfaceTimer : float
var _attackMoment : float
var _delay_timer : Timer
var _locator : Locator

func _ready():
	initGameObjectComponent()
	_gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	health_component = _gameObject.getChildNodeWithMethod("setInvincibleForTime")
	_locator = _gameObject.getChildNodeWithMethod("SetLocatorActive")
	_delay_timer = Timer.new()
	add_child(_delay_timer)
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
		pick_target_position()
	default_collision_layer = CollisionNode.collision_layer
	set_underground(true)

func _on_child_entered_gameObject(node:Node):
	if node.has_method("is_stunned"):
		stunEffect = node

func _process(delta):
	if underground_state:
		_below_process(delta)
	else:
		_surface_process(delta)

func _below_process(delta):
	var newInputDir : Vector2 = Vector2.ZERO
	if MovePattern == 0:
		newInputDir = get_linear_movement_input(_targetPosition)
	elif MovePattern == 1:
		newInputDir = get_curved_movement_input(_targetPosition)
	if newInputDir.length() <= StopWhenInRange:
		targetFacingSetter.set_facingDirection(newInputDir)
		newInputDir = Vector2.ZERO
	else:
		newInputDir = newInputDir.normalized()
		
	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)

	var distToDestSQ = get_gameobjectWorldPosition().distance_squared_to(_targetPosition)
	if distToDestSQ <= DestinationDistThreshold*DestinationDistThreshold:
		set_underground(false)
		_surfaceTimer = SurfaceDuration
	elif distToDestSQ >= 1500*1500:
		# we were probably teleported! so our current
		# target position is not really relevant anymore.
		pick_target_position()

func _surface_process(delta):
	if _surfaceTimer > 0.0:
		if stunEffect and stunEffect.is_stunned(): return
		_surfaceTimer -= delta
		targetDirectionSetter.set_targetDirection(Vector2.ZERO)
		targetFacingSetter.set_facingDirection(get_aimDirection())
		if _surfaceTimer <= _attackMoment:
			AttackTriggered.emit(0)
			_attackMoment = -1.0
			FirewallEmitter.set_emitting(true)
			_delay_timer.start(0.3)
			await _delay_timer.timeout
			FirewallEmitter.set_emitting(false)
	else:
		set_underground(true)
		pick_target_position()

func get_linear_movement_input(targetPos : Vector2) -> Vector2:
	return targetPos - get_gameobjectWorldPosition()

func get_curved_movement_input(targetPos : Vector2) -> Vector2:
	var target_vector : Vector2 = targetPos - get_gameobjectWorldPosition()
	var curve_factor = clamp(
		inverse_lerp(8.0, MovementCurvatureDistance, target_vector.length()),
		0.0, 1.0)
	return target_vector.rotated(deg_to_rad(lerp(0.0, MovementCurvatureAngle, curve_factor)))

func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")

func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	if not underground_state and is_targetProvider_valid():
		var target_pos = _targetPosProvider.get_worldPosition()
		return (target_pos - get_gameobjectWorldPosition()).normalized()
	return input_direction


func set_underground(is_underground:bool):
	if is_underground:
		CollisionNode.collision_layer = 0
		SurfaceSprite.set_sprite_animation_state("rise", true, true)
		await SurfaceSprite.animation_cycle_finished
		health_component.setInvincibleForTime(1800.0)
		_locator.SetLocatorActive(false)
		AreaOfEffectNode.ProbabilityToApply = 0.0
		SurfaceSprite.visible = false
		BelowSprite.visible = true
		underground_state = is_underground
	else:
		CollisionNode.collision_layer = default_collision_layer
		underground_state = is_underground
		BelowSprite.visible = false
		SurfaceSprite.visible = true
		health_component.setInvincibleForTime(-1.0)
		_locator.SetLocatorActive(true)
		AreaOfEffectNode.ProbabilityToApply = 1.0
		_attackMoment = randf_range(1.5, SurfaceDuration - 0.5)
		AttackTriggered.emit(1)
		await SurfaceSprite.animation_cycle_finished
		SurfaceSprite.set_sprite_animation_state("idle", true)


func pick_target_position():
	if is_targetProvider_valid():
		var target_pos = _targetPosProvider.get_worldPosition()
		_targetPosition = target_pos + (
			Vector2((randf() - 0.5), (randf() - 0.5)).normalized() * randf_range(
				ClosestDistanceToPlayer, FarthestDistanceToPlayer))

func is_targetProvider_valid():
	return _targetPosProvider != null and is_instance_valid(_targetPosProvider) and not _targetPosProvider.is_queued_for_deletion()

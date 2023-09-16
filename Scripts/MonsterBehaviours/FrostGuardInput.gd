extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var MaxAttackDistance : float = 32.0
@export var AttackEffectScene : PackedScene
@export var TrailEffectNode : Node
@export var TwoDMoveNode : TwoDMover

@export_group("Charge Settings")
@export var MinChargeInterval : float = 3.5
@export var MaxChargeInterval : float = 7.0
@export var ChargeDuration : float = 2.0

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var attacking : bool
var charging : bool

signal AttackTriggered(attack_index:int)
signal input_dir_changed(dir_vector:Vector2)

var _aimDirection : Vector2
var _targetPosProvider : Node
var _targetOverrideProvider : Node
var _targetPosOffset : Vector2
var _movementSpeedMod : Modifier


func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_targetOverrideProvider = _gameObject.getChildNodeWithMethod("get_override_target_position")
	if (SetPlayerAsTargetOnSpawn and
		Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	_targetPosOffset = (Vector2.ONE * randf_range(20.0, 40.0)).rotated(randf_range(-PI, PI))
	$ChargeTimer.timeout.connect(perform_charge)
	$ChargeTimer.start(randf_range(MinChargeInterval, MaxChargeInterval))

	_movementSpeedMod = Modifier.create("MovementSpeed", _gameObject)
	_movementSpeedMod.setName("Frost Guard Charge Movement")
	_movementSpeedMod.setAdditiveMod(0)
	_movementSpeedMod.setMultiplierMod(0)
	_gameObject.triggerModifierUpdated("MovementSpeed")


func _process(delta):
	if attacking: return
	var newInputDir : Vector2 = Vector2.ZERO

	var targetPos : Vector2
	var hasOverridePos : bool = _targetOverrideProvider != null and _targetOverrideProvider.has_override_target_position()
	if not hasOverridePos:
		if is_targetProvider_valid(): targetPos = _targetPosProvider.get_worldPosition() + _targetPosOffset
	else:
		targetPos = _targetOverrideProvider.get_override_target_position()

	newInputDir = (targetPos - get_gameobjectWorldPosition()).normalized()

	if is_targetProvider_valid():
		_aimDirection = _targetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()
		var dist_sqr = _aimDirection.length_squared()
		_aimDirection = _aimDirection.normalized()
		targetFacingSetter.set_facingDirection(_aimDirection)
		if not charging and dist_sqr <= MaxAttackDistance * MaxAttackDistance:
			perform_sword_attack()
			return
	else:
		targetFacingSetter.set_facingDirection(newInputDir)

	if newInputDir != input_direction:
		input_direction = newInputDir
		input_dir_changed.emit(input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)
		if input_direction.length_squared() > 0.0:
			_aimDirection = input_direction.normalized()


func perform_sword_attack():
	if attacking: return
	input_direction = Vector2.ZERO
	input_dir_changed.emit(input_direction)
	targetDirectionSetter.set_targetDirection(input_direction)
	attacking = true
	var attack_effect = AttackEffectScene.instantiate()
	attack_effect.global_position = get_gameobjectWorldPosition() + _aimDirection * 32.0
	Global.attach_toWorld(attack_effect)
	if attack_effect.has_method("start"):
		attack_effect.start(_gameObject, _aimDirection, 0.5)
	AttackTriggered.emit(0)
	$AttackTimer.start(0.8)
	await $AttackTimer.timeout
	_targetPosOffset = (Vector2.ONE * randf_range(60.0, 90.0)).rotated(randf_range(-PI, PI))
	attacking = false


func perform_charge():
	$ChargeTimer.stop()
	charging = true
	TrailEffectNode.Active = true
	var defaultForce = TwoDMoveNode.movementForce
	TwoDMoveNode.movementForce = 150
	_movementSpeedMod.setMultiplierMod(1.5)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	AttackTriggered.emit(1)
	$AttackTimer.start(ChargeDuration)
	await $AttackTimer.timeout
	TrailEffectNode.Active = false
	TwoDMoveNode.movementForce = defaultForce
	_movementSpeedMod.setMultiplierMod(0)
	_gameObject.triggerModifierUpdated("MovementSpeed")
	charging = false
	$ChargeTimer.start(randf_range(MinChargeInterval, MaxChargeInterval))


func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")


func get_inputWalkDir() -> Vector2:
	return input_direction


func get_aimDirection() -> Vector2:
	return _aimDirection


func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()

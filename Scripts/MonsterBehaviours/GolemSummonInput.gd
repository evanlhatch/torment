extends SummonInput

const CURL_TIME = 0.2

@export var WalkingSprite : Node
@export var RollingSprite : Node
@export var GhostlyTrail : Node
@export var RollingSpeedMultiplier : float = 5
@export var RollCooldown : float = 2
@export var RollingTime : float = 2
@export var AttackTargetUpdateInterval : float = 1.0

@export_group("Circle Roll Parameters")
@export var CircleRadius : float = 160

var positionComponent : Node
var fixedPushComponent : Node
var collisionComponent : Node
var locatorCollider : Node
var damageByTimeComponent : Node

var curl_transition : bool
var curled_up : bool
var delay_timer : Timer
var _movementSpeedModifier : Modifier
var remainingCooldown : float
var remainingRollTime : float

var _modifiedLifetime
var _modifiedCooldown

var target_update_timer : Timer


func _ready():
	super()
	if _gameObject == null:
		return
	_movementSpeedModifier = Modifier.create("MovementSpeed", _gameObject)
	_movementSpeedModifier.setName("Rolling Golem")
	_movementSpeedModifier.setMultiplierMod(0.0)
	_modifiedLifetime = createModifiedFloatValue(RollingTime, "Force")
	_modifiedCooldown = createModifiedFloatValue(RollCooldown, "Cooldown")
	applyModifierCategories()

	positionComponent = _gameObject.getChildNodeWithMethod("set_targetDirection")
	fixedPushComponent = _gameObject.getChildNodeWithMethod("set_push_active")
	collisionComponent = _gameObject.getChildNodeWithProperty("collision_layer")
	damageByTimeComponent = _gameObject.getChildNodeWithMethod("resetTimeDamageModifier")
	locatorCollider = _gameObject.getChildNodeWithMethod("set_locator_collider_active")
	locatorCollider.set_locator_collider_active(false)
	delay_timer = Timer.new()
	add_child(delay_timer)
	remainingCooldown = get_totalCooldown()

	target_update_timer = Timer.new()
	add_child(target_update_timer)
	target_update_timer.timeout.connect(update_attack_target)
	target_update_timer.start(AttackTargetUpdateInterval)


func applyModifierCategories():
	_modifiedLifetime.setModifierCategories(ModifierCategories)
	_modifiedCooldown.setModifierCategories(ModifierCategories)

func get_totalCooldown() -> float: return _modifiedCooldown.Value()
func get_totalLifetime() -> float: return _modifiedLifetime.Value()


func _process(delta):
	remainingCooldown -= delta
	if remainingCooldown < 0 and _currentState != States.Custom:
		remainingCooldown = get_totalCooldown() + get_totalLifetime() + CURL_TIME * 2
		switchState(States.Custom)

	updateWalkingToTargetPosition()
	match _currentState:
		States.Idle:
			idleBehaviour(delta)
		States.WalkingBackToSummoner:
			walkingBackToSummonerBehaviour(delta)
		States.Attacking:
			attackingBehaviour(delta)
		States.Custom:
			rollingBehaviour(delta)


func switchState(newState:States):
	match newState:
		States.Idle:
			if curled_up: uncurl()
			_gameObject.triggerModifierUpdated("MovementSpeed")
			_idleRemainingTimeToPositionUpdate = 0
			if _emitter != null:
				_emitter.set_emitting(false)
		States.WalkingBackToSummoner:
			if _emitter != null:
				_emitter.set_emitting(false)
		States.Attacking:
			if curled_up: uncurl()
			_gameObject.triggerModifierUpdated("MovementSpeed")
			if _emitter != null:
				_emitter.set_emitting(false)
		States.Custom:
			# custom is our rolling state!
			remainingRollTime = get_totalLifetime()
			if not curled_up: curl_up()
			_gameObject.triggerModifierUpdated("MovementSpeed")
			if _emitter != null:
				_emitter.set_emitting(false)
	_currentState = newState


func curl_up():
	if _gameObject == null or not is_instance_valid(_gameObject):
		return
	if curl_transition or not is_summonerPosProvider_valid(): return
	if damageByTimeComponent != null:
		damageByTimeComponent.resetTimeDamageModifier()
	collisionComponent.collision_layer = 0
	collisionComponent.collision_mask = 0
	locatorCollider.set_locator_collider_active(true)
	_movementSpeedModifier.setMultiplierMod(RollingSpeedMultiplier)
	curl_transition = true
	curled_up = true
	_gameObject.injectEmitSignal("AttackTriggered", [1])
	delay_timer.start(CURL_TIME); await delay_timer.timeout
	if GhostlyTrail != null: GhostlyTrail.set_active(true)
	fixedPushComponent.set_push_active(true)

	WalkingSprite.visible = false
	RollingSprite.visible = true
	curl_transition = false


func uncurl():
	if _gameObject == null or not is_instance_valid(_gameObject):
		return
	if curl_transition: return
	collisionComponent.collision_layer = 1
	collisionComponent.collision_mask = 1
	locatorCollider.set_locator_collider_active(false)
	_movementSpeedModifier.setMultiplierMod(0.0)
	if GhostlyTrail != null: GhostlyTrail.set_active(false)
	curl_transition = true
	WalkingSprite.visible = true
	RollingSprite.visible = false
	fixedPushComponent.set_push_active(false)
	_gameObject.injectEmitSignal("AttackTriggered", [2])
	delay_timer.start(CURL_TIME); await delay_timer.timeout
	curled_up = false
	curl_transition = false


func walkingBackToSummonerBehaviour(delta):
	var summonerPosition:Vector2
	if is_summonerPosProvider_valid():
		summonerPosition = _summonedByPosProvider.get_worldPosition()
	else:
		switchState(States.Idle)
		return # no summoner?

	var myPosition:Vector2 = get_gameobjectWorldPosition()
	var newDirection = (summonerPosition - myPosition).normalized()
	targetDirectionSetter.set_targetDirection(newDirection)
	aim_direction = newDirection


func rollingBehaviour(delta:float):
	remainingRollTime -= delta
	if remainingRollTime <= 0:
		switchState(States.Idle)
		return

	var summonerPosition:Vector2
	if is_summonerPosProvider_valid():
		summonerPosition = _summonedByPosProvider.get_worldPosition()
	else:
		switchState(States.Idle)
		return # no summoner?

	var myPosition:Vector2 = get_gameobjectWorldPosition()
	var targetRadiusVector = (myPosition - summonerPosition).rotated(-PI * 0.2)
	targetRadiusVector = targetRadiusVector.normalized() * CircleRadius

	var targetPosition = summonerPosition + targetRadiusVector
	var newDirection : Vector2 = (targetPosition - myPosition).normalized()

	fixedPushComponent.set_fixedPushDirection((myPosition - summonerPosition).normalized())
	targetDirectionSetter.set_targetDirection(newDirection)
	aim_direction = newDirection


func update_attack_target():
	if curled_up: return
	if AutoAttackWhenIdle:
		var attackTargetObj:GameObject = findClosestGameObjectToAttack()
		if attackTargetObj != null:
			attackTarget(attackTargetObj)

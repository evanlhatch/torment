extends SummonInput

@export var TouchNumberOfEnemies : int = 10
@export var ApplyEffectOnTouch : Array[PackedScene]
@export var AppliesOnToch : int = 5
@export var TouchDistanceSquared : float = 400

var _effectPrototype : Array[EffectBase]
var _remainingEnemies : int
var _modifiedSummonDurationMultOnly : ModifiedFloatValue
var _prevAttackTarget:GameObject = null

func _ready():
	super()

	# we still want the summon duration to have an effect here, so we
	# use the multiplier part to change our Number of touched enemies
	_modifiedSummonDurationMultOnly = ModifiedFloatValue.new()
	_modifiedSummonDurationMultOnly.initAsMultiplicativeOnly("Force", _gameObject, Callable())
	_remainingEnemies = ceili(_modifiedSummonDurationMultOnly.Value() * TouchNumberOfEnemies)
	_modifiedSummonDurationMultOnly.ValueUpdated.connect(SummonDurationWasUpdated)
	
	for effectPrototype in ApplyEffectOnTouch:
		_effectPrototype.append(effectPrototype.instantiate())

func SummonDurationWasUpdated(valueBefore:float, valueNow:float):
	var touchNumberOfEnemiesBefore : int = ceili(valueBefore * TouchNumberOfEnemies)
	var touchNumberOfEnemiesNow : int = ceili(valueNow * TouchNumberOfEnemies)
	var change : int = touchNumberOfEnemiesNow - touchNumberOfEnemiesBefore
	_remainingEnemies += change

func _exit_tree():
	if _effectPrototype != null:
		for effectPrototype in _effectPrototype:
			if effectPrototype != null:
				effectPrototype.queue_free()
		_effectPrototype.clear()

func _process(delta):
	super(delta)

	if _gameObject == null:
		return
	if _currentState == SummonInput.States.Attacking:
		tryToTouchTargetAndApplyEffect()
	elif _currentState == SummonInput.States.Idle:
		findAndTargetNewEnemy()
		

func tryToTouchTargetAndApplyEffect():
	var myPos : Vector2 = get_gameobjectWorldPosition()
	var targetPos : Vector2 = _currentAttackTargetPosProvider.get_worldPosition()
	if myPos.distance_squared_to(targetPos) < TouchDistanceSquared:
		# we are in range! apply the effect and move on to the next...
		var mySource : GameObject = _gameObject.get_rootSourceGameObject()
		for n in range(AppliesOnToch):
			_currentAttackTarget.add_effect(_effectPrototype.pick_random(), mySource)
		switchState(SummonInput.States.Idle)
		_prevAttackTarget = _currentAttackTarget
		_currentAttackTarget = null
		_remainingEnemies -= 1
		if _remainingEnemies <= 0:
			var killedSignaller = _gameObject.getChildNodeWithSignal("Killed")
			killedSignaller.emit_signal("Killed", null)
			_gameObject.queue_free()
			_gameObject = null



func findAndTargetNewEnemy():
	_currentAttackTarget = null
	var numIterations : int = 0
	while numIterations < 5:
		numIterations+=1
		var randomLocator : Locator = Global.World.Locators.get_random_locator_in_pool("Enemies")
		if randomLocator == null:
			# there are no locators in this pool at all, so we give up directly:
			return
		_currentAttackTarget = Global.get_gameObject_in_parents(randomLocator)
		if _currentAttackTarget == null or _currentAttackTarget == _prevAttackTarget:
			continue
		attackTarget(_currentAttackTarget)
		return

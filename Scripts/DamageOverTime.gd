extends GameObjectComponent

@export var ApplyDamageCadenceInSeconds : float = 1
@export var DamageAmount : int = 1
@export var Duration : float = 5
@export var DamageCategories : Array[String] = ["Fire"]

var _healthComp : Node
var _remainingTimeToNextDamage : float
var _runningTime : float = 0

func _ready():
	initGameObjectComponent()
	_healthComp = _gameObject.getChildNodeWithMethod("applyDamage")
	# the first damage will not be applied right away, we'll wait the cadence
	_remainingTimeToNextDamage = ApplyDamageCadenceInSeconds

func _process(delta):
	if _runningTime > Duration:
		queue_free()
		return
	_runningTime += delta
		
	if not _healthComp:
		return
	
	_remainingTimeToNextDamage -= delta
	while _remainingTimeToNextDamage < 0:
		_remainingTimeToNextDamage += ApplyDamageCadenceInSeconds
		var damageReturn = _healthComp.applyDamage(DamageAmount, null)
		var externalSource : GameObject = get_externalSource()
		if externalSource != null and is_instance_valid(externalSource):
			externalSource.injectEmitSignal("DamageApplied", [DamageCategories, DamageAmount, damageReturn, _gameObject, false])

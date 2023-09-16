extends GameObjectComponent2D

const PIXELS_PER_METER : int = 16
const DAMAGE_CATEGORIES_FOR_EFFECT_KILL : Array[String] = ["Burn", "Electrify"]

var _lastFramePos : Vector2
var _distanceWalked : float
var _timeTakenForLastMeter : float
var _noDamageForTime : float
var _currentNumberOfBurningEnemies : int = 0
var _currentSecondsPassed : float = 0
var _currentMaxHealth : int = 0
var _ignoreNextDamage : bool = false

func _ready():
	initGameObjectComponent()
	_lastFramePos = global_position
	if _gameObject != null:
		_gameObject.connectToSignal("HealthChanged", healthChanged)
		_gameObject.connectToSignal("MaxHealthChanged", maxHealthChanged)
		_gameObject.connectToSignal("DefenseChanged", defenseChanged)
		_gameObject.connectToSignal("Regeneration", regenerationWasApplied)
		_gameObject.connectToSignal("DamageApplied", damageWasApplied)
		_gameObject.connectToSignal("MaxSpeedUpdated", maxSpeedWasUpdated)
		_gameObject.connectToSignal("BlockedDamage", blockedDamage)


func healthChanged(currentHealth, change):
	if change > 0:
		Global.QuestPool.notify_health_recovered(change)
	if change < 0:
		if _ignoreNextDamage:
			_ignoreNextDamage = false
			return
		Global.QuestPool.notify_damage_taken(-change)
		_noDamageForTime = 0


func maxHealthChanged(newMaxHealth, change):
	_currentMaxHealth = newMaxHealth
	Global.QuestPool.notify_max_health_changed(change, newMaxHealth)
	if change < 0: _ignoreNextDamage = true


func blockedDamage(amount:int):
	Global.QuestPool.notify_damage_blocked(amount)
	

func defenseChanged(newDefense, change):
	Global.QuestPool.notify_defense_changed(change, newDefense)


func regenerationWasApplied(amount:int):
	Global.QuestPool.notify_health_regenerated(amount)


func damageWasApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, _isCritical:bool):
	for effectCatName in DAMAGE_CATEGORIES_FOR_EFFECT_KILL:
		if categories.has(effectCatName):
			Global.QuestPool.notify_effect_kill(effectCatName)
			break			
	if categories.has("Fire"):
		Global.QuestPool.notify_fire_damage(damageAmount)
	if categories.has("Lightning"):
		Global.QuestPool.notify_lightning_damage(damageAmount)
	if categories.has("Magic"):
		Global.QuestPool.notify_magic_damage(damageAmount)
	if categories.has("Summon"):
		Global.QuestPool.notify_summon_damage(damageAmount)
	if categories.has("Physical"):
		Global.QuestPool.notify_physical_damage(damageAmount)
	if categories.has("Ice"):
		Global.QuestPool.notify_ice_damage(damageAmount)


func maxSpeedWasUpdated(newSpeed:float):
	Global.QuestPool.notify_player_speed(newSpeed)


func _process(delta):
	_ignoreNextDamage = false
	var currentSecondsPassed := floori(_currentSecondsPassed)
	_currentSecondsPassed += delta

	if floori(_currentSecondsPassed) != currentSecondsPassed:
		Global.QuestPool.notify_current_max_health(_currentMaxHealth)

	var noDamageTimeInt := floori(_noDamageForTime)
	_noDamageForTime += delta
	if floori(_noDamageForTime) != noDamageTimeInt:
		# we trigger the no damage signal every second
		Global.QuestPool.notify_player_undamaged(_noDamageForTime)

	_timeTakenForLastMeter += delta
	if global_position == _lastFramePos:
		return
	var distWalkedSinceLastFrame := _lastFramePos.distance_to(global_position)
	_distanceWalked += distWalkedSinceLastFrame
	if _distanceWalked > PIXELS_PER_METER:
		Global.QuestPool.notify_player_walked(_timeTakenForLastMeter)
		_timeTakenForLastMeter = 0
		_distanceWalked -= PIXELS_PER_METER
	_lastFramePos = global_position

	var burningEnemiesBefore = _currentNumberOfBurningEnemies
	# we'll count the number of burning enemies via the group that the burn effect is in.
	_currentNumberOfBurningEnemies = get_tree().get_nodes_in_group("BurnEffect").size()
	if burningEnemiesBefore != _currentNumberOfBurningEnemies:
		Global.QuestPool.notify_enemies_burning(_currentNumberOfBurningEnemies)

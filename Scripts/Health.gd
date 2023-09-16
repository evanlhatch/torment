extends GameObjectComponent
class_name Health

@export var StartHealth : int = 100
@export var RankHealthModifierMethod : String = ""
@export var DestroyWhenKilled : bool = true
@export var InvincibilityTimeWhenDamaged : float = 0
@export var InitialInvincibilityTime : float = 0.2
@export var BaseChanceToBlock : float = 0.0
@export var BaseBlockValue : int = 0
@export var InterruptPiercing : bool = false
@export var ShowDamageNumbers : bool = true
@export var ShowHealNumbers : bool = false
@export var AddsToKillCount : bool = false
@export var KillAfterNumberOfHits : int = -1
@export var BaseDamageFactor : float = 1.0
@export var HealOnLevelUp : int = 0
@export var BaseRegenerationPerSecond : float = 0.0
@export var BaseDefense : int = 0
@export var RankDefenseModifierMethod : String = ""


signal Killed(byNode:Node)
signal ReceivedDamage(amount:int, byNode:Node, weapon_index:int)
signal OnInvincibilityStateChanged(isInvincible:bool)
signal HealthChanged(amount:int, change:int)
signal DefenseChanged(amount:int, change:int)
signal MaxHealthChanged(amount:int, change:int)
signal Regeneration(amount:int)
signal BlockedDamage(amount:int)
signal OnHitTaken(invincible:bool, blocked:bool, byNode:Node)
signal InvincibilityNegatedDamage(amount:int, byNode:Node)
signal DeathCheated
signal Instakilled(byNode:Node)

const CRIT_COLOR = Color(1.0, 0.4, 0.3)
const BURN_COLOR = Color(1.0, 0.7, 0.0)
const ELECTRIFY_COLOR = Color(0.4, 0.7, 1.0)
const FROST_COLOR = Color(0.5, 0.5, 0.9)

enum DamageEffectType {
	None, Burn, Electrify, Frost
}

var _currentHealth:int
var _remainingInvincibility:float
var _damageTakenBeforeInvincibility:float
var _hitCount:int
var _regenBucket : float

var _modifiedMaxHealth
var _modifiedChanceToBlock
var _modifiedBlockValue
var _modifiedDamageFactor
var _modifiedRegeneration
var _modifiedDamageFromEffectsFactor
var _modifiedDefense

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedMaxHealth,
		_modifiedChanceToBlock,
		_modifiedBlockValue,
		_modifiedDamageFactor,
		_modifiedRegeneration,
		_modifiedDamageFromEffectsFactor,
		_modifiedDefense
	]
func is_character_base_node() -> bool : return true

var _cheatDeathCallableStack : Array[Callable] = []

func addCheatDeathCallable(callable:Callable, addToFront:bool=false):
	var i = _cheatDeathCallableStack.find(callable)
	if i == -1:
		if addToFront:
			_cheatDeathCallableStack.push_front(callable)
		else:
			_cheatDeathCallableStack.append(callable)

func removeCheatDeathCallable(callable:Callable):
	var i = _cheatDeathCallableStack.find(callable)
	if i != -1:
		_cheatDeathCallableStack.remove_at(i)

func _ready():
	initGameObjectComponent()
	_remainingInvincibility = InitialInvincibilityTime
	_damageTakenBeforeInvincibility = Global.MAX_VALUE
	_modifiedChanceToBlock = createModifiedFloatValue(BaseChanceToBlock, "BlockChance")
	_modifiedBlockValue = createModifiedIntValue(BaseBlockValue, "BlockValue")
	_modifiedDamageFactor = createModifiedFloatValue(BaseDamageFactor, "DamageFactor")
	_modifiedDamageFromEffectsFactor = createModifiedFloatValue(BaseDamageFactor, "DamageFromEffectsFactor")

	if not RankHealthModifierMethod.is_empty() and Global.World.TormentRank.has_method(RankHealthModifierMethod):
		_modifiedMaxHealth = createModifiedIntValue(
			StartHealth * Global.World.TormentRank.call(RankHealthModifierMethod), "MaxHealth")
	else:
		_modifiedMaxHealth = createModifiedIntValue(StartHealth, "MaxHealth")

	if not RankDefenseModifierMethod.is_empty() and Global.World.TormentRank.has_method(RankDefenseModifierMethod):
		_modifiedDefense = createModifiedIntValue(
			BaseDefense + Global.World.TormentRank.call(RankDefenseModifierMethod), "Defense")
	else:
		_modifiedDefense = createModifiedIntValue(BaseDefense, "Defense")

	_modifiedRegeneration = createModifiedFloatValue(BaseRegenerationPerSecond, "HealthRegen")
	_modifiedRegeneration.connect("ValueUpdated", checkAndUpdateNeedsProcess)
	_modifiedMaxHealth.connect("ValueUpdated", maxHealthWasUpdated)
	_modifiedDefense.connect("ValueUpdated", defenseWasUpdated)
	resetToMaxHealth()
	checkAndUpdateNeedsProcess()
	Global.connect("WorldReady", _on_world_ready)

func _on_world_ready():
	Global.World.connect("ExperienceThresholdReached", on_level_up)

func _exit_tree():
	_allModifiedValues.clear()
	_modifiedMaxHealth = null
	_modifiedChanceToBlock = null
	_modifiedBlockValue = null
	_modifiedDamageFactor = null
	_modifiedRegeneration = null
	_modifiedDamageFromEffectsFactor = null
	_modifiedDefense = null

func resetToMaxHealth():
	# no callbacks or anything, this is for initialization!
	_currentHealth = _modifiedMaxHealth.Value()

func checkAndUpdateNeedsProcess(_nop1:float=0, _nop2:float=0):
	if needsProcess(): process_mode = Node.PROCESS_MODE_PAUSABLE
	else: process_mode = Node.PROCESS_MODE_DISABLED

func maxHealthWasUpdated(oldHealth:int, newMaxHealth:int):
	var healthDelta : int = 0
	if _currentHealth > newMaxHealth:
		healthDelta = newMaxHealth - _currentHealth
		_currentHealth = newMaxHealth
	# we do not add to the current health here (the modifier does
	# that, when necessary), but we still have to emit the signal!
	MaxHealthChanged.emit(newMaxHealth, newMaxHealth-oldHealth)
	HealthChanged.emit(_currentHealth, healthDelta)

func defenseWasUpdated(oldDefense:int, newDefense:int):
	var defenseDelta : int = newDefense - oldDefense
	DefenseChanged.emit(newDefense, defenseDelta)

func is_invincible() -> bool: return _remainingInvincibility > 0.0

func is_fullHealth() -> bool: return _currentHealth == _modifiedMaxHealth.Value()

func is_dead() -> bool: return _currentHealth <= 0

func get_healthPercentage() -> float: return float(_currentHealth) / float(_modifiedMaxHealth.Value())

func get_health() -> int: return _currentHealth

func get_maxHealth() -> int: return max(1, _modifiedMaxHealth.Value())
func get_maxHealthBase() -> int: return StartHealth

func get_regeneration() -> float: return _modifiedRegeneration.Value()

func get_baseChanceToBlock() -> float: return BaseChanceToBlock

func get_baseBaseBlockValue() -> int: return BaseBlockValue

func get_totalChanceToBlock(damage_amount) -> float:
	var block_fraction : float = float(_modifiedBlockValue.Value()) / float(damage_amount)
	return minf(1.0, minf(block_fraction * 0.5, pow(block_fraction, 0.5) * 0.5) + _modifiedChanceToBlock.Value())

func add_health(add:int):
	if add < 0:
		printerr("add_health only supports positive numbers, use applyDamage instead...")
		return
	var actualAdd := add
	if _currentHealth + add > get_maxHealth():
		actualAdd = get_maxHealth() - _currentHealth
		Logging.log_heal(_gameObject.name, actualAdd)
		_currentHealth = get_maxHealth()
	else:
		Logging.log_heal(_gameObject.name, add)
		_currentHealth += add

	if actualAdd > 0:
		HealthChanged.emit(_currentHealth, actualAdd)

	if ShowHealNumbers and _positionProvider:
		Fx.show_text_indicator(
			_positionProvider.get_worldPosition() + Vector2.UP * 20.0,
			str(add), 2, 1.5, Color.GREEN)

func reduce_health(reduce:int):
	if reduce < 0:
		printerr("reduce_health only supports positive numbers, use applyDamage instead...")
		return
	var actualReduce := reduce
	if _currentHealth - reduce < 0:
		actualReduce = _currentHealth - 1
	_currentHealth -= reduce
	if actualReduce > 0:
		HealthChanged.emit(_currentHealth, -actualReduce)

func needsProcess() -> bool:
	return _remainingInvincibility > 0 or get_regeneration() > 0

func _process(delta):
#ifdef PROFILING
#	updateHealth(delta)
#
#func updateHealth(delta):
#endif
	if get_regeneration() > 0.0:
		_regenBucket += delta * get_regeneration()
		if _regenBucket >= 1.0:
			if _currentHealth < _modifiedMaxHealth.Value():
				add_health(int(floor(_regenBucket)))
				Regeneration.emit(int(floor(_regenBucket)))
			_regenBucket = fmod(_regenBucket, 1.0)
	if is_invincible():
		_remainingInvincibility -= delta
		if _remainingInvincibility <= 0:
			_remainingInvincibility = 0
			_damageTakenBeforeInvincibility = 0
			OnInvincibilityStateChanged.emit(false)
			checkAndUpdateNeedsProcess()


const DEF_BASE_COEFF : float = 40.0
const DEF_BASE_INV_COEFF : float = 1.0 / DEF_BASE_COEFF
const DEF_FACTOR_COEFF : float = 0.4
func apply_defense_to_damage_value(damageAmount:int) -> int:
	var def = _modifiedDefense.Value()
	var part_1 = 1.0 / ((abs(def) + DEF_BASE_COEFF) * DEF_BASE_INV_COEFF)
	if def < 0:
		part_1 = 2-part_1
	part_1 = part_1 * (1.0 - DEF_FACTOR_COEFF)
	var part_2 = max(0, (1.0 - (def / 100.0)) * DEF_FACTOR_COEFF)
	return max(1, int(round(damageAmount * (part_1 + part_2))))


# applyDamage returns an Array with two Elements: [Global.ApplyDamageResult, ActualDamage]
# NOTE: When ApplyDamageResult is "Killed", then there will be a third element: OverDamage
func applyDamage(
	damageAmount:int,
	byNode:Node,
	critical:bool = false,
	weapon_index:int = -1,
	unblockable:bool = false,
	damageEffectType:DamageEffectType = DamageEffectType.None) -> Array:
	if is_invincible() and damageAmount <= _damageTakenBeforeInvincibility:
		InvincibilityNegatedDamage.emit(damageAmount, byNode)
		OnHitTaken.emit(true, false, byNode)
		return [Global.ApplyDamageResult.Invincible, 0]
	if damageAmount < 0:
		printerr("the damage amount in applyDamage has to be a positive value!")
		return [Global.ApplyDamageResult.Invalid, 0]
	if _currentHealth <= 0:
		return [Global.ApplyDamageResult.Invalid, 0]

	if not unblockable && randf() <= get_totalChanceToBlock(damageAmount):
		if InvincibilityTimeWhenDamaged > 0:
			_damageTakenBeforeInvincibility = damageAmount
		if _positionProvider:
			Logging.log_block_event(byNode, _gameObject)
			Fx.show_text_indicator( # show BLOCK icon
				_positionProvider.get_worldPosition() + Vector2.UP * 32.0, "", 1, 2.0)
			Fx.show_block(_positionProvider.get_worldPosition()+ Vector2.UP * 16.0)
		OnHitTaken.emit(false, true, byNode)
		BlockedDamage.emit(damageAmount)
		set_invincible_after_damage()
		return [Global.ApplyDamageResult.Blocked, 0]

	var scaledDamageAmount : int = damageAmount
	if damageEffectType == DamageEffectType.None:
		scaledDamageAmount = roundi(damageAmount * get_totalDamageFactor())
	else:
		scaledDamageAmount = roundi(damageAmount * _modifiedDamageFromEffectsFactor.Value())
	scaledDamageAmount = apply_defense_to_damage_value(scaledDamageAmount)
	if ShowDamageNumbers and _positionProvider:
		if critical:
			Fx.show_text_indicator(
				_positionProvider.get_worldPosition() + Vector2.UP * 20.0,
				str(scaledDamageAmount), 0, 2.0, CRIT_COLOR)
		else:
			if damageEffectType == DamageEffectType.Burn:
				Fx.show_text_indicator(
					_positionProvider.get_worldPosition() + Vector2.UP * 20.0,
					str(scaledDamageAmount), 4, 1.0, BURN_COLOR)
			elif damageEffectType == DamageEffectType.Electrify:
				Fx.show_text_indicator(
					_positionProvider.get_worldPosition() + Vector2.UP * 20.0,
					str(scaledDamageAmount), 3, 1.0, ELECTRIFY_COLOR)
			elif damageEffectType == DamageEffectType.Frost:
				Fx.show_text_indicator(
					_positionProvider.get_worldPosition() + Vector2.UP * 20.0,
					str(scaledDamageAmount), 6, 1.0, FROST_COLOR)
			else:
				Fx.show_text_indicator(
					_positionProvider.get_worldPosition() + Vector2.UP * 20.0,
					str(scaledDamageAmount))

	Logging.log_damage_event(byNode, _gameObject, scaledDamageAmount, critical, weapon_index)

	# We want incoming damage to pierce through invincibility
	# when it's higher then the damage that triggered the current invincibility
	# state. If this case applies we want only the remaining damage to be received.
	# Reason: enemies which deal more damage should take precedence before
	# weaker enemies. This is our way of dealing with this.
	var actualDamageAmount = clamp(scaledDamageAmount - _damageTakenBeforeInvincibility, 0, Global.MAX_VALUE)
	if InvincibilityTimeWhenDamaged > 0:
		_damageTakenBeforeInvincibility = damageAmount

	_hitCount += 1

	var killedByLackOfHealth : bool = actualDamageAmount >= _currentHealth
	var killedByHitCount : bool = KillAfterNumberOfHits > 0 and _hitCount >= KillAfterNumberOfHits
	if killedByLackOfHealth or killedByHitCount:
		Logging.log_kill_event(byNode, _gameObject)
		var overkillDamage = max(0, actualDamageAmount - _currentHealth)
		if killedByLackOfHealth:
			actualDamageAmount = _currentHealth
		if killedByHitCount:
			# we can't really name a sensible actualDamage amount when
			# the object simply gets destroyed after a certain amount of
			# hits. (example: breakables. they have a huge amount of health)
			actualDamageAmount = 0
		_currentHealth = 0
		OnHitTaken.emit(false, false, byNode)
		ReceivedDamage.emit(actualDamageAmount, byNode, weapon_index)
		HealthChanged.emit(_currentHealth, -actualDamageAmount)
		if _cheatDeathCallableStack.size() > 0:
			var currentDeathCheatCallable : Callable = _cheatDeathCallableStack.back()
			currentDeathCheatCallable.call()
			DeathCheated.emit()
			return [Global.ApplyDamageResult.CheatedDeath, 0]
		Killed.emit(byNode)
		if AddsToKillCount:
			Global.World.TriggerDamageEvent(
				_gameObject,
				byNode,
				actualDamageAmount,
				scaledDamageAmount,
				critical,
				weapon_index)
			Global.World.TriggerDeathEvent(_gameObject, byNode)

#ifdef USE_STATISTICS
#		Statistics.add_damage_event(byNode, _gameObject, actualDamageAmount, critical, weapon_index)
#endif
		Stats.AddDamageEvent(byNode, _gameObject, actualDamageAmount, weapon_index)

		if DestroyWhenKilled:
			_gameObject.queue_free()
		return [Global.ApplyDamageResult.Killed, actualDamageAmount, overkillDamage]

	set_invincible_after_damage()

	_currentHealth -= actualDamageAmount
	OnHitTaken.emit(false, false, byNode)
	ReceivedDamage.emit(actualDamageAmount, byNode, weapon_index)
	if AddsToKillCount:
		Global.World.TriggerDamageEvent(
			_gameObject,
			byNode,
			actualDamageAmount,
			scaledDamageAmount,
			critical,
			weapon_index)
	HealthChanged.emit(_currentHealth, -actualDamageAmount)
#ifdef USE_STATISTICS
#	Statistics.add_damage_event(byNode, _gameObject, actualDamageAmount, critical, weapon_index)
#endif
	Stats.AddDamageEvent(byNode, _gameObject, actualDamageAmount, weapon_index)
	if InterruptPiercing:
		return [Global.ApplyDamageResult.Blocked, actualDamageAmount]
	return [Global.ApplyDamageResult.DamagedButNotKilled, actualDamageAmount]

func set_invincible_after_damage():
	if InvincibilityTimeWhenDamaged > 0:
		if !is_invincible():
			_remainingInvincibility = InvincibilityTimeWhenDamaged
			process_mode = Node.PROCESS_MODE_PAUSABLE
			OnInvincibilityStateChanged.emit()
		else: _remainingInvincibility = max(_remainingInvincibility, InvincibilityTimeWhenDamaged)

func setInvincibleForTime(invincibleDuration:float):
	if invincibleDuration > 0:
		_remainingInvincibility = max(_remainingInvincibility, invincibleDuration)
		# so that no damage is taken for the invincibility time, we also have to set this!
		_damageTakenBeforeInvincibility = 99999
		process_mode = Node.PROCESS_MODE_PAUSABLE
	else:
		# when we get a duration less than 0, we will actually reset the invincibility
		_remainingInvincibility = 0
		_damageTakenBeforeInvincibility = 0
		if needsProcess(): process_mode = Node.PROCESS_MODE_PAUSABLE
		else: process_mode = Node.PROCESS_MODE_DISABLED

func get_totalDamageFactor() -> float:
	return _modifiedDamageFactor.Value()

func on_level_up():
	if HealOnLevelUp > 0:
		add_health(HealOnLevelUp)

# Kills the character/monster immediately without triggering item drops or followup spawns
func instakill():
	Instakilled.emit(null)
	_gameObject.queue_free()

func force_health_update_signals():
	MaxHealthChanged.emit(get_maxHealth(), 0)
	HealthChanged.emit(get_health(), 0)

extends EffectBase

@export var Duration : float = 3.0
@export var BaseDamage : int = 1
@export var BaseRange : int = 1
@export var BonusRangePerDamageReceived : float = 1
@export var MaxStacks : int = 5
@export var IceWaveLocatorPoolIdentifier : String = "Enemies"
@export var ChanceToApplyFrostOnIceWave : float = 0
@export var FreezeIndicatorPath : NodePath
@export var ModifierCategories : Array[String] = ["Frost", "Elemental"]
@export var DamageCategories : Array[String] = ["Frost"]
@export var IceWaveAudioFX : AudioFXResource

@export_group("Visual Settings")
@export var IcewaveTexture : Texture2D
@export var IcewaveColor : Color = Color.WHITE

@export_group("internal state")
@export var _weapon_index : int = -1


var _freeze_indicator : Node

var _remove_timer : float
var _num_stacks : int
var _largest_single_damage_received : int = 0

func get_effectID() -> String:
	return "FROST"

func add_additional_effect(additionalEffectNode:EffectBase) -> void:
	if _num_stacks >= MaxStacks:
		emit_ice_wave(null)
	else:
		_num_stacks += 1
	_remove_timer = Duration
	Global.QuestPool.notify_effect_stacks(_num_stacks, _weapon_index)


func _enter_tree():
	# not sure why this sometimes is false on the FrostEffect
	# this doesn't seem to happen on other elemental effects
	if has_node(FreezeIndicatorPath):
		_freeze_indicator = get_node(FreezeIndicatorPath)

	initGameObjectComponent()
	if _gameObject:
		_gameObject.connectToSignal("ReceivedDamage", damage_was_received)
		_gameObject.connectToSignal("Killed", was_killed)
		var position_component = _gameObject.getChildNodeWithMethod("get_worldPosition")
		if position_component != null and is_instance_valid(_freeze_indicator):
			remove_child(_freeze_indicator)
			position_component.add_child(_freeze_indicator)
			_freeze_indicator.position = Vector2.ZERO
			_freeze_indicator.visible = true
		# initialize the effect even when it is the first one:
		add_additional_effect(self)


func _exit_tree():
	_gameObject = null
	if is_instance_valid(_freeze_indicator) and _freeze_indicator.get_parent() != self:
		_freeze_indicator.queue_free()

func damage_was_received(amount:int, byNode:Node, weapon_index:int):
	if amount > _largest_single_damage_received:
		_largest_single_damage_received = amount

func was_killed(byNode:Node):
	emit_ice_wave(byNode)

func _process(delta):
#ifdef PROFILING
#	updateBurnEffect(delta)
#
#func updateBurnEffect(delta):
#endif
	if _gameObject == null: return

	_remove_timer -= delta
	if _remove_timer <= 0.0:
		emit_ice_wave(null, 0.5)
		queue_free()


func get_totalRange() -> float:
	return BaseRange + _largest_single_damage_received / BonusRangePerDamageReceived

func get_totalDamage() -> int:
	return _num_stacks * BaseDamage

func emit_ice_wave(excludeNode:Node, damageMultiplier:float = 1.0):
	var mySource : GameObject = get_externalSource()
	if not is_instance_valid(mySource): return

	var emitPosition = get_gameobjectWorldPosition()
	var hits : Array = Global.World.Locators.get_gameobjects_in_circle(IceWaveLocatorPoolIdentifier, emitPosition, float(get_totalRange()))

	var damage : int = mySource.calculateModifiedValue("EffectStrength", get_totalDamage(), ModifierCategories) * damageMultiplier
	var chanceToApplyFrostWave : float = mySource.calculateModifiedValue("SelfApplyEffectChance", ChanceToApplyFrostOnIceWave, ModifierCategories)
	for hitGO in hits:
		if hitGO == _gameObject: continue
		if hitGO == excludeNode: continue
		var healthComp = hitGO.getChildNodeWithMethod("applyDamage")
		if not healthComp: continue
		if healthComp.is_dead(): continue
		var result = healthComp.applyDamage(damage, mySource, false, _weapon_index, true, Health.DamageEffectType.Frost)
		if result[0] == Global.ApplyDamageResult.Killed:
			Global.QuestPool.notify_frost_kill()
		Global.QuestPool.notify_frost_damage(result[1])

		var chance := chanceToApplyFrostWave
		while chance > 0:
			# when the probability is over 1, we don't roll the dice!
			if chance < 1 and randf() > chance:
				break
			chance -= 1
			# should be possible to just use ourself as an effect prototype!
			hitGO.add_effect(self, mySource)

	Fx.show_cone_wave(
		emitPosition,
		Vector2.UP,
		get_totalRange(), 360,
		3.0, 1.0, IcewaveColor, Callable(),
		IcewaveTexture, 1.0,
		true)
	if IceWaveAudioFX:
		FxAudioPlayer.play_sound_2D(IceWaveAudioFX, emitPosition, false, false, 0.0)


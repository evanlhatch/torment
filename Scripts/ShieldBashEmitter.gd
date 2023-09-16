extends GameObjectComponent

@export var AttackAnimationIndex : int = 0

@export_group("Emission Parameters")
@export var EmitSpeed : float = 0.3
@export var EmitRange : int = 110
@export var EmitAngle : float = 90
@export var EmitDelay : float = 0.3
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]
@export var ModifierCategories : Array[String] = ["Physical"]
@export var DamageCategories : Array[String] = ["ShieldBash"]

@export_group("Visual Fx Parameters")
@export var EffectPositionOffset : Vector2
@export var EffectColor : Color
@export var EffectTexture : Texture2D

@export_group("Damage and Knockback Parameters")
@export var BlockValueDamageScaling : float = 0.25
@export var KnockbackBasePower : float = 0.1
@export var KnockbackForce : float = 150

@export_group("Info Area Parameters")
@export var Icon : Texture2D
@export var InfoName : String
@export_multiline var TooltipText : String

@export_group("Internal State")
@export var _weapon_index : int = -1

var _health
var _modifiedBlockValue
var _modifiedDamage
var _modifiedRange
var _modifiedAngle
var _modifiedSpeed
var _modifiedKnockbackPower : ModifiedFloatValue
var _modifiedKnockbackForce : ModifiedFloatValue

var _emitTimer : float
var _localDelayTimerNode : Timer

func get_modified_values() -> Array:
	return [
		_modifiedDamage,
		_modifiedRange,
		_modifiedAngle,
		_modifiedSpeed,
		_modifiedKnockbackPower,
		_modifiedKnockbackForce
	]
func is_character_base_node() -> bool : return true

signal AttackTriggered(attack_index:int)
signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _directionProvider : Node
var _audio : AudioStreamPlayer
var _audio_default_pitch : float


func _ready():
	initGameObjectComponent()
	_localDelayTimerNode = Timer.new()
	add_child(_localDelayTimerNode)
	_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")
	_health = _gameObject.getChildNodeWithProperty("_modifiedBlockValue")

	_modifiedDamage = ModifiedFloatValue.new()
	_modifiedDamage.initAsMultiplicativeOnly("Damage", _gameObject, Callable())
	_modifiedRange = createModifiedIntValue(EmitRange, "Range")
	_modifiedAngle = createModifiedFloatValue(EmitAngle, "Area")
	_modifiedSpeed = createModifiedFloatValue(EmitSpeed, "AttackSpeed")
	_modifiedKnockbackPower = createModifiedFloatValue(KnockbackBasePower, "KnockbackPower")
	_modifiedKnockbackForce = createModifiedFloatValue(KnockbackForce, "Force")
	applyModifierCategories()

	_emitTimer = 1.0 / _modifiedSpeed.Value()
	if has_node("Audio"):
		_audio = $Audio
		_audio_default_pitch = _audio.pitch_scale


func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedKnockbackPower.setModifierCategories(ModifierCategories)
	_modifiedKnockbackForce.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)
	_modifiedAngle.setModifierCategories(ModifierCategories)
	_modifiedSpeed.setModifierCategories(ModifierCategories)


func _process(delta):
	_emitTimer -= delta
	while _emitTimer <= 0:
		emit_with_delay_timer(_localDelayTimerNode)
		_emitTimer += 1.0 / get_totalAttackSpeed()


var _tempHitsArray : Array[Locator] = []
func emit_with_delay_timer(delayTimer:Timer, crit_guarantee:bool = false) -> void:
	AttackTriggered.emit(AttackAnimationIndex)

	var waitTime = (EmitDelay / get_attackSpeedFactor()) * 0.5
	delayTimer.start(waitTime); await delayTimer.timeout
	play_sound()
	delayTimer.start(waitTime); await delayTimer.timeout

	if _directionProvider:
		var emitDir = _directionProvider.get_aimDirection()
		var emitPosition = get_gameobjectWorldPosition()

		Fx.show_cone_wave(
			emitPosition + EffectPositionOffset,
			emitDir, get_totalRange(), get_totalAngle(), 1.5, 1.0,
			EffectColor, Callable(), EffectTexture, 1.0, true)

		_tempHitsArray.clear()
		for hitPoolName in HitLocatorPools:
			_tempHitsArray.append_array(Global.World.Locators.get_locators_in_circle(hitPoolName, emitPosition, get_totalRange()))
		var hitGameObjects = []
		for hitLocator in _tempHitsArray:
			var hitGameObject: GameObject = Global.get_gameObject_in_parents(hitLocator)
			if hitGameObject == null:
				continue
			var hitPositionProvider = hitGameObject.getChildNodeWithMethod("get_worldPosition")
			if not hitPositionProvider:
				continue
			var hitPosition : Vector2 = hitPositionProvider.get_worldPosition()
			var hitDir : Vector2 = (hitPosition - emitPosition).normalized()

			var distSquared : float = emitPosition.distance_squared_to(hitPosition)
			# is the position in the hit cone?
			var angleToPosition : float = abs(rad_to_deg(hitDir.angle_to(emitDir)))
			if angleToPosition < get_totalAngle() * 0.5:
				hitGameObjects.append(hitGameObject)
				continue
			# is the circle of the locator in the hit cone?
			# this is the angle of the isosceles triangle composed of
			# the locator radius (as c) and the distance (as a and b). formula of the angle:
			# γ = arccos( ( 2 * a² - c² ) / (2a²) )
			var locatorCircleDiameterSquared : float = hitLocator.Radius * 2.0
			locatorCircleDiameterSquared *= locatorCircleDiameterSquared
			var angleOfLocatorRadius : float = acos(
				(2 * distSquared - locatorCircleDiameterSquared) /
				(2 * distSquared))
			if angleOfLocatorRadius != NAN:
				# divided by 2, because we only want the circle and not the diameter
				angleOfLocatorRadius = rad_to_deg(angleOfLocatorRadius) / 2
				if (angleToPosition - angleOfLocatorRadius) < get_totalAngle() * 0.5:
					hitGameObjects.append(hitGameObject)
					continue

		hitGameObjects.sort_custom(distance_sort)

		for hitGO in hitGameObjects:
			var healthComp = hitGO.getChildNodeWithMethod("applyDamage")
			if not healthComp:
				continue # we can't do damage :(

			var dmg = 0
			var applyDamageReturn = 0
			dmg = get_totalDamage()
			applyDamageReturn = healthComp.applyDamage(dmg, get_parent(), false, _weapon_index)
			DamageApplied.emit(DamageCategories, dmg, applyDamageReturn, hitGO, false)

			Forces.TryToApplyKnockback(
				hitGO,
				_modifiedKnockbackPower.Value(),
				emitDir, # is normalized in-function
				_modifiedKnockbackForce.Value())


func play_sound():
	if _audio != null:
		_audio.pitch_scale = _audio_default_pitch + randf_range(-0.1, 0.1)
		_audio.play()

func get_totalDamage() -> int:
		return _modifiedDamage.Value() * _health._modifiedBlockValue.Value() * BlockValueDamageScaling
func get_totalRange() -> float: return _modifiedRange.Value()
func get_totalAngle() -> float: return _modifiedAngle.Value()
func get_totalAttackSpeed() -> float: return _modifiedSpeed.Value()
func get_attackSpeedFactor() -> float:
	return _modifiedSpeed.Value() / EmitSpeed

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return _emitTimer * EmitSpeed

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return InfoName

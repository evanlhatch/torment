extends GameObjectComponent

@export var EffectNode : PackedScene
@export var BaseBurnChance : float = 1.0
@export var BaseRange : float = 120
@export var NotHitTimeChanceMultiplier : float = 2
@export var NotHitTimeRangeMultiplier : float = 2
@export var TimeToNotHitForMaxMultiplier : float = 5
@export var ModifierCategories : Array[String] = ["Burn"]
@export var OnlyForDamageCategory : String = "FlameStrike"
@export var LocatorPool : String = "Enemies"

var _modifiedChance : ModifiedFloatValue
var _modifiedRange : ModifiedFloatValue
var _effectPrototype : EffectBase
var _last_hit_worldtime : float
var _modifiedChargeTime : ModifiedFloatValue
var _modifiedChanceMultiplier : ModifiedFloatValue
var _modifiedRangeMultiplier : ModifiedFloatValue

func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_effectPrototype = EffectNode.instantiate()
		_gameObject.connectToSignal("DamageApplied", damageWasApplied)
		_modifiedChance = createModifiedFloatValue(BaseBurnChance, "Burn")
		_modifiedRange = createModifiedFloatValue(BaseRange, "Range")
		_modifiedChargeTime = createModifiedFloatValue(TimeToNotHitForMaxMultiplier, "ChargeTime")
		_modifiedChanceMultiplier = createModifiedFloatValue(NotHitTimeChanceMultiplier, "ChargeMultiplier")
		_modifiedRangeMultiplier = createModifiedFloatValue(NotHitTimeRangeMultiplier, "ChargeMultiplier")
		applyModifierCategories()
		_last_hit_worldtime = Global.World.current_world_time

func _exit_tree():
	if _effectPrototype != null:
		_effectPrototype.queue_free()
		_effectPrototype = null

func applyModifierCategories():
	_modifiedChance.setModifierCategories(ModifierCategories)
	_modifiedRange.setModifierCategories(ModifierCategories)
	_modifiedChargeTime.setModifierCategories(ModifierCategories)
	_modifiedChanceMultiplier.setModifierCategories(ModifierCategories)
	_modifiedRangeMultiplier.setModifierCategories(ModifierCategories)

func damageWasApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, isCritical:bool):
	if not OnlyForDamageCategory in categories:
		return

	var positionProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	if positionProvider == null:
		return
	var position : Vector2 = positionProvider.get_worldPosition()

	var notHitTime : float = clamp(Global.World.current_world_time - _last_hit_worldtime, 0, _modifiedChargeTime.Value())
	var noHitChanceMultiplier : float = remap(notHitTime, 0, _modifiedChargeTime.Value(), 1, _modifiedChanceMultiplier.Value())
	var noHitRangeMultiplier : float = remap(notHitTime, 0, _modifiedChargeTime.Value(), 1, _modifiedRangeMultiplier.Value())

	_last_hit_worldtime = Global.World.current_world_time

	var applyChance :float = _modifiedChance.Value() * noHitChanceMultiplier
	var radius : float = _modifiedRange.Value() * noHitRangeMultiplier
	var mySource : GameObject = _gameObject.get_rootSourceGameObject()

	var hits := Global.World.Locators.get_gameobjects_in_circle(
		LocatorPool, get_gameobjectWorldPosition(), radius)

	for hit in hits:
		var chance := applyChance
		while chance > 0:
			# when the probability is over 1, we don't roll the dice!
			if chance < 1 and randf() > chance:
				break
			chance -= 1
			hit.add_effect(_effectPrototype, mySource)

	Fx.show_cone_wave(
		position,
		Vector2.RIGHT,
		radius,
		360,
		1.5,
		2.0,
		Color(1, 0.647059, 0, 0.35), # Color.ORANGE with alpha
		Callable(), null, 1.0,
		true)

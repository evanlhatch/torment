extends GameObjectComponent

class_name AreaOfEffect

@export var ApplyDamage : int
@export var RankDamageModifierMethod : String = ""
@export var ApplyNode : PackedScene
@export var TriggerHitOnChildren : bool = true
@export var TriggerHitOnParentGameObject : bool = false
@export var LocatorPoolName : String = "Player"
@export var Radius : float = 30
@export var TriggerEverySeconds : float = 0
@export var ProbabilityToApply : float = 1
@export var ModifierCategories : Array[String] = ["Summon"]
@export var DamageCategories : Array[String]
@export var UseModifiedArea : bool = false

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _remainingTimeToNextTrigger:float = 0
var _is_harmless:bool
var _modifiedDamage : ModifiedFloatValue
var _damageModifier : Modifier
var _modifiedAttackSpeed : ModifiedFloatValue
var _modifiedArea : ModifiedFloatValue

@export_group("Internal State")
# this component is normally only for enemies, but can
# also be important for the player. so it needs a
# _weapon_index (will be set by Item/Ability...)
@export var _weapon_index : int = -1


func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedAttackSpeed.setModifierCategories(ModifierCategories)
	_modifiedArea.setModifierCategories(ModifierCategories)

func _ready():
	initGameObjectComponent()
	if _gameObject == null: return
	if not RankDamageModifierMethod.is_empty():
		_damageModifier = Modifier.create("Damage", _gameObject)
		_damageModifier.setName("Torment Scaling")
		_damageModifier.setAdditiveMod(0)
		_damageModifier.setMultiplierMod(Global.World.TormentRank.get_modifier_accessor(RankDamageModifierMethod).call())
		_gameObject.triggerModifierUpdated("Damage")
	_modifiedDamage = createModifiedFloatValue(ApplyDamage, "Damage")
	var attackSpeed : float = 9999.0 if TriggerEverySeconds == 0 else 1.0 / TriggerEverySeconds
	_modifiedAttackSpeed = createModifiedFloatValue(attackSpeed, "AttackSpeed", Callable())
	_modifiedAttackSpeed.ValueUpdated.connect(attackSpeedWasChanged)
	_modifiedArea = createModifiedFloatValue(Radius, "Area")
	applyModifierCategories()

func attackSpeedWasChanged(oldValue:float, newValue:float):
	if newValue == 0:
		# this is something like a stun. so the emit timer has
		# to be very large (so it doesn't trigger). but we also
		# want to preserve the current value (so that repeated
		# stunning doesn't result in no attacks at all)
		_remainingTimeToNextTrigger = (_remainingTimeToNextTrigger + 100) * 100000
	elif oldValue == 0:
		# coming out of a stun, try to reconstruct the emit timer
		_remainingTimeToNextTrigger = (_remainingTimeToNextTrigger / 100000) - 100
		# safeguard against strange values:
		if _remainingTimeToNextTrigger < 0: _remainingTimeToNextTrigger = 0
		elif _remainingTimeToNextTrigger > 1.0 / newValue: _remainingTimeToNextTrigger = 1.0 / newValue
	else:
		# we can apply the proportional change to the
		# currently running time (but: attackSpeed is
		# inverse of time!)
		_remainingTimeToNextTrigger *= oldValue / newValue

func _enter_tree():
	if Global.is_world_ready():
		Global.World.AreaOfEffectSys.RegisterAreaOfEffect(self)

func _exit_tree():
	Global.World.AreaOfEffectSys.UnregisterAreaOfEffect(self)

func set_harmless(harmless:bool):
	_is_harmless = harmless
	if harmless: _remainingTimeToNextTrigger = 99999
	else: _remainingTimeToNextTrigger = TriggerEverySeconds

func get_modifiedRadius() -> float:
	return _modifiedArea.Value()

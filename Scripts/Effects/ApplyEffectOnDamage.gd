extends GameObjectComponent

@export var EffectNode : PackedScene
@export var ApplyChance : float = 1.0
@export var ChanceModifier : String = ""
@export var MultiplyChanceEveryTimeChecked : float = 1.0
@export var ApplyOnlyOnCritical : bool = false
@export var ApplyOnlyWhenActuallyDamaged : bool = true
@export var ModifierCategories : Array[String] = ["Burn"]
@export var OnlyForDamageCategories : Array[String] = ["DefaultWeapon"]

# we forward the damage our spawned effects do to our gameobject with this signal
signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _modifiedChance
var _modifiedOnHitChance
var _modifiedOnCritChance
var _effectPrototype : EffectBase

func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_effectPrototype = EffectNode.instantiate()
		_gameObject.connectToSignal("DamageApplied", damageWasApplied)
		_modifiedOnHitChance = createModifiedFloatValue(ApplyChance, "OnHitChance")
		_modifiedOnCritChance = createModifiedFloatValue(ApplyChance, "OnCritChance")
		if ChanceModifier != "":
			_modifiedChance = createModifiedFloatValue(ApplyChance, ChanceModifier)
		applyModifierCategories()

func _exit_tree():
	if _effectPrototype != null:
		_effectPrototype.queue_free()
		_effectPrototype = null

func applyModifierCategories():
	if _modifiedChance != null:
		_modifiedChance.setModifierCategories(ModifierCategories)
	_modifiedOnHitChance.setModifierCategories(ModifierCategories)

func damageWasApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, isCritical:bool):
	if not OnlyForDamageCategories.is_empty():
		var atLeastOneCategoryMatches : bool = false
		for damageCat in categories:
			if OnlyForDamageCategories.has(damageCat):
				atLeastOneCategoryMatches = true
				break
		if not atLeastOneCategoryMatches:
			return
	if ApplyOnlyOnCritical and not isCritical:
		return
	if ApplyOnlyWhenActuallyDamaged && applyReturn[1] <= 0:
		return
	if applyReturn[0] == Global.ApplyDamageResult.Killed and not _effectPrototype.has_method("was_killed"):
		# the target was killed in the process, no need to apply effects anymore :)
		return
	var chance : float = 0.0
	if isCritical:
		chance = _modifiedOnCritChance.Value()
	else:
		chance = _modifiedOnHitChance.Value()
	if _modifiedChance != null:
		chance += _modifiedChance.Value() - _modifiedChance.BaseValue()
	chance *= MultiplyChanceEveryTimeChecked
	MultiplyChanceEveryTimeChecked *= MultiplyChanceEveryTimeChecked

	while chance > 0:
		# when the probability is over 1, we don't roll the dice!
		if chance < 1 and randf() > chance:
			return
		chance -= 1
		var mySource : GameObject = _gameObject.get_rootSourceGameObject()
		var effectNode : Node = targetNode.add_effect(_effectPrototype, mySource)
		if effectNode.has_method("damage_was_received"):
			# this can potentionally lead to multiple damage_was_received calls for the same event.
			# the effect node has to handle that itself, when that is a problem...
			effectNode.damage_was_received(damageAmount, _gameObject, -1)

func externalDamageWasApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, isCritical:bool):
	DamageApplied.emit(damageCategories, damageAmount, applyReturn, targetNode, isCritical)

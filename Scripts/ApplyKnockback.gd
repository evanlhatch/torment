extends GameObjectComponent

@export var KnockbackBasePower : float = 0.1
@export var KnockbackForce : float = 150
@export var ApplyOnlyOnCritical : bool = false
@export var ApplyOnlyWhenActuallyDamaged : bool = true
@export var ModifierCategories : Array[String] = []
@export var OnlyForDamageCategories : Array[String] = ["DefaultWeapon"]


var _modifiedKnockbackPower : ModifiedFloatValue
var _modifiedKnockbackForce : ModifiedFloatValue
# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedKnockbackPower,
		_modifiedKnockbackForce
	]
func is_character_base_node() -> bool : return true

func _ready():
	initGameObjectComponent()
	if _gameObject != null:
		_gameObject.connectToSignal("DamageApplied", damageWasApplied)
		_modifiedKnockbackPower = createModifiedFloatValue(KnockbackBasePower, "KnockbackPower")
		_modifiedKnockbackForce = createModifiedFloatValue(KnockbackForce, "Force")
		applyModifierCategories()


func applyModifierCategories():
	_modifiedKnockbackPower.setModifierCategories(ModifierCategories)
	_modifiedKnockbackForce.setModifierCategories(ModifierCategories)


func damageWasApplied(categories:Array[String], _damageAmount:float, applyReturn:Array, targetNode:GameObject, isCritical:bool):
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
	if applyReturn[0] == Global.ApplyDamageResult.Killed :
		# the target was killed in the process, no need to apply knockback anymore :)
		return
	
	var targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")
	if targetPosProvider == null:
		return
	
	var targetPosition : Vector2 = targetPosProvider.get_worldPosition()
	var myPosition : Vector2 = get_gameobjectWorldPosition()

	Forces.TryToApplyKnockback(
		targetNode, 
		_modifiedKnockbackPower.Value(),
		targetPosition - myPosition, # is normalized in-function
		_modifiedKnockbackForce.Value())

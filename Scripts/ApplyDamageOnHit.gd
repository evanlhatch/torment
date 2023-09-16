extends GameObjectComponent

@export var DamageAmount : int
@export var Blockable : bool = true
@export var CritChance : float
@export var CritBonus : float
@export var ModifierCategories : Array[String] = ["Physical"]
@export var DamageCategories : Array[String]
@export_enum("OnHit", "CollisionStarted") var ApplyOnSignal : int = 0
@export var MaxNumberOfHits : int = 999999
@export var DamageMultPerHit : float = 1.0
@export var DamageChangePerSec : float = 0
@export var IsCharacterBaseNode : bool = false

@export_group("Internal State")
@export var _weapon_index : int

var _modifiedDamage
var _modifiedForce
var _modifiedCriticalHitChance
var _modifiedCriticalHitBonus
var _activeTime : float = 0

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedDamage,
		_modifiedForce,
		_modifiedCriticalHitChance,
		_modifiedCriticalHitBonus
	]
func is_character_base_node() -> bool : return IsCharacterBaseNode

var _numberOfHits : int = 0

signal DamageApplied(categories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

func _ready():
	initGameObjectComponent()
	if ApplyOnSignal == 0:
		_gameObject.connectToSignal("OnHit", _on_hit)
	elif ApplyOnSignal == 1:
		_gameObject.connectToSignal("CollisionStarted", collisionWithNode)

	if _gameObject != null:
		initialize_modifiers(self)

func _process(delta):
	_activeTime += delta

func initialize_modifiers(referenceParent):
	_modifiedForce = ModifiedFloatValue.new()
	_modifiedForce.initAsMultiplicativeOnly("Force", referenceParent._gameObject, Callable())
	_modifiedDamage = referenceParent.createModifiedIntValue(DamageAmount, "Damage")
	_modifiedCriticalHitChance = referenceParent.createModifiedFloatValue(CritChance, "CritChance")
	_modifiedCriticalHitBonus = referenceParent.createModifiedFloatValue(CritBonus, "CritBonus")
	applyModifierCategories()

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedForce.setModifierCategories(ModifierCategories)
	_modifiedCriticalHitChance.setModifierCategories(ModifierCategories)
	_modifiedCriticalHitBonus.setModifierCategories(ModifierCategories)

func transformCategories(onlyWithDamageCategory:String, addModifierCategories:Array[String], removeModifierCategories:Array[String], addDamageCategories:Array[String], removeDamageCategories:Array[String]):
	if not DamageCategories.has(onlyWithDamageCategory):
		return
	for addMod in addModifierCategories:
		if not ModifierCategories.has(addMod):
			ModifierCategories.append(addMod)
	for remMod in removeModifierCategories:
		ModifierCategories.erase(remMod)
	for addCat in addDamageCategories:
		if not DamageCategories.has(addCat):
			DamageCategories.append(addCat)
	for remMod in removeDamageCategories:
		DamageCategories.erase(remMod)
	applyModifierCategories()

func get_totalCritChance() -> float: return _modifiedCriticalHitChance.Value()
func get_totalCritBonus() -> float: return _modifiedCriticalHitBonus.Value()
func get_totalDamageChangePerSecond() -> float:
	if DamageChangePerSec < 0:
		return DamageChangePerSec / _modifiedForce.Value()
	return DamageChangePerSec
func get_damageReductionMultiplier() -> float:	return 1 / _modifiedForce.Value()
func get_totalCritDamage() -> float:
		var damage = _modifiedDamage.Value()
		return damage + get_totalCritBonus() * damage

func _on_hit(node:GameObject, hitNumber:int):
	if _numberOfHits >= MaxNumberOfHits:
		return
	var healthComponent = node.getChildNodeWithMethod("applyDamage")
	if healthComponent:
		var critical:bool = false
		var damage : int = _modifiedDamage.Value()

		if _modifiedCriticalHitBonus.Value() > 0:
			var numCrits : int = floori(_modifiedCriticalHitChance.Value())
			var remainingChance : float = _modifiedCriticalHitChance.Value() - numCrits
			if randf() <= remainingChance:
				numCrits += 1
			critical = numCrits > 0
			damage += (damage * _modifiedCriticalHitBonus.Value()) * numCrits

		if hitNumber > 0 && DamageMultPerHit != 1:
			var hitMultDamage : float = float(damage) * pow(DamageMultPerHit, hitNumber*get_damageReductionMultiplier())
			if hitMultDamage < 1:
				# when the damage would dip below 1, we remove the bullet,
				# since it can't do any damage anymore!
				_gameObject.queue_free()
				return
			damage = floori(hitMultDamage)
		if DamageChangePerSec != 0:
			var timeModeDamage : float = float(damage) + float(damage) * get_totalDamageChangePerSecond() * _activeTime
			damage = ceili(max(1, timeModeDamage))

		var mySource : GameObject = _gameObject.get_rootSourceGameObject()
		var damageReturn = healthComponent.applyDamage(damage, mySource, critical, _weapon_index, not Blockable)

		if mySource != null and is_instance_valid(mySource):
			mySource.injectEmitSignal("DamageApplied", [DamageCategories, damage, damageReturn, node, critical])
			if mySource != _gameObject:
				DamageApplied.emit(DamageCategories, damage, damageReturn, node, critical)
		_numberOfHits += 1


func resetTimeDamageModifier():
	_activeTime = 0

func collisionWithNode(node:Node):
	_on_hit(node, 1)

func set_weapon_index(weapon_index:int):
	_weapon_index = weapon_index

extends GameObjectComponent

@export_group("Emission State")
@export var Emitting : bool = false

@export_group("Emission Parameters")
@export var BaseDamage : int = 10
@export var HitSpeed : float = 1.0
@export var EmitDelay : float = 0.3
@export var ModifierCategories : Array[String] = ["Physical"]
@export var DamageCategories : Array[String] = ["DefaultWeapon"]
@export var LocatorCollider : Node
@export var RayEffectNode : Node

@export_group("Attack Animation Indices")
@export var StartAnimationIndex : int = 1
@export var EndAnimationIndex : int = 0

@export_group("Internal State")
@export var _weapon_index : int = -1

signal AttackTriggered(attack_index:int)

var _directionProvider : Node

var _modifiedSpeed
var _emitTimer : float

# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	var allMods : Array = [
		_modifiedSpeed
	]
	return allMods
func is_character_base_node() -> bool : return true


func _ready():
	initGameObjectComponent()
	_directionProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")
	_modifiedSpeed = createModifiedFloatValue(HitSpeed, "AttackSpeed")
	applyModifierCategories()
	RayEffectNode.visible = false


func _process(delta: float) -> void:
	if Emitting:
		_emitTimer -= delta
		if _emitTimer <= 0 and not RayEffectNode.visible:
			RayEffectNode.visible = true
	else:
		_emitTimer -= delta
		if _emitTimer < 0:
			_emitTimer = 0
		return
	while _emitTimer <= 0:
		damage_tick()
		_emitTimer += 1.0 / get_totalAttackSpeed()


func damage_tick():
	for c in LocatorCollider._currentCollisions:
		if not is_instance_valid(c): continue
		var healthComponent = c.getChildNodeWithMethod("applyDamage")
		if is_instance_valid(healthComponent):
			healthComponent.applyDamage(BaseDamage, _gameObject)


func applyModifierCategories():
	_modifiedSpeed.setModifierCategories(ModifierCategories)


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


func set_emitting(emit:bool, _reset_timer:bool = false) -> void:
	if not emit:
		RayEffectNode.visible = false
	elif not Emitting and emit and StartAnimationIndex >= 0:
		AttackTriggered.emit(StartAnimationIndex)
	elif Emitting and not emit and EndAnimationIndex >= 0:
		AttackTriggered.emit(EndAnimationIndex)
	_emitTimer = EmitDelay
	Emitting = emit


func get_attackSpeedFactor() -> float: return get_totalAttackSpeed() / HitSpeed
func get_totalAttackSpeed() -> float: return _modifiedSpeed.Value()


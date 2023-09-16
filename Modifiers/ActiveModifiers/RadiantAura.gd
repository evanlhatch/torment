extends GameObjectComponent2D

@export var Radius : float = 100
@export var HitLocatorPool : String = "Enemies"
@export var BaseDamage : int = 100
@export var BaseCriticalChance : float = 0.0
@export var BaseCriticalBonus : float = 0.0
@export var EmitInterval : float = 2.0
@export var FlashColor : Color = Color(1.0, 1.0, 1.0, 0.4)
@export var ModifierCategories : Array[String] = ["Magic", "RadiantAura"]
@export var DamageCategories : Array[String] = ["Fire"]

@export var ApplyEffectScenes : Array[PackedScene]
@export_enum("DontApplyEffects", "EvenlyDistributeStacks", "UseApplyEffectChance") var EffectApplicationType : int
@export var ApplyNumberOfEffectStacks : int = 0
@export var NumberOfStacksModifiedBy : String
@export var ApplyEffectChance : float = 0

@export_group("internal state")
@export var _baseSize : float = -1
@export var _weapon_index : int = -1

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _modifiedDamage
var _modifiedCritChance
var _modifiedCritBonus
var _modifiedSpeed
var _modifiedSize
var _modifiedNumberOfEffectStacks

var ray_rotation : float
var rays1
var rays2

var _emit_timer : float
var _timeSinceLastEmit : float = 9999
var _numEnemiesHitLastEmit : int = 0

var _effectPrototypes : Array[EffectBase]
var _col1
var _col2

func _ready():
	rays1 = $AuraRays_1
	rays2 = $AuraRays_2
	_col1 = rays1.material.get_shader_parameter("modulate_color")
	_col2 = rays2.material.get_shader_parameter("modulate_color")

func _on_player_died():
	_gameObject = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func _enter_tree():
	if _baseSize < 0: _baseSize = scale.x
	initGameObjectComponent()
	if get_parent() is Item and TooltipText.is_empty():
		TooltipText = get_parent().Description
	if _gameObject:
		_emit_timer = 0.0
		visible = true
		process_mode = Node.PROCESS_MODE_PAUSABLE
		_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
		_modifiedSize = createModifiedFloatValue(_baseSize, "Area")
		_modifiedSize.connect("ValueUpdated", sizeWasUpdated)
		_modifiedCritChance = createModifiedFloatValue(BaseCriticalChance, "CritChance")
		_modifiedCritBonus = createModifiedFloatValue(BaseCriticalBonus, "CritBonus")
		_modifiedSpeed = createModifiedFloatValue(1.0 / EmitInterval, "AttackSpeed")
		
		for effectscene in ApplyEffectScenes:	
			_effectPrototypes.append(effectscene.instantiate())
		if ApplyNumberOfEffectStacks > 0 and NumberOfStacksModifiedBy != "":
			_modifiedNumberOfEffectStacks = createModifiedFloatValue(ApplyNumberOfEffectStacks, NumberOfStacksModifiedBy, Callable())
		
		applyModifierCategories()
		sizeWasUpdated(_baseSize, _modifiedSize.Value())
		Global.World.connect("PlayerDied", _on_player_died)
	else:
		visible = false
		var parent = get_parent()
		if parent and parent.has_method("get_weapon_index"):
			_weapon_index = parent.get_weapon_index()
		else: _weapon_index = -1

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedCritChance.setModifierCategories(ModifierCategories)
	_modifiedCritBonus.setModifierCategories(ModifierCategories)
	_modifiedSpeed.setModifierCategories(ModifierCategories)
	_modifiedSize.setModifierCategories(ModifierCategories)

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


func _exit_tree():
	_allModifiedValues.clear()
	for effectPrototype in _effectPrototypes:
		effectPrototype.queue_free()
	_effectPrototypes.clear()
	_gameObject = null
	_modifiedDamage = null
	_modifiedCritChance = null
	_modifiedCritBonus = null
	_modifiedSpeed = null
	_positionProvider = null
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta):
	if _gameObject == null: return
	if _positionProvider:
		global_position = _positionProvider.get_worldPosition()
	
	ray_rotation = wrapf(ray_rotation + delta * .1, 0.0, 2*PI)
	rays1.rotation = ray_rotation
	rays2.rotation = -ray_rotation
	
	_timeSinceLastEmit += delta
	if _emit_timer <= 0.0:
		emit()
		_emit_timer += get_totalEmitInterval()
	_emit_timer -= delta

func emit():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_parallel()
	tween.tween_property(rays1.material, "shader_parameter/modulate_color", _col1, 0.8).from(FlashColor)
	tween.tween_property(rays2.material, "shader_parameter/modulate_color", _col2, 0.8).from(FlashColor)

	var scaledRadius : float = scale.x * Radius
	var hits : Array = Global.World.Locators.get_gameobjects_in_circle(
			HitLocatorPool, global_position, scaledRadius)
	
	_numEnemiesHitLastEmit = 0
	_timeSinceLastEmit = 0
	if len(hits) > 0:
		var remainingEffectStacks : int = ApplyNumberOfEffectStacks
		if _modifiedNumberOfEffectStacks != null:
			remainingEffectStacks = _modifiedNumberOfEffectStacks.Value()
		var effectStacksPerHit : float = 1
		if remainingEffectStacks > hits.size():
			effectStacksPerHit = remainingEffectStacks / float(hits.size())
		var effectStacksOverflow : float = 0
		
		hits.sort_custom(distance_sort)
		var damageFraction : float = get_totalDamage() / float(len(hits))
		var critDamageFraction = get_critDamage(damageFraction)
		for hit in hits:
			if EffectApplicationType == 1 and remainingEffectStacks > 0:
				var numEffectsOnThisGameObject : int = floori(effectStacksPerHit)
				effectStacksOverflow += effectStacksPerHit - numEffectsOnThisGameObject
				if effectStacksOverflow >= 1:
					numEffectsOnThisGameObject += 1
					effectStacksOverflow -= 1.0
				for i in range(numEffectsOnThisGameObject):
					for effectPrototype in _effectPrototypes:
						hit.add_effect(effectPrototype, _gameObject)
					remainingEffectStacks -= 1
			elif EffectApplicationType == 2:
				# every effect gets its own chance
				for effectPrototype in _effectPrototypes:
					var applyChance : float = ApplyEffectChance
					while applyChance > 0:
						# when the probability is over 1, we don't roll the dice!
						if applyChance < 1 and randf() > applyChance:
							break
						applyChance -= 1.0
						hit.add_effect(effectPrototype, _gameObject)
					
				
			var healthComponent = hit.getChildNodeWithMethod("applyDamage")
			if healthComponent:
				var critical:bool = randf() <= get_totalCritChance()
				var damage = 0
				if critical:
					damage = critDamageFraction
				else:
					damage = damageFraction
				var damageReturn = healthComponent.applyDamage(damage, _gameObject, critical, _weapon_index)
				DamageApplied.emit(DamageCategories, damage, damageReturn, hit, critical)
				_numEnemiesHitLastEmit += 1

func sizeWasUpdated(_oldValue: float, totalSize:float): 
	scale = Vector2.ONE * totalSize

func get_totalDamage() -> int: return _modifiedDamage.Value()
func get_totalCritChance() -> float: return _modifiedCritChance.Value()
func get_totalCritBonus() -> float: return _modifiedCritBonus.Value()
func get_totalEmitInterval() -> float: return 1.0 / _modifiedSpeed.Value()

func get_critDamage(damageFraction:float) -> int:
	return int(ceil(damageFraction - 0.001)) + int(ceil(damageFraction * get_totalCritBonus()))


@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Radiant Aura"
@export_multiline var TooltipText : String = ""


# func get_modifierInfoArea_icon() -> Texture2D:
# 	return Icon

# func get_modifierInfoArea_cooldownfactor() -> float:
# 	return _emit_timer / EmitInterval

# func get_modifierInfoArea_active() -> bool:
# 	return _timeSinceLastEmit < 0.5

# func get_modifierInfoArea_valuestr() -> String:
# 	if _timeSinceLastEmit < 0.5:
# 		return str(_numEnemiesHitLastEmit)
# 	return ""

# func get_modifierInfoArea_tooltip() -> String:
# 	return TooltipText.format({
# 		"Radius": Radius,
# 		"BaseDamage" : BaseDamage,
# 		"EmitInterval" : EmitInterval
# 	})

# func get_modifierInfoArea_name() -> String:
# 	return Name

func get_cooldown_factor() -> float:
	return 1.0 - _emit_timer / get_totalEmitInterval()

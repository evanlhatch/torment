extends GameObjectComponent2D

@export var Radius : float = 56
@export var DamageLocatorPool : String = "Enemies"
@export var DamageLocatorPool2 : String = ""
@export var ApplyModifierLocatorPool : String = "Player"
@export var ApplyModifierScene : PackedScene
@export var BaseDamage : int = 4
@export var BaseCriticalChance : float = 0.0
@export var BaseCriticalBonus : float = 0.0
@export var DamageInterval : float = 0.6
@export var Lifetime : float = 4.0
@export var ModifierCategories : Array[String] = ["Magic", "Item"]
@export var DamageCategories : Array[String]
@export var InitialDelayBeforeDamage : float = 0.0
@export var Unblockable : bool = false

@export_group("Audio Settings")
@export var AudioFX : AudioFXResource

@export_group("internal state")
@export var _baseSize : float = -1
@export var _weapon_index : int = -1

var _firstDamageApplied : bool

var modifierPrototype
var bestowed_modifiers = {}
var timer : float
var currentModifiedObjects : Array[GameObject] = []
var timeUntilVanish : float

var _modifiedDamage
var _modifiedArea
var _modifiedForce
# only use for the statistics. not very optimized...
func get_modified_values() -> Array:
	return [
		_modifiedDamage,
		_modifiedArea,
		_modifiedForce
	]

signal Expired(shadow_patch)
signal FirstDamage

func _ready():
	initGameObjectComponent()

	if ApplyModifierScene != null:
		modifierPrototype = ApplyModifierScene.instantiate()
	var scale_tween = create_tween()
	timer = InitialDelayBeforeDamage
	_modifiedDamage = createModifiedIntValue(BaseDamage, "Damage")
	_modifiedForce = createModifiedFloatValue(Lifetime, "Force")
	_modifiedArea = createModifiedFloatValue(Radius, "Area")
	timeUntilVanish = get_totalDuration()
	applyModifierCategories()
	scale_tween.tween_property($SpriteScaler, "scale", Vector2.ONE * (get_totalArea() / Radius), 0.3).from(Vector2.ZERO)
	if AudioFX != null:
		await get_tree().create_timer(InitialDelayBeforeDamage).timeout
		FxAudioPlayer.play_sound_2D(
			AudioFX,
			get_gameobjectWorldPosition(),
			false, false, -2.0)


func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedForce.setModifierCategories(ModifierCategories)
	_modifiedArea.setModifierCategories(ModifierCategories)

func _exit_tree():
	if modifierPrototype != null:
		modifierPrototype.queue_free()
		modifierPrototype = null

func handleModifier():
	if ApplyModifierLocatorPool == "" or not modifierPrototype:
		return
	var scaledRadius : float = scale.x * get_totalArea()
	var currentObjectsInside = Global.World.Locators.get_gameobjects_in_circle(
			ApplyModifierLocatorPool, global_position, scaledRadius)
	# check for newly left modifiedObjects
	for i in range(currentModifiedObjects.size(), 0, -1):
		if not currentObjectsInside.has(currentModifiedObjects[i-1]):
			# object left!
			if bestowed_modifiers.has(currentModifiedObjects[i-1]):
				for m in bestowed_modifiers[currentModifiedObjects[i-1]]:
					m.queue_free()
				bestowed_modifiers.erase(currentModifiedObjects[i-1])
			currentModifiedObjects.remove_at(i-1)
	# check for newly entered modifiedObjects
	for gameobject in currentObjectsInside:
		if not currentModifiedObjects.has(gameobject):
			# object entered!
			var mod = modifierPrototype.duplicate()
			if not bestowed_modifiers.has(gameobject):
				bestowed_modifiers[gameobject] = [mod]
			else:
				bestowed_modifiers[gameobject].append(mod)
			gameobject.add_child(mod)
			currentModifiedObjects.append(gameobject)

func _process(delta):
	handleModifier()

	timer -= delta
	if timer <= 0:
		timer = DamageInterval
		hurt()

	timeUntilVanish -= delta
	if timeUntilVanish <= 0:
		var scale_tween = create_tween()
		scale_tween.tween_property($SpriteScaler, "scale", Vector2.ZERO, 0.3).from_current()
		scale_tween.connect("finished", kill)

func kill():
	remove_all_bestowed_modifiers()
	emit_signal("Expired", _gameObject)
	_gameObject.queue_free()

func remove_all_bestowed_modifiers():
	for player in bestowed_modifiers:
		for mod in bestowed_modifiers[player]:
			mod.queue_free()
	bestowed_modifiers.clear()

func hurt():
	if not _firstDamageApplied:
		_firstDamageApplied = true
		FirstDamage.emit()
	var scaledRadius : float = scale.x * get_totalArea()
	var currentObjectsInside = Global.World.Locators.get_gameobjects_in_circle(
			DamageLocatorPool, global_position, scaledRadius)

	if not DamageLocatorPool2.is_empty():
		var objectInside2 = Global.World.Locators.get_gameobjects_in_circle(
			DamageLocatorPool2, global_position, scaledRadius)
		currentObjectsInside.append_array(objectInside2)

	for gameObject in currentObjectsInside:
		var healthComponent = gameObject.getChildNodeWithMethod("applyDamage")
		if healthComponent:
			var critical:bool = randf() <= BaseCriticalChance
			var damage = 0
			if critical:
				damage = get_totalCritDamage()
			else:
				damage = get_totalDamage()
			var mySource : GameObject = _gameObject.get_rootSourceGameObject()
			var damageReturn = healthComponent.applyDamage(damage, mySource, critical, _weapon_index, Unblockable)
			if mySource != null and is_instance_valid(mySource):
				mySource.injectEmitSignal("DamageApplied", [DamageCategories, damage, damageReturn, gameObject, critical])


# the shadow patch doesn't have a mover or anything, but it should
# still be positionable, so we just implement the get/set_worldPosition "interface"
func get_worldPosition() ->  Vector2:
	return global_position

func set_worldPosition(new_position : Vector2):
	global_position = new_position


func sizeWasUpdated(_before:float, valueNow:float):
	scale = Vector2.ONE * valueNow


func get_totalCritDamage() -> int:
	return get_totalDamage() + ceili(get_totalDamage() * BaseCriticalBonus)

func get_totalDuration() -> float:
	return _modifiedForce.Value()
func get_totalDamage() -> int:
	return _modifiedDamage.Value()
func get_totalArea() -> float:
	return _modifiedArea.Value()

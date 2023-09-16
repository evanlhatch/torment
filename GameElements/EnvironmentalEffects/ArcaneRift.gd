extends GameObjectComponent2D

@export var Radius : float = 24
@export var Lifetime : float = 4.0
@export var ModifierCategories : Array[String] = ["Magic"]
@export var InitialDelayBeforeDamage : float = 0.0
@export var Unblockable : bool = false

@export_group("Damage Settings")
@export var DamageLocatorPool : String = "Enemies"
@export var DamageCategories : Array[String] = ["Magic"]
@export var BaseDamage : int = 0
@export var BaseCriticalChance : float = 0.0
@export var BaseCriticalBonus : float = 0.0
@export var DamageInterval : float = 0.4

@export_group("Audio Settings")
@export var AudioFX : AudioFXResource

@export_group("internal state")
@export var _baseSize : float = -1
@export var _weapon_index : int = -1


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

signal Expired(game_object)
signal Killed(by_node)
var _trigger_killed_signal : bool

func _ready():
	initGameObjectComponent()
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

	var touchable = _gameObject.getChildNodeWithSignal("Touched")
	if is_instance_valid(touchable):
		_gameObject.connectToSignal("Touched", _on_touched)
		touchable.global_position = global_position


func _on_touched():
	_trigger_killed_signal = true
	kill()

func applyModifierCategories():
	_modifiedDamage.setModifierCategories(ModifierCategories)
	_modifiedForce.setModifierCategories(ModifierCategories)
	_modifiedArea.setModifierCategories(ModifierCategories)

func _exit_tree():
	if modifierPrototype != null:
		modifierPrototype.queue_free()
		modifierPrototype = null

func _process(delta):
	if BaseDamage > 0:
		timer -= delta
		if timer <= 0:
			timer = DamageInterval
			hurt()

	timeUntilVanish -= delta
	if timeUntilVanish <= 0:
		var scale_tween = create_tween()
		scale_tween.tween_property($SpriteScaler, "scale", Vector2.ZERO, 0.3).from_current()
		_trigger_killed_signal = false
		scale_tween.connect("finished", kill)

func kill():
	Expired.emit(_gameObject)
	_gameObject.queue_free()
	if _trigger_killed_signal:
		Killed.emit(_gameObject)


func hurt():
	var scaledRadius : float = scale.x * get_totalArea()
	var currentObjectsInside = Global.World.Locators.get_gameobjects_in_circle(
			DamageLocatorPool, global_position, scaledRadius)

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


func get_weapon_index() -> int:
	return _weapon_index

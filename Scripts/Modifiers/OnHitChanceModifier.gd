extends GameObjectComponent

@export var AddOnHitChance : float = 0
@export var AddOnHitChancePercent : float = 0
@export var RemoveAfterTime : float = -1

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _hitChanceMod : Modifier
var _remainingLevelsToChange : int = 0

func _enter_tree():
	initGameObjectComponent()

	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT if RemoveAfterTime > 0 or get_child_count() > 0 else PROCESS_MODE_DISABLED

	if ChangeEveryXLevels > 0:
		await Global.awaitWorldReady()
		Global.World.ExperienceThresholdReached.connect(on_level_up)
		_remainingLevelsToChange = ChangeEveryXLevels

	_hitChanceMod = Modifier.create("OnHitChance", _gameObject)
	_hitChanceMod.setName(Name)
	_hitChanceMod.setAdditiveMod(AddOnHitChance)
	_hitChanceMod.setMultiplierMod(AddOnHitChancePercent)
	_hitChanceMod.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("OnHitChance")


func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_hitChanceMod.setMultiplierMod(_hitChanceMod.getMultiplierMod() + ChangeMultiplier)
		_hitChanceMod.setAdditiveMod(_hitChanceMod.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("OnHitChance")

func _exit_tree():
	_hitChanceMod = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()

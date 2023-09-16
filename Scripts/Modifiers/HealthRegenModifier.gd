extends GameObjectComponent

@export var AddHealthRegen : float = 0.1
@export var AddHealthRegenPercent : float = 0.0
@export var RemoveAfterTime : float = -1

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _healthRegenMod : Modifier
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

	_healthRegenMod = Modifier.create("HealthRegen", _gameObject)
	_healthRegenMod.setName(Name)
	_healthRegenMod.setAdditiveMod(AddHealthRegen)
	_healthRegenMod.setMultiplierMod(AddHealthRegenPercent)
	_gameObject.triggerModifierUpdated("HealthRegen")


func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_healthRegenMod.setMultiplierMod(_healthRegenMod.getMultiplierMod() + ChangeMultiplier)
		_healthRegenMod.setAdditiveMod(_healthRegenMod.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("HealthRegen")


func _exit_tree():
	_healthRegenMod = null
	_gameObject = null


func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()

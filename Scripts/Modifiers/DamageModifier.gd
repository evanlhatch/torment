extends GameObjectComponent

@export var AddDamage : int = 0
@export var AddDamagePercent : float = 0.5
@export var RemoveAfterTime : float = -1

@export var ChangeEveryXLevels : int = 0
@export var ChangeMultiplier : float = 0
@export var ChangeAdditive : float = 0
@export var ModifierCategories : Array[String]

@export var Name : String
func get_modifier_name() -> String:
	return Name

var _damageModifier : Modifier
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

	_damageModifier = Modifier.create("Damage", _gameObject)
	_damageModifier.setName(Name)
	_damageModifier.setAdditiveMod(AddDamage)
	_damageModifier.setMultiplierMod(AddDamagePercent)
	_damageModifier.allowCategories(ModifierCategories)
	_gameObject.triggerModifierUpdated("Damage")


func on_level_up():
	_remainingLevelsToChange -= 1
	if _remainingLevelsToChange <= 0:
		_remainingLevelsToChange = ChangeEveryXLevels
		_damageModifier.setMultiplierMod(_damageModifier.getMultiplierMod() + ChangeMultiplier)
		_damageModifier.setAdditiveMod(_damageModifier.getAdditiveMod() + ChangeAdditive)
		_gameObject.triggerModifierUpdated("Damage")

func _exit_tree():
	_damageModifier = null
	_gameObject = null

func _process(delta):
	if RemoveAfterTime < 0:
		return
	RemoveAfterTime -= delta
	if RemoveAfterTime <= 0:
		queue_free()

extends GameObjectComponent2D

@export_group("Modifier Settings")
@export var ModifierName : String = ""
@export var FromModifier : String = "MovementSpeed"
@export var FromModifierCategories : Array[String]
@export var ToModifier : String = "AttackSpeed"
@export var ToModifierCategories : Array[String]


@export_group("Transform Settings")
@export var TransformMultiplier : float = 1.0
@export var TransformLimitMax : float = 0.0
@export var TransformLimitMin : float = 0.0
@export var ValuePerEntry : float = 0.01
@export var ReductionIntervalLength : float = 0.2


@export_group("Conditions")
@export var MovementThreshold : float = 0.0


var _modifier : Modifier
var _fromModifier : ModifiedFloatValue
var _modifierStrength : float = 0.0

var _previousPosition : Vector2
var _distanceMoved : float
var _buff_reduction_timer : float


func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		mod_info_str = "0%"
		_buff_reduction_timer = 0.0
		_previousPosition = _positionProvider.get_worldPosition()
		_modifier = Modifier.create(ToModifier, _gameObject)
		_modifier.setName(ModifierName)
		_modifier.allowCategories(ToModifierCategories)
		_fromModifier = ModifiedFloatValue.new()
		_fromModifier.initAsMultiplicativeOnly(FromModifier, _gameObject, Callable())
		applyModifierCategories()


func applyModifierCategories():
	_fromModifier.setModifierCategories(FromModifierCategories)


func _exit_tree():
	_gameObject = null


func _process(delta):
	if _gameObject == null or _positionProvider == null: return
	if not check_movement():
		increase_reduction_timer(delta)
		return

	_distanceMoved -= MovementThreshold
	increase_buff()


func check_movement() -> bool:
	if MovementThreshold <= 0.0:
		return true
	var new_position = _positionProvider.get_worldPosition()
	var distance_this_frame = _previousPosition.distance_to(new_position)
	if distance_this_frame > 1.0:
		_distanceMoved += distance_this_frame
		_previousPosition = new_position
		_buff_reduction_timer = 0.0
		if _distanceMoved >= MovementThreshold:
			return true
	return false


func increase_reduction_timer(delta:float):
	_buff_reduction_timer += delta
	if _buff_reduction_timer >= ReductionIntervalLength:
		_buff_reduction_timer -= ReductionIntervalLength
		reduce_buff()


func reduce_buff():
	if _modifierStrength > 0:
		_modifierStrength -= ValuePerEntry
	set_modifier()


func increase_buff():
	if _modifierStrength < 1.0:
		_modifierStrength += ValuePerEntry
	set_modifier()


func set_modifier():
	print(_fromModifier.Value())
	var value = (_fromModifier.Value() - 1.0) * TransformMultiplier * _modifierStrength
	value = max(TransformLimitMin, min(TransformLimitMax, value))
	mod_info_str = "%d%%" % (value * 100)
	_modifier.setMultiplierMod(value)
	_gameObject.triggerModifierUpdated(ToModifier)


@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export_multiline var TooltipText : String = ""
var mod_info_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_valuestr() -> String:
	return mod_info_str

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return ModifierName

extends GameObjectComponent2D

@export var Cooldown : float = 5.0
@export var EffectPositionOffset : Vector2
@export var EffectRange : int = 100
@export var EffectStacks : int = 5
@export var EffectColor : Color = Color.ORANGE
@export var FragileEffectScene : PackedScene
@export var HitLocatorPool : String = "Enemies"

var _cooldown_time : float
var _fragile_effect_prototype

var _modifiedRange

func _enter_tree():
	initGameObjectComponent()
	if _fragile_effect_prototype == null:
		_fragile_effect_prototype = FragileEffectScene.instantiate()
	if _gameObject:
		_modifiedRange = createModifiedIntValue(EffectRange, "Area")
	_cooldown_time = Cooldown


func _exit_tree():
	_gameObject = null
	_modifiedRange = null
	if _fragile_effect_prototype != null:
		_fragile_effect_prototype.queue_free()
		_fragile_effect_prototype = null


func _process(delta):
	if _gameObject and _positionProvider:
		global_position = _positionProvider.get_worldPosition() + EffectPositionOffset
		_cooldown_time -= delta
		if _cooldown_time <= 0.0:
			emit()
			_cooldown_time = Cooldown

func emit():
	var mySource : GameObject = _gameObject.get_rootSourceGameObject()
	var hits = Global.World.Locators.get_gameobjects_in_circle(
		HitLocatorPool, global_position, float(_modifiedRange.Value()))
	for h in hits:
		var healthComponent = h.getChildNodeWithMethod("applyDamage")
		if healthComponent:
			for i in range(EffectStacks):
				h.add_effect(_fragile_effect_prototype, mySource)
	Fx.show_cone_wave(
		_positionProvider.get_worldPosition() + EffectPositionOffset,
		Vector2.RIGHT,
		_modifiedRange.Value(),
		360.0,
		3.0,
		1.0,
		EffectColor,
		Callable(), null, 1.0,
		true)
	_mod_value_str = str(hits.size())

func get_cooldown_factor() -> float:
	return 1.0 - _cooldown_time / Cooldown

@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "WarcryEffect"
@export_multiline var TooltipText : String = ""
var _mod_value_str : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return _cooldown_time / Cooldown

func get_modifierInfoArea_active() -> bool:
	return Cooldown - _cooldown_time < 1.0

func get_modifierInfoArea_valuestr() -> String:
	if Cooldown - _cooldown_time < 1.0:
		return _mod_value_str
	return ""

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText

func get_modifierInfoArea_name() -> String:
	return Name

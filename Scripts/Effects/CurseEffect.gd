extends EffectBase


@export var RemoveAfterTime : float = -1
@export var CurseIndicatorPath : NodePath
@export var DamageCategories : Array[String]
@export var _weapon_index : int = 666
@export var AudioFX : AudioFXResource

var _curse_indicator : AnimatedSprite2D
var _counter_label : Label
var _remove_timer : float
var curse_lifted : bool


func get_effectID() -> String:
	return "CURSE"


func _enter_tree():
	initGameObjectComponent()
	if get_parent() is Item and TooltipText.is_empty():
		TooltipText = get_parent().Description
	if _gameObject:
		var sourceHealth = get_externalSource().getChildNodeWithSignal("Killed")
		if sourceHealth != null: sourceHealth.Killed.connect(lift_curse)
		_curse_indicator = get_node(CurseIndicatorPath)
		_counter_label = _curse_indicator.get_child(0)
		var indicator_slot = _gameObject.getChildNodeInGroup("StatusIndicator")
		if indicator_slot != null:
			remove_child(_curse_indicator)
			indicator_slot.add_child(_curse_indicator)
			_curse_indicator.position = Vector2.ZERO
			_curse_indicator.visible = true
		add_additional_effect(self)
		prolong_curse()
		FxAudioPlayer.play_sound_mono(AudioFX, false, true, -4)
		_curse_indicator.play("start")
		await _curse_indicator.animation_finished
		_curse_indicator.play("loop")


func _process(delta):
	if RemoveAfterTime < 0:
		return
	_remove_timer -= delta
	_counter_label.text = "%0.0f" % abs(ceil(_remove_timer))
	if _remove_timer <= 0:
		if curse_lifted: return
		_curse_indicator.play("end")
		await _curse_indicator.animation_finished
		
		# try to kill the player
		var health_component = _gameObject.getChildNodeWithMethod("applyDamage")
		if health_component != null:
			var damage = health_component.get_maxHealth() * 3
			var damageReturn = health_component.applyDamage(
				damage, null, false, _weapon_index, true)
			var externalSource : GameObject = get_externalSource()
			if externalSource != null and is_instance_valid(externalSource):
				externalSource.injectEmitSignal("DamageApplied", [DamageCategories, damage, damageReturn, _gameObject, false])
		_curse_indicator.queue_free()
		queue_free()


func add_additional_effect(additionalFragileEffectNode:EffectBase) -> void:
	# curse can only be applied once and has no additional effects
	return


func prolong_curse():
	_remove_timer =  RemoveAfterTime


func lift_curse(_killedByNode:Node):
	curse_lifted = true
	_curse_indicator.play("end")
	_counter_label.visible = false
	await _curse_indicator.animation_finished
	_curse_indicator.queue_free()
	queue_free()


@export_group("Modifier Info Area")
@export var Icon : Texture2D
@export var Name : String = "Curse of Pain"
@export_multiline var TooltipText : String = ""

func get_modifierInfoArea_icon() -> Texture2D:
	return Icon

func get_modifierInfoArea_cooldownfactor() -> float:
	return _remove_timer / RemoveAfterTime

func get_modifierInfoArea_tooltip() -> String:
	return TooltipText.format({
		"RemoveAfterTime": RemoveAfterTime
	})

func get_modifierInfoArea_name() -> String:
	return Name

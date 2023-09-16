extends GameObjectComponent

@export var DashTelegraphNode : Line2D
@export var DeathEffectNode : Node
@export var BaseDistanceTrigger : float = 180
@export var DashBullet : PackedScene
@export var DashAudio : AudioFXResource

var _playerPosPorvider : Node
var _modifiedTriggerDistance : ModifiedFloatValue
var _modulateColor : Color
var _dashed : bool
var bullet : GameObject

signal DashFinished


func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady
	initGameObjectComponent()
	if is_instance_valid(Global.World.Player):
		_playerPosPorvider = Global.World.Player.getChildNodeWithMethod("get_worldPosition")
	_modifiedTriggerDistance = createModifiedFloatValue(BaseDistanceTrigger, "DashRange")
	_modulateColor = DashTelegraphNode.material.get_shader_parameter("modulate_color")
	bullet = DashBullet.instantiate()

func _exit_tree():
	if bullet != null && not bullet.is_queued_for_deletion():
		bullet.queue_free()
		bullet = null


func transformCategories(onlyWithDamageCategory:String, addModifierCategories:Array[String], removeModifierCategories:Array[String], addDamageCategories:Array[String], removeDamageCategories:Array[String]):
	if bullet == null:
		return
	var bulletTransformComps : Array = []
	bullet.getChildNodesWithMethod("transformCategories", bulletTransformComps)
	for bulletTransformComp in bulletTransformComps:
		if bulletTransformComp.has_method("initialize_modifiers"):
			bulletTransformComp.initialize_modifiers(self)
		bulletTransformComp.transformCategories(onlyWithDamageCategory, addModifierCategories, removeModifierCategories, addDamageCategories, removeDamageCategories)


func _process(delta):
	if not is_instance_valid(_playerPosPorvider):
		return
	var vector_to_player : Vector2 = _playerPosPorvider.get_worldPosition() - get_gameobjectWorldPosition()
	DashTelegraphNode.points[1] = vector_to_player

	var trigger_distance : float = get_modifiedTriggerDistance()
	var distance : float = vector_to_player.length()
	_modulateColor.a = inverse_lerp(0.0, trigger_distance, distance)
	DashTelegraphNode.material.set_shader_parameter("modulate_color", _modulateColor)

	if distance >= trigger_distance and not _dashed:
		_dashed = true
		trigger_dash(vector_to_player)


func get_modifiedTriggerDistance() -> float:
	return _modifiedTriggerDistance.Value()


func trigger_dash(direction : Vector2):
	var pos = get_gameobjectWorldPosition()
	if DashAudio != null:
		FxAudioPlayer.play_sound_2D(DashAudio, pos, false, false, 1.0)
	
	if is_instance_valid(Global.World.Player):
		bullet.set_sourceGameObject(Global.World.Player)
		bullet.setInheritModifierFrom(Global.World.Player)
	Global.attach_toWorld(bullet, false)

	var emitDir = Vector2.RIGHT
	var dirComponent = bullet.getChildNodeWithMethod("set_targetDirection")
	if dirComponent:
		dirComponent.set_targetDirection(direction.normalized())
	var posComponent = bullet.getChildNodeWithMethod("set_worldPosition")
	if posComponent:
		posComponent.set_worldPosition(pos)

	if is_instance_valid(DeathEffectNode):
		DeathEffectNode.queue_free()

	_gameObject.visible = false
	_positionProvider.set_worldPosition(pos + direction)

	var bulletComponent = bullet.getChildNodeWithSignal("OnEndOfLife")
	if bulletComponent:
		bulletComponent.OnEndOfLife.connect(on_bullet_end_of_life)
		await bulletComponent.OnEndOfLife
		await get_tree().process_frame

	if not is_instance_valid(_gameObject): return
	var killedSignaller = _gameObject.getChildNodeWithSignal("Killed")
	killedSignaller.emit_signal("Killed", null)
	_gameObject.queue_free()


func on_bullet_end_of_life():
	DashFinished.emit()

extends GameObjectComponent

@export var SacrificeCount : int = 100
@export var ActivationDistance : float = 100
@export var SacrificeZones : Array[NodePath]
@export var Animations : AnimationPlayer
@export var CountLabel : Label
@export var SacrificeCollectTarget : Node2D
@export var SacrificePointStartOffset : Vector2 = Vector2(0, -20)
@export var ActivationAudio : AudioStreamPlayer2D
@export var SacrificeAudio : AudioStreamPlayer2D

@export_group("Scene_References")
@export var SacrificePointScene : PackedScene

signal OnEndOfLife

var active : bool
var sacrifice_zones : Array[Node]
var player_pos_provider : Node
var pitch_scale_increment : float

func _ready():
	initGameObjectComponent()
	if not Global.is_world_ready(): Global.WorldReady.connect(_on_world_ready)
	else: _on_world_ready()
	sacrifice_zones = []
	$"../SelfLight".energy = 2.5
	$"../Sprite/TwinkleGlow".visible = false
	CountLabel.visible = false
	for sz in SacrificeZones:
		var sz_node = get_node(sz)
		sacrifice_zones.append(sz_node)
		sz_node.visible = false
	pitch_scale_increment = 0.5 / float(SacrificeCount)
	SacrificeAudio.pitch_scale = 0.8

func _on_world_ready():
	player_pos_provider = Global.World.Player.getChildNodeWithMethod("get_worldPosition")

func _process(_delta):
	if active: return
	if is_instance_valid(player_pos_provider):
		if _gameObject.global_position.distance_to(player_pos_provider.get_worldPosition()) < ActivationDistance:
			activate()

func activate():
	active = true
	$"../Sprite/TwinkleGlow".visible = true
	ActivationAudio.play()
	for sz in sacrifice_zones:
		sz.visible = true
		CountLabel.visible = true
		CountLabel.text = str(SacrificeCount)
		sz.SacrificeEvent.connect(_on_sacrifice_event)
	var tween = create_tween()
	tween.set_parallel()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property($"../SelfLight", "energy", 4.0, 0.5).from(10.0)
	tween.tween_property($"../Sprite/TwinkleGlow", "scale", Vector2(3.5, 1.03), 0.5).from(Vector2(9.0, 2.7))
	await tween.finished
	Animations.play("twinkle")

func _on_sacrifice_event(sacrifice_position : Vector2):
	var point : GameObject = SacrificePointScene.instantiate()
	Global.attach_toWorld(point, false)
	var point_mover = point.getChildNodeWithMethod("start_motion_with_target")
	point_mover.global_position = sacrifice_position + SacrificePointStartOffset
	point_mover.start_motion_with_target(
		SacrificeCollectTarget,
		point_mover.global_position - SacrificeCollectTarget.global_position)
	await point_mover.OnEndOfLife
	SacrificeAudio.play()
	SacrificeAudio.pitch_scale += pitch_scale_increment
	if SacrificeCount == 1:
		complete_sacrifice()
		return
	SacrificeCount = max(SacrificeCount - 1, 0)
	CountLabel.text = str(SacrificeCount)

func get_worldPosition() -> Vector2:
	return _gameObject.global_position

func complete_sacrifice():
	OnEndOfLife.emit()
	_gameObject.queue_free()

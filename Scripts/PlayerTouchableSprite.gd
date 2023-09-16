extends AnimatedSprite2D

@export var DropAnimationName : String = "drop"
@export var IdleAnimationName : String = "idle"
@export var CollectAnimationName : String = "open"
@export var DecayAnimationName : String = "decay"
@export var Light : NodePath

var gameObject : GameObject
var light : Light2D
var light_tween : Tween

signal Collected

func _ready():
	connect("animation_finished", _on_animation_finished)
	connect("animation_looped", _on_animation_finished)
	gameObject = Global.get_gameObject_in_parents(self)
	gameObject.connectToSignal("Touched", _on_touched)
	play(DropAnimationName)
	
	if not Light.is_empty():
		var l = get_node(Light)
		if l is Light2D:
			light = l
			light_tween = create_tween()
			light_tween.tween_property(light, "energy", 2.0, 0.5).from(0)
	
func _on_touched():
	play(CollectAnimationName)

func _on_animation_finished():
	if animation == DropAnimationName:
		play(IdleAnimationName)
		
	elif animation == CollectAnimationName:
		emit_signal("Collected")
		play(DecayAnimationName)
		if light != null and light is Light2D:
			light_tween = create_tween()
			light_tween.tween_property(light, "energy", 0.0, 0.5).from(2.0)
	
	elif animation == DecayAnimationName:
		gameObject.queue_free()


extends AnimatedSprite2D

@export var PlayAnimationWhenPickedUp : String = ""
@export var FlashWhenPickedUp : bool = false
@export var FlashIntensity : float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready():
	material = material.duplicate()
	var parentGameObj = Global.get_gameObject_in_parents(self)
	if parentGameObj:
		parentGameObj.connectToSignal("MotionStarted", onMotionStarted)


func onMotionStarted():
	if FlashWhenPickedUp:
		material.set_shader_parameter("flash_modifier", FlashIntensity)
	if len(PlayAnimationWhenPickedUp) > 0:
		play(PlayAnimationWhenPickedUp)

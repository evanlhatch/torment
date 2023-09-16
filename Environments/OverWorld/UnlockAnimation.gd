extends AnimatedSprite2D

@export var UnlockAnimationName : String
@export var AnimationDelay : float = 0.5
@export var AudioNode : AudioStreamPlayer

func _ready():
	for c in get_children():
		if c.has_signal("FirstTimeUnlock"):
			c.connect("FirstTimeUnlock", _on_first_time_unlock)


func _on_first_time_unlock(gating_node:Node):
	if GlobalMenus.title != null and not GlobalMenus.title.is_queued_for_deletion():
		await GlobalMenus.title.finished
	if AnimationDelay > 0.0:
		await get_tree().create_timer(AnimationDelay).timeout
	play(UnlockAnimationName)
	if is_instance_valid(AudioNode): AudioNode.play()
	connect("animation_finished", _on_animation_finished.bind(gating_node))


func _on_animation_finished(gating_node:Node):
	if gating_node:
		gating_node.set_active(false)

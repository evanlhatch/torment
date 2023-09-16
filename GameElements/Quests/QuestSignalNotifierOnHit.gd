extends GameObjectComponent

@export var CountBlockedHits : bool = true

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("OnHitTaken", _on_signal)

func _on_signal(was_invincible : bool, was_blocked : bool, byNode : Node):
	if was_invincible:
		return
	if not CountBlockedHits and was_blocked:
		return
	if was_blocked:
		Global.QuestPool.notify_on_hit_taken(1, 1)
	else:
		Global.QuestPool.notify_on_hit_taken(1, 0)

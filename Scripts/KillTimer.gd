extends Timer

@export var MinCountdown : float = 5.0
@export var MaxCountdown : float = 10.0

func _ready():
	var gameObject = Global.get_gameObject_in_parents(self)
	if gameObject != null:
		start(randf_range(MinCountdown, MaxCountdown))
		await timeout
		if is_instance_valid(gameObject) and not gameObject.is_queued_for_deletion():
			gameObject.injectEmitSignal("Killed", [gameObject])
			gameObject.queue_free()

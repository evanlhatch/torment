extends GameObjectComponent

@export var ProbabilityToApply : float = 1
@export var HealthAmount : int = 15
@export var HealthPercentage : float = 0.0

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Collected", addHealth)

func addHealth(toNode:GameObject):
	if ProbabilityToApply >= 1 or randf() < ProbabilityToApply:
		if toNode == Global.World.Player:
			var healthSetter = toNode.getChildNodeWithMethod("add_health")
			if healthSetter:
				var actual_health_amount:int = HealthAmount
				if healthSetter.has_method("get_maxHealth"):
					actual_health_amount += round(healthSetter.get_maxHealth() * HealthPercentage)
				if actual_health_amount > 0:
					Logging.log_pickup("HEALTH", actual_health_amount)
					healthSetter.add_health(actual_health_amount)

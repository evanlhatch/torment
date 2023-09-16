extends GameObjectComponent


func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Touched", _show_sacrifice_menu)

func _show_sacrifice_menu():
	GameState.SetState(GameState.States.ItemSacrifice)

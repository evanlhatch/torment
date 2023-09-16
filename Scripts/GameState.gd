extends Node

enum States {
	Overworld,
	InGame,
	Paused,
	PlayerDied,
	PlayerSurvived,
	TraitSelection,
	AbilitySelection,
	ItemPickup,
	Debug,
	Quests,
	BlessingShrine,
	ReviveScreen,
	OverworldMenu,
	StoryDialogue,
	ItemPurchase,
	ItemSacrifice,
	ItemStash,
	RegisterOfHalls,
	Credits,
	Potions
}

var CurrentState : States = States.Overworld

signal StateChanged(newState:States, oldState:States)

var _stateScenes = [
	"res://Environments/OverWorld/Overworld.tscn",  # Overworld
	"EXT", 						 # InGame (scene is loaded via WorldPool!)
	null,						 # Paused
	null,						 # PlayerDied
	null,						 # PlayerSurvived
	null,						 # Trait Selection
	null,						 # Ability Selection
	null,						 # Item Pickup
	null,						 # Debug
	null,						 # Quests
	null,						 # BlessingShrine
	null,						 # ReviveScreen
	null,						 # OverworldMenu
	null,						 # StoryDialogue
	null,						 # ItemPurchase
	null,						 # ItemSacrifice
	null,						 # ItemStash
	null,						 # Register of Halls
	null,						 # Credits
	null						 # Potions
]
var _currentlyLoadedSceneState : States


func SetState(newState:States, forcedStateUpdate:bool = false) -> void:
	if CurrentState == newState and not forcedStateUpdate:
		return;
	var oldState = CurrentState
	CurrentState = newState

	emit_signal("StateChanged", newState, oldState)
	if _stateScenes[CurrentState] and _currentlyLoadedSceneState != CurrentState:
		_currentlyLoadedSceneState = CurrentState
		if _stateScenes[CurrentState] == "EXT":
			return
		# we load and instantiate the new scene manually, according to
		# https://docs.godotengine.org/en/latest/tutorials/scripting/singletons_autoload.html#custom-scene-switcher
		# so that we have a little more control over it than using change_scene...
		var newScene = ResourceLoaderQueue.getCachedResource(_stateScenes[CurrentState]).instantiate()
		get_tree().root.add_child(newScene)
		# setting the current_scene means that we are still compatible with change_scene
		get_tree().current_scene = newScene


func TransitionToState(newState:States, wait_before_state_change:float = 0.0) -> void:
	var newSceneLoadNeeded : bool = _stateScenes[newState] and _currentlyLoadedSceneState != newState
	if newSceneLoadNeeded and _stateScenes[newState] != "EXT":
		ResourceLoaderQueue.queueResource(_stateScenes[newState])
	GlobalMenus.transition.fade_out(wait_before_state_change)
	await GlobalMenus.transition.TransitionFinished

	# unload the old scene
	if newSceneLoadNeeded and get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		# need to wait at least one frame, so that the
		# queue_free really freed the scene!
		await get_tree().process_frame

	await ResourceLoaderQueue.waitForLoadingFinished()
	SetState(newState)
	GlobalMenus.transition.fade_in()

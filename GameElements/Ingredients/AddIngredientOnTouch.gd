extends GameObjectComponent

@export var CollectedIngredient : IngredientResource.IngredientEnum
@export var GatherSound : AudioFXResource

func _ready():
	initGameObjectComponent()
	var touchable = _gameObject.getChildNodeWithSignal("Touched")
	touchable.Touched.connect(on_touched)
	
func on_touched():
	# we'll play the gather sound regardless of whether the ingredient
	# was collected or not (it will be "collected" and destroyed either way)
	FxAudioPlayer.play_sound_mono(GatherSound, false, true, 0.0)
	
	if not Global.PlayerProfile.Ingredients.has(int(CollectedIngredient)):
		Global.PlayerProfile.Ingredients.append(int(CollectedIngredient))
		Global.savePlayerProfile(true)


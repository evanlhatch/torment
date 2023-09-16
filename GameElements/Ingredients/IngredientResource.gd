extends Resource
class_name IngredientResource

enum IngredientEnum
{
	Amanita,
	Belladonna,
	Bluecap,
	Coppergrass,
	DragonNettle,
	Firepaw,
	Salsify,
	Truffle,
	Wallflower,
	Saxifarga,
	Sulfur,
	Redmoss,
	Heracleum,
	PinkSalt,
	Asafoetida
}

@export var IngredientType : IngredientEnum
@export var Icon : Texture2D
@export var IngredientName : String

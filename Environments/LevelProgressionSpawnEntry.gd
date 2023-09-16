@tool
extends Resource
class_name LevelProgressionSpawnEntry

@export var EntryColor : Color = Color("#db8b00")
@export var Name : String = "spawn"
@export var Start : float = 1800.0
@export var End : float = 1740.0

@export var SpawnedScene : PackedScene

@export var SpawnInterval : float = 1.0
@export var ApplyTormentToSpawnInterval : bool = false
@export var SpawnsPerInterval : int = 10
@export var ApplyTormentToSpawnsPerInterval : bool = false
@export var CountTarget : int = 100
@export var ApplyTormentToCountTarget : bool = false
@export var DisposableOnExit : bool = true
@export var DestroyOnTargetCount : bool = false
@export var MinRank : int = 0
@export var MaxRank : int = 5
@export_flags("North", "South", "East", "West") var SpawnFlags = 0b1111

func _init():
	Name = "spawn"
	Start = 1800.0
	End = 1740.0
	
	SpawnInterval = 1.0
	SpawnsPerInterval = 10
	CountTarget = 100
	DisposableOnExit = true
	DestroyOnTargetCount = false
	MinRank = 0
	MaxRank = 5
	SpawnFlags = 0b1111

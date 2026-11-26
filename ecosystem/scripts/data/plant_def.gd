class_name PlantDef
extends Resource
## Especie de flora cultivable.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var model: StringName = &"fern"
@export var seed_cost: int = 1
## Recursos adicionales necesarios para plantar (además de semillas).
@export var plant_cost: Dictionary = {}
## Segundos hasta la madurez con condiciones perfectas.
@export var grow_time: float = 30.0
@export var water_use: float = 0.1
@export var light_use: float = 0.1
@export var essence: float = 0.5
@export var oxygen: float = 0.2
## Capacidad de fauna aérea que aporta cada planta madura.
@export var habitat: float = 0.5
## Semillas por segundo que deja caer una planta madura sana.
@export var seed_rate: float = 0.01
@export var biodiversity: float = 1.0
## Segundos para producir una floración cosechable.
@export var bloom_time: float = 45.0
@export var unlock_tech: StringName = &""
## Vacío = cualquier isla.
@export var allowed_islands: PackedStringArray = PackedStringArray()
@export var color: Color = Color(0.3, 0.85, 0.4)
@export var accent: Color = Color(0.7, 1.0, 0.9)

class_name FaunaDef
extends Resource
## Especie de fauna. Su población crece de forma logística si el ecosistema la sostiene.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var model: StringName = &"butterfly"
## "air" usa la capacidad de flora + nidos; "water" usa la capacidad de los estanques.
@export var habitat_kind: StringName = &"air"
@export var oxygen_use: float = 0.05
@export var water_use: float = 0.0
@export var light_use: float = 0.0
@export var repro_rate: float = 0.05
@export var essence: float = 0.1
## Producción adicional por individuo y segundo, p. ej. {"pollen": 0.02}.
@export var produce: Dictionary = {}
@export var biodiversity: float = 3.0
## Bonificación multiplicativa de esencia de flora por individuo.
@export var plant_bonus: float = 0.0
@export var intro_cost: Dictionary = {}
@export var intro_amount: float = 2.0
@export var unlock_tech: StringName = &""
@export var color: Color = Color(0.6, 0.9, 1.0)

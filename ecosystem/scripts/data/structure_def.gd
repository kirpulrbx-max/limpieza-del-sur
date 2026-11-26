class_name StructureDef
extends Resource
## Estructura construible en el mundo.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var model: StringName = &"condenser"
@export var cost: Dictionary = {}
## Multiplicador de coste por cada unidad ya construida.
@export var cost_growth: float = 1.35
## Producción por segundo, p. ej. {"water": 0.6}.
@export var produce: Dictionary = {}
@export var fauna_capacity: float = 0.0
@export var footprint: float = 1.3
@export var effect_radius: float = 0.0
## 0 = sin límite.
@export var max_count: int = 0
@export var unlock_tech: StringName = &""

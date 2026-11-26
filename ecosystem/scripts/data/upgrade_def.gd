class_name UpgradeDef
extends Resource
## Mejora con niveles. category "run" se reinicia al renacer; "prestige" es permanente.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: StringName = &"run"
@export var group: String = "Herramientas"
@export var cost: Dictionary = {}
@export var cost_growth: float = 1.7
## 0 = sin límite.
@export var max_level: int = 0
@export var effect: float = 0.25
@export var unlock_tech: StringName = &""

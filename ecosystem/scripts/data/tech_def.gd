class_name TechDef
extends Resource
## Nodo del árbol tecnológico (desbloqueo único).

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: Dictionary = {}
@export var requires: PackedStringArray = PackedStringArray()
@export var min_level: int = 1
## Posición en el árbol: columna (tier) y fila.
@export var tier: int = 0
@export var row: int = 0
## Tecnologías básicas que la mejora "Conocimiento heredado" conserva al renacer.
@export var basic: bool = false

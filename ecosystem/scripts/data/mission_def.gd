class_name MissionDef
extends Resource
## Objetivo guiado. kind: stat, tech, fauna, level, biodiv, upgrade, structure, plant_species, plants_alive, island_visit.

@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""
@export var kind: StringName = &"stat"
@export var key: String = ""
@export var target: float = 1.0
@export var reward: Dictionary = {}

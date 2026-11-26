class_name IslandDef
extends Resource
## Isla flotante / bioma.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var biome: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var radius: float = 14.0
@export var noise_seed: int = 1
@export var grass_dead: Color = Color(0.5, 0.46, 0.4)
@export var grass_lush: Color = Color(0.3, 0.85, 0.35)
@export var rock_color: Color = Color(0.7, 0.75, 0.85)
@export var crystal_color: Color = Color(0.5, 0.9, 1.0)
@export var pond_offset: Vector2 = Vector2.ZERO
## 0 = sin estanque.
@export var pond_radius: float = 3.0
@export var pond_capacity: float = 8.0
@export var crystal_count: int = 3
@export var base_plots: int = 4
@export var unlock_tech: StringName = &""
## Isla desde la que parte el puente de luz.
@export var bridge_from: StringName = &""
@export var light_mult: float = 1.0
@export var water_mult: float = 1.0
@export var essence_mult: float = 1.0

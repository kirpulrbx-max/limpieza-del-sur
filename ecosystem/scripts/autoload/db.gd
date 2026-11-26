extends Node
## Base de datos: carga las definiciones configurables (.tres) de res://data.

var plants: Array[PlantDef] = []
var fauna: Array[FaunaDef] = []
var structures: Array[StructureDef] = []
var upgrades: Array[UpgradeDef] = []
var techs: Array[TechDef] = []
var missions: Array[MissionDef] = []
var islands: Array[IslandDef] = []

var _by_id := {}


func _init() -> void:
	_load_list("res://data/plants.tres", plants)
	_load_list("res://data/fauna.tres", fauna)
	_load_list("res://data/structures.tres", structures)
	_load_list("res://data/upgrades.tres", upgrades)
	_load_list("res://data/techs.tres", techs)
	_load_list("res://data/missions.tres", missions)
	_load_list("res://data/islands.tres", islands)


func _load_list(path: String, target: Array) -> void:
	var list := load(path) as DefList
	if list == null:
		push_error("DB: no se pudo cargar %s" % path)
		return
	var cat := path.get_file().get_basename()
	for item in list.items:
		target.append(item)
		_by_id["%s/%s" % [cat, item.id]] = item


func plant(id: StringName) -> PlantDef:
	return _by_id.get("plants/%s" % id)


func fauna_def(id: StringName) -> FaunaDef:
	return _by_id.get("fauna/%s" % id)


func structure(id: StringName) -> StructureDef:
	return _by_id.get("structures/%s" % id)


func upgrade(id: StringName) -> UpgradeDef:
	return _by_id.get("upgrades/%s" % id)


func tech(id: StringName) -> TechDef:
	return _by_id.get("techs/%s" % id)


func island(id: StringName) -> IslandDef:
	return _by_id.get("islands/%s" % id)


func run_upgrades() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for u in upgrades:
		if u.category == &"run":
			out.append(u)
	return out


func prestige_upgrades() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for u in upgrades:
		if u.category == &"prestige":
			out.append(u)
	return out

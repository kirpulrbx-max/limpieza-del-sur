# Arquitectura técnica

## Principios

- **Modelo separado de la vista.** Todo el estado vive en `GameState` como datos planos
  (diccionarios y números). Nada del estado depende de nodos 3D.
- **Simulación pura.** `EcosystemSim.step(gs, dt)` (scripts/core) calcula producción,
  consumo, salud, crecimiento, fauna, equilibrio y automatización. Se ejecuta a 5 Hz en el
  juego, en pasos grandes en el progreso offline y directamente en las pruebas.
- **Datos configurables.** Plantas, fauna, estructuras, mejoras, tecnologías, misiones e
  islas son `Resource` (`.tres` en `data/`). Añadir una especie o una mejora no requiere
  tocar código: basta con añadir un elemento a la lista.
- **Geometría determinista.** `IslandLayout` calcula contorno, altura del terreno,
  estanque, parcelas y cristales a partir de una semilla; lo usan el mundo, el mapa, la
  validación de construcción y la simulación.
- **Sin dependencias.** Todo es GDScript y recursos nativos de Godot.

## Autoloads (orden de carga)

| Nombre | Archivo | Función |
|---|---|---|
| `DB` | autoload/db.gd | Carga las listas `.tres` y ofrece búsqueda por id |
| `GameState` | autoload/game_state.gd | Estado, reglas de negocio (plantar, comprar, investigar, construir, renacer), multiplicadores, misiones, nivel, serialización |
| `Audio` | autoload/audio_manager.gd | Síntesis de efectos al arrancar, pad ambiental renderizado en un hilo, campanas generativas, buses Music/SFX |
| `SaveManager` | autoload/save_manager.gd | JSON + copia de seguridad, autoguardado, ajustes (ConfigFile) y progreso offline |

## Flujo de datos

```
Entrada del jugador ─► Player (rayo) ─► objeto interactuable ─► GameState.<acción>()
                                                              │
                              señales: plant_added, structure_added, tech_unlocked,
                              island_unlocked, world_reset, notify...
                                                              ▼
                              World / IslandView / PlantView / HUD / Menu
```

Cada objeto interactuable implementa `get_prompt()` e `interact(player, hit)`; opcionalmente
`get_remove_prompt()` / `remove_action()` (mantener X) y `continuous` (mantener E).

## Escena del mundo (`scenes/main.tscn` → `world.gd`)

- `EnvironmentController`: WorldEnvironment, cielo por shader (degradado, sol, estrellas,
  nubes arriba y abajo), sol/luna, niebla, nubes en MultiMesh, burbujas y luciérnagas.
  El ciclo día/noche dura 6 minutos; la saturación y la niebla dependen de la vitalidad.
- `IslandView` ×3: terreno procedural (malla + colisión cóncava desde los mismos
  triángulos), estanque con shader de agua refractiva, cristales de luz, parcelas, hierba y
  flores en MultiMesh (cantidad visible según vitalidad) y cúpula de bloqueo.
- `PlantView`, `StructureView`: modelos procedurales con animación; leen su diccionario de
  estado cada fotograma (escala por crecimiento, color por salud, floración).
- `Phenomena`: rocío, motas de luz, semillas flotantes y burbujas de oxígeno; imán del
  recolector y atracción de las torres recolectoras.
- `FaunaView`: un MultiMesh por especie (mariposas con alas por shader, peces, medusas).
- `BridgeView`: puentes de cristal transitables con barandillas.
- `Player` (`scenes/player.tscn`): CharacterBody3D, cámara, RayCast3D, herramienta en mano
  y modo construcción con previsualización validada.
- `HUD` (CanvasLayer): HUD, menú, diálogos, pantalla de título.

## Capas de colisión

| Capa | Uso |
|---|---|
| 1 | Mundo sólido: terreno, estructuras, cristales, puentes |
| 2 | Interacción: parcelas, plantas, estanque, fenómenos, cristales |
| 3 (valor 4) | Jugador |

El rayo del jugador usa la máscara 1|2 y detecta áreas.

## Rendimiento

- Simulación a 5 Hz con un máximo de 10 pasos por fotograma.
- Hierba, flores, nubes y fauna con MultiMesh; distancia de visibilidad en la hierba.
- Materiales y mallas compartidos y cacheados (`ProcMesh`).
- Parámetros por instancia (`instance uniform`) para salud/brillo sin duplicar materiales;
  solo se actualizan cuando cambian.
- Las parcelas comprueban su estado cada 0,3 s; el HUD se refresca a 10 Hz y el menú a 4 Hz.
- Radiancia del cielo de 64 px en modo incremental; sombras direccionales a 60 m con 2 cortes.
- La fauna visible se limita a 28 individuos por especie (la población simulada no tiene límite).

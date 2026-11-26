# Registro de desarrollo por fases

Cada fase se comprobó con Godot 4.3: importación del proyecto sin errores de script,
pruebas headless de sistemas (`tests/test_runner.tscn`) y partida automatizada con render
real Vulkan (`--autotest`, capturas de pantalla).

| Fase | Contenido | Estado |
|---|---|---|
| 1. Proyecto y mundo 3D | Proyecto Godot 4.3 Forward+, autoloads, islas flotantes procedurales (terreno con ruido, contorno irregular, base rocosa con vetas luminosas, estanque), cielo por shader, nubes, islotes decorativos | ✅ |
| 2. Movimiento e interacción | Primera persona (aceleración, carrera, salto, balanceo de cámara, pasos), rayo de interacción con indicaciones, mantener para acciones continuas o de eliminación, reaparición al caer al vacío | ✅ |
| 3. Primer recolectable | Agua del estanque, luz de cristales, rocío, motas de luz, semillas flotantes, burbujas de oxígeno, imán del recolector | ✅ |
| 4. Economía incremental | Recursos con capacidad, producción/consumo por segundo, costes exponenciales, formato de números grandes, nivel del ecosistema, misiones | ✅ |
| 5. Ecosistema dinámico | Cadena agua+luz → flora → oxígeno/esencia → fauna → polen/perlas/biodiversidad, salud, marchitamiento, extinción, sobrepoblación, equilibrio, vitalidad visual, día/noche | ✅ |
| 6. Mejoras y automatización | 14 mejoras, 5 mejoras permanentes, condensadores, prismas, dron sembrador, torre recolectora, nidos | ✅ |
| 7. Interfaz | HUD Aero (recursos y tasas, nivel, vitalidad, equilibrio, biodiversidad, reloj, objetivo, avisos, mira, barra de semilla/construcción, notificaciones), menú con 11 pestañas, árbol tecnológico dibujado, mapa, estadísticas, ajustes, título, diálogos | ✅ |
| 8. Expansión y desbloqueos | Expansión de la Isla Origen (×5, +4 parcelas cada una), 3 biomas, puentes de luz animados, cúpulas de bloqueo, especies exclusivas de bioma, renacimiento | ✅ |
| 9. Efectos visuales y sonido | Agua refractiva con espuma, cristal iridiscente, hierba con viento, hojas con barniz, glow, partículas (salpicaduras, floraciones, burbujas, luciérnagas), audio sintetizado y música generativa | ✅ |
| 10. Guardado, optimización y pruebas | JSON + copia de seguridad, autoguardado, progreso offline configurable, ajustes persistentes, MultiMesh, cachés de material, actualizaciones limitadas, pruebas automatizadas | ✅ |

## Problemas encontrados y corregidos durante las pruebas

- **Economía desbocada**: la simulación de balance mostró nivel 15 en 28 min porque
  Fotosíntesis era multiplicativa (×1,25^n, llegaba a ×400). Pasó a aditiva (+30 %/nivel),
  la polinización y la bonificación de fauna se redujeron, los niveles escalan ×6 y la
  fórmula de Ecos se suavizó.
- **Terreno blanco**: la franja de arena del estanque dependía de la altura y cubría casi
  toda la isla (el agua está a la misma altura que el terreno). Ahora depende de la
  distancia al estanque.
- **Menú vacío**: el contenedor del menú tenía tamaño cero (anclas sin offsets); se usa
  `set_anchors_and_offsets_preset`.
- **Indicación de interacción descentrada**: se ancló a todo el ancho de pantalla.
- **Colisión en modo headless**: `create_trimesh_shape()` depende del renderizador; la
  colisión del terreno se genera ahora desde los mismos triángulos de la malla.
- **Warnings tratados como errores** (inferencia desde Variant): tipos explícitos.
- **Hilo de audio al cerrar**: se espera la tarea del pad ambiental en `_exit_tree`.

## Resultados de la última ejecución

- `test_runner`: **104 comprobaciones, 0 fallos** (formato, datos, bucle inicial,
  desequilibrio, tecnología, estructuras, fauna, expansión, automatización, guardado,
  offline, renacimiento y simulación de balance de 40 min).
- `autoplay` con render real: **0 fallos** — movimiento, agua con E, semilla, plantar,
  regar, madurar, producción automática, compra desde el menú, todas las pestañas,
  investigación, expansión, colocación en modo construcción, fauna, cambio de vitalidad
  (7 % → ~67 %), día/atardecer/noche, puente y visita a la Isla Cristalina, guardar y cargar
  con reconstrucción del mundo.

## Limitaciones conocidas / siguientes pasos

- Las pruebas visuales se ejecutaron con renderizado por software (lavapipe, ~3 FPS);
  falta medir FPS en GPU real.
- Sin reasignación de teclas desde el menú (las acciones usan teclas físicas, válidas en
  QWERTY y AZERTY) ni soporte de mando.
- El contenido de la Isla Laguna (Coral Aéreo, Medusas) existe y es funcional, pero el
  tramo final de la progresión necesita más contenido y ajuste fino con jugadores reales.
- La música es un pad generativo sencillo; podría ampliarse con capas según el bioma.

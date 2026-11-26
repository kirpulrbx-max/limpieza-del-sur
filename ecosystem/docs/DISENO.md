# Documento de diseño

## Fantasía

Un "terrario en el cielo" con estética Frutiger Aero: agua cristalina, cristales
iridiscentes, burbujas, vegetación brillante y arquitectura blanca con cromo y neón.
El mundo empieza gris y apagado; cada decisión del jugador lo hace más vivo.

## Variables del ecosistema

| Variable | Fuentes | Consumidores |
|---|---|---|
| **Agua** | Estanque (manual, mantener E), rocío, filtración natural 0,12/s, Condensadores | Flora, peces, plantar (coste), regar brotes |
| **Luz** | Sol (0,5/s × luz del día), cristales (manual), motas de luz, Prismas (más de día) | Flora, medusas, algunas siembras |
| **Oxígeno** | Flora (madura 100 %, brote 15 %), burbujas | Fauna, tecnologías, introducir especies |
| **Biodiversidad** | Especies vivas: Σ valor × (1 + ln n), ×(1 + 0,15 por especie distinta) | — (es un índice) |

Recursos derivados: **Esencia** (moneda principal, de flora y fauna), **Semillas**
(fenómenos y plantas maduras), **Polen** (mariposas) y **Perlas** (peces). Moneda de
prestigio: **Ecos**.

## Multiplicadores

```
Esencia de flora = base × salud × fase × isla
                 × (1 + 0,3·Fotosíntesis)
                 × fauna polinizadora (1 + Σ n·bonus·(1 + 0,2·Polinización))
                 × biodiversidad (1 + 0,02·B)
                 × equilibrio (0,4 + 0,6·E)
                 × prestigio (1 + 0,03·Ecos)·(1 + 0,15·Eco resonante)
```

## Equilibrio y efectos negativos

- Satisfacción de la flora = min(agua disponible / demanda, luz disponible / demanda).
  La salud de cada planta tiende a esa satisfacción (cae despacio, se recupera rápido).
  Salud < 30 % = planta marchita (hojas caídas, color pardo, sin producción).
- Fauna: necesita oxígeno (y agua/luz según especie). Satisfacción < 60 % → la población
  decrece; < 0,5 individuos → extinción con aviso.
- Capacidad de hábitat: flora madura × hábitat de la especie × salud + Nidos de cristal
  (aéreo); estanques de islas desbloqueadas (acuático). Por encima de la capacidad la fauna
  decrece y, con más de un 20 % de exceso, **daña a la flora** (plaga).
- Equilibrio = 0,55·flora + 0,25·fauna + 0,2·(sin sobrepoblación). Multiplica la esencia
  y la vitalidad visual. Los avisos aparecen en el HUD (Sequía, Penumbra, Asfixia,
  Sobrepoblación, plantas marchitas, brotes sin regar).

## Progresión

- **Nivel del ecosistema** por esencia generada en el ciclo: nivel *n* requiere
  50·6^(n−2). Desbloquea tecnologías.
- **Vitalidad** (0–100 %) = 1 − e^−(0,08·plantas maduras + 0,025·B), ponderada por el
  equilibrio. Controla color del terreno, hierba y flores visibles, claridad del agua,
  saturación del cielo, niebla, burbujas ambientales y luciérnagas.
- **Mejoras** (14) con coste exponencial; **tecnologías** (15) en 5 columnas con requisitos.
- **Estructuras** (5): Condensador de rocío, Prisma solar, Sembrador autónomo (dron que
  siembra y riega), Recolector de burbujas (atrae fenómenos y cosecha floraciones),
  Nido de cristal (hábitat).
- **Flora** (4): Helecho Burbuja, Lirio Prisma, Árbol Aurora, Coral Aéreo (solo Laguna).
- **Fauna** (3): Mariposas de vidrio (polen, polinización), Peces burbuja (perlas),
  Medusas aéreas (mucha esencia).
- **Islas/biomas** (3): Isla Origen (pradera, expandible ×5), Isla Cristalina (luz ×1,6,
  esencia ×1,2), Isla Laguna (agua ×1,5, gran estanque). Se conectan con puentes de luz.
- **Floraciones**: cada planta madura sana acumula una floración que se cosecha a mano
  (15 s de producción de golpe) o automáticamente al 75 % con el Recolector.
- **Renacimiento**: Ecos = ⌊√(esencia del ciclo / 50 000)⌋. Mejoras permanentes:
  Eco resonante, Semillero ancestral, Raíz veloz, Memoria del suelo, Conocimiento heredado.
- **Misiones**: 23 objetivos guiados con recompensa y después misiones infinitas.

## Ritmo (simulación de balance incluida en las pruebas)

Un jugador modelo eficiente alcanza aproximadamente: nivel 2 en 1,5 min, Condensación en
2 min, Botánica en 7 min, Automatización en 11 min, puente a la Isla Cristalina en 14 min,
nivel 6 (renacimiento disponible) en 15 min y nivel 9 en 40 min. Un jugador humano, que
camina y explora, tarda bastante más; el renacimiento y los Ecos extienden la partida.

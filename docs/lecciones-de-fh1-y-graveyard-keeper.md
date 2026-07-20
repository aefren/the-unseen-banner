# Lecciones de F&H1 y Graveyard Keeper aplicables a Battle Brothers

Destilado (jul 2026) de la experiencia real de los dos mods anteriores:

- **Fear & Hunger 1** (`D:\repos\project_accessibility`) — RPG Maker MV / NW.js.
  17 plugins JS, mod **terminado y verificado** con NVDA y con la traducción
  española. La técnica central (árbol ARIA / `aria-live`) NO se traslada a Battle
  Brothers, pero casi todo el diseño de sonares, colas de voz y detección sí.
- **Graveyard Keeper** (`D:\repos\grabeyard_keeper_accessibility`) — Unity Mono /
  BepInEx / HarmonyX / Tolk. **En curso** (fases 0–3 implementadas). Su
  arquitectura por capas y su puente Tolk son el modelo directo para la app
  compañera de Battle Brothers.

Este documento recoge lo que costó aprender allí para no repagarlo aquí. La
arquitectura concreta de Battle Brothers está en
[arquitectura-propuesta-y-roadmap.md](arquitectura-propuesta-y-roadmap.md).

---

## 1. Diseño de la voz (la lección más cara de F&H1)

### Dos canales de habla, nunca uno

En F&H1 el bug más grave del proyecto (PLAN 1.6/1.7) fue tratar todos los
anuncios igual. El diseño final, que debe replicarse en la app compañera:

- **Canal "interrupt" (el último gana):** navegación por cursor/foco. Al
  recorrer una lista rápido, el jugador quiere oír SOLO el elemento actual;
  cada anuncio cancela el anterior. Usarlo para: foco de menús, casilla bajo
  el cursor de hexágonos, tooltip actual.
- **Canal "cola FIFO" (nada se descarta):** eventos del juego. Dos eventos en
  el mismo frame ("recibes moneda" + "recibes arma") deben sonar AMBOS en
  orden; descartar en silencio es el fallo invisible más difícil de detectar.
  Usarlo para: log de combate, resultado de acciones, notificaciones.
- Un anuncio interrupt **vacía y cancela** la cola FIFO pendiente (para que no
  hable por encima ni después del foco nuevo).

### De-duplicación con ventana corta

En Graveyard Keeper, foco de mando y hover de ratón disparan para el mismo
elemento en el mismo frame: `Speech` de-duplica anuncios idénticos en una
ventana de 0,15 s. En Battle Brothers pasará igual (evento Squirrel + mutación
del DOM describiendo lo mismo): de-duplicar SIEMPRE en la capa de voz, no en
cada hook.

### La capa de voz nunca tira el juego

`Speech.cs` de GK es el patrón: envoltorio defensivo, único punto por el que
se habla, degrada a silencio si Tolk falla, `Tolk_TrySAPI(true)` antes de
`Tolk_Load` para que SAPI sea fallback real sin lector activo. Trampa concreta
de Tolk ya sufrida: `Tolk_DetectScreenReader` devuelve memoria propiedad de
Tolk — leerla con `Marshal.PtrToStringUni`, jamás marshalearla como string de
retorno (libera el puntero de Tolk y revienta el proceso).

### Limpiar el texto antes de hablar

En F&H1, los códigos de escape (`\N[n]`, `\c[n]`) llegaban crudos al lector y
NVDA leía "N4" en vez del nombre (PLAN 3.6). El equivalente en Battle Brothers:
el texto de la UI lleva **etiquetas BBCode propias** (`[color=...]`,
`[img]...[/img]`, saltos) y los tooltips mezclan iconos con texto. Regla: toda
cadena pasa por un `clean()` central que quita marcado y sustituye iconos por
palabras ANTES de llegar a la capa de voz. En GK lo hace `UiText.Clean()`
(quita las etiquetas `[...]` de NGUI); aquí tocará su gemelo para el HTML de
Coherent (leer `textContent`, mapear `<img>` conocidos a texto).

### Leer el texto final renderizado, no re-localizar

Lección de GK: leer `UILabel.text` (ya localizado y con parámetros
sustituidos), nunca reconstruir el string desde claves de localización. En
Battle Brothers igual: leer el DOM ya renderizado siempre que se pueda, y solo
ir a los datos Squirrel cuando el dato no esté en pantalla.

### Los textos propios del mod, centralizados y traducibles

`L10n.cs` de GK: cada string que el mod dice por sí mismo (prefijos,
categorías, direcciones, "puerta", "enemigo cerca") vive en un módulo único
con defaults en inglés y override por archivo `lang/es.lang`. Nunca hardcodear
un string hablado en un hook. F&H1 no lo hizo así y la compatibilidad con la
traducción española (PLAN 6.6) costó una auditoría entera de regex bilingües.

---

## 2. Diseño del sonar (F&H1, portado ya una vez a GK)

La capa de sonar de F&H1 se portó a Graveyard Keeper con éxito; tercera
iteración aquí (para el mapamundi). El vocabulario sonoro ya validado por el
usuario, mantenerlo idéntico para que la curva de aprendizaje sea cero:

- **Pan** = desplazamiento horizontal; **pitch** = vertical (arriba agudo,
  abajo grave); **volumen + cadencia** = distancia (cerca fuerte/rápido).
- **Timer por objetivo** + purga al cambiar de escena/mapa.
- **Cooldown global anti-solapamiento** (~½ s): si vencen varios a la vez,
  suena primero el más cercano, los demás esperan hueco sin reiniciar espera.
  Imprescindible donde hay densidad (en F&H1, salas con decenas de cajas).
- **Jerarquía de volumen por importancia:** amenazas > landmarks > botín >
  información. Cada categoría con su SE distinto.
- **Beacon activo sin filtros:** una vez el jugador elige un destino, el
  beacon lo sigue guiando aunque salga de rango o pase tras un obstáculo
  (decisión de diseño confirmada con el usuario en F&H1).

### Paridad de percepción

El principio que gobernó las fases finales de F&H1: **no delatar lo que un
jugador vidente no percibiría**, ni ocultar lo que sí. De ahí los filtros
`Max Range` + línea de visión (Bresenham contra tiles-muro) y el recorte por
iluminación (5.21). En Battle Brothers el equivalente en el mapamundi es la
**niebla de guerra / rango de visión de la compañía**: el sonar solo debe
pingar lo que el juego considera avistado.

### Herramienta activa vs sentido pasivo

Distinción que emergió en F&H1 (5.22): los sonares siempre-activos y el
"vistazo rápido" (A/S) son símil de visión → se recortan por percepción; el
menú-lista completo que se abre a propósito es una herramienta de
reconocimiento → rango completo. Mantener esa distinción al diseñar teclas.

### Estado a demanda, no spam de redibujados

Nunca hookear redibujados de paneles de estado para narrarlos (hablan sin
parar). Patrón validado dos veces: **una tecla = un readout** (Tab para la
party, Shift+Tab para enemigos en F&H1; View/Back+RT para el HUD en GK). En
combate de Battle Brothers: una tecla para el estado del hermano activo, otra
para el resumen del campo (orden de turnos, enemigos vivos).

---

## 3. Detección de objetivos (metodología F&H1)

Aunque el motor cambie, el método es el mismo y está muy rodado:

1. **Detectar por forma/marcador, nunca por coordenadas** ni listas fijas:
   en F&H1, "contenedor = evento cuyo texto casa con 'You search the'";
   en Battle Brothers será "poblado = entidad con tal script/propiedad".
   La detección en runtime se auto-adapta a DLCs y mods.
2. **Auditar contra los datos completos antes de dar un detector por bueno.**
   En F&H1 cada detector se validó recorriendo los 170 mapas reales y contando
   aciertos/falsos positivos exactos. En Battle Brothers el equivalente es
   auditar los `.nut` decompilados (massdecompile) y el DOM de cada pantalla.
3. **Esperar dos rondas de falsos positivos.** En F&H1 el sonar de enemigos
   necesitó tres pasadas (5.10 → 5.13 → 5.23): la detección genérica atrapa
   puertas-emboscada, cutscenes, triggers condicionales que casi nunca
   disparan… La regla limpia sale de auditar los casos reales, no de razonar
   en abstracto.
4. **El estado vivo manda:** leer la página/estado ACTIVO del objetivo, de
   modo que un contenedor saqueado se silencia solo y un enemigo muerto pasa
   de "enemigo" a "cadáver" sin código extra.

---

## 4. Metodología de trabajo

- **Hookear el punto de embudo.** Antes de hookear pantalla a pantalla,
  buscar la función por la que TODO pasa: en F&H1 `Window_Command.select` y
  `drawGabText` cubrieron docenas de pantallas; en GK,
  `GamepadNavigationItem.Focus` anuncia cualquier pantalla navegada con mando.
  En Battle Brothers los candidatos a embudo son el sistema de **tooltips**
  (todo objeto con información pasa por ahí) y el **log de combate**.
- **Modo diagnóstico conmutable.** `Diagnostics.cs` de GK: logging apagado por
  defecto que, activado, registra qué métodos disparan y qué texto encuentra
  el extractor. Es LA herramienta para mapear una pantalla desconocida.
  Equivalente aquí: hooks Squirrel de traza + el Awesome UI Inspector.
- **Un archivo por preocupación**, y los hooks solo narran: la lógica de
  extracción de texto y la de voz viven en módulos compartidos.
- **Nada está hecho hasta oírlo con NVDA en el juego.** Disciplina literal del
  PLAN de F&H1: cada ítem queda "pendiente de verificar" hasta la prueba real.
  Compilar/no petar no es verificar. El usuario (jugador ciego real) valida.
- **Toda constante afinable, en config** sin recompilar: rangos, cadencias,
  volúmenes, teclas (en GK, el `.cfg` de BepInEx; aquí, el config de la app
  compañera). Los valores buenos salen de probar, no de la primera estimación.
- **Copia local de desarrollo + instalador dev.** Ya documentado en
  [desarrollo-copia-local-sin-steam.md](desarrollo-copia-local-sin-steam.md);
  App ID de Battle Brothers: `365360`. Scripts `dev-install`/`dev-uninstall`
  separados de los de distribución, como en los dos proyectos anteriores.
- **El mod solo AÑADE archivos, nunca modifica los del juego.** En Battle
  Brothers esto lo garantiza Modern Hooks/MSU (parcheo en runtime con colas de
  compatibilidad) — no sobrescribir `.cnut` sueltos aunque sea más rápido.

---

## 5. Diferencias clave que Battle Brothers introduce (trabajo nuevo)

Lo que NO está resuelto por la experiencia previa, para no subestimarlo:

1. **El puente al lector no existe todavía.** F&H1 lo tenía gratis (árbol
   ARIA de NW.js); GK lo tiene en-proceso (Tolk por P/Invoke desde el propio
   plugin). Aquí la UI vive en un Chromium embebido (CoherentUIGT) que
   renderiza a textura: sin ARIA y, en principio, sin cargar DLLs propias.
   El plan de puente (WebSocket → tail de log → DLL nativa) es la **primera
   incógnita a despejar**, antes de escribir ningún hook de contenido.
2. **"Narrar, no navegar" puede no bastar.** GK tenía navegación completa de
   mando que solo había que sonorizar; F&H1 era 100 % teclado. Battle Brothers
   es un juego **de ratón**: los atajos de teclado existen en combate (skills
   numeradas, fin de turno…) pero los menús de gestión, la contratación o el
   mapamundi asumen puntero. Hay que asumir que una parte del proyecto será
   **construir navegación por teclado** (foco virtual sobre el DOM, cursor de
   hexágonos, cursor de mapamundi), no solo narrarla. Es la diferencia de
   alcance más importante respecto a los dos proyectos anteriores.
3. **JS en ES3** (Chromium 48): sin `let/const`, arrows, template literals ni
   APIs modernas en el código inyectado en la UI. Escribir ese código como en
   2005 o transpilar.
4. **Tiempo real pausable en el mapamundi.** F&H1 era todo por turnos; GK es
   tiempo real y su sonar ya lo maneja, pero aquí además la pausa es una
   herramienta de accesibilidad de primera clase: pausar → interrogar el
   mundo → reanudar. Diseñar los readouts del mapamundi asumiendo pausa libre.

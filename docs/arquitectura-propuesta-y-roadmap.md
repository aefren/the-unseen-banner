# Arquitectura propuesta y roadmap — mod de accesibilidad de Battle Brothers

Estado: **borrador inicial** (jul 2026), derivado de la ficha de prospección
(`prospections/prospect/battle-brothers.md`) y de la experiencia de F&H1 y
Graveyard Keeper ([lecciones-de-fh1-y-graveyard-keeper.md](lecciones-de-fh1-y-graveyard-keeper.md)).
Se irá corrigiendo conforme se verifiquen cosas en el juego real.

## El terreno

Motor C++ propio de Overhype, pero con **dos capas de script accesibles y
comunicadas entre sí**:

| Capa | Tecnología | Qué vive ahí | Cómo se toca |
|---|---|---|---|
| Lógica | **Squirrel** (`.nut` → `.cnut` encriptados en los `.dat`) | Combate, eventos, mundo, datos de personajes | Hooks con **Modern Hooks / MSU** |
| UI | **HTML/CSS/JS** en Chromium 48 embebido (**CoherentUIGT**) | TODO el texto en pantalla: menús, tooltips, log de combate, eventos | JS inyectado que lee/observa el DOM |

Puntos clave verificados en la prospección:

- Squirrel ↔ JS se comunican en ambos sentidos: se puede leer estado de juego
  desde la UI y viceversa.
- Coherent renderiza a textura: **no hay árbol ARIA** ni ventana de navegador
  que un lector pueda ver. De ahí la necesidad de un puente propio.
- JS limitado a **ES3** (Chromium 48).
- El juego está **terminado** (último DLC 2021): los anclajes no caducan.
- El log del juego se escribe como HTML en
  `Documentos\Battle Brothers\log.html` (`::logInfo` desde Squirrel).
  Ruta verificada en esta máquina (Documentos redirigido a OneDrive):
  `C:\Users\alfre\OneDrive\Documentos\Battle Brothers\log.html`.

## Herramientas

- [Mod kit de Adam Milazzo](https://www.adammil.net/blog/v133_Battle_Brothers_mod_kit.html)
  — `bbsq` (desencripta `.cnut`) + `nutcracker` (decompila) + `massdecompile`.
  El "dnSpy" de este juego: primer paso de cualquier investigación.
- [Modern Hooks](https://www.nexusmods.com/battlebrothers/mods/685) +
  [MSU](https://github.com/MSUTeam/MSU) — framework de hooking Squirrel sin
  sobrescribir archivos, con [documentación de UI modding](https://bbmodding.enduriel.com/docs/concepts/ui-modding/).
- [Awesome UI Inspector](https://www.nexusmods.com/battlebrothers/mods/744) —
  devtools del DOM de Coherent en vivo. Nuestro `Diagnostics` de esta era.
- [bbkit](https://github.com/Enduriel/bbkit) — flujo de trabajo de build/pack.

## Arquitectura propuesta

```
[ Battle Brothers ]
  Squirrel (Modern Hooks) ──┐            eventos de juego (combate, mundo, eventos)
  JS inyectado en la UI  ───┤            foco/tooltips/DOM (texto ya renderizado)
                            ▼
                     PUENTE (a decidir en fase 0)
                            ▼
              [ App compañera (C#) ]
      Speech (cola FIFO + interrupt, dedupe, clean)
                 Tolk → NVDA / SAPI
              Audio posicional (sonar)
```

- **App compañera en C#**: reutiliza tal cual `Tolk.cs`, `Speech.cs` y el
  patrón `L10n` de Graveyard Keeper (incluida la trampa de
  `Marshal.PtrToStringUni`). Proceso aparte que se lanza junto al juego.
- **Protocolo de mensajes** entre juego y compañera: JSON de una línea con
  `{canal: "interrupt"|"queue"|"sonar", texto|categoria, ...}` — pensado para
  que funcione igual por WebSocket o por líneas añadidas a un archivo, de modo
  que cambiar de puente no cambie los hooks.

### El puente, en orden de preferencia (fase 0 decide)

1. **WebSocket/XHR desde el Chromium embebido** a `localhost`. Si Coherent lo
   permite, es el puente en vivo y limpio. Verificar PRIMERO — es la incógnita
   señalada en la ficha.
2. **Tail del log**: Squirrel escribe con `::logInfo` a `log.html`; la
   compañera hace tail y parsea nuestras líneas marcadas. A prueba de todo,
   latencia algo mayor. **Plan B garantizado** — vale incluso como puente
   provisional para empezar las fases 1+ mientras se investiga el 1.
3. **Inyección DLL nativa** con Tolk dentro del proceso. La vía "pro", solo si
   1 y 2 se quedan cortos (latencia o volumen de datos).

### División del trabajo entre capas

- **JS (DOM)**: lo que ya está en pantalla — tooltips, fichas, textos de
  evento, log de combate visible, foco. Regla de F&H1/GK: leer el texto final
  renderizado. `MutationObserver` existe en Chromium 48; verificar en fase 0.
- **Squirrel (hooks)**: lo que no está en pantalla o llega antes/mejor por
  datos — resultado de tiradas, estado completo de un hermano, entidades del
  mapamundi con posición (para el sonar), turno activo.
- Ante la duda, DOM primero (menos frágil, texto ya localizado y formateado).

## Roadmap por fases

Mismo esqueleto que funcionó dos veces: primero el canal de voz, luego texto
puro, luego menús, luego combate, luego mundo, luego pulido. Cada ítem queda
"pendiente" hasta verificarlo con NVDA en el juego real.

### Fase 0 — El puente (bloqueante, todo lo demás depende de esto)

- [x] 0.1 Copia local + `steam_appid.txt` = `365360`
      (ver [desarrollo-copia-local-sin-steam.md](desarrollo-copia-local-sin-steam.md)).
- [x] 0.2 Instalar Modern Hooks + MSU + UI Inspector; confirmar que un hook
      Squirrel trivial y un JS inyectado trivial corren en nuestra copia.
      **Hecho** (jul 2026): Modern Hooks 0.6.0 + MSU 1.9.0 (zips de GitHub,
      instalados en `plugin/`) y `mod/` en el repo con el smoke test: preload,
      función encolada, hook de clase sobre `root_state` y JS inyectado que
      llama de vuelta a Squirrel — las cuatro señales visibles en `log.html`
      sin errores. Bonus: el viaje JS→Squirrel ya funciona (`registerScreen` +
      `::UI.connect` + `SQ.call`), lo que despeja parte del 0.4.
      *Nota:* la verificación se hizo con los zips en `data/`; después se fijó
      la regla de no tocar la carpeta del juego y los zips viven en `plugin/`.
      Cómo los carga el juego desde ahí (junction, copia al lanzar…) queda
      para 0.4/0.6 — el motor solo escanea `data/`.
      *Pendiente:* Awesome UI Inspector solo está en Nexus (mod 744) y
      requiere descarga manual con cuenta.
- [ ] 0.3 `massdecompile` sobre los `.dat` → árbol de `.nut` legibles en el
      repo (gitignorado: es código del juego con copyright).
- [ ] 0.4 **Spike del puente:** ¿permite Coherent WebSocket/XHR a localhost?
      ¿Funciona `MutationObserver`? Si no → medir latencia del tail de
      `log.html`. Decidir puente y congelar el protocolo de mensajes.
- [x] 0.5 App compañera mínima: recibe mensaje → lo habla por Tolk. Oír
      "Battle Brothers accessibility loaded" con NVDA al arrancar el juego.
      **Hecho**: `companion/` habla por Tolk/NVDA al arrancar (verificado).
- [ ] 0.6 Scripts `dev-install`/`dev-uninstall` + build empaquetable.

### Fase 1 — Texto puro (máximo valor / mínimo riesgo)

Los **eventos de texto** son la joya narrativa del juego y son solo texto +
opciones: el equivalente a los diálogos de F&H1.

- [ ] 1.1 Pantalla de evento: narrar título + cuerpo al abrirse, opciones al
      enfocarlas (canal interrupt), resultado al elegir (canal cola).
- [ ] 1.2 Menú principal y opciones.
- [ ] 1.3 Navegación por teclado de los eventos si el foco es solo-ratón
      (primer contacto con el problema de navegación — empezar aquí porque
      son listas simples de opciones).

### Fase 2 — Tooltips y gestión de la compañía

El tooltip es el punto de embudo de la información en este juego (perks,
objetos, estados, terreno… todo vive ahí).

- [ ] 2.1 Hook genérico de tooltip: capturar el DOM del tooltip al mostrarse,
      limpiar BBCode/iconos, narrar. Debería cubrir decenas de pantallas de
      golpe, como `Window_Command.select` en F&H1.
- [ ] 2.2 Ficha de hermano: stats, perks, equipo, heridas, moral (readout
      ordenado, no lectura del layout).
- [ ] 2.3 Inventario y mercado: objeto enfocado + precio + comparación.
- [ ] 2.4 Navegación por teclado de las rejillas de gestión (foco virtual
      sobre el DOM). La parte de más diseño nuevo del proyecto.

### Fase 3 — Combate táctico (por turnos = narrable al completo)

- [ ] 3.1 Log de combate → canal cola (cada línea, limpia, en orden — la
      lección FIFO de F&H1 aplica literalmente).
- [ ] 3.2 Cursor de hexágonos por teclado: casilla enfocada → terreno, altura,
      ocupante, distancia y dirección respecto al hermano activo (interrupt).
- [ ] 3.3 Skills del hermano activo (ya tienen atajos numéricos): narrar
      selección, objetivos válidos y % de acierto antes de confirmar.
- [ ] 3.4 Readouts a demanda: tecla para estado del hermano activo, tecla para
      orden de turnos, tecla para resumen de enemigos (patrón Tab/Shift+Tab).
- [ ] 3.5 Inicio/fin de turno, moral, heridas y muertes como eventos hablados.

### Fase 4 — Mapamundi (tiempo real pausable)

- [ ] 4.1 Sonar posicional vía app compañera: poblados, contratos, partidas
      enemigas, lugares — pan/pitch/volumen/cadencia idénticos a F&H1/GK,
      cooldown anti-solapamiento, jerarquía amenaza > landmark > botín.
- [ ] 4.2 Paridad de percepción: solo pingar lo avistado (niebla de guerra).
- [ ] 4.3 Lista de cercanos navegable + beacon persistente al elegir destino
      (portar `NearbyList` de GK).
- [ ] 4.4 Readout de pausa: contrato activo, destino, dinero, comida, moral
      de la compañía, días restantes.
- [ ] 4.5 Pantalla de ciudad: edificios, reclutas, contratos.

### Fase 5 — Pulido y distribución

- [ ] 5.1 Verbosidad configurable + todos los parámetros en config.
- [ ] 5.2 Pantallas especiales no cubiertas (creación de compañía, ambiciones,
      pantalla de fin, orígenes de DLC).
- [ ] 5.3 Empaquetar para Nexus (formato mod estándar + app compañera).
- [ ] 5.4 Publicar en audiogames.net, buscar testers ciegos, iterar.

## Riesgos abiertos (de la ficha, a vigilar)

- El puente Chromium→lector es LA incógnita; por eso la fase 0 lo ataca antes
  que nada y el tail del log queda como plan B garantizado.
- ES3 en la capa JS: molesto, no bloqueante.
- Sin precedente de mod de accesibilidad en este juego (verificado jul 2026):
  terreno pionero — revisar Nexus de vez en cuando por si aparece algo.
- Navegación por teclado sobre UI de ratón: el mayor volumen de trabajo nuevo;
  las fases la introducen gradualmente (listas → rejillas → hexágonos → mapa).

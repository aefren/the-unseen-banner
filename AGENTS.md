# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Qué es este proyecto

**The Unseen Banner** — mod de accesibilidad para jugadores ciegos de *Battle Brothers*.
Tercer proyecto de una serie: precede *Fear & Hunger 1* (`D:\repos\project_accessibility`,
terminado) y *Graveyard Keeper* (`D:\repos\grabeyard_keeper_accessibility`, en curso),
de donde se portan directamente los patrones de voz, sonar y localización.

El idioma del proyecto es el **español** (docs y mensajes de commit). Los textos que
el mod dice al jugador son **inglés por defecto**, traducibles vía `L10n`.

## Comandos

```bash
# Compilar la app compañera
cd companion && dotnet build -c Debug

# Ejecutarla (habla por Tolk al arrancar; requiere NVDA o SAPI)
cd companion/bin/Debug/net8.0 && ./TheUnseenBanner.Companion.exe

# Lanzar juego + app compañera en desarrollo (ver docs/desarrollo-copia-local.md)
./play.bat
```

No hay tests todavía. `dotnet build` con 0 warnings es el listón mínimo, pero
**no es verificación** (ver "Disciplina de verificación").

## Arquitectura

El juego tiene **dos capas de script**, ambas modificables, que se comunican en
los dos sentidos:

| Capa | Tecnología | Contenido | Cómo se toca |
|---|---|---|---|
| Lógica | Squirrel (`.nut` → `.cnut` encriptados en `data/*.dat`) | Combate, mundo, eventos, datos | Modern Hooks / MSU |
| UI | HTML/CSS/JS en Chromium 48 embebido (CoherentUIGT) | **Todo** el texto en pantalla | JS inyectado que lee el DOM |

**El problema central**: Coherent renderiza a textura — no hay árbol ARIA ni ventana
que un lector de pantalla pueda ver. De ahí la arquitectura de tres piezas:

```
hooks Squirrel + JS que lee el DOM  →  PUENTE (sin decidir)  →  app compañera C# → Tolk → NVDA
```

**El puente es la incógnita bloqueante** (tarea 0.4 del roadmap), en orden de
preferencia: (1) WebSocket/XHR desde Coherent a localhost, (2) tail de
`Documentos\Battle Brothers\log.html` como plan B garantizado, (3) DLL nativa.
El protocolo de mensajes (JSON de una línea, `{canal, texto|categoria}`) está
pensado para que cambiar de puente no obligue a tocar los hooks.

### Estado actual

**Fase 0 completa** (jul 2026). Lo esencial:

- 0.3: juego decompilado en `decompiled/` (3.107 `.nut` + los 239 JS/CSS de
  `ui/`, sin minificar); kit de Adam Milazzo en `tools/`. Un solo `.cnut`
  falla (evento dlc4, bug de NutCracker).
- 0.4: **puente decidido = tail de `log.html`** (100 ms de polling,
  `LogBridge.cs`), protocolo `UB_MSG:{"canal","texto"}` emitido solo por
  `::UnseenBanner.sendMessage`. Latencia verificada de oído: imperceptible.
- Hallazgo clave: el motor **no** entrega teclado al DOM de Coherent; las
  teclas se capturan en Squirrel (`onKeyInput` del estado; códigos del enum
  del motor en `KeyMapSQ` de MSU) y se reenvían al JS vía `asyncCall`.
- 1.2 parcial: cursor de teclado sobre el menú principal funcionando y
  verificado (flechas + Enter, canal interrupt).
- 0.6: falta solo el empaquetado para Nexus (→ 5.3).

El log verificado está en `C:\Users\alfre\OneDrive\Documentos\Battle Brothers\log.html`.

**Cómo se lanza el juego en desarrollo**: `dev_install.bat` y luego `play.bat`.
El detalle del launcher de desarrollo, el debugger de Coherent
(`127.0.0.1:19999`, WebSocket DevTools en `/devtools/page/0`) y el UI Inspector
está en `docs/desarrollo-copia-local.md`.

El roadmap completo por fases está en [docs/arquitectura-propuesta-y-roadmap.md](docs/arquitectura-propuesta-y-roadmap.md).
**Léelo antes de planificar trabajo nuevo**, junto con
[docs/lecciones-de-fh1-y-graveyard-keeper.md](docs/lecciones-de-fh1-y-graveyard-keeper.md),
que destila lo aprendido en los dos mods anteriores. La carpeta `docs/` entera
es **documentación interna, gitignorada**: existe solo en local, no en GitHub.

### Estructura

- `mod/` — el mod en sí (Squirrel + JS). `scripts/!mods_preload/` registra con
  Modern Hooks; `ui/mods/mod_unseen_banner/` es el JS inyectado (ES3). Se
  empaqueta como zip en `plugin/` (lo hace `dev_install.bat`).
- `companion/` — app compañera .NET 8 x64, proceso aparte del juego.
  `Tolk.cs` (P/Invoke), `Speech.cs` (envoltorio defensivo), `L10n.cs` (strings propios).
- `plugin/` — **todo lo instalable del mod**: los zips de Modern Hooks, MSU y
  `mod_unseen_banner.zip` (gitignorados como `*.zip`; se regeneran/redescargan),
  más `Tolk.dll` + `nvdaControllerClient64.dll`, versionadas; el `.csproj`
  las copia al output. Las DLL son de **64 bits**: valen para la compañera
  (proceso aparte), pero la vía 3 del puente (DLL inyectada en el juego, que es
  de 32 bits) necesitaría las variantes de 32.
- `docs/` — arquitectura, lecciones previas, recetas de desarrollo.
  **Gitignorada** (documentación interna, solo local).
- `Battle Brothers/` — copia local del juego. **Gitignorada** (copyright), igual que
  `decompiled/` (los `.nut` decompilados) y `tools/`. Se reproduce a mano en cada
  máquina; ver [docs/desarrollo-copia-local.md](docs/desarrollo-copia-local.md).

## Convenciones que vienen de sangre derramada

Estas reglas salieron de bugs reales en F&H1 y GK. No reinventarlas:

- **Dos canales de voz, nunca uno.** *Interrupt* (el último gana) para navegación de
  foco/cursor; *cola FIFO* (nada se descarta) para eventos de juego. Un interrupt
  vacía la cola. Tratar todo igual fue el peor bug de F&H1.
- **De-duplicar en la capa de voz**, no en cada hook (ventana de 0,15 s): dos fuentes
  independientes describirán el mismo evento en el mismo frame.
- **La capa de voz nunca tira el proceso.** Todo pasa por `Speech`; si Tolk falla,
  degrada a silencio. Trampa concreta ya sufrida: `Tolk_DetectScreenReader` devuelve
  memoria propiedad de Tolk — leerla con `Marshal.PtrToStringUni`, **jamás** declararla
  como return `LPWStr` (el CLR la libera y revienta el proceso sin excepción manejada).
- **`clean()` central antes de hablar.** El texto del juego lleva BBCode (`[color=...]`,
  `[img]`) e iconos; toda cadena se limpia en un único sitio, nunca en el hook.
- **Leer el texto ya renderizado** (`textContent` del DOM), nunca reconstruirlo desde
  claves de localización. Ir a datos Squirrel solo cuando el dato no esté en pantalla.
- **Ningún string hablado se hardcodea en un hook** — va a `L10n` con default en inglés
  y override en `lang/<código>.lang`. Saltarse esto costó una auditoría entera en F&H1.
- **Hookear el punto de embudo**, no pantalla a pantalla. Candidatos aquí: el sistema
  de tooltips y el log de combate.
- **La carpeta del juego (`Battle Brothers/`) no se toca a mano NUNCA.** Todo
  lo instalable (nuestro zip, Modern Hooks, MSU, UI Inspector) vive y se
  desarrolla en `plugin/` en la raíz del repo. El único camino hacia el juego
  son dos scripts (tarea 0.6): `dev_install.bat` copia lo de `plugin/` a la
  carpeta desde donde el juego carga mods (`Battle Brothers/data/`), y
  `dev_uninstall_mod.bat` lo retira dejando el juego como vino. Así la
  instalación es siempre reversible y auditable. Y dentro del mod, la regla de
  siempre: solo añadir vía Modern Hooks/MSU, jamás sobrescribir `.cnut` del
  juego.
- **Toda constante afinable va a config** (rangos, cadencias, volúmenes, teclas).
- **JS inyectado en ES3**: Chromium 48, sin `let/const`, arrows ni template literals.

## Disciplina de verificación

**Nada está hecho hasta oírlo con NVDA en el juego.** Compilar sin errores no es
verificar; el usuario es jugador ciego real y es quien valida. Al terminar un ítem,
pedir confirmación auditiva explícita antes de darlo por bueno o hacer commit.

## Commits

- Mensajes **en inglés**, cuerpo explicando el porqué.
- **Sin co-autoría**: no añadir `Co-Authored-By`, ni "Generated with Codex",
  ni ningún trailer. El único autor es `alfred <alfred.hl@gmail.com>`.

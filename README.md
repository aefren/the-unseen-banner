# The Unseen Banner

**An accessibility mod for blind players of *Battle Brothers*.**

Battle Brothers does not draw its interface as text a screen reader can read:
the whole game renders to a texture inside an embedded Chromium, with no
accessibility tree. The Unseen Banner adds a layer that reads the game's real
state and speaks it aloud through your screen reader (NVDA or a SAPI voice),
plus a set of keys to navigate the menus, the events and tactical combat
without a mouse.

It is the third mod in an accessibility series, after *Fear & Hunger 1* and
*Graveyard Keeper*, from which it inherits the speech and localization patterns.

> **Language:** the mod speaks **English** by default (translatable via `L10n`;
> see below).

---

## Current status

Here is what is **already playable by ear** and what is **not yet**. Be realistic
before starting a serious campaign:

- ✅ **Main menu, options, starting a new campaign.** Navigable and narrated.
- ✅ **Loading and saving campaigns** (main menu and world-map pause menu).
- ✅ **Text events** (the narrative part): title, body and options.
- ✅ **Tactical combat**: the most complete part. Tile cursor, skills with valid
  targets and hit chance, combat log, brother status, turn order, character
  sheet, result screen and loot.
- ⚠️ **World map**: only a company-status readout (the G key). **Missing** the
  positional sonar (settlements, contracts, enemy parties, locations), the nearby
  list and the town screens. Moving around the map is not comfortable blind yet.
- ❌ **Company management** (inventory, market, world-map character sheet,
  recruitment, ambitions): **not accessible yet**.
- ❌ **Pre-battle deployment** (arranging your formation before a fight): still
  mouse-only.

In short: **tactical combat is well covered**, but the world map and
between-battle management still have significant gaps. It is not that the game is
"only playable up to the tutorial" — it is that some surfaces are done and others
are not (see the [Roadmap](#roadmap)).

---

## Requirements

- **Battle Brothers** (the base game; the mod does not include it).
- **Windows**.
- **A screen reader**: **NVDA** (recommended) or a system **SAPI** voice.
- The **Tolk** speech engine and `nvdaControllerClient64.dll` ship with the mod.
- The companion app targets .NET 8 (x64).

---

## Installation and how to play

> ⚠️ **There is no Nexus install package yet** (roadmap task 5.3). For now the
> installation is the development one. The game folder is never touched by hand:
> everything is copied in and out by scripts, reversibly.

1. Run `dev_install.bat`. It repackages the mod and copies what is needed (Modern
   Hooks, MSU, our zip and the speech DLLs) into the folder the game loads mods
   from.
2. Run `play.bat`. It launches both the **voice companion app** and the **game**
   at once. On startup you will hear a confirmation through your screen reader.
3. To uninstall and leave the game as it was: `dev_uninstall_mod.bat`.

The companion app (`TheUnseenBanner.Companion.exe`) runs as a separate process
from the game: it reads what the mod emits and speaks it. If your screen reader
or Tolk fail, it degrades to silence without bringing the game down.

### Translating to another language

Everything the mod says comes from `companion/L10n.cs`, with the English defaults
compiled in. To translate, create a plain-text file `lang/<code>.lang` next to the
companion executable (for example `lang/es.lang`), with one `key = value` line per
string. Missing keys fall back to English, so a partial translation is safe.

---

## Keys

The engine does not deliver the keyboard to the game's DOM, so the mod captures
keys and narrates the action. Where a mod key overlaps a native shortcut, the mod
acts on it and consumes the press during your turn.

### General navigation (menus, lists, character sheet)

| Key | Action |
|---|---|
| Up / Down arrows | Move through the list or options, one entry at a time |
| Left / Right arrows | Switch tabs, adjust sliders and resolution |
| Enter | Activate the focused item |
| Escape | Back / cancel |
| Home / End | Jump to the start / end of the list |

### World map

| Key | Action |
|---|---|
| G | Company status: day, number of brothers, money and daily wage, food and days it lasts, active contract |

On an **event screen**: the arrows move through the options and Enter picks one
(the native number keys 1-6 still work). A first Enter with nothing focused
focuses the first option instead of activating it, so you don't close an event by
accident.

### Tactical combat

| Key | Action |
|---|---|
| Q W E / A S D | Move the cursor to the 6 neighbouring tiles (Q=NW, W=N, E=NE, A=SW, S=S, D=SE) |
| X | Recenter the cursor on the active brother |
| Z / Shift+Z | Cycle living, visible enemies by distance (Z farther, Shift+Z nearer) |
| V | Inspect the unit under the cursor (health, armor, fatigue, morale, effects, when it acts) |
| G | Confirm on the cursor tile: move there, or use the armed skill |
| T | Active brother's status (health, action points, fatigue, morale) |
| Tab | Turn order for the round |
| B | Visible enemies sorted by distance, with range |
| Shift+B | Enemies adjacent to the cursor tile (would I be surrounded if I moved there?) |
| K | Active brother's usable skills (the numbered bar, read aloud) |
| Number row / numpad | Use skill 1-10 (the game's native shortcut) |
| C / I | Open the character sheet (navigable with arrows / Home / End) |
| R | End round (opens the confirmation dialog, now accessible) |

With a **targeted skill armed**, the tile cursor adds "valid target, N% to hit" /
"not a valid target" for the focused tile, and G uses it there.

On the **in-combat character sheet**: Up/Down arrows walk the attributes, Home/End
jump to the ends, and A/D (or arrows/Tab, as in vanilla) switch brothers while
keeping your position, to compare quickly.

### Post-combat result screen

| Key | Action |
|---|---|
| Up / Down arrows | Walk the outcome, casualties, survivors and loot |
| Enter | Activate "Loot all items" or "Continue" |
| L | Loot everything |
| R | Repeat the current row |

---

## Roadmap

Status by phase. Nothing is considered done until it is verified by ear with NVDA
in the real game.

### Done

- **Phase 0 — The bridge (complete).** Voice bridge by tailing `log.html`, frozen
  message protocol, the game decompiled for reference, and reversible install
  scripts (`dev_install.bat` / `dev_uninstall_mod.bat` / `play.bat`).
- **Phase 1 — Pure text (almost complete).**
  - Event screen (title, body, navigable options).
  - Main menu, Options submenu and starting a new campaign.
  - Load / save campaign (main menu and world-map pause menu).
- **Phase 3 — Tactical combat (complete).**
  - Spoken combat log (hits, misses, morale, wounds, deaths, rounds).
  - Keyboard tile cursor with terrain, occupant, distance and direction.
  - Skills with valid targets and hit chance before confirming.
  - On-demand readouts: status, turn order, enemies, skills, inspection.
  - Enemies adjacent to a tile (Shift+B).
  - Turn-start and round announcements.
  - Navigable character sheet.
  - Result screen and loot as a navigable list.
  - Confirmation dialog (end round / quit battle) made accessible.
- **Phase 4 — World map (partial).**
  - Company-status readout on the pause (the G key).

### Pending

- **Phase 1.**
  - A keyboard-navigation review for mouse-only event focus, if any event turns
    up that the generic event screen does not cover.
- **Phase 2 — Tooltips and company management (not started).**
  - Generic tooltip hook (perks, items, status effects, terrain).
  - Brother sheet on the world map.
  - Inventory and market (item, price, comparison).
  - Keyboard navigation of the management grids.
- **Phase 3 — Tactical combat.**
  - **Pre-battle deployment**: placing and rearranging the formation before a
    fight (mouse-only today; a known gap, not yet numbered in the roadmap).
  - Verify by ear the flow of loading a save *during* a battle.
- **Phase 4 — World map (real-time, pausable).**
  - Positional sonar (settlements, contracts, enemy parties, locations).
  - Perception parity: ping only what has been sighted (fog of war).
  - Navigable nearby list + persistent beacon when a destination is set.
  - Town screen (buildings, recruits, contracts).
- **Phase 5 — Polish and distribution (not started).**
  - Configurable verbosity and every parameter in config.
  - Special screens (company creation, ambitions, end screen, DLC origins).
  - Package for Nexus (standard mod format + companion app).
  - Publish on audiogames.net, find blind testers and iterate.

---

## How it works (technical summary)

The game has two scriptable layers: the **logic** in Squirrel (combat, world,
events) and the **UI** in HTML/JS inside Chromium. The problem is that Chromium
renders to a texture, with nothing a screen reader can see. The solution is three
pieces:

```
Squirrel hooks (read the game state)  →  bridge (tail of log.html)  →  C# companion app → Tolk → NVDA
```

The bridge writes one JSON line per message (`UB_MSG:{...}`) from a single point
in the mod; the companion tails the log, parses it and speaks it. There are two
speech channels: an *interrupt* one (last wins) for focus and cursor, and a *FIFO
queue* (nothing dropped) for combat events.

The bulk of the code lives in:

- `mod/` — the mod itself (Squirrel hooks + injected JS).
- `companion/` — the .NET 8 companion app (speech and localization).
- `plugin/` — everything installable (zips and DLLs), from which the scripts copy
  it into the game.

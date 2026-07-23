# The Unseen Banner

**An accessibility mod for blind players of *Battle Brothers*.**

*Battle Brothers* is a turn-based tactical RPG where you lead a medieval
mercenary company: hire and equip fighters, take contracts across an open world
map, and fight hex-grid battles where death is permanent.

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
- ⚠️ **World map**: directional movement, nearby-entity inspection, company
  status, town entry, town contracts, obituary, factions/relations and the
  Retinue are playable by ear. **Missing** the positional sonar, destination
  beacon and the mouse-only building sub-dialogs.
- ⚠️ **Company management**: the Retinue and the world-map character sheet are
  accessible, including follower hiring/replacement, cart upgrades and complete
  brother readouts. The sheet also exposes the game's native details for
  backgrounds, statistics, skills, injuries, traits, perks and equipped items.
  Inventory, market, brother recruitment and ambitions are not accessible yet.
- ❌ **Pre-battle deployment** (arranging your formation before a fight): still
  mouse-only.

In short: **tactical combat is well covered** and the basic world-map loop is
usable, but between-battle management still has significant gaps. It is not that
the game is "only playable up to the tutorial" — it is that some surfaces are
done and others are not (see the [Roadmap](#roadmap)).

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

Vanilla *Battle Brothers* is played mostly with the mouse (click to move and
attack, drag to deploy, real-time-with-pause on the world map). Those controls
are of no use without sight, so the mod replaces them with the keyboard scheme
below — you do not need to learn the native mouse controls.

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
| Q W E / A S D | Move the company one neighbouring world tile; hold Shift to keep marching; Space stops and pauses |
| Enter | Enter a settlement or location when standing on it |
| B | Open perceived nearby parties, settlements and locations; Up/Down review, Home/End jump, V opens details, B closes |
| G | Company status: day, brothers, money, wages, food, active contract and current objectives |
| C / I | Open the character sheet; Up/Down review, Home/End jump, V opens native details, A selects the previous brother, D or Tab selects the next, C/I/Escape closes |
| O | Open the obituary; Up/Down review the fallen, Home/End jump to the start/end, O or Escape closes |
| R | Open factions and relations; Up/Down review, Home/End jump to the start/end, R or Escape closes |
| P | Open the Retinue; Up/Down review, Home/End jump, Enter hires/replaces followers or upgrades the cart, P or Escape goes back |

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
| H / Shift+H | Cycle living allies by distance, excluding the active brother (H farther, Shift+H nearer) |
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
- **Phase 2 — Tooltips and company management (partial).**
  - Generic on-demand native-tooltip reader: the game renders its localized
    tooltip first, then the mod reads the final DOM and announces it.
  - Navigable world-map brother sheet with statistics, injuries, traits, perks
    and equipment, quick brother comparison, and V-key details. A multi-detail
    row becomes a navigable sub-list; mouse-only item instructions are omitted.
- **Phase 3 — Tactical combat (complete).**
  - Spoken combat log (hits, misses, morale, wounds, deaths, rounds).
  - Keyboard tile cursor with terrain, occupant, distance and direction, plus
    enemy and ally cycling (Z / Shift+Z and H / Shift+H).
  - Skills with valid targets and hit chance before confirming.
  - On-demand readouts: status, turn order, enemies, skills, inspection.
  - Enemies adjacent to a tile (Shift+B).
  - Turn-start and round announcements.
  - Navigable character sheet.
  - Result screen and loot as a navigable list.
  - Confirmation dialog (end round / quit battle) made accessible.
- **Phase 4 — World map (partial).**
  - Directional company movement and pause-state announcements.
  - Perception-safe nearby list (B) with entity details (V).
  - Company-status and active-objective list (G).
  - Keyboard entry into settlements and a navigable town frame for contracts.
- **Phase 5 — Special screens (partial).**
  - Obituary (O) and factions/relations (R) as navigable lists.
  - Retinue (P): seats, follower details, requirements, hiring/replacement and
    cart upgrades with accessible confirmations.

### Pending

- **Phase 1.**
  - A keyboard-navigation review for mouse-only event focus, if any event turns
    up that the generic event screen does not cover.
- **Phase 2 — Tooltips and company management (partial).**
  - Inventory and market (item, price, comparison).
  - Reuse the native-tooltip reader from the character sheet for inventory,
    market, recruitment and other management surfaces.
  - Keyboard navigation of the management grids.
- **Phase 3 — Tactical combat.**
  - **Pre-battle deployment**: placing and rearranging the formation before a
    fight (mouse-only today; a known gap, not yet numbered in the roadmap).
  - Verify by ear the flow of loading a save *during* a battle.
- **Phase 4 — World map (real-time, pausable).**
  - Positional sonar (settlements, contracts, enemy parties, locations).
  - Persistent beacon and travel-to-selection from the nearby list.
  - Accessible building sub-dialogs (market, recruits, tavern and others).
- **Phase 5 — Polish and distribution (partial).**
  - Configurable verbosity and every parameter in config.
  - Remaining special screens (company creation, ambitions, end screen,
    DLC origins).
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

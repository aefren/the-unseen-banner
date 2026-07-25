# The Unseen Banner

**An accessibility mod for blind players of *Battle Brothers*.**

**Version 0.7** — first public release.

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

---

## Language: English only

**This mod supports Battle Brothers in English, and nothing else.**

Everything the mod speaks is either text the game itself rendered — item names,
contract objectives, tooltips, combat log lines — or a short framing phrase of
its own. Both sides are English here: the mod is written, tested and verified
by ear against the game set to English.

Running the game in another language is not supported. The game's own text
would come through in that language while every framing word stays English, and
the readouts have only ever been verified in English, so nothing about that
mixture is guaranteed to work.

**Any other language is the responsibility of whoever wants it.** The pieces
are in place to make that possible without touching the code:

- The mod's own phrases live in `companion/L10n.cs`, with the English defaults
  compiled in. To translate them, create a plain-text file `lang/<code>.lang`
  next to the companion executable (for example `lang/es.lang`), with one
  `key = value` line per string. Missing keys fall back to English, so a partial
  translation is safe.
- The game's text is not the mod's to translate: it comes from whatever
  language Battle Brothers is set to.

Translations are neither maintained nor verified here. If you build one, it is
yours to test and to keep working across updates.

---

## Current status

Here is what is **already playable by ear** and what is **not yet**. Be realistic
before starting a serious campaign:

- ✅ **Main menu, options, load and save.** Navigable and narrated, both from
  the main menu and from the in-game pause menu.
- ✅ **Text events** (the narrative part): title, body and options. Contracts
  and ambitions are offered through this same screen, so taking, tracking and
  turning them in works end to end.
- ✅ **Tactical combat.** The most complete part: tile cursor with terrain,
  occupants and corpses, skills with valid targets and hit chance, spoken combat
  log, brother status, turn order, enemy and ally cycling, character sheet with
  in-battle equipment changes, retreat dialogs, and a result screen where loot
  can be taken piece by piece.
- ✅ **Before the battle**: the encounter report, the native engage/retreat
  actions and formation editing are keyboard-driven.
- ✅ **World map**: directional movement, arrivals, camping, the map explorer
  cursor with travel-to-tile and footprint reading, the nearby survey of
  settlements, locations, landmarks and visible parties, and a company readout
  covering day and time, brothers, crowns, wages, food, the active contract with
  its objectives, and the current ambition. Day changes, speed changes, pauses
  and brothers ready to level up are announced as they happen.
- ✅ **Settlements**: the town screen as a list of buildings and contracts, plus
  accessible market, recruitment, tavern, temple and arena.
- ✅ **Company management**: the character screen — sheet, equipped items,
  backpack, stash, perks and formation — including perk acquisition, renaming,
  dismissing a brother, inventory and stash actions, and the game's own native
  details for backgrounds, statistics, skills, injuries, traits and items. The
  Retinue, the obituary and factions/relations are navigable lists.
- ✅ **End of campaign**: the victory/defeat screen is navigable.
- ⚠️ **Company creation** (banner, company name, DLC origins) is only partly
  reachable from the menu cursor; the customization screen itself is not
  covered yet.
- ❌ **Positional sonar and destination beacon**: the world map speaks, but it
  does not yet *sound*. Direction and distance are read as words, not as audio
  cues.
- ❌ **Configurable verbosity and key remapping**: the keys below are fixed for
  now.

In short: a campaign is playable by ear from the main menu to the end screen.
What is missing is polish — audio positioning and configurability — rather than
whole surfaces.

---

## Requirements

- **Battle Brothers** on **Steam**, **set to English** (the base game is not
  included).
- **Windows**.
- **A screen reader**: **NVDA** (recommended) or a system **SAPI** voice.
- Nothing else to install: the companion app is self-contained (no .NET runtime
  needed), and the **Tolk** speech engine and `nvdaControllerClient64.dll` ship
  with the mod.

---

## Installation

The installer is the only thing that touches your game folder, it only ever
writes mod files into `data\`, and the uninstaller removes exactly what it put
there. Your saves are never touched.

1. Unzip this release anywhere you like — your Downloads folder is fine. Do not
   put it inside the game folder.
2. Run **`install.bat`**. It finds Battle Brothers in your Steam libraries and
   installs the mod. If it cannot find the game, it asks you to paste the full
   path to the game folder — the one that contains `data` and `win32`.
3. Start your screen reader, then run **`play-unseen-banner.bat`**, which the
   installer writes next to `install.bat`. It starts the companion app (the
   voice) and then the game through Steam.

To remove the mod, run **`uninstall.bat`**. It deletes the mod files it
installed and leaves the game as it was. Modern Hooks and MSU are only removed
if the installer was the one that added them, so other mods keep working.

### Two prompts you will get, and what they mean

Neither is an error. Both are Windows and the game doing their job, and a screen
reader user should know they are coming so they are not left guessing at a dialog
that stole the focus:

- **Windows asks for administrator permission** as soon as you run `install.bat`
  (and `uninstall.bat`). That is Windows' own User Account Control prompt —
  "Do you want to allow this app to make changes to your device?" — and it
  appears because the Steam folder normally lives under Program Files, where
  writing needs elevation. Answer **Yes**; if you answer No, nothing is installed
  and nothing is changed.
- **The game warns, the first time, that it is being modified.** That is Battle
  Brothers reporting that mods are loaded — Modern Hooks, MSU and this one.
  Expected, and the price of any mod: confirm it and carry on.

Windows may also warn about running a file downloaded from the internet
("Windows protected your PC"). These scripts are not signed, so that warning is
normal for this kind of release; choose the option to run it anyway if you trust
the download.

### Starting the two pieces separately

`play-unseen-banner.bat` is a convenience, not a requirement. The companion app
(`TheUnseenBanner.Companion.exe`, inside the `companion` folder of this release)
is a separate process from the game: it reads what the mod emits and speaks it.
You can start it before or after the game, and launch Battle Brothers however
you normally do. On startup you will hear a confirmation through your screen
reader.

If your screen reader or Tolk fail, the companion degrades to silence without
bringing the game down.

---

## Keys

Vanilla *Battle Brothers* is played mostly with the mouse (click to move and
attack, drag to deploy, real-time-with-pause on the world map). Those controls
are of no use without sight, so the mod replaces them with the keyboard scheme
below — you do not need to learn the native mouse controls.

The engine does not deliver the keyboard to the game's DOM, so the mod captures
keys and narrates the action. Where a mod key overlaps a native shortcut, the
mod acts on it and consumes the press. None of these keys are remappable yet.

### The pattern behind every list

Almost everything the mod opens is a list, and every list works the same way:

| Key | Action |
|---|---|
| Up / Down | Move one entry at a time |
| Home / End | Jump to the first / last entry |
| Enter | Activate the focused entry |
| V | Open the focused entry's native details; V again returns |
| Page Down / Page Up | Next / previous section, where a screen has sections |
| Escape | Back or cancel |

Learn that, and the rest of this section is only about which key opens what.

> **One deliberate change to vanilla**: in combat, vanilla binds **End** to
> "wait turn", the same key every list here uses for "last entry". A blind
> player cannot see which of the two is in front of them, and spending a turn is
> irreversible, so the mod takes End away from vanilla during battle. **Space**
> keeps its native wait-turn behaviour.

### Menus and events

| Key | Action |
|---|---|
| Up / Down | Move through the menu or the event's options |
| Left / Right | Adjust sliders and resolution (Options only) |
| Enter | Activate the focused item |
| Escape | Back / cancel |

On an **event screen** the arrows move through the options and Enter picks one
(the native number keys 1-6 still work). A first Enter with nothing focused
focuses the first option instead of activating it, so you don't close an event by
accident.

### World map

| Key | Action |
|---|---|
| Q W E / A S D | Move the company one neighbouring hex; hold Shift to keep marching; Space stops and pauses |
| Enter | Enter the settlement or location the company is standing on, or engage a hostile party at contact range |
| G | Company status: day and time, brothers, crowns, wages, food, active contract with its objectives, and current ambition |
| B | Known places: settlements, locations and landmarks. Page Down/Page Up switch category, V opens details, Enter travels there or enters, B closes |
| Shift+B | The parties currently in sight, same navigation |
| M | Map explorer on/off (see below) |
| T | Make or break camp (native); **Shift+T** explains the current camp state without changing it |
| C / I | Company management and character screen (see below) |
| P | The Retinue: seats, followers, requirements; Enter hires, replaces or upgrades the cart |
| O | The obituary: the fallen, with days served, battles, kills and cause of death |
| R | Factions and relations: renown, moral reputation and every known faction |
| 1 / 2 / 3 | Game speed (native; the change is now announced) |
| Space | Pause / unpause (native; announced) |

**Map explorer (M)** is a cursor that walks the map without moving the company,
so you can survey what is around before committing to a march:

| Key | Action |
|---|---|
| Q W E / A S D | Move the cursor one hex (same directions as the company and the battlefield cursor) |
| X | Bring the cursor back to the company; **Shift+X** reports the company's bearing and distance from it |
| V | Read the cursor's tile as a list: terrain, places, parties and footprints. Enter acts on the focused one |
| G | Send the company to the cursor tile |
| M | Leave the mode |

Footprints keep the game's own asymmetry: the family of whoever passed is always
read, but the exact party type only if you have hired a Lookout — the same thing
a sighted player gets from the sprite.

### Settlements

The town screen is one list: the town's name, each building, each contract, and
Leave. Enter opens the focused one; Escape leaves the town.

| Building | Keys |
|---|---|
| **Market** | Page Down/Page Up switch overview, stock and stash. Enter opens the actions for the focused item (buy, sell, repair, sort, filter), V reads its native tooltip and compares it against what a brother has equipped, and A/D (or Left/Right, or Tab) change which brother that comparison uses. Selling something unique or valuable asks for confirmation, with Cancel selected by default |
| **Recruitment** | Up/Down walk the candidates with their live hiring and wage costs, V opens the native background and revealed-trait tooltips, and Enter offers hiring or paying for a tryout |
| **Tavern** | Two paid actions — a round for the patrons, a round for your men — Enter performs the focused one, V re-reads the rumor or report it produced |
| **Temple** | Up/Down walk the wounded, Enter opens that brother's treatable injuries, a second Enter pays for the treatment, V or Escape backs out |
| **Arena** | Opens as it does for a mouse; when it refuses (night, cooldown, another contract, no stash room) the reason is spoken instead of nothing happening |

### Character screen (C / I)

The same screen in battle and on the world map, as a navigable list — but with
different depth in each.

**On the world map**, Page Down and Page Up move between six sections:

| Section | Contents |
|---|---|
| Sheet | Identity, background, XP, mood, health, fatigue, resolve, initiative, melee and ranged skill and defence, armour, injuries, traits |
| Equipment | Each worn item; Enter opens its actions |
| Backpack | Each bag slot; Enter opens its actions (equip, use, move, mark for repair) |
| Stash | The company stash, with the same action menu |
| Perks | Every perk, taken and available; Enter buys the focused one when the brother has a point to spend |
| Formation | The 27 formation slots; Enter picks a brother up and places them, Escape cancels an armed move |

**In battle** it is a single flat list — the sheet, ending with the backpack
slots. Enter on an occupied slot opens its equip action, and a second Enter
performs it through the game's own combat rules, Action Point cost included.

Everywhere: Up/Down and Home/End navigate, V opens the focused row's native
details (a row with several details becomes its own sub-list), Enter on the
identity row renames the brother, and A/D — or Left/Right, or Tab — switch
brother while keeping your position in the list, so attributes can be compared
quickly. C, I or Escape close the screen.

**Delete**, on the identity row, dismisses that brother from the company — the
mouse-only button next to the portrait in vanilla. It opens a confirmation with
three choices, **Cancel focused first**: cancel, dismiss, or dismiss and pay the
compensation vanilla offers (10 crowns per day served), which spares the rest of
the company the mood hit. Up/Down choose, Enter confirms, Escape or V cancel.
Dismissing is refused, with the reason spoken, for your last brother, for the
player character, and during a battle — exactly the cases where vanilla hides
the button.

### Tactical combat

| Key | Action |
|---|---|
| Q W E / A S D | Move the tile cursor to the 6 neighbours (Q=NW, W=N, E=NE, A=SW, S=S, D=SE) |
| X | Recenter the cursor on the active brother |
| Z / Shift+Z | Cycle living, visible enemies by distance (Z farther, Shift+Z nearer) |
| H / Shift+H | Cycle living allies by distance, excluding the active brother |
| V | Inspect the unit under the cursor: health, armour, fatigue, morale, effects, when it acts |
| Shift+V | Open that same inspection as a navigable list, one fact per row; V on a row opens its native tooltip (status effects included); Shift+V or Escape closes |
| G | Confirm on the cursor tile: move there, or use the armed skill |
| T | Active brother's status (health, action points, fatigue, morale) |
| Tab | Turn order for the round |
| B | Visible enemies sorted by distance, with range |
| Shift+B | Enemies adjacent to the cursor tile, each with its clock direction (would I be surrounded if I moved there?) |
| K | Active brother's usable skills — the numbered bar read aloud, with costs and whether each can be used right now |
| Number row / numpad | Use skill 1-10 (the game's native shortcut) |
| C / I | Character sheet (see above) |
| R | End round (native; its confirmation dialog is navigable) |
| Space | Wait turn (native) |

With a **targeted skill armed**, the tile cursor adds "valid target, N% to hit" /
"not a valid target" for the focused tile, and G uses it there. Arming and
cancelling a skill are both announced.

The cursor also reads corpses, cover and decorations standing on a tile, so
skills that consume bodies can be aimed by ear.

### Before and after the battle

**Encounter dialog** (the scout report before a fight): Up/Down/Home/End walk
the report, Enter runs the focused native action — engage, or review the
formation, which opens the character screen straight on its Formation section —
and Escape retreats when the encounter allows it.

**Result screen** (victory or defeat):

| Key | Action |
|---|---|
| Up / Down / Home / End | Walk the outcome, casualties, survivors and loot |
| Enter | Activate the focused button, or take exactly the focused loot item |
| V | Read the focused loot item's native tooltip |
| L | Loot everything |
| R | Repeat the current row |

**Confirmation dialogs** (end round, retreat, quit battle, Retinue purchases) are
plain lists: Up/Down/Home/End, Enter to choose, Escape for the secondary option.

---

## Roadmap

Status by phase. Nothing is considered done until it is verified by ear with NVDA
in the real game.

### Done

- **Phase 0 — The bridge.** Voice bridge by tailing `log.html`, frozen message
  protocol, the game decompiled for reference, and reversible install scripts.
- **Phase 1 — Pure text.** Event screen; main menu, Options and starting a new
  campaign; load and save from both the main menu and the world-map pause menu.
- **Phase 2 — Tooltips and company management.**
  - Generic on-demand native-tooltip reader: the game renders its localized
    tooltip first, then the mod reads the final DOM and announces it.
  - The character screen as a full keyboard surface: sheet, equipped items,
    backpack, stash, perks and formation, with perk acquisition, brother
    renaming, dismissal with its compensation choice, and quick
    brother-to-brother comparison.
  - Inventory, stash and market actions: equip, use, move, mark for repair,
    sort, filter, buy, sell and repair, with localized results and errors.
  - Recruitment, tavern and temple.
- **Phase 3 — Tactical combat.** Spoken combat log; tile cursor with terrain,
  occupants and corpses; enemy and ally cycling; skills with valid targets and
  hit chance; on-demand readouts; adjacency by clock direction; turn and round
  announcements; in-battle equipment changes; retreat and confirmation dialogs;
  result screen with per-item looting.
- **Phase 4 — World map.** Directional movement and arrivals; camping; the
  perception-safe survey of places and parties; the company and objectives
  readout; the map explorer cursor with travel-to-tile and footprints; keyboard
  entry into settlements and the town screen.
- **Phase 5 — Special screens.** Obituary, factions and relations, the Retinue
  with accessible confirmations, and the end-of-campaign screen.

### Pending

- **Positional sonar** (settlements, contracts, enemy parties, locations) and a
  **persistent beacon** for the chosen destination — the world map's remaining
  gap, and the reason direction is currently words rather than sound.
- **Company creation**: banner, company name and DLC origins.
- **Configurable verbosity**, and every tunable constant — cadences, ranges,
  keys — moved into config with MSU keybinds for remapping.
- **A keyboard-navigation review** for any event whose focus the generic event
  screen does not cover.
- Verify by ear the flow of loading a save *during* a battle.
- Publish on Nexus and audiogames.net, find blind testers and iterate.

### Known limitations

- Accepting a contract does not rebuild the town's contract list; leaving the
  settlement and entering again refreshes it.
- The mod is verified on the Steam build of the game.

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
- `installer/` — the PowerShell the install and uninstall scripts run.
- `packaging/` — `build-release.bat` builds the downloadable release into
  `dist/`: it repacks the mod zip, publishes the companion self-contained and
  assembles this exact folder layout.
- `plugin/` — everything installable (zips and DLLs), from which the scripts copy
  it into the game.

## License

MIT. See [LICENSE](LICENSE), which also credits the third-party pieces this mod
depends on: Modern Hooks, MSU, Tolk and the NVDA controller client.

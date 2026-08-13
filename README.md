# The Unseen Banner

**An accessibility mod for blind players of *Battle Brothers*.**

**Version 1.1**

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
  the main menu and from the in-game pause menu. Confirmation dialogs — deleting
  a save, retiring the company — are read out with the game's own warning and
  focus Cancel first. In the main menu Escape dismisses just the dialog; in the
  pause menu Escape closes the whole menu, dialog included, because MSU claims
  that key there. The world-map pause menu starts on the current map seed;
  Enter copies it to the Windows clipboard. A campaign whose save contains no
  seed says so instead of silently skipping the row.
- ✅ **Text events** (the narrative part): title, body and options. Contracts
  and ambitions are offered through this same screen, so taking, tracking and
  turning them in works end to end.
- ✅ **Tactical combat.** The most complete part: tile cursor with terrain,
  height, enemy zone of control and what a step there would cost in action
  points and fatigue, occupants, corpses and ground items, skills with valid
  targets and hit chance, spoken combat log, brother status, turn order, enemy and ally cycling,
  character sheet with in-battle equipment changes, retreat dialogs, and a
  result screen where loot can be taken piece by piece.
- ✅ **Before the battle**: the encounter report, the native engage/retreat
  actions and formation editing are keyboard-driven.
- ✅ **World map**: directional movement, arrivals, camping, the map explorer
  cursor with travel-to-tile, road, river and footprint reading, a directional
  summary of the tracks and road segments currently in sight, the nearby survey of
  settlements, locations, landmarks and visible parties, and a company readout
  covering day and time, brothers, crowns, wages, food, the active contract with
  its objectives, and the current ambition. Settlements, locations and landmarks
  are announced the first time they come into sight, and enemy parties every
  time they do — and a hostile party already in sight says so again each time it
  closes the gap, so being run down is something you hear coming. Day changes,
  speed changes, pauses and brothers ready to level up are announced as they
  happen, and the day the company settles its wages and rations says who went
  unpaid or hungry and what tomorrow will cost if nothing changes.
- ✅ **Settlements**: the town screen as a list of buildings, situations and
  contracts, plus accessible market, recruitment, tavern, temple, taxidermist,
  harbor, training hall and arena.
- ✅ **Company management**: the character screen — sheet, equipped items,
  backpack, stash, perks and formation — including both halves of a level up
  (attribute increases and perks), renaming, dismissing a brother, inventory and
  stash actions, and the game's own native details for backgrounds, statistics,
  skills, injuries, traits and items. The Retinue, the obituary and
  factions/relations are navigable lists.
- ✅ **End of campaign**: the victory/defeat screen is navigable.
- ✅ **Daily upkeep warnings**: food and wages are announced correctly when the
  company is in trouble; a well-supplied company remains quiet.
- ✅ **Company creation**: origin, company name, banner, both difficulties, the
  late-game crisis, the seed and the remaining boxes. The banner is announced
  only by its number, having no name of its own to read.
- ✅ **Scenarios**: the nine prepared tactical battles are navigable from the
  menu cursor. Each row reads the battle's name and description; Play remains a
  separate entry after the scenarios, so reviewing one never starts it by accident.
- 🧪 **Tactical focus sonar**: focusing a visible ally or enemy plays a positional
  cue. Stereo pan grows by 10% per horizontal tile and pitch moves by three semitones
  per vertical tile relative to the active brother. Timbre identifies friend or
  foe, and rhythm identifies whether the unit acts in one, two, three, more than
  three turns, or has already acted. Implemented and build-verified; awaiting the
  required in-game listening pass.
- ⏭️ **After 1.0 — quality of life and positional audio**: key remapping,
  configurable verbosity, world-map sonar and the destination beacon. The map
  already gives direction and distance in words, and the fixed keys below cover
  the complete playable loop.

In short: version 1.0 makes a complete campaign playable by ear from the main
menu to the end screen, and the practice battles provide a repeatable place to
learn its tactical combat. Rare, non-blocking verification gaps are documented
below; remapping, verbosity and world-map audio positioning are deliberately
scheduled after 1.0.

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

**F1 answers the same question from inside the game.** It opens the keys that are
live on whatever surface you are standing on — the battlefield, the map, the
market, a confirmation — as a list, one key per row, navigated like any other:
Up/Down/Home/End walk it, Escape or F1 again closes it. It reads the surface that
would receive your next keystroke, so it is never a menu of keys you cannot use.

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

On the **world-map pause menu**, the first entry is the current map seed. Enter
copies it to the Windows clipboard and confirms the copy aloud. Old or malformed
campaigns that were saved without a seed instead announce “Map seed unavailable”;
the mod cannot reconstruct a seed that the save itself does not contain.

On an **event screen** the arrows move through the options and Enter picks one
(the native number keys 1-6 still work). A first Enter with nothing focused
focuses the first option instead of activating it, so you don't close an event by
accident.

### World map

| Key | Action |
|---|---|
| Q W E / A S D | Move the company one neighbouring hex; hold Shift to keep marching; Space stops and pauses |
| Enter | Enter the settlement or location the company is standing on, or engage a hostile party at contact range |
| X | The hex the company stands on, in one breath: terrain, any road or river and the way it runs, then each trail of footprints crossing it and the directions it runs. The quick version of V, meant to be tapped between marching steps |
| V | The same hex as a navigable list: terrain, roads and rivers, place, parties and trails, one row at a time, with Enter on a place or party |
| F2 | Two categories, switched with Page Down/Page Up. **Company status** has day and time, brothers, crowns with daily wages and days covered, food, supplies with total repair time, medicine with total healing time and cost, active contract with objectives, and ambition; Enter cancels the focused contract or ambition after its native confirmation. **Wounded brothers** lists each affected man with missing health, light-wound recovery and every temporary injury's remaining day or day range |
| F1 | The keys that work right here (see above) |
| B | Known places: settlements, locations and landmarks. Page Down/Page Up switch category, V opens details, Enter travels there or enters, B closes |
| Shift+B | The parties currently in sight, same navigation |
| Shift+F | Count the tracks currently inside the company's vision and group them by direction; plain F keeps its native show/hide-tracking action |
| Shift+R | Count the discovered road segments currently inside the company's vision and group them by direction; plain R still opens factions and relations |
| M | Map explorer on/off (see below) |
| T | Make or break camp (native); **Shift+T** explains the current camp state without changing it |
| C / I | Company management and character screen (see below) |
| P | The Retinue: seats, followers, requirements; Enter hires, replaces or upgrades the cart |
| O | The obituary: the fallen, with days served, battles, kills and cause of death |
| R | Factions and relations: renown, moral reputation and every known faction |
| 1 / 2 / 3 | Game speed (native; the change is now announced) |
| Space | Pause / unpause (native; announced) |

A hostile party you can already see is announced again each time it closes the
gap — at six, four and two tiles, the last with a warning that contact is a step
away — with the distance and bearing each time. It fires on the distance, not on
who moved, so marching at a camped party says it too.

**Map explorer (M)** is a cursor that walks the map without moving the company,
so you can survey what is around before committing to a march:

| Key | Action |
|---|---|
| Q W E / A S D | Move the cursor one hex (same directions as the company and the battlefield cursor) and read it: terrain, any road or river with the way it runs, place, parties, and each trail of footprints with the directions it runs |
| X | Bring the cursor back to the company and read that hex the same way; **Shift+X** reports the company's bearing and distance from it |
| V | Read the cursor's tile as a list instead, one row at a time. Enter acts on the focused place or party |
| G | Send the company to the cursor tile |
| M | Leave the mode |

**Roads and rivers are read like a trail**, with the directions they run — "on a
road, running 2 o'clock and 8 o'clock" — because a road is only worth knowing
about once you know which way it goes. They are the map's two travel-speed
modifiers, a road moving the company half as fast again and a river slowing it by
a quarter, and neither changes the terrain, so nothing else would tell you. `X`
and the `V` list also report one on a neighbouring hex, which is how you find the
road in the first place; while marching, stepping onto one is announced with its
directions and stepping off it in a word.

Footprints keep the game's own asymmetry: the family of whoever passed is always
read, but the exact party type only if you have hired a Lookout — the same thing
a sighted player gets from the sprite. `Shift+F` is the quick overview: it scans
only the company's current vision circle — including night, terrain, camp and
Lookout modifiers — and says, for example, "3 tracks to the northeast and 1 track
to the southwest." One count is one live trail type on one tile, the finest count
the game's footprint query exposes.

`Shift+R` applies the same quick-overview pattern to roads: it scans that current
vision circle, respects fog of war and groups discovered road hexes by direction.
It also says whether the company is standing on a road. Plain `R` keeps opening
the factions and relations screen.

### Settlements

The town screen is one list: the town's name and how many situations it has, then
each situation, each building, each contract, and Leave. Enter opens the focused
one, V explains a situation, and Escape leaves the town.

Situations are the icons vanilla draws in the corner of that screen — a good
harvest that halves food prices, ambushed trade routes, a siege, a tournament.
On the world map they are gated behind the Agent follower, and `V` in the `B`
survey honours that gate, exactly as the game does.

| Building | Keys |
|---|---|
| **Market** | Page Down/Page Up switch overview, stock and stash. Every row carries the price this town is asking or offering **and what the item is worth**, so a deal can be judged without opening anything; in your own stash, provisions and trading goods also say what you paid for them, which is the only place the game records it. Enter opens the actions for the focused item (buy, sell, repair, sort, filter), V reads its native tooltip and compares it against what a brother has equipped, and A/D (or Left/Right, or Tab) change which brother that comparison uses. Selling something unique or valuable asks for confirmation, with Cancel selected by default |
| **Recruitment** | Up/Down walk the candidates with their live hiring and wage costs, V opens the native background and revealed-trait tooltips, and Enter offers hiring or paying for a tryout |
| **Tavern** | Two paid actions — a round for the patrons, a round for your men — Enter performs the focused one, V re-reads the rumor or report it produced |
| **Temple** | Up/Down walk the wounded, Enter opens that brother's treatable injuries, a second Enter pays for the treatment, V or Escape backs out |
| **Taxidermist** | Up/Down walk the recipes with their cost and, when one cannot be made, why not; V opens its description and ingredients, each with how many are still missing; Enter opens the craft action and a second Enter pays for it |
| **Kennel** | A shop like any other, and driven by the market keys above |
| **Harbor** | Up/Down walk the destinations with the fare for each and whether you can afford it, V opens the destination's own description, Enter asks to confirm the passage and a second Enter pays and sails. When the harbor refuses (you are escorting a caravan) the reason is spoken |
| **Training hall** | Up/Down walk your men, Enter opens the three paid lessons for one of them, a second Enter pays, and V reads what a lesson teaches. Men who cannot train are still listed, with the reason — too experienced, already training, or a slave the manhunters will not school |
| **Arena** | Opens as it does for a mouse; when it refuses (night, cooldown, another contract, no stash room) the reason is spoken instead of nothing happening |
| **Barber** | Not described. It only changes a man's sprite — no cost, no effect in play — so there is nothing to read out; the mod says so instead of staying silent |

### Character screen (C / I)

The same screen in battle and on the world map, as a navigable list — but with
different depth in each.

**On the world map**, Page Down and Page Up move between six sections:

| Section | Contents |
|---|---|
| Sheet | Identity, background, XP, mood, health, fatigue, resolve, initiative, melee and ranged skill and defence, weapon damage, effectiveness against armour, chance to hit the head, sight distance, armour, injuries, traits. The eight attributes that grow on level up also report their talent stars, so a brother can be judged without waiting for a level up |
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
| Q W E / A S D | Move the tile cursor to the 6 neighbours (Q=NW, W=N, E=NE, A=SW, S=S, D=SE); visible units are announced with health and morale |
| X | Recenter the cursor on the active brother |
| Z / Shift+Z | Cycle living, visible enemies by distance (Z farther, Shift+Z nearer); an armed enemy is named with its weapon |
| H / Shift+H | Cycle living allies by distance, excluding the active brother |
| V | Inspect the unit under the cursor: identity, health, morale, armour, equipment, effects and when it acts; an armed enemy is named with its weapon |
| Shift+V | Open that same inspection as a navigable list, one fact per row (equipment included); V on a row opens its native tooltip (status effects and each worn item included) — on the equipment row with several pieces, V opens a second list to browse them and V again backs out; Shift+V or Escape closes (Escape backs out of that nested list first) |
| Shift+E | Read the equipment of the unit under the cursor |
| Shift+F | Read all effects on the unit under the cursor |
| Shift+S | Active brother's usable skills — the numbered bar read aloud, with costs and whether each can be used right now |
| Shift+D | Read that unit's damage range, armour damage, head-hit chance and vision |
| Shift+A | Read bag slots 1 and 2 of that unit, including empty slots |
| Shift+W | Read that unit's body and head armour, including item names and current/maximum durability |
| G | Confirm on the cursor tile: move there, or use the armed skill |
| P | Open the pickable items under the active brother; Up/Down chooses one, Enter moves it to the backpack, P or Escape closes |
| T | Active brother's live resources: action points and fatigue |
| Shift+T | Unit under the cursor: whether it is acting now, has finished its turn or acts in N turns, plus current/maximum fatigue |
| Tab | Turn order for the round |
| B | Visible enemies sorted by distance, with range and each enemy's equipped weapon |
| Shift+B | Enemies adjacent to the cursor tile, each with its equipped weapon and clock direction (would I be surrounded if I moved there?) |
| Number row / numpad | Use skill 1-10 (the game's native shortcut) |
| C / I | Character sheet (see above) |
| R | End round (native; its confirmation dialog is navigable) |
| Space | Wait turn (native) |
| F1 | The keys that work right here (see above) |

Whenever these controls focus a visible ally or enemy, the tactical sonar starts
alongside the spoken tile readout. Its ten logical cues combine five timing
patterns with two musical identities:

- **Ally:** the chord G3+D4. One 250 ms pulse means one turn; two pulses occupy
  400 ms; three occupy 600 ms; one continuous 400 ms pulse means more than three.
  A unit which already acted plays D4-G4-D4-G4 as four separate notes.
- **Enemy:** the same rhythms use the chord B-flat3+C-sharp4. A unit which already
  acted plays C-sharp4-B-flat3-C-sharp4-B-flat3.
- **Position:** northwest/southwest pan left, north/south stay centred and
  northeast/southeast pan right. Each tile of distance adds 10% pan in a lateral
  direction and transposes the complete cue three semitones in a vertical direction;
  diagonal sectors apply both. Transposition does not change the rhythm's duration.

The previous cue is stopped when the cursor moves, so a long sound can never keep
describing a unit which no longer has focus. Empty, hidden and non-unit tiles are
silent.

Every tile the cursor lands on also reports three things a sighted player reads
off the screen. **Height opens the readout**, in the same breath as the terrain;
the other two close it, after everything the readout already said, so a fast
sweep stays fast:

- **Height**, relative to the active brother — "one level higher" — and silence
  when you are level with it. High ground is hit chance and reach in this game.
- **Zone of control**, when enemies hold the tile: standing there means each of
  them gets a free attack the moment you walk away.
- **What walking there costs** in action points and fatigue, or that it is out of
  reach this turn, or that there is no path at all. These are the game's own
  numbers, from the same navigator the mouse hover prices its path with.

With a **targeted skill armed**, the tile cursor adds "valid target, N% to hit" /
"not a valid target" for the focused tile, and G uses it there; the walking cost
steps aside there, since the question has already been answered. Arming and
cancelling a skill are both announced.

The cursor also reads corpses, cover, decorations and every item lying on a tile,
so skills that consume bodies can be aimed by ear and recoverable weapons or
shields can be found. Ground items are the live `tile.Items` collection shown as
icons by the game; armour retained inside a corpse for the post-battle loot roll
is not described as something that can be picked up during combat.

To recover one during battle, first move the active brother onto its hex and press
`P`. Up/Down chooses an item and Enter sends that exact instance through the
game's native ground-to-backpack action. Its Action Point cost, Quick Hands, free
bag space and every ordinary inventory restriction are therefore unchanged.

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
  campaign; load and save from both the main menu and the world-map pause menu;
  current map seed with clipboard copy.
- **Phase 2 — Tooltips and company management.**
  - Generic on-demand native-tooltip reader: the game renders its localized
    tooltip first, then the mod reads the final DOM and announces it.
  - The character screen as a full keyboard surface: sheet, equipped items,
    backpack, stash, perks and formation, with perk acquisition, brother
    renaming, dismissal with its compensation choice, and quick
    brother-to-brother comparison.
  - Inventory, stash and market actions: equip, use, move, mark for repair,
    sort, filter, buy, sell and repair, with localized results and errors.
  - Recruitment, tavern, temple, the taxidermist's crafting, the harbor's
    passage by ship and the training hall's paid lessons.
- **Phase 3 — Tactical combat.** Spoken combat log; tile cursor with terrain,
  occupants, corpses, recoverable ground items, height, zone of control and the
  cost of walking there; keyboard pickup from the active brother's tile;
  enemy and ally cycling; skills with valid targets and hit chance; on-demand
  readouts; adjacency by clock direction; turn and round announcements;
  in-battle equipment changes; retreat and confirmation dialogs; result screen
  with per-item looting.
- **Phase 4 — World map.** Directional movement and arrivals; camping; the
  perception-safe survey of places and parties; the company and objectives
  readout, with abandoning an ambition; the map explorer cursor with
  travel-to-tile, roads, rivers and footprints; directional summaries of tracks
  and roads in sight; threats announced again as they close in; keyboard entry
  into settlements and the town screen.
- **Phase 5 — Special screens.** Obituary, factions and relations, the Retinue
  with accessible confirmations, and the end-of-campaign screen.
- **Contextual key help (F1)** on every surface the mod drives.

### Pending

- Verify a real taxidermist craft and the river wording if a river can be found;
  both paths are implemented but could not be reproduced for the final audit.
- **Name the banner by its emblem** rather than by its number, the one thing
  company creation still leaves unsaid.
- **A keyboard-navigation review** for any event whose focus the generic event
  screen does not cover.
- Refresh the settlement contract list immediately after accepting a contract.
- After 1.0: **key remapping and configurable verbosity**, followed by the
  remaining tunable constants. Tactical-sonar settings already live in
  `companion/sonar.json` next to the executable.

After 1.0: **world-map positional sonar** (settlements, contracts, enemy
parties, locations) and a **persistent beacon** for the chosen destination.

Releases are published through **GitHub Releases** after the downloadable zip
has been tested on a clean installation and its new behavior verified by ear.

### Known limitations

- Accepting a contract does not rebuild the town's contract list; leaving the
  settlement and entering again refreshes it.
- A campaign saved without a map seed cannot have one reconstructed. Its pause
  menu explicitly reports the seed as unavailable and does not copy anything.
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
in the mod; the companion tails the log and parses it. There are two speech
channels: an *interrupt* one (last wins) for focus and cursor, and a *FIFO queue*
(nothing dropped) for combat events. A third, pure-audio `sonar` channel bypasses
Tolk and drives the companion's positional tactical synthesizer.

The bulk of the code lives in:

- `mod/` — the mod itself (Squirrel hooks + injected JS).
- `companion/` — the .NET 8 companion app (speech, localization and positional
  tactical audio). `sonar.json` holds its runtime-tunable volume, pan per tile,
  pitch per tile, rhythm and MIDI voicing.
- `installer/` — the PowerShell the install and uninstall scripts run.
- `packaging/` — `build-release.bat` builds the downloadable release into
  `dist/`: it repacks the mod zip, publishes the companion self-contained and
  assembles this exact folder layout.
- `plugin/` — everything installable (zips and DLLs), from which the scripts copy
  it into the game.

## License

MIT. See [LICENSE](LICENSE), which also credits the third-party pieces this mod
depends on: Modern Hooks, MSU, Tolk and the NVDA controller client.

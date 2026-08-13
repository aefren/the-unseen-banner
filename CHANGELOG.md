# Changelog

## 1.1

Version 1.1 makes battlefield decisions faster and adds two practical
world-map tools. Saves remain compatible with 1.0.0.

### Faster, focused combat inspection

The tactical cursor now includes morale when announcing visible units. Armed
enemies are named with their main-hand weapon when moving the cursor, cycling
enemies, listing nearby threats, or inspecting a unit. Unarmed enemies remain
identified without a misleading weapon label.

Focusing a visible combatant now also plays a positional tactical-sonar cue.
Horizontal distance adds 10% stereo pan per tile (10% at one tile, 30% at three
and 60% at six). Vertical distance transposes the whole cue by three semitones
per tile (three at one, six at two and twelve at four) without changing its duration.
Allies use G+D; enemies use B-flat+C-sharp. One, two and three turns use the same
number of pulses, more than three uses a long pulse, and a unit which already
acted gets its own four-note melody. Cursor audio is last-focus-wins and never
reveals hidden units.

The ground itself is reported by a 200 ms violin glide sounding in two octaves at
once: rising C to G where the hex stands above the active brother, falling G to C
where it lies below. Level ground stays silent.

Hexes nobody can stand on — trees, boulders, walls, deep water — get a 250 ms
rasp of their own, buzzing and chopped, its pitch wobbling up from A to C and
back rather than settling on a note. It is meant to be known by its texture
before any pitch is identified.

Both ground cues sound on any hex, with or without a unit on it, and everything a
hex reports is mixed into a single waveform, so a unit on high ground next to an
obstacle is heard as one sound starting at one instant rather than as a queue.

Volume, pan per tile, pitch per tile, rhythm, MIDI notes and every parameter of
the height glide and the impassable rasp can be adjusted in
`companion/sonar.json` without rebuilding.

New shortcuts read individual parts of the unit under the cursor without opening
the full inspection list:

- `Shift+E`: equipment.
- `Shift+F`: active effects.
- `Shift+D`: damage range, armour damage, head-hit chance and vision.
- `Shift+A`: bag slots 1 and 2, including empty slots.
- `Shift+W`: body and head armour, with item names and current/maximum durability.
- `Shift+T`: turn timing and current/maximum fatigue.

`Shift+S` now reads the active brother's usable skills, their costs and whether
each can currently be used, replacing the former `K` shortcut. The unmodified
Q/W/E/A/S/D movement cluster is unchanged.

### Roads can be surveyed at a glance

`Shift+R` counts discovered road segments inside the company's current vision,
groups them by direction and says whether the company is standing on a road. The
scan respects fog of war, while plain `R` continues to open factions and
relations.

### The current map seed can be copied

The world-map pause menu now starts on the campaign's map seed. Pressing Enter
copies it to the Windows clipboard and confirms the copy aloud.

Campaigns whose saves contain no seed explicitly announce “Map Seed:
Unavailable” instead of silently omitting the information.

### Named regions can be located without sight

`Z` now reads the region on the company's current tile and its position relative
to the region's printed name, using eight compass directions — for example,
“East of Glaucious Domain.” In the `M` map explorer it reads the cursor tile
instead, so a region remains useful for orientation even when it contains no
settlements. Both press and release are consumed, preserving the readout without
also triggering vanilla's northward camera pan.

Travel now announces that same reading automatically when the company crosses
into another named region or moves into another compass sector of its current
region. It is joined to the existing terrain, road and place cue so no interrupt
announcement cuts another one off. Every row in `B` also names its region and
sector after the place — for a settlement, after its owning faction as well — so
settlements, locations and landmarks are all placed on the map by name.

Regions are only named on explored ground. Map tiles keep their region under fog
of war, so `Z` on an unexplored hex in the `M` map explorer now answers
“Unexplored ground, no region known.” rather than reading out an area the map has
not yet revealed.

### Installing over 1.0.0

Run `install.bat` from this release; it replaces the files installed by 1.0.0.
Saved games are never touched, and `uninstall.bat` still leaves the game as it
came.

## 1.0

Version 1.0 marks the complete campaign milestone: company creation, management,
contracts, travel, tactical combat, rewards, saving and loading on the surfaces
the game provides, and the end of a campaign can all be played by ear without a
mouse. The nine practice battles provide a safe, repeatable place to learn the
tactical controls.

### Ground items can be found and recovered during battle

The tactical cursor now names every item physically lying on a discovered hex.
These are the game's live `tile.Items`: weapons, shields and other objects that a
brother standing there can equip or put in his bag during battle. Items retained
only inside `Corpse.Items` remain post-combat loot candidates and are not falsely
described as recoverable from the ground.

`P` opens the pickable objects under the active brother as a short list. Up/Down
selects one and Enter moves it to the backpack through the native ground-inventory
endpoint, preserving Action Point costs, Quick Hands, capacity checks and rollback.
F1 includes both the battlefield shortcut and the controls of the open list.

Verified in game with NVDA.

### The world map warns, guides and respects what is still hidden

A hostile party already in sight now announces again when it crosses the closing
distance bands at six, four and two tiles. The alerts have hysteresis, speak only
the most urgent party per scan and use the FIFO event channel, so a threat cannot
disappear into silence or repeatedly shout while pacing one threshold.

Roads are read with the directions they run from X, the map explorer and its V
list, and when the company walks onto or off one. The same implementation covers
rivers. Roads were verified in every readout; no river could be found during the
final audit, so its equivalent wording remains an explicitly non-blocking
verification gap. Undiscovered road segments stay hidden.

`Shift+F` counts the tracks inside the company's current vision and groups them by
north, northeast, southeast, south, southwest and northwest. Plain `F` retains
the game's show/hide-tracking action. Known landmarks accept Enter as an ordinary
approach order, while landmarks attached to undiscovered settlements remain out of
the lists and every other readout. Place rows now start with the useful rendered
name instead of repeating a category the list header already announced.

All reproducible paths above were verified in game with NVDA.

### The map speaks upkeep, confirmations and the numbers behind a deal

The daily settlement of food and wages now says who went hungry or unpaid, how
many days of food remain when supplies are low, and whether tomorrow's payroll is
covered. Both failure paths were forced and verified by ear.

F2 now has Company Status and Wounded Brothers categories. It reports payroll
coverage, total repair time and tools, total treatment time and medicine, and the
individual recovery time of every wounded man. Enter on an active contract or
ambition follows the game's own confirmation and consequence path; abandoning an
ambition and the expanded F2 readouts were verified in play.

Every otherwise unknown `dialog_screen` now owns the keyboard and is announced,
instead of sounding like a frozen game. Market rows carry both the town's price
and the item's base worth; provisions and trade goods in the company stash also
name their recorded purchase price when one exists.

### Practice battles and shorter tactical checks

The Scenarios screen is now a keyboard list of the nine prepared battles with
their names and descriptions, followed by separate Play and Cancel entries.
Selecting a row never starts it by accident. Starting a scenario also clears the
hidden menu cursor before tactical input begins.

Repeated battlefield checks are shorter: V keeps identity, health, armour,
equipment, morale, timing and effects; T reports only Action Points and fatigue;
and the combat log preserves the rendered sentence while compressing its standard
chance-and-roll suffix. The shorter place lists, scenarios and tactical hand-off
were verified in game with NVDA.

### Scope deliberately left after 1.0

The taxidermist cursor, ingredient list, guards and craft action are implemented,
including the Blazing Deserts building variant, but a real craft could not be
reproduced for final auditory confirmation. It remains documented rather than
holding back the complete campaign. Saving and loading during battle are not
offered by Battle Brothers itself.

Key remapping, configurable verbosity, positional sonar and a persistent
destination beacon are quality-of-life and orientation work scheduled after 1.0.
Accepting a settlement contract still requires leaving and re-entering the town to
refresh the accessible contract list.

### Installing over 0.9

Run `install.bat` as before; it replaces what 0.9 installed. Saves are never
touched, and `uninstall.bat` still leaves the game as it came.

## 0.9

Three of the four buildings that still answered "not accessible yet" now have a
cursor, the tile cursor reads the ground it lands on, `F1` answers "which keys
work here" from inside the game, and the attribute half of every level up stops
being lost in silence.

### New: harbor, training hall and taxidermist

The **harbor** is the one whose absence changed how a campaign had to be played:
booking passage is the map's only fast travel and it was mouse-only. Up/Down walk
the destinations, `V` opens the destination's own description, and `Enter` asks to
confirm before a second `Enter` pays and sails — sailing cannot be undone and
lands the company somewhere else. Each row also carries the owning faction and the
bearing and distance, both of which a sighted player has from the map, and which
together make the fare legible: it is distance times company size. A destination
still under fog says so instead of giving a bearing. When the harbor refuses —
you are escorting a caravan — the reason is spoken.

The **training hall** lists your whole roster, not just the men who can train.
Vanilla quietly drops the ones who cannot, and a short list read aloud sounds like
men gone missing, so those men are listed with the reason: too experienced, already
training, or a slave the manhunters will not school. `Enter` opens the three paid
lessons, a second `Enter` pays, `V` reads what a lesson teaches. Your purse is
checked before the game is called, because the game's own guard was the greyed-out
button and nothing else.

The **taxidermist** was unreadable: its ingredients are icons whose only text
lives in a mouse-over tooltip, and a greyed-out recipe gave no reason. Up/Down now
walk the recipes with their cost and, when one cannot be made, why not; `V` opens
the description and the ingredients, each with how many are still missing; `Enter`
opens the craft action and a second `Enter` pays for it. As with the temple,
crowns and ingredients are enforced before the game is called.

The **barber** is answered honestly rather than promised for later: it only swaps a
man's sprite — no cost, no effect in play — so there is nothing to describe, and
the mod says that instead of staying silent.

### New: F1 lists the keys that are live where you are standing

The mod owns some thirty keys across a dozen surfaces, and they lived only in the
README — unreachable from inside the game, which is exactly where one is
forgotten. `F1` opens the keys for the surface you are on as an ordinary
navigable list: the battlefield, the map, the market, a confirmation dialog, 21
contexts in all, resolved in the same order the key handling itself uses, so the
help always describes the surface that would receive your next keystroke. It
closes on any other key, which then goes on to do its job. The rows are
translatable strings like every other, so a translation covers the help too.

### New: the tile cursor reads height, zone of control and what a step costs

Three things the game always knew and only ever showed on screen. For every hex
the tactical cursor lands on:

- **Height** relative to the active brother. High ground is hit chance and reach
  in this game, and it was the one property of the ground that was unavailable by
  ear. It opens the readout, in the same breath as the terrain, and stays silent
  when you are level with the tile.
- **Enemy zone of control** — the same count the AI reads before deciding whether
  disengaging is safe. Standing there means a free attack for each of them the
  moment you walk away.
- **What walking there would cost** in action points and fatigue, the same preview
  a mouse hover draws. It says nothing with a skill already armed, where the
  target preview answers the question, and nothing on an occupied or undiscovered
  tile. The cursor can never cancel an armed skill.

Zone of control and cost close the readout, after everything it already said, so
sweeping hexes by ear stays as fast as it was.

### New: spending the attribute half of a level up

A level grants two things, spent separately: the attribute increases and the perk
point. Only the perk half had a keyboard route — the other half lived in a popup
behind the portrait's level label, reachable with the mouse alone. Every attribute
increase the company earned was therefore lost, and `F2` could report a man as
waiting to level up with an empty perk tree and nothing left to do.

**This changes a key you learned in 0.8.** `Enter` on the character screen's
identity row no longer renames the man directly; it opens a short menu — where
vanilla draws its star, next to the name and the level — with the level up first
and renaming second. The level-up entry appears only while the man really has
increases to spend, and never in battle or for a guest, the two exclusions vanilla
makes.

Choosing the increases is a modal list, like the dismissal confirmation and for
the same reason: it cannot be undone by anything short of loading a save. `Enter`
chooses or unchooses a row and nothing is spent until you activate the entry that
applies them, which reads the three attributes back and says it is permanent
before you commit. `Escape` discards. That is more permissive than vanilla, which
kills its `+` button on the first click.

### The character sheet grows weapon rows and talent stars

Two readouts a sighted player gets for free: the four weapon-dependent rows
vanilla prints under ranged defense, and the **talent stars** on the eight
attributes that grow on level up. The stars decide who to hire, arm, train and
spend perks on, and until now they were spoken only inside a level up — too late
for any of those.

### Settlements speak their situations

A good harvest that halves food prices, a siege, ambushed trade routes: vanilla
draws these in the corner of the town screen for everyone to see and they had no
voice at all. The town screen now names how many there are and reads each one. On
the world map they are gated behind the Agent follower, and `V` in the `B` survey
honours that gate exactly as the game does. The survey also names each
settlement's owning faction — the banner, in words.

### F2 says what each man owes, and lost two rows

The company status now names which half of a level each man still owes — the
attribute increases or the perk point — instead of one ambiguous sentence that
could never reach zero.

`Enter` on the **ambition** row abandons the ambition, through the same path and
the same guards as the mouse-only click on the banner.

Two rows are gone. The speed row answered "what speed is it now?", but pausing
and the `1`, `2` and `3` keys have announced every speed change as it happens
since the release that added the row. And "no one is waiting to level up" was the
empty case of the level-up rows — an empty list says that best by not being there.

### Menus and towns answer on the key press

Every cursor over the main and pause menus, the settlement screen and its
building dialogs used to wait for the key *release* before announcing the row it
had moved to, so a long building or item list was "press, lift, then hear it" —
dead time on surfaces that are nothing but list navigation. Those cursors now
speak on the press, debounced so that holding a direction key walks the list at a
deliberate cadence instead of doing nothing.

`Enter` deliberately stays on the release: it opens text fields — the company
name, the name prompt when saving — and once a field has focus the engine routes
the keyboard straight to it, so acting on the press opened and closed the field
inside a single tap and nothing could be typed. The movement keys are where the
latency actually was.

### Fix: Retire's confirmation dialog was a trap

Retire was reachable and its end screen already worked, but its confirmation
announced nothing, the cursor kept driving the buttons behind it, and a second
`Enter` stacked a second popup. `Escape` was worse than useless: it closed the
pause menu underneath and left the dialog hanging on screen — a live "Ok" one
keystroke away from ending a campaign you had just backed out of. The dialog is
now announced, owns the keyboard while it is up, and `Escape` cancels it properly.

### Fix: the loot tooltip told you to right-click

`V` on a piece of loot on the post-combat result screen ended with "right mouse
button: take item" — an instruction that is false there, where loot is taken with
`Enter`. The mod has stripped those mouse-hint rows from tooltips for a while, but
the result screen was missing from the list of places it did so. Rows carrying a
meaningful icon, like the lock or the warning, are untouched.

### Fix: direction keys walked the company under a confirmation dialog

With a confirmation dialog on screen, the world map's direction keys still moved
the company underneath it. They now stay quiet until the dialog is answered.

### Installing over 0.8

Run `install.bat` as before; it replaces what 0.8 installed. Saves are never
touched, and `uninstall.bat` still leaves the game as it came.

## 0.8

Four changes on top of 0.7: three world-map improvements, one item-loss fix.

### New: places and enemies announced as they come into sight

Until now the only way to learn that a city, camp or landmark existed was to open
the B survey and re-check it by hand — a sighted player sees it the moment it
scrolls into view. The mod now watches the same fog-of-war tests the survey uses
and speaks a sighting as it crosses that line, with no list open.

- Settlements, locations and landmarks announce **once**, the first time they are
  seen.
- **Enemy parties** re-announce every time they come back into sight, the way a
  sighted player watches them reappear. Allies and neutrals stay silent, matching
  the vanilla discovery sound, which never plays for them either.
- Several sightings in the same scan collapse into a short count instead of
  reading every row.

### Footprint headings on every cursor readout

`X` and the `Q/W/E/A/S/D` cursor steps used to read footprints by family only;
the direction a trail ran cost opening the `V` list — too slow between marching
steps or while sweeping hexes. Every cursor readout now carries the trail
directions: `X` in either explorer mode, and each directional step. `X` also
works with the map explorer **off**, reading terrain and trails on the company's
own hex; it did nothing of ours there before.

### Company status moved from G to F2

**This changes a key you learned in 0.7.** The map explorer's own `G` (send the
company to the cursor tile) made the company readout unreachable while the
explorer was on. `F2` carries no native binding and no ambiguity in either mode.

### Worn equipment in Shift+V

`Shift+V`'s per-unit inspection was missing worn equipment — the one sheet fact
you could not get for an enemy or ally without the character screen, which is
player-only. The new equipment row uses the character sheet's own wording, and
`V` on it opens a nested list to browse each piece.

### Fix: moving an item from a brother's bag to the stash could destroy it

"Move to stash" on a backpack row emptied the bag slot but never stored the item,
and still reported success — anything moved that way was silently lost. Vanilla
never hits this path, because a mouse drag always names the stash slot it dropped
on. Now routed through the null-tolerant path the game already uses for
equipment-to-stash.

### Installing over 0.7

Run `install.bat` as before; it replaces what 0.7 installed. Saves are never
touched, and `uninstall.bat` still leaves the game as it came.

The installer also refuses to install a mod and a companion app from different
releases — the mismatch that would otherwise leave you with an older voice — and
says which half is stale instead of installing the pair.

## 0.7

First public release: the installer, the packaged companion app and the
documentation. See the README for everything the mod covers.

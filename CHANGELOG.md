# Changelog

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

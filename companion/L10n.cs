using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// Every string added by the mod lives here. Game text is passed in already
    /// localized from the rendered DOM and is only interpolated into these phrases.
    /// English defaults are compiled in; a translation is a plain-text file
    /// <c>lang/&lt;code&gt;.lang</c> next to the exe ("key = value" per line, "#"
    /// comments, UTF-8), selected by <see cref="Init"/>. Missing keys fall back to
    /// English, so partial translations are safe. Game text itself is always read
    /// already-localized from the DOM/Squirrel and never passes through this class.
    /// </summary>
    internal static class L10n
    {
        internal const string DefaultLanguage = "en";

        private static Dictionary<string, string>? _overrides;

        internal static void Init(string languageCode)
        {
            _overrides = null;
            if (string.IsNullOrEmpty(languageCode) ||
                string.Equals(languageCode, DefaultLanguage, StringComparison.OrdinalIgnoreCase))
                return;

            try
            {
                string? dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                string path = Path.Combine(Path.Combine(dir ?? ".", "lang"), languageCode + ".lang");
                if (!File.Exists(path))
                {
                    Console.WriteLine($"[L10n] Language file not found: {path}. Using English.");
                    return;
                }

                var map = new Dictionary<string, string>(StringComparer.Ordinal);
                foreach (string rawLine in File.ReadAllLines(path))
                {
                    string line = rawLine.Trim();
                    if (line.Length == 0 || line[0] == '#') continue;

                    int eq = line.IndexOf('=');
                    if (eq <= 0) continue;

                    string key = line.Substring(0, eq).Trim();
                    string value = line.Substring(eq + 1).Trim();
                    if (key.Length > 0 && value.Length > 0)
                        map[key] = value;
                }

                _overrides = map;
                Console.WriteLine($"[L10n] Loaded {map.Count} strings from lang/{languageCode}.lang.");
            }
            catch (Exception e)
            {
                _overrides = null;
                Console.WriteLine($"[L10n] Could not load language '{languageCode}': {e.Message}. Using English.");
            }
        }

        /// <summary>Translated string for <paramref name="key"/>; the key itself when
        /// unknown, so a typo is audible instead of silent.</summary>
        internal static string T(string key)
        {
            if (string.IsNullOrEmpty(key)) return key;

            if (_overrides != null && _overrides.TryGetValue(key, out string? value))
                return value;
            return English.TryGetValue(key, out value) ? value : key;
        }

        /// <summary>As <see cref="T"/> plus <see cref="string.Format(string,object[])"/>.
        /// A malformed translation degrades to the unformatted string, never throws.</summary>
        internal static string F(string key, params object[] args)
        {
            string format = T(key);
            try { return string.Format(format, args); }
            catch (FormatException) { return format; }
        }

        private static readonly Dictionary<string, string> English = new(StringComparer.Ordinal)
        {
            ["companion.loaded"] = "The Unseen Banner, version {0}, loaded.",
            ["menu.main"] = "Main menu. {0}.",
            ["menu.screen"] = "{0}. {1}.",
            ["menu.option.selected"] = "{1}: {0}, selected.",
            ["menu.option.not_selected"] = "{1}: {0}, not selected.",
            ["menu.option.selected_detail"] = "{1}: {0}, selected. {2}",
            ["menu.checked"] = "{0}, checked.",
            ["menu.not_checked"] = "{0}, not checked.",
            ["menu.value"] = "{1}: {0}.",
            ["menu.editing"] = "{1}: {0}. Editing.",
            ["menu.previous_banner"] = "Previous banner.",
            ["menu.next_banner"] = "Next banner.",
            ["menu.banner"] = "Banner {0}.",
            // Scenarios: the main menu's prepared tactical battles. The description is
            // what the row is for — it says what the battle teaches and how hard it is —
            // so it is spoken with the name, the way a company origin is. Selecting a row
            // is what the cursor does by standing on it; Play is a button of its own,
            // past the last scenario, so no single keystroke starts a fight.
            ["menu.scenario.screen"] = "Scenarios. {1} entries. Use Up and Down to review; the last two entries are Play and Cancel.",
            ["menu.scenario"] = "{0}.",
            ["menu.scenario.detail"] = "{0}. {2}",
            // Load / Save campaign screens.
            ["menu.button.disabled"] = "{0}, unavailable.",
            ["menu.campaign.screen"] = "{0}. {1}",
            ["menu.campaign.screen.one"] = "1 save game.",
            ["menu.campaign.screen.count"] = "{0} save games.",
            ["menu.campaign.screen.empty"] = "No save games.",
            ["menu.campaign"] = "{0}",
            ["menu.campaign.selected"] = "Selected.",
            ["menu.campaign.disabled"] = "Unavailable.",
            ["menu.popup.delete"] = "Delete {0}? Choose Cancel or Ok.",
            // Retiring ends the campaign for good, so the warning read out is the
            // game's own wording ({0}), not a paraphrase. {1} is the dialog title.
            ["menu.popup.retire"] = "{1}. {0} Cancel is focused. Use Up and Down to choose Cancel or Ok, Enter to take it, Escape to cancel.",
            ["menu.save.name_prompt"] = "Type a name for the save, then press Enter to confirm or Escape to cancel.",
            // Options screen. Game-owned labels (tabs and setting names) arrive
            // from the rendered DOM; only the connective speech lives here.
            ["menu.options.screen"] = "{0}. {1} tab. Up and down move, left and right adjust, Enter activates, Escape goes back.",
            ["menu.options.tab"] = "{0} tab, selected.",
            ["menu.options.value"] = "{0}: {1}.",
            ["menu.options.percent"] = "{0}: {1} percent.",
            ["menu.options.applied"] = "Options applied.",
            ["event.screen"] = "{0}. {1}",
            ["event.option"] = "Option {1} of {2}: {0}",
            // Generic native tooltips (phase 2.1). Their visible game text arrives
            // verbatim from the rendered DOM; only labels for known image-only
            // semantics belong to the mod and therefore live in L10n.
            ["tooltip.content"] = "{0}",
            ["tooltip.detail"] = "{0} Detail {1} of {2}.",
            ["tooltip.details.group"] = "Details",
            ["tooltip.details.one"] = "1 detail available. Press V.",
            ["tooltip.details.many"] = "{0} details available. Press V.",
            ["tooltip.unavailable"] = "No details available.",
            ["tooltip.icon.action_points"] = "Action points",
            ["tooltip.icon.ambition"] = "Ambition",
            ["tooltip.icon.ammunition"] = "Ammunition",
            ["tooltip.icon.armor_body"] = "Body armor",
            ["tooltip.icon.armor_damage"] = "Armor damage",
            ["tooltip.icon.armor_head"] = "Head armor",
            ["tooltip.icon.bonus"] = "Bonus",
            ["tooltip.icon.brothers"] = "Brothers",
            ["tooltip.icon.camp"] = "Camp",
            ["tooltip.icon.cancel"] = "Cancel",
            ["tooltip.icon.chance_to_hit_head"] = "Chance to hit the head",
            ["tooltip.icon.condition"] = "Condition",
            ["tooltip.icon.contract"] = "Contract",
            ["tooltip.icon.crowns"] = "Crowns",
            ["tooltip.icon.daily_wages"] = "Daily wages",
            ["tooltip.icon.damage"] = "Damage",
            ["tooltip.icon.days_wounded"] = "Days wounded",
            ["tooltip.icon.direct_damage"] = "Damage ignoring armor",
            ["tooltip.icon.documents"] = "Documents",
            ["tooltip.icon.experience"] = "Experience",
            ["tooltip.icon.fatigue"] = "Fatigue",
            ["tooltip.icon.food"] = "Food",
            ["tooltip.icon.health"] = "Health",
            ["tooltip.icon.height"] = "Height",
            ["tooltip.icon.hit_chance"] = "Hit chance",
            ["tooltip.icon.initiative"] = "Initiative",
            ["tooltip.icon.kills"] = "Kills",
            ["tooltip.icon.left_mouse_button"] = "Left mouse button",
            ["tooltip.icon.level"] = "Level",
            ["tooltip.icon.locked"] = "Locked",
            ["tooltip.icon.medical_supplies"] = "Medical supplies",
            ["tooltip.icon.melee_defense"] = "Melee defense",
            ["tooltip.icon.melee_skill"] = "Melee skill",
            ["tooltip.icon.morale"] = "Morale",
            ["tooltip.icon.negative"] = "Negative",
            ["tooltip.icon.positive"] = "Positive",
            ["tooltip.icon.ranged_defense"] = "Ranged defense",
            ["tooltip.icon.ranged_skill"] = "Ranged skill",
            ["tooltip.icon.relations"] = "Relations",
            ["tooltip.icon.resolve"] = "Resolve",
            ["tooltip.icon.right_mouse_button"] = "Right mouse button",
            ["tooltip.icon.ctrl_right_mouse_button"] = "Control plus right mouse button",
            ["tooltip.icon.shield_damage"] = "Shield damage",
            ["tooltip.icon.sight"] = "Sight",
            ["tooltip.icon.special"] = "Special",
            ["tooltip.icon.tools"] = "Tools and supplies",
            ["tooltip.icon.warning"] = "Warning",
            // Narrative body as a re-readable list entry above the options
            // (phase 4.5): read verbatim when the player navigates onto it.
            ["event.body"] = "{0}",
            // Tactical tile readout (phase 3.2). Terrain names keyed by the
            // engine's TerrainType enum (see config/tactical.nut).
            ["tile.terrain.0"] = "Impassable",
            ["tile.terrain.1"] = "Paved ground",
            ["tile.terrain.2"] = "Flat ground",
            ["tile.terrain.3"] = "Rough ground",
            ["tile.terrain.4"] = "Forest",
            ["tile.terrain.5"] = "Rocks",
            ["tile.terrain.6"] = "Swamp",
            ["tile.terrain.7"] = "Sand",
            ["tile.terrain.8"] = "Shallow water",
            ["tile.terrain.9"] = "Deep water",
            ["tile.empty"] = "empty",
            ["tile.self"] = "{0}, your active man",
            ["tile.ally"] = "ally {0}",
            ["tile.enemy"] = "enemy {0}",
            ["tile.object"] = "{0}",
            ["tile.health"] = "health {0} of {1}",
            ["tile.corpse"] = "Corpse: {0}",
            ["tile.edge"] = "Edge of the battlefield.",
            ["tile.position"] = "{0} tiles, {1} o'clock",
            ["tile.position.one"] = "1 tile, {0} o'clock",
            ["tile.no_enemies"] = "No enemies in sight.",
            ["tile.no_allies"] = "No other allies on the battlefield.",
            // Target preview appended to the tile readout while a skill is armed
            // (phase 3.3).
            ["tile.target.valid"] = "Valid target.",
            ["tile.target.invalid"] = "Not a valid target.",
            ["tile.target.hit"] = "Valid target, {0} percent to hit.",
            // Height, zone of control and movement cost, spoken last of all so they
            // never delay the part of the readout the player already navigates by.
            // Height is relative to the active man and silent when level with him.
            ["tile.elevation.higher.one"] = "One level higher.",
            ["tile.elevation.lower.one"] = "One level lower.",
            ["tile.elevation.higher"] = "{0} levels higher.",
            ["tile.elevation.lower"] = "{0} levels lower.",
            ["tile.zoc.one"] = "Held by 1 enemy zone of control.",
            ["tile.zoc"] = "Held by {0} enemy zones of control.",
            ["tile.move.cost"] = "Walk: {0} action points, {1} fatigue.",
            ["tile.move.partial"] = "Walk: {0} action points, {1} fatigue, stopping short.",
            ["tile.move.far"] = "Out of walking reach this turn.",
            ["tile.move.none"] = "No path there.",
            // Skill selection and acting on the focused tile (phase 3.3).
            ["combat.skill.selected"] = "{0}. {1} action points, {2} fatigue.",
            ["combat.skill.choose_target"] = "Choose a target.",
            ["combat.skill.deselected"] = "{0}, deselected.",
            ["combat.move"] = "Moving {0} tiles.",
            ["combat.move.one"] = "Moving 1 tile.",
            ["combat.move.here"] = "Already there.",
            ["combat.move.blocked"] = "Can't reach that tile.",
            ["combat.move.no_ap"] = "Not enough action points to move.",
            ["combat.move.rooted"] = "You are rooted and can't move.",
            ["combat.log.rolls"] = "(rolls {0}, {1})",
            // On-demand readouts (phase 3.4).
            ["combat.status"] = "{0} of {1} action points. Fatigue {2} of {3}.",
            ["combat.morale.0"] = "Fleeing",
            ["combat.morale.1"] = "Breaking",
            ["combat.morale.2"] = "Wavering",
            ["combat.morale.3"] = "Steady",
            ["combat.morale.4"] = "Confident",
            ["combat.morale.5"] = "Unbreakable",
            ["combat.turnorder"] = "Turn order: {0}.",
            ["combat.turnorder.self"] = "{0}, you",
            ["combat.turnorder.ally"] = "{0}",
            ["combat.turnorder.enemy"] = "enemy {0}",
            ["combat.turnorder.empty"] = "No turn order available.",
            ["combat.enemies"] = "{0} enemies. {1}.",
            ["combat.enemies.one"] = "1 enemy. {0}.",
            ["combat.enemies.entry"] = "{0} at {1} tiles",
            ["combat.enemies.entry.one"] = "{0} at 1 tile",
            ["combat.enemies.empty"] = "No enemies in sight.",
            ["combat.engaged"] = "{0} enemies around. ({1})",
            ["combat.engaged.one"] = "1 enemy around. ({0})",
            ["combat.engaged.entry"] = "{0} at {1} o'clock",
            ["combat.engaged.none"] = "No enemies around.",
            // Active man's usable skills, the numbered action bar (the k key).
            ["combat.skills"] = "{0} skills. {1}.",
            ["combat.skills.one"] = "1 skill. {0}.",
            ["combat.skills.entry"] = "{0}: {1}, {2} action points, {3} fatigue",
            ["combat.skills.unavailable"] = "(unavailable)",
            ["combat.skills.empty"] = "No skills available.",
            // Turn and round events (phase 3.5).
            ["combat.turn.player"] = "Your turn: {0}, {1} action points.",
            ["combat.round"] = "Round {0}.",
            // On-demand unit inspection for any unit on the field (the v key). Kind
            // header, then the tooltip's live combat stats, when it acts, and effects.
            ["combat.inspect.header.self"] = "{0}, your man, level {1}.",
            ["combat.inspect.header.ally"] = "Ally {0}, level {1}.",
            ["combat.inspect.header.enemy"] = "Enemy {0}, level {1}.",
            ["combat.inspect.body"] = "Health {0} of {1}. Head armor {2} of {3}. Body armor {4} of {5}.",
            ["combat.inspect.morale"] = "Morale: {0}.",
            ["combat.inspect.timing.now"] = "Acting now.",
            ["combat.inspect.timing.done"] = "Turn done.",
            ["combat.inspect.timing.turns"] = "Acts in {0} turns.",
            ["combat.inspect.timing.turns.one"] = "Acts next.",
            ["combat.inspect.effects"] = "Effects: {0}.",
            ["combat.inspect.sight"] = "{0}. Not currently in sight.",
            ["combat.inspect.empty"] = "Nothing there.",
            ["combat.inspect.hidden"] = "Hidden opponent.",
            ["combat.inspect.object"] = "{0}.",
            ["combat.inspect.object_corpse"] = "{0}. Corpse: {1}.",
            ["combat.inspect.corpse"] = "Corpse: {0}.",
            // Shift+V presents the same unit readout as a navigable list. Effect
            // names remain game-owned text and V resolves their native tooltips.
            ["combat.inspect.menu.screen"] = "Combatant details for {0}. Use Up and Down to review; Home and End jump to the beginning and end; V reads the focused effect tooltip. Press Shift plus V or Escape to close.",
            ["combat.inspect.menu.health"] = "Health {1} of {2}.",
            ["combat.inspect.menu.armor.head"] = "Head armor {1} of {2}.",
            ["combat.inspect.menu.armor.body"] = "Body armor {1} of {2}.",
            ["combat.inspect.menu.fatigue"] = "Fatigue {1} of {2}.",
            ["combat.inspect.menu.morale"] = "Morale: {0}.",
            ["combat.inspect.menu.effect"] = "Effect: {0}.",
            ["combat.inspect.menu.effects.none"] = "No effects.",
            ["combat.inspect.menu.closed"] = "Combatant details closed.",
            // Character sheet as a navigable list for the C/I screen. Up/Down walk
            // these entries one at a time for the shown brother.
            ["combat.sheet.brother"] = "{0}. {1}",
            ["combat.sheet.identity"] = "{0}, level {1}.",
            ["combat.sheet.background"] = "{0}.",
            ["combat.sheet.xp"] = "{1} experience, {2} needed for next level.",
            ["combat.sheet.mood"] = "Mood: {0}.",
            ["combat.sheet.hp"] = "Health {1} of {2}.",
            ["combat.sheet.fatigue"] = "Fatigue {1} of {2}.",
            ["combat.sheet.resolve"] = "Resolve {1}.",
            ["combat.sheet.initiative"] = "Initiative {1}.",
            ["combat.sheet.mskill"] = "Melee skill {1}.",
            ["combat.sheet.rskill"] = "Ranged skill {1}.",
            ["combat.sheet.mdef"] = "Melee defense {1}.",
            ["combat.sheet.rdef"] = "Ranged defense {1}.",
            // The four weapon-dependent rows vanilla shows under ranged defense. Kept
            // terse on purpose: they are read on every pass through the sheet.
            ["combat.sheet.damage"] = "Damage {1} to {2}.",
            ["combat.sheet.damage.none"] = "Unarmed.",
            ["combat.sheet.armordamage"] = "Armor damage {1} percent.",
            ["combat.sheet.headhit"] = "Head hit {1} percent.",
            ["combat.sheet.vision"] = "Vision {1}.",
            // Talent stars, appended to the eight attributes that grow on level up.
            // Zero is silent: a brother always has exactly three talents, so the three
            // rows that speak tell you the other five are empty, and saying "no stars"
            // on five of eight rows every pass would be pure noise.
            ["combat.sheet.talent.0"] = "",
            ["combat.sheet.talent.1"] = "One star.",
            ["combat.sheet.talent.2"] = "Two stars.",
            ["combat.sheet.talent.3"] = "Three stars.",
            ["combat.sheet.armor.head"] = "Head armor {1} of {2}.",
            ["combat.sheet.armor.body"] = "Body armor {1} of {2}.",
            ["combat.sheet.skills"] = "Skills: {0}.",
            ["combat.sheet.skills.details"] = "Skill details",
            ["combat.sheet.skills.entry"] = "{0}, {1} action points, {2} fatigue",
            ["combat.sheet.skills.none"] = "No skills.",
            ["combat.sheet.injuries"] = "Injuries: {0}.",
            ["combat.sheet.injuries.details"] = "Injury details",
            ["combat.sheet.injuries.none"] = "No injuries.",
            ["combat.sheet.traits"] = "Traits: {0}.",
            ["combat.sheet.traits.details"] = "Trait details",
            ["combat.sheet.traits.none"] = "No traits.",
            ["combat.sheet.perks"] = "Perks: {0}.",
            ["combat.sheet.perks.details"] = "Perk details",
            ["combat.sheet.perks.none"] = "No perks.",
            ["combat.sheet.equipment"] = "Equipment: {0}.",
            ["combat.sheet.equipment.details"] = "Equipment details",
            ["combat.sheet.equipment.none"] = "No equipment.",
            // Full world CharacterScreen navigation (phase 2.4). Page Up/Down
            // changes section; Up/Down walks the current section's linear list.
            ["world.character.position"] = "Entry {0} of {1}.",
            ["world.character.section.changed"] = "{0}. {1}",
            ["world.character.section.sheet"] = "Character sheet",
            ["world.character.section.equipment"] = "Equipped items",
            ["world.character.section.bag"] = "Backpack",
            ["world.character.section.stash"] = "Stash",
            ["world.character.section.perks"] = "Perks",
            ["world.character.section.formation"] = "Formation",
            ["world.character.empty"] = "Empty.",
            ["world.character.rename.opened"] = "Change name for {0}. The current name is selected. Type the replacement and press Enter to save; Escape cancels. The title will remain unchanged.",
            ["world.character.rename.saved"] = "{0} renamed to {1}.",
            ["world.character.rename.cancelled"] = "Name change cancelled.",
            ["world.character.rename.unavailable"] = "The name editor is unavailable.",
            ["world.character.item.empty"] = "empty",
            ["world.character.item.amount"] = "{0}, {1}",
            ["world.character.equipment.slot"] = "{0}: {1}.",
            ["world.character.equipment.slot.mainhand"] = "Main hand",
            ["world.character.equipment.slot.offhand"] = "Off hand",
            ["world.character.equipment.slot.head"] = "Head",
            ["world.character.equipment.slot.body"] = "Body",
            ["world.character.equipment.slot.accessory"] = "Accessory",
            ["world.character.equipment.slot.ammo"] = "Ammunition",
            ["world.character.equipment.details"] = "Equipment details",
            ["world.character.bag.slot"] = "Bag slot {0}: {1}.",
            ["world.character.bag.details"] = "Backpack details",
            ["world.character.stash.item"] = "{0}.",
            ["world.character.stash.commands"] = "Inventory commands. Filter: {0}.",
            ["world.character.stash.details"] = "Stash item details",
            // Phase 2.3 inventory actions. Enter opens this explicit sub-list and V
            // returns to the focused inventory row without changing game state.
            ["world.inventory.filter.all"] = "all items",
            ["world.inventory.filter.weapons"] = "weapons",
            ["world.inventory.filter.armor"] = "armor",
            ["world.inventory.filter.misc"] = "miscellaneous",
            ["world.inventory.filter.usable"] = "usable items",
            ["world.inventory.action.equip"] = "Equip",
            ["world.inventory.action.unlock_perk"] = "Take this perk",
            ["world.inventory.action.use"] = "Use",
            ["world.inventory.action.move_bag"] = "Move to backpack",
            ["world.inventory.action.move_stash"] = "Move to stash",
            ["world.inventory.action.repair_mark"] = "Mark for repair",
            ["world.inventory.action.repair_unmark"] = "Stop repairing",
            ["world.inventory.action.sort"] = "Sort stash",
            ["world.inventory.action.filter_all"] = "Show all items",
            ["world.inventory.action.filter_weapons"] = "Show weapons",
            ["world.inventory.action.filter_armor"] = "Show armor",
            ["world.inventory.action.filter_misc"] = "Show miscellaneous items",
            ["world.inventory.action.filter_usable"] = "Show usable items",
            ["world.inventory.action.for_item"] = "{0}: {1}.",
            ["world.inventory.action.standalone"] = "{0}.",
            ["world.inventory.action.position"] = "Action {0} of {1}.",
            ["world.inventory.action.opened"] = "Actions. {0} Press Enter to perform; V to go back.",
            ["combat.inventory.action.cost"] = "{0} Cost: {1} Action Points.",
            ["world.inventory.actions.one"] = "Press Enter for one action.",
            ["world.inventory.actions.many"] = "Press Enter for {0} actions.",
            ["world.inventory.actions.none"] = "No inventory actions are available for {0}.",
            ["world.inventory.actions.none_empty"] = "No inventory actions are available for this empty slot.",
            ["world.inventory.result.equip"] = "{0} equipped.",
            ["world.inventory.result.use"] = "{0} used.",
            ["world.inventory.result.move_bag"] = "{0} moved to backpack.",
            ["world.inventory.result.move_stash"] = "{0} moved to stash.",
            ["world.inventory.result.repair_mark"] = "{0} marked for repair.",
            ["world.inventory.result.repair_unmark"] = "{0} is no longer marked for repair.",
            ["world.inventory.result.sort"] = "Stash sorted.",
            ["world.inventory.result.filter_all"] = "Showing all stash items.",
            ["world.inventory.result.filter_weapons"] = "Showing weapons.",
            ["world.inventory.result.filter_armor"] = "Showing armor.",
            ["world.inventory.result.filter_misc"] = "Showing miscellaneous items.",
            ["world.inventory.result.filter_usable"] = "Showing usable items.",
            ["combat.inventory.result.equip"] = "{0} equipped. {1} action points remaining.",
            ["world.inventory.error.0"] = "Inventory action failed.",
            ["world.inventory.error.1"] = "The selected brother is no longer available.",
            ["world.inventory.error.2"] = "The selected inventory is unavailable.",
            ["world.inventory.error.3"] = "The stash is unavailable.",
            ["world.inventory.error.4"] = "The ground inventory is unavailable.",
            ["world.inventory.error.5"] = "The ground item is no longer available.",
            ["world.inventory.error.6"] = "The stash item is no longer available.",
            ["world.inventory.error.7"] = "The backpack item is no longer available.",
            ["world.inventory.error.8"] = "The item could not be removed from the backpack.",
            ["world.inventory.error.9"] = "The target equipment slot could not be cleared.",
            ["world.inventory.error.10"] = "The selected item could not be removed.",
            ["world.inventory.error.11"] = "The backpack item could not be equipped.",
            ["world.inventory.error.12"] = "The ground item could not be equipped.",
            ["world.inventory.error.13"] = "The stash item could not be equipped or used.",
            ["world.inventory.error.14"] = "The displaced item could not be placed in the backpack.",
            ["world.inventory.error.15"] = "The ground item could not be placed in the backpack.",
            ["world.inventory.error.17"] = "The stash item could not be placed in the backpack.",
            ["world.inventory.error.20"] = "The item is already in the backpack.",
            ["world.inventory.error.21"] = "This item cannot be changed during battle.",
            ["world.inventory.error.22"] = "This item has no compatible equipment slot.",
            ["world.inventory.error.30"] = "Not enough Action Points.",
            ["world.inventory.error.31"] = "The backpack has no room for this change.",
            ["world.inventory.error.32"] = "The stash has no room for this change.",
            ["world.inventory.error.40"] = "Only the active brother can change items.",
            // Phase 2.3b market navigation. Prices come from each live item; V
            // reads the native rendered tooltip for the item and equipped comparison.
            ["world.market.screen"] = "{0}. {1} {2} crowns available. Use Page Down and Page Up to change section; Up and Down to review items; A and D to change the comparison brother; Escape to return to town.",
            ["world.market.section.buy"] = "Shop stock",
            ["world.market.section.sell"] = "Company stash",
            ["world.market.buy.item"] = "{0}. Buy price {1} crowns.",
            ["world.market.sell.item"] = "{0}. Sell price {1} crowns.",
            // The two numbers that decide a deal, spoken with the row instead of waiting
            // behind V: what the item is worth anywhere — the same figure the tooltip words
            // as "Worth" — and, for provisions and trading goods, what this company paid
            // for it. No other item records a purchase price, so none claims one.
            ["world.market.value"] = "Worth {0}.",
            ["world.market.bought"] = "Bought for {0}.",
            ["world.market.comparison.equipped"] = "Comparing for {0}: equipped {1}.",
            ["world.market.comparison.empty"] = "Comparing for {0}: nothing equipped in this slot.",
            ["world.market.position"] = "Item {0} of {1}.",
            ["world.market.commands"] = "Market inventory commands. Filter: {0}.",
            ["world.market.empty"] = "{0} is empty.",
            ["world.market.actions.none"] = "No market actions are available for {0}.",
            ["world.market.actions.none_empty"] = "No market actions are available here.",
            ["world.market.action.buy"] = "Buy for {0} crowns",
            ["world.market.action.sell"] = "Sell for {0} crowns",
            ["world.market.action.repair"] = "Repair for {0} crowns",
            ["world.market.action.sort"] = "Sort company stash",
            ["world.market.action.filter_all"] = "Show all company items",
            ["world.market.action.filter_weapons"] = "Show company weapons",
            ["world.market.action.filter_armor"] = "Show company armor",
            ["world.market.action.filter_misc"] = "Show miscellaneous company items",
            ["world.market.action.filter_usable"] = "Show usable company items",
            ["world.market.action.for_item"] = "{0}: {1}.",
            ["world.market.action.standalone"] = "{0}.",
            ["world.market.action.position"] = "Action {0} of {1}.",
            ["world.market.action.opened"] = "Actions. {0} Press Enter to perform; V or Escape to go back.",
            ["world.market.confirm.unique"] = "{0} is unique. Sell it for {1} crowns?",
            ["world.market.confirm.precious"] = "{0} is valuable. Sell it for {1} crowns?",
            ["world.market.confirm.choice.cancel"] = "Cancel",
            ["world.market.confirm.choice.sell"] = "Confirm sale",
            ["world.market.confirm.choice.position"] = "Choice {0} of {1}.",
            ["world.market.confirm.opened"] = "{0} Use Up and Down to choose; Enter confirms; V or Escape cancels.",
            ["world.market.confirm.cancelled"] = "Sale of {0} cancelled.",
            ["world.market.result.buy"] = "{0} bought for {1} crowns. {2} crowns remaining.",
            ["world.market.result.sell"] = "{0} sold for {1} crowns. {2} crowns remaining.",
            ["world.market.result.repair"] = "{0} repaired for {1} crowns. {2} crowns remaining.",
            ["world.market.result.sort"] = "Company stash sorted.",
            ["world.market.result.filter_all"] = "Showing all company items.",
            ["world.market.result.filter_weapons"] = "Showing company weapons.",
            ["world.market.result.filter_armor"] = "Showing company armor.",
            ["world.market.result.filter_misc"] = "Showing miscellaneous company items.",
            ["world.market.result.filter_usable"] = "Showing usable company items.",
            ["world.market.error.money"] = "Not enough crowns.",
            ["world.market.error.space"] = "The company stash is full.",
            ["world.market.error.cannot_sell"] = "This item cannot be sold.",
            ["world.market.error.repair"] = "The item could not be repaired. Check the available crowns and try again.",
            ["world.market.error.unavailable"] = "The market action could not be completed.",
            // Phase 4.5 recruitment. Candidate facts come from the live native
            // roster; V renders the game's own background/trait tooltips.
            ["world.recruit.screen"] = "Recruitment. {0} crowns available. Use Up and Down to review candidates; Enter opens actions; V reads background and trait details; Escape returns to town. {1}",
            ["world.recruit.candidate"] = "{0}, {1}, level {2}. Hiring fee {3} crowns. Daily wage {4} crowns.",
            ["world.recruit.tryout.unknown"] = "Traits unknown. Tryout price {0} crowns.",
            ["world.recruit.tryout.none"] = "Tryout complete; no traits revealed.",
            ["world.recruit.tryout.one"] = "Tryout complete; 1 trait revealed.",
            ["world.recruit.tryout.count"] = "Tryout complete; {0} traits revealed.",
            ["world.recruit.position"] = "Candidate {0} of {1}.",
            ["world.recruit.empty"] = "No recruits are available here. {0} crowns available.",
            ["world.recruit.empty.opened"] = "Recruitment. {0} Use Escape to return to town.",
            ["world.recruit.action.hire"] = "Hire for {0} crowns",
            ["world.recruit.action.tryout"] = "Try out for {0} crowns",
            ["world.recruit.action.for_candidate"] = "{0}: {1}.",
            ["world.recruit.action.position"] = "Action {0} of {1}.",
            ["world.recruit.action.opened"] = "Actions. {0} Press Enter to perform; V or Escape to go back.",
            ["world.recruit.actions.none"] = "No recruitment actions are available for {0}.",
            ["world.recruit.result.hire"] = "{0} hired for {1} crowns. {2} crowns remaining.",
            ["world.recruit.result.tryout"] = "{0}'s tryout completed for {1} crowns. {2} crowns remaining.",
            ["world.recruit.error.money"] = "Not enough crowns.",
            ["world.recruit.error.roster"] = "The company roster is full.",
            ["world.recruit.error.missing"] = "That recruit is no longer available.",
            ["world.recruit.error.unavailable"] = "The recruitment action could not be completed.",
            ["world.character.perk"] = "{0}, tier {1}, {2}.",
            ["world.character.perk.state.acquired"] = "acquired",
            ["world.character.perk.state.available"] = "available",
            ["world.character.perk.state.no_points"] = "unlocked tier, no perk points available",
            ["world.character.perk.state.locked"] = "locked",
            ["world.character.perks.details"] = "Perk details",
            ["world.character.perks.summary"] = "{0} perk points available, {1} spent. Use Up and Down to review the perks. On an available one, press Enter to take it.",
            ["world.character.perks.summary.no_action"] = "This line only reports perk points. Move down to a perk to take it.",
            ["world.character.perk.actions.none"] = "{0} cannot be taken: {1}.",
            ["world.character.perk.result.unlock_perk"] = "{0} taken. {1} perk points left.",
            // Level up: the attribute increases a level grants. Vanilla puts them in a
            // mouse-only popup behind the portrait's level label, so this list, opened
            // with Enter on the identity row, is their only keyboard route. Nothing is
            // spent until the last entry is confirmed — and then nothing can undo it.
            ["world.character.levelup.hint"] = "A level up is waiting: press Enter to spend it.",
            ["world.character.levelup.unavailable"] = "This brother has no level up to spend.",
            ["world.character.levelup.opened"] = "Attribute increases for {0}. {1} Choose three of the eight; each can be raised only once, and only by the amount it offers. Use Up and Down to review them and the entry that applies them. Enter chooses an attribute or unchooses it, V reads what it does, Escape cancels without spending anything.",
            ["world.character.levelup.position"] = "Entry {0} of {1}.",
            ["world.character.levelup.cancelled"] = "Level up for {0} cancelled. Nothing was spent.",
            ["world.character.levelup.attribute"] = "{0} {1} of {2}, offers plus {3}.",
            ["world.character.levelup.attribute.chosen"] = "Chosen.",
            ["world.character.levelup.attribute.free"] = "Not chosen.",
            ["world.character.levelup.attribute.hitpoints"] = "Health",
            ["world.character.levelup.attribute.bravery"] = "Resolve",
            ["world.character.levelup.attribute.fatigue"] = "Fatigue",
            ["world.character.levelup.attribute.initiative"] = "Initiative",
            ["world.character.levelup.attribute.mskill"] = "Melee skill",
            ["world.character.levelup.attribute.rskill"] = "Ranged skill",
            ["world.character.levelup.attribute.mdef"] = "Melee defense",
            ["world.character.levelup.attribute.rdef"] = "Ranged defense",
            // The stars the dialog only draws as an icon: how talented this brother is
            // with the attribute, and the reason to prefer one increase over another.
            ["world.character.levelup.talent.0"] = "",
            ["world.character.levelup.talent.1"] = "One star.",
            ["world.character.levelup.talent.2"] = "Two stars.",
            ["world.character.levelup.talent.3"] = "Three stars.",
            ["world.character.levelup.result.pick"] = "{0} chosen. {1} of {2}.",
            ["world.character.levelup.result.undo"] = "{0} unchosen. {1} of {2}.",
            ["world.character.levelup.result.ready"] = "Go to the last entry to apply them.",
            ["world.character.levelup.full"] = "{1} attributes are already chosen, and {0} is not one of them. Press Enter on a chosen one to undo it first.",
            // Read on focus, before Enter: the game has no way back from this, and the
            // player must hear so while it still costs nothing to walk away.
            ["world.character.levelup.confirm"] = "Apply the level up: {0} This cannot be undone. Press Enter to apply it, Escape to cancel.",
            ["world.character.levelup.confirm.pending"] = "Apply the level up. Not yet: {0} of {1} attributes chosen.",
            ["world.character.levelup.confirm.blocked"] = "Choose {2} attributes first. {1} chosen so far.",
            ["world.character.levelup.confirmed"] = "Level up applied. {0}",
            ["world.character.levelup.raised"] = "{0} plus {1}.",
            ["world.character.levelup.remaining"] = "{0} more level ups to spend for this brother.",
            ["world.character.levelup.remaining.one"] = "1 more level up to spend for this brother.",
            ["world.character.levelup.remaining.none"] = "No level ups left for this brother.",
            ["world.inventory.action.rename"] = "Change name and title",
            ["world.inventory.action.levelup_open"] = "Spend the level up on attributes",
            ["world.character.formation.summary"] = "Deployed: {0} of {1}. Reserves: {2}. Use Up and Down to review the 27 formation slots. On an occupied slot, press Enter to move that brother.",
            ["world.character.formation.slot"] = "{0}, position {1}: {2}.",
            ["world.character.formation.line.front"] = "Front line",
            ["world.character.formation.line.back"] = "Back line",
            ["world.character.formation.line.reserve"] = "Reserve",
            ["world.character.formation.selected"] = "Selected brother.",
            ["world.character.formation.move.hint"] = "Press Enter to move this brother.",
            ["world.character.formation.move.started"] = "Moving {0} from {1}, position {2}. Use Up and Down to choose a destination, then press Enter. Press V or Escape to cancel.",
            ["world.character.formation.target"] = "{0} Destination for {1}.",
            ["world.character.formation.target.source"] = "{0} This is {1}'s current slot.",
            ["world.character.formation.move.cancelled"] = "Move of {0} cancelled.",
            ["world.character.formation.result.move"] = "{0} moved to {1}, position {2}.",
            ["world.character.formation.result.swap"] = "{0} swapped with {1}. {0} is now at {2}, position {3}.",
            ["world.character.formation.error.empty_source"] = "That formation slot is empty. Choose an occupied slot before pressing Enter.",
            ["world.character.formation.error.invalid_target"] = "Choose one of the 27 formation slots as the destination.",
            ["world.character.formation.error.same"] = "{0} is already in that slot. Choose a different destination or cancel.",
            ["world.character.formation.error.maximum"] = "At most {0} brothers can be deployed. Swap with a deployed brother or choose a reserve slot.",
            ["world.character.formation.error.minimum"] = "At least one brother must remain deployed.",
            ["world.character.formation.error.stale"] = "The formation changed. The pending move was cancelled; review the updated slots.",
            ["world.character.formation.error.unavailable"] = "The formation move could not be completed. Review the updated slots and try again.",
            ["world.character.formation.details"] = "Brother details",
            // Dismissing a brother (Delete on the identity row). Vanilla speaks of
            // dismissing a man and paying him compensation, and of freeing a man and
            // paying reparations when he draws no wage; both wordings are kept.
            ["world.character.dismiss.hint"] = "Press Delete to dismiss from the company.",
            ["world.character.dismiss.opened"] = "Really dismiss {0}? {0} leaves permanently and their equipment goes to the stash. {1}",
            ["world.character.dismiss.opened.free"] = "Really free {0}? {0} leaves permanently and their equipment goes to the stash. {1}",
            ["world.character.dismiss.option.cancel"] = "Cancel, keep {0}.",
            ["world.character.dismiss.option.plain"] = "Dismiss {0} without paying anything.",
            ["world.character.dismiss.option.plain.free"] = "Free {0} without paying anything.",
            ["world.character.dismiss.option.paid"] = "Dismiss {0} and pay {1} crowns in compensation, sparing the company the loss of mood. You have {2} crowns.",
            ["world.character.dismiss.option.paid.free"] = "Free {0} and pay {1} crowns in reparations. You have {2} crowns.",
            ["world.character.dismiss.position"] = "Choice {0} of {1}.",
            ["world.character.dismiss.cancelled"] = "{0} stays in the company.",
            ["world.character.dismiss.done"] = "{0} has been dismissed. {1} brothers left in the company.",
            ["world.character.dismiss.done.paid"] = "{0} has been dismissed and paid {1} crowns. {2} brothers left in the company, {3} crowns.",
            ["world.character.dismiss.failed"] = "{0} could not be dismissed. Nothing changed.",
            ["world.character.dismiss.blocked.last"] = "{0} is your last brother; the company cannot be left without anyone.",
            ["world.character.dismiss.blocked.player"] = "{0} is you, and cannot be dismissed.",
            ["world.character.dismiss.blocked.tactical"] = "Nobody can be dismissed during a battle.",
            ["world.character.dismiss.blocked.none"] = "There is no brother to dismiss here.",
            // Mood states (config/character.nut Const.MoodStateName).
            ["combat.mood.0"] = "Angry",
            ["combat.mood.1"] = "Disgruntled",
            ["combat.mood.2"] = "Dissatisfied",
            ["combat.mood.3"] = "Content",
            ["combat.mood.4"] = "In good spirit",
            ["combat.mood.5"] = "Eager",
            ["combat.mood.6"] = "Euphoric",
            // Post-combat result screen (phase 3.6).
            ["combat.result.screen"] = "{0}. Use Up and Down to review the results and buttons.",
            ["combat.result.casualty"] = "Fallen: {0}.",
            ["combat.result.casualties.none"] = "No fallen brothers.",
            ["combat.result.stats.heading"] = "Statistics.",
            ["combat.result.stats.none"] = "No survivor statistics.",
            ["combat.result.stats.entry"] = "{0}: {1} kills, {2} XP",
            ["combat.result.stats.leveled"] = "leveled up",
            ["combat.result.stats.wounded"] = "wounded",
            ["combat.result.loot.heading"] = "Loot: {1} items. {2} free stash slots.",
            ["combat.result.loot.heading.one"] = "Loot: 1 item. {2} free stash slots.",
            // Loot rows: name, the game's own category line, condition and value, so
            // the player can judge an item without opening its tooltip.
            ["combat.result.loot.item"] = "{0}. {1}",
            ["combat.result.loot.item.condition"] = "Condition {0} of {1}.",
            ["combat.result.loot.item.value"] = "Worth {0} crowns.",
            ["combat.result.loot.item.position"] = "Item {0} of {1}.",
            ["combat.result.loot.item.take"] = "Press Enter to take it.",
            ["combat.result.loot.none"] = "No loot.",
            ["combat.result.loot.taken"] = "All loot taken.",
            ["combat.result.loot.taken.one"] = "{0} taken. {1} free stash slots left.",
            ["combat.result.loot.stash_full"] = "The stash is full. Nothing more fits.",
            ["combat.result.loot.locked"] = "This battle yields no loot for the company.",
            ["combat.result.loot.partial"] = "Stash full. Some loot was left behind.",
            ["combat.result.button.lootall"] = "Loot all items, button.",
            ["combat.result.button.lootall.disabled"] = "Loot all items, button, unavailable.",
            ["combat.result.button.continue"] = "Continue, button.",
            // World encounter dialog. Enemy labels and retreat wording are the
            // game's live values; framing, controls and the formation action live here.
            ["world.combat.dialog.title.prepare"] = "Prepare for combat.",
            ["world.combat.dialog.title.attacked"] = "You are being attacked.",
            ["world.combat.dialog.report.unknown"] = "Enemy composition is unknown.",
            ["world.combat.dialog.report.one"] = "The scout reports 1 enemy entry.",
            ["world.combat.dialog.report.many"] = "The scout reports {0} enemy entries.",
            ["world.combat.dialog.formation.available"] = "Formation review is available.",
            ["world.combat.dialog.controls.retreat"] = "Use Up and Down to review; Home and End jump to the beginning and end; Enter chooses; Escape retreats.",
            ["world.combat.dialog.controls.forced"] = "Use Up and Down to review; Home and End jump to the beginning and end; Enter chooses. Retreat is not available.",
            ["world.combat.dialog.enemy"] = "Enemy entry {0} of {1}: {2}.",
            ["world.combat.dialog.unknown"] = "Scout report: {0}",
            ["world.combat.dialog.action.formation"] = "Review formation and equipment, button. Press Enter to open.",
            ["world.combat.dialog.action.engage"] = "Engage, button. Press Enter to begin combat.",
            ["world.combat.dialog.action.defend"] = "To arms, button. Press Enter to defend.",
            ["world.combat.dialog.action.disengage"] = "{0} Button. Press Enter to retreat.",
            ["world.combat.dialog.formation.returned"] = "Returned to combat preparation. Formation changes saved.",
            ["world.combat.dialog.error.cannot_disengage"] = "Retreat is not available in this encounter.",
            // Battle confirmation dialog (the End Round popup and quit-battle prompts)
            // as a navigable list. The message row carries the game's own title (valor)
            // and body (texto); the button labels mirror the visible Yes/No/Ok.
            ["combat.dialog.screen"] = "{1}. {0}. Use Up and Down to review, Enter to choose, Escape to cancel.",
            // The same modal with a single Ok and no cancel path — the game's info popups,
            // among them the "Old Campaign Loaded" one that arrives unasked after a load.
            // Escape confirms it here, so it is not offered as a way to back out.
            ["combat.dialog.screen.mono"] = "{1}. {0}. Press Enter or Escape to dismiss.",
            ["combat.dialog.button.confirm"] = "Yes, button.",
            ["combat.dialog.button.confirm.mono"] = "Ok, button.",
            ["combat.dialog.button.cancel"] = "No, button.",
            ["combat.tactical.dialog.button"] = "{0}, button.",
            // World-map company/campaign list (phase 4.4, F2). Page Up/Down moves
            // between general status and one row per wounded brother.
            ["world.status.screen"] = "Company status, category 1 of 2. Use Up and Down to review; Page Up and Page Down change categories. Press F2 to close.",
            ["world.status.closed"] = "Company status closed.",
            ["world.status.time.day"] = "Day {1}, {0}.",
            // Most buildings shut at night (building.nut defaults IsClosedAtNight to
            // true; only the port and the tavern stay open), so the hour is worth more
            // than a label here: it tells the player whether entering a town is useful.
            ["world.status.time.night"] = "Day {1}, {0}. Most buildings are closed at night.",
            // No game-speed row: pause and the 1/2/3 keys announce the speed as it
            // changes (world.speed.* below), so the list does not repeat it.
            ["world.status.brothers"] = "{1} of {2} brothers.",
            ["world.status.brothers.one"] = "1 of {2} brothers.",
            // Only present when somebody really is waiting; there is no "nobody is"
            // row, because an empty list says that by not being there.
            ["world.status.levelup"] = "{1} brothers are waiting to level up.",
            ["world.status.levelup.one"] = "1 brother is waiting to level up.",
            // A level grants attribute increases and a perk point separately, and
            // spending one leaves the other pending, so each man says what he owes.
            ["world.status.levelup.brother"] = "{0} has {1} to spend.",
            ["world.status.levelup.brother.both"] = "{0} has {1} and {2} to spend.",
            ["world.status.levelup.attributes"] = "{0} level ups of attributes",
            ["world.status.levelup.attributes.one"] = "1 level up of attributes",
            ["world.status.levelup.perks"] = "{0} perk points",
            ["world.status.levelup.perks.one"] = "1 perk point",
            ["world.status.money"] = "Crowns: {1}.",
            ["world.status.wages"] = "Daily wages: {1} crowns.",
            ["world.status.money.daily"] = "Daily wages: {0} crowns.",
            ["world.status.money.days"] = "Enough for {0} days.",
            ["world.status.money.day.one"] = "Enough for 1 day.",
            ["world.status.money.no_wages"] = "No wage expenses.",
            ["world.status.money.insufficient"] = "Not enough for 1 day of wages.",
            ["world.status.food"] = "Food: {1}.",
            ["world.status.food.days"] = "{1} days of food left.",
            ["world.status.food.day"] = "1 day of food left.",
            ["world.status.food.none"] = "No food upkeep.",
            ["world.status.supplies"] = "Supplies: {1}.",
            ["world.status.repair.hour.one"] = "1 hour",
            ["world.status.repair.hours"] = "{0} hours",
            ["world.status.repair"] = "Repairing all equipment will take {0} and require {1} supplies.",
            ["world.status.repair.insufficient"] = "Not enough supplies.",
            ["world.status.ammo"] = "Ammunition: {1}.",
            ["world.status.medicine"] = "Medicine: {1}.",
            ["world.status.healing.day.one"] = "1 day",
            ["world.status.healing.days"] = "{0} days",
            ["world.status.healing.days.range"] = "{0} to {1} days",
            ["world.status.healing.medicine.range"] = "{0} to {1}",
            ["world.status.healing"] = "Healing all severe injuries will take {0} and require {1} medicine.",
            ["world.status.healing.insufficient"] = "Not enough medicine.",
            ["world.status.healing.possibly_insufficient"] = "Medicine may be insufficient.",
            ["world.status.ambition"] = "Ambition: {0}.",
            ["world.status.ambition.cancelable"] = "Ambition: {0}. Press Enter to abandon it.",
            ["world.status.ambition.none"] = "No ambition chosen.",
            ["world.status.ambition.uncancelable"] = "This ambition cannot be abandoned.",
            // Passage of time, spoken on the queue as the clock moves. Terse on
            // purpose: these arrive unbidden, several times a day, and the player is
            // usually in the middle of something else.
            ["world.clock.time"] = "{0}.",
            ["world.clock.day"] = "Day {1}, {0}.",
            // Feedback for pressing 1, 2 or 3. Shorter than the readout row above: this
            // one repeats on every tap, so it states the result and nothing else.
            ["world.speed.normal"] = "Normal speed.",
            ["world.speed.fast"] = "Fast speed.",
            ["world.speed.veryfast"] = "Very fast speed.",
            ["world.speed.paused"] = "Paused.",
            ["world.speed.camp"] = "Speed is fixed while camping.",
            ["world.speed.locked"] = "Speed is fixed for now.",
            ["world.status.contract"] = "Contract: {0}.",
            ["world.status.contract.cancelable"] = "Contract: {0}. Press Enter to cancel it.",
            ["world.status.contract.none"] = "No active contract.",
            ["world.status.contract.cancelled"] = "Contract cancelled.",
            ["world.status.contract.cancelled.named"] = "Contract cancelled: {0}.",
            ["world.status.objective"] = "Objective: {0}.",
            ["world.status.objectives.none"] = "No current objectives.",
            ["world.status.objectives.current.one"] = "Current objective: {0}.",
            ["world.status.objectives.current"] = "Current objectives: {0}.",
            ["world.status.objectives.updated.one"] = "Objective updated: {0}.",
            ["world.status.objectives.updated"] = "Objectives updated: {0}.",
            ["world.status.wounded.screen"] = "Wounded brothers: {1}. Category 2 of 2. Use Up and Down to review; Page Up and Page Down change categories. Press F2 to close.",
            ["world.status.wounded.screen.one"] = "1 wounded brother. Category 2 of 2. Use Up and Down to review; Page Up and Page Down change categories. Press F2 to close.",
            ["world.status.wounded.none"] = "No wounded brothers.",
            ["world.status.wounded.health"] = "Health {0} of {1}.",
            ["world.status.wounded.light.tomorrow"] = "Light wounds heal by tomorrow.",
            ["world.status.wounded.light.days"] = "Light wounds heal in {0} days.",
            ["world.status.wounded.injury.tomorrow"] = "{0} will heal by tomorrow.",
            ["world.status.wounded.injury.days"] = "{0} will heal in {1} days.",
            ["world.status.wounded.injury.range"] = "{0} will heal in {1} to {2} days.",
            ["world.status.wounded.injury.no_medicine"] = "{0} will not heal without medical supplies.",
            ["world.status.wounded.injury.oath"] = "{0} will not heal because of the Oath of Sacrifice.",
            // World explorer (phase 4.3). B owns static places, split into settlements,
            // locations and landmarks with Page Up/Down. Shift+B owns currently visible
            // parties. Both lists retain the same item/detail/interaction controls.
            ["world.survey.places.screen"] = "{0}: {1}. Use Up and Down to review; Page Up and Page Down cycle between settlements, locations and landmarks; V reads details; Enter travels to the selected place. Press B to close.",
            ["world.survey.parties.screen"] = "Parties in sight: {0}. Use Up and Down to review, V for details, and Enter to engage. Press Shift plus B to close.",
            ["world.survey.parties.empty"] = "No parties in sight.",
            ["world.survey.section.settlements"] = "Settlements",
            ["world.survey.section.locations"] = "Locations",
            ["world.survey.section.landmarks"] = "Landmarks",
            // Appended to the landmark category header only: the whole list is scenery,
            // so say once at the top that Enter will get you nowhere, rather than
            // repeating a refusal on every row the player walks through.
            ["world.survey.section.landmarks.note"] = "Nothing in this list can be entered or attacked; these are the farms, mines and workshops around a settlement, listed only to orient by.",
            ["world.survey.closed"] = "Survey closed.",
            ["world.survey.item.enemy"] = "Enemy party, {0}",
            ["world.survey.item.ally"] = "Allied party, {0}",
            ["world.survey.item.neutral"] = "Party, {0}",
            ["world.survey.item.settlement"] = "Settlement, {0}",
            // The owning faction is the banner the map draws beside the settlement.
            ["world.survey.item.settlement.owned"] = "Settlement, {0}, {1}",
            ["world.survey.item.location"] = "Location, {0}",
            ["world.survey.item.landmark"] = "Landmark, {0}",
            ["world.survey.here"] = "At your position",
            ["world.survey.action.enemy"] = "Press Enter to engage or pursue.",
            ["world.survey.action.place"] = "Press Enter to approach or enter.",
            // Ambient discovery pings: a settlement, location, landmark or enemy party
            // newly entering the player's sight while travelling. Only enemy parties are
            // announced (user decision); a single sighting is read in full, several at
            // once collapse into the summary below.
            //
            // The name comes first and the kind after it (user decision, jul 2026): the
            // name is what the player is waiting to hear, and leading with the category
            // buries it behind a word he already expects. "In sight" replaces
            // "discovered" for accuracy — nothing is being discovered here, it has come
            // into view, and an enemy party says it again every time it reappears.
            ["world.discovery.enemy"] = "{0}, enemy party, in sight",
            ["world.discovery.settlement"] = "{0}, settlement, in sight",
            ["world.discovery.location"] = "{0}, location, in sight",
            ["world.discovery.landmark"] = "{0}, landmark, in sight",
            ["world.discovery.summary"] = "{0}.",
            ["world.discovery.summary.places.one"] = "1 place now in sight",
            ["world.discovery.summary.places"] = "{0} places now in sight",
            ["world.discovery.summary.enemies.one"] = "1 enemy party now in sight",
            ["world.discovery.summary.enemies"] = "{0} enemy parties now in sight",
            // Threat proximity (phase 4.7). A sighting happens once; being run down happens
            // over the twenty scans after it, and that stretch used to be silent however
            // directly the party came on. Each proximity band crossed inwards says so, with
            // the distance and bearing the survey would have given. The wording says the gap
            // is closing rather than that the party is charging, because the band is measured
            // and not the intent: marching at a camped party crosses the same bands.
            ["world.threat.closing"] = "{0} closing in.",
            ["world.threat.contact"] = "{0} nearly on you.",
            // Daily upkeep (phase 4.9), spoken once a day when the game settles wages and
            // rations. Two halves: what the settlement just cost the company in mood — the
            // real damage, and invisible until now — and what the next day will cost if
            // nothing changes. The food estimate is the same division F2 speaks, so the two
            // never contradict each other.
            ["world.upkeep.hungry.one"] = "One man went hungry.",
            ["world.upkeep.hungry"] = "{0} men went hungry.",
            ["world.upkeep.unpaid.one"] = "One man went unpaid.",
            ["world.upkeep.unpaid"] = "{0} men went unpaid.",
            ["world.upkeep.food.none"] = "No food left.",
            ["world.upkeep.food.one"] = "One day of food left.",
            ["world.upkeep.food"] = "{0} days of food left.",
            ["world.upkeep.wages"] = "Tomorrow's wages are not covered: {0} crowns needed, {1} in the purse.",
            // Contextual Enter on the focused B-survey entity. The actual order uses
            // world_state's AutoAttack/AutoEnterLocation funnels; these are only the
            // immediate confirmations and failure cues for a screen-reader user.
            ["world.interact.engaging"] = "Engaging {0}.",
            ["world.interact.pursuing"] = "Pursuing {0}.",
            ["world.interact.entering"] = "Entering {0}.",
            ["world.interact.approaching"] = "Approaching {0}.",
            ["world.interact.none"] = "Select an enemy party, settlement, or location first.",
            ["world.interact.gone"] = "That target is no longer available.",
            ["world.interact.unavailable"] = "That target cannot be interacted with.",
            ["world.interact.escorting"] = "You cannot do that while escorting another party.",
            ["world.interact.no_route"] = "No route to {0}.",
            // Arriving somewhere that opens no screen at all. Anywhere that does opens
            // the town screen, an event or the encounter dialog, each of which announces
            // itself; this covers the case vanilla leaves completely silent.
            ["world.interact.arrived.empty"] = "Arrived at {0}. That target cannot be interacted with.",
            // Detail inspection of the focused survey entity (V), a navigable sub-list of
            // the entity's tooltip lines. The lines are already-localized game text, spoken
            // as-is (cleaned centrally); only the header and the empty cases live here.
            ["world.inspect.screen"] = "Details. Use Up and Down to review, V to go back.",
            ["world.inspect.item"] = "{0}",
            ["world.inspect.none"] = "Nothing to inspect here.",
            ["world.inspect.gone"] = "No longer there.",
            // World-map directional movement (phase 4.0, Q/W/E/A/S/D). Terrain of a
            // tile is spoken when it changes as the party walks; "Stopped" is the
            // distinct cue that the movement order finished.
            ["world.move.edge"] = "Edge of the map.",
            ["world.move.blocked"] = "Blocked that way.",
            ["world.move.step"] = "{0}.",
            ["world.move.stopped"] = "Stopped. {0}.",
            // Stepping onto the tile of a settlement, camp or ruin: the running
            // commentary a sighted player gets from watching the map. Appended to the
            // step and stopped cues above rather than spoken on its own, so a tile that
            // changes terrain AND holds a place is one utterance. Landmarks say so,
            // because standing on one is not an opportunity to do anything.
            ["world.move.passing"] = "{0}.",
            ["world.move.passing.landmark"] = "Landmark, {0}.",
            // Map explorer (phase 4.6, M). A keyboard cursor over the map: the letter
            // cluster walks it, V opens its tile as a list, X anchors it back on the
            // company and Shift+X gives its bearing, G travels there. The mode cue carries
            // the controls, so the per-hex readout can stay as short as the tile allows.
            ["world.cursor.on"] = "Map explorer on. Cursor on your company. Q, W, E, A, S and D move it over the map; V reads the tile under it; X brings it back to your company and Shift plus X gives its bearing; G travels there. Press M to give the letter keys back to your company.",
            ["world.cursor.off"] = "Map explorer off. Q, W, E, A, S and D move your company again.",
            ["world.cursor.unavailable"] = "The map explorer is not available right now.",
            ["world.cursor.edge"] = "Edge of the map.",
            ["world.cursor.recentered"] = "Cursor on your company.",
            ["world.cursor.bearing"] = "Cursor {0} from your company.",
            ["world.cursor.bearing.here"] = "The cursor is on your company's own tile.",
            ["world.cursor.travel"] = "Travelling to {0}.",
            ["world.cursor.travel.here"] = "Your company is already on the cursor tile.",
            ["world.cursor.travel.no_route"] = "No route to the cursor tile.",
            ["world.cursor.parties.more.one"] = "And one more party.",
            ["world.cursor.parties.more"] = "And {0} more parties.",
            ["world.cursor.list.screen"] = "{0}: {1} entries. Use Up and Down to review; Enter acts on a settlement, location or party; V closes.",
            ["world.cursor.list.where"] = "This tile, {0}",
            ["world.cursor.list.where.here"] = "Your company's own tile",
            ["world.cursor.list.closed"] = "Tile details closed.",
            ["world.cursor.list.terrain"] = "Terrain: {0}.",
            ["world.cursor.list.self"] = "Your company is here.",
            // Footprints. Vanilla draws them for everyone but only turns them into words
            // for a player who has hired the Lookout, and only then names the exact party
            // type; the family words below are what the four sprite sets tell a sighted
            // player without him. The trail's heading is reconstructed from the
            // neighbouring tiles, since the engine reports presence only.
            ["world.cursor.tracks"] = "Tracks of {0}.",
            ["world.cursor.trail"] = "The trail continues {0}.",
            ["world.cursor.trail.hour"] = "{0} o'clock",
            ["world.cursor.trail.none"] = "The trail does not continue into any neighbouring tile.",
            // Roads and rivers (phase 4.8). The map's two travel-speed modifiers — a road
            // moves the company at 1.5x and a river at 0.75x, both applied to its speed by
            // the game itself — and neither of them changes the tile's terrain type, so no
            // other readout could give them away. Worded like a footprint trail, with the
            // directions the feature runs, because a road is only worth knowing about once
            // you know which way it goes; the reading of the hex directions as clock hours
            // is shared with the trails above. The speed effect is spelled out only in the
            // V list, which takes one fact at a time; the one-breath readouts stay short.
            ["world.path.road.on"] = "On a road, running {0}.",
            ["world.path.road.on.end"] = "On a road that ends here.",
            ["world.path.road.near"] = "A road one tile away, {0}.",
            ["world.path.road.entered"] = "Onto a road, running {0}.",
            ["world.path.road.entered.end"] = "Onto a road that ends here.",
            ["world.path.road.left"] = "Off the road.",
            ["world.path.road.effect"] = "A road moves the company half as fast again.",
            ["world.path.river.on"] = "On a river, running {0}.",
            ["world.path.river.on.end"] = "On a river that ends here.",
            ["world.path.river.near"] = "A river one tile away, {0}.",
            ["world.path.river.entered"] = "Into a river, running {0}.",
            ["world.path.river.entered.end"] = "Into a river that ends here.",
            ["world.path.river.left"] = "Out of the river.",
            ["world.path.river.effect"] = "A river slows the company by a quarter.",
            // Exact party types, keyed by Const.World.FootprintsType (config/world.nut) and
            // worded after the game's own Const.Strings.FootprintsType. Spoken only with a
            // Lookout in the retinue.
            ["world.footprints.exact.1"] = "northern soldiers",
            ["world.footprints.exact.2"] = "gilded soldiers",
            ["world.footprints.exact.3"] = "a caravan",
            ["world.footprints.exact.4"] = "peasants",
            ["world.footprints.exact.5"] = "militia",
            ["world.footprints.exact.6"] = "refugees",
            ["world.footprints.exact.7"] = "brigands",
            ["world.footprints.exact.8"] = "the undead",
            ["world.footprints.exact.9"] = "orcs",
            ["world.footprints.exact.10"] = "goblins",
            ["world.footprints.exact.11"] = "barbarians",
            ["world.footprints.exact.12"] = "nomads",
            ["world.footprints.exact.13"] = "direwolves",
            ["world.footprints.exact.14"] = "nachzehrers",
            ["world.footprints.exact.15"] = "hyenas",
            ["world.footprints.exact.16"] = "serpents",
            ["world.footprints.exact.17"] = "webknechts",
            ["world.footprints.exact.18"] = "unholds",
            ["world.footprints.exact.19"] = "alps",
            ["world.footprints.exact.20"] = "hexen",
            ["world.footprints.exact.21"] = "schrats",
            ["world.footprints.exact.22"] = "a kraken",
            ["world.footprints.exact.23"] = "ifrits",
            ["world.footprints.exact.24"] = "lindwurms",
            ["world.footprints.exact.25"] = "mercenaries",
            // The same types collapsed onto the four footprint sprite sets the game
            // actually draws (Const.GenericFootprints / Orc / Beast / Undead in
            // config/factions.nut — goblins deliberately share the orc prints). Spoken
            // without a Lookout, which is why several types map to one word.
            ["world.footprints.family.1"] = "men",
            ["world.footprints.family.2"] = "men",
            ["world.footprints.family.3"] = "men",
            ["world.footprints.family.4"] = "men",
            ["world.footprints.family.5"] = "men",
            ["world.footprints.family.6"] = "men",
            ["world.footprints.family.7"] = "men",
            ["world.footprints.family.8"] = "the undead",
            ["world.footprints.family.9"] = "greenskins",
            ["world.footprints.family.10"] = "greenskins",
            ["world.footprints.family.11"] = "men",
            ["world.footprints.family.12"] = "men",
            ["world.footprints.family.13"] = "beasts",
            ["world.footprints.family.14"] = "beasts",
            ["world.footprints.family.15"] = "beasts",
            ["world.footprints.family.16"] = "beasts",
            ["world.footprints.family.17"] = "beasts",
            ["world.footprints.family.18"] = "beasts",
            ["world.footprints.family.19"] = "beasts",
            ["world.footprints.family.20"] = "beasts",
            ["world.footprints.family.21"] = "beasts",
            ["world.footprints.family.22"] = "beasts",
            ["world.footprints.family.23"] = "beasts",
            ["world.footprints.family.24"] = "beasts",
            ["world.footprints.family.25"] = "men",
            // Generic enumeration joiner, used wherever a spoken list ends in a conjunction.
            ["list.and"] = "{0} and {1}",
            // Pause state, announced from the setPause funnel (Space, pause button...).
            ["world.pause.on"] = "Paused.",
            ["world.pause.off"] = "Unpaused.",
            // Camping state. T changes it; Shift+T reports the state and explains
            // the trade-offs without changing anything.
            ["world.camp.on"] = "Encamped.",
            ["world.camp.off"] = "Camp broken.",
            ["world.camp.unavailable"] = "Camping is unavailable while travelling with another party.",
            ["world.camp.info.on"] = "Camping is active. Time passes at triple speed, and brothers heal and repair equipment fifty percent faster. The company has reduced vision, is easier to spot, and may be caught without a chance to rearrange its formation. Press T to break camp.",
            ["world.camp.info.off"] = "Camping is inactive. While encamped, time passes at triple speed, and brothers heal and repair equipment fifty percent faster. The company has reduced vision, is easier to spot, and may be caught without a chance to rearrange its formation. Press T to make camp.",
            ["world.camp.info.unavailable"] = "Camping is inactive and unavailable while travelling with another party.",
            // Obituary (phase 5.2, O). The visual table becomes a navigable list:
            // one header plus one complete spoken row per fallen brother.
            ["world.obituary.screen.empty"] = "Obituary. No one has fallen since you took command. Press O or Escape to close.",
            ["world.obituary.screen.one"] = "Obituary. One man has fallen since you took command. Use Up and Down to review; Home and End jump to the beginning and end. Press O or Escape to close.",
            ["world.obituary.screen"] = "Obituary. {1} men have fallen since you took command. Use Up and Down to review; Home and End jump to the beginning and end. Press O or Escape to close.",
            ["world.obituary.entry"] = "{0}. {1}. {2}. {3}. {4}.",
            ["world.obituary.days.one"] = "1 day with the company",
            ["world.obituary.days"] = "{0} days with the company",
            ["world.obituary.battles.one"] = "1 battle",
            ["world.obituary.battles"] = "{0} battles",
            ["world.obituary.kills.one"] = "1 kill",
            ["world.obituary.kills"] = "{0} kills",
            ["world.obituary.demise"] = "Demise: {0}",
            // End of campaign. The verdict and the score come first; the ending
            // itself runs to several paragraphs and waits as the first list entry,
            // so the player is not held through it before hearing the outcome.
            ["world.finish.defeat"] = "Defeat. The company is no more, and the campaign is over. {0}. Use Up and Down to review the ending and the score, and Enter on Quit to return to the main menu.",
            ["world.finish.victory"] = "The campaign is over. {0}. Use Up and Down to review the ending and the score, and Enter on Quit to return to the main menu.",
            ["world.finish.body"] = "{0}",
            ["world.finish.score"] = "Final score: {0}.",
            ["world.finish.button"] = "{0}, button {1} of {2}.",
            // Factions & Relations (phase 5.2, R). The left faction list and right
            // details pane are flattened into a single keyboard-navigable list.
            ["world.relations.screen.empty"] = "Factions and relations. No known factions. Use Up and Down to review renown and reputation; Home and End jump to the beginning and end. Press R or Escape to close.",
            ["world.relations.screen.one"] = "Factions and relations. 1 known faction. Use Up and Down to review; Home and End jump to the beginning and end. Press R or Escape to close.",
            ["world.relations.screen"] = "Factions and relations. {1} known factions. Use Up and Down to review; Home and End jump to the beginning and end. Press R or Escape to close.",
            ["world.relations.renown"] = "Renown: {0}.",
            ["world.relations.reputation"] = "Reputation: {0}.",
            ["world.relations.faction"] = "{0}. Relations: {1}, {2} out of 100.",
            ["world.relations.motto"] = "{1} motto: {0}.",
            ["world.relations.description"] = "{1}: {0}",
            ["world.relations.member"] = "Member of {1}: {0}.",
            // Retinue (phase 5.2, P). The scenic camp, its follower seats and the
            // two-pane hire view become synchronized semantic keyboard lists.
            ["world.retinue.screen"] = "Retinue. Use Up and Down to review; Home and End jump to the beginning and end; Enter chooses. Press P or Escape to go back.",
            ["world.retinue.seats"] = "{0} followers hired. {1} of {2} seats unlocked.",
            ["world.retinue.money"] = "{0} crowns.",
            ["world.retinue.renown"] = "Renown: {0}, {1}.",
            ["world.retinue.cart.upgrade"] = "{0}. {1} for {2} crowns. Press Enter to upgrade.",
            ["world.retinue.cart.max"] = "{0}. Maximum inventory upgrade reached.",
            ["world.retinue.slot.free"] = "Seat {0}, free. Press Enter to hire a follower.",
            ["world.retinue.slot.locked"] = "Seat {0}, locked. Requires {1}, {2} renown.",
            ["world.retinue.slot.follower.base"] = "Seat {1}, {0}. Press Enter to replace this follower.",
            ["world.retinue.slot.description"] = "{0}",
            ["world.retinue.slot.effects"] = "Effects: {0}.",
            ["world.retinue.hire.screen.free"] = "Hire a follower for free seat {0}. {1} candidates. Use Up and Down to review; Home and End jump to the beginning and end; Enter hires. Press P or Escape to go back.",
            ["world.retinue.hire.screen.replace"] = "Replace {2} in seat {0}. {1} candidates. Use Up and Down to review; Home and End jump to the beginning and end; Enter hires. Press P or Escape to go back.",
            ["world.retinue.hire.none"] = "No followers are available to hire.",
            ["world.retinue.hire.follower.available"] = "{0}. Cost: {1} crowns. Available. Press Enter to hire.",
            ["world.retinue.hire.follower.unaffordable"] = "{0}. Cost: {1} crowns. Not enough crowns.",
            ["world.retinue.hire.follower.locked"] = "{0}. Cost: {1} crowns. Locked.",
            ["world.retinue.hire.description"] = "{0}",
            ["world.retinue.hire.effects"] = "Effects: {0}.",
            ["world.retinue.hire.requirement.met"] = "met, {0}",
            ["world.retinue.hire.requirement.unmet"] = "not met, {0}",
            ["world.retinue.hire.requirements"] = "Requirements: {0}.",
            ["world.retinue.hire.confirm.free"] = "Hire {0} for {1} crowns in seat {2}? Use Up and Down, Home or End to choose; Enter confirms; P or Escape cancels.",
            ["world.retinue.hire.confirm.replace"] = "Replace {2} with {0} for {1} crowns? Use Up and Down, Home or End to choose; Enter confirms; P or Escape cancels.",
            ["world.retinue.hire.done"] = "Hired {0}. {1} crowns remaining. Focus returned to seat {2}.",
            ["world.retinue.hire.failed"] = "Could not hire {0}. No crowns were spent.",
            ["world.retinue.cart.done"] = "Inventory upgraded to {0}. {1} crowns remaining. Focus returned to the cart.",
            // Town screen (phase 4.5), a navigable list of buildings and contracts.
            ["world.town.screen"] = "{0}. Use Up and Down to review, Enter to choose, Escape to leave.",
            ["world.town.building"] = "{0}, building.",
            // Situations: the icons vanilla draws in this screen's corner. Named on the
            // header so the player knows whether to bother walking to them.
            ["world.town.situations.one"] = "{0}, 1 situation",
            ["world.town.situations.many"] = "{0}, {1} situations",
            ["world.town.situation"] = "Situation, {0}. Press V.",
            ["world.town.situation.details"] = "{1}. {0}",
            ["world.town.building.locked"] = "{0}. Not accessible yet.",
            ["world.town.building.closed"] = "{0} is closed.",
            // The barber only swaps sprites: no cost, no effect on play, and nothing
            // behind it to describe. Say so, rather than promise it for later.
            ["world.town.building.cosmetic"] = "{0}. Appearance only, with no effect in play, so this mod does not describe it.",
            // The harbour refuses silently while a caravan is being escorted overland.
            ["world.town.port.caravan"] = "{0} will not book passage while you are escorting a caravan.",
            // The arena refuses to open for four distinct reasons; vanilla shows a
            // closed sign for all of them, so each one is named here instead.
            ["world.town.arena.night"] = "{0} is closed for the night.",
            ["world.town.arena.cooldown"] = "{0} holds no more bouts today. Come back tomorrow.",
            ["world.town.arena.contract"] = "{0} will not take you while another contract is active.",
            ["world.town.arena.stash"] = "{0} needs at least three free stash slots before a bout.",
            ["world.town.contract"] = "Contract: {0}.",
            ["world.town.contract.active"] = "Active contract: {0}.",
            ["world.town.leave"] = "Leave town, button.",
            // Tavern. The rumor and the drinking report are the game's own prose and
            // arrive verbatim; everything here is the mod's connective speech.
            ["world.tavern.screen"] = "Tavern. {0} Use Up and Down to review, Enter to pay, V to hear the last answer again, Escape to return to town.",
            ["world.tavern.action.rumor"] = "Buy the patrons a round for news and rumors, {0} crowns.",
            ["world.tavern.action.drink"] = "Buy your own men a round to lift their spirits, {0} crowns.",
            ["world.tavern.position"] = "Entry {0} of {1}.",
            ["world.tavern.purse"] = "{0} crowns available.",
            ["world.tavern.unheard"] = "Nothing heard yet.",
            ["world.tavern.unread"] = "Press V to hear it again.",
            ["world.tavern.result.rumor"] = "{0} Paid {1} crowns. {2} crowns remaining.",
            ["world.tavern.result.drink"] = "{0} Paid {1} crowns. {2} crowns remaining.",
            ["world.tavern.reread"] = "{0}",
            ["world.tavern.nothing.rumor"] = "The patrons have told you nothing yet. Press Enter to buy them a round.",
            ["world.tavern.nothing.drink"] = "Your men have not been bought a round yet. Press Enter to buy one.",
            ["world.tavern.error.money"] = "Not enough crowns.",
            // Temple. Wounded brothers with treatable injuries, and a price per injury.
            ["world.temple.screen"] = "Temple. {0} Use Up and Down to review the wounded, Enter to open a man's injuries, Escape to return to town.",
            ["world.temple.patient"] = "{0}, {1}. Treating all of them costs {2} crowns.",
            ["world.temple.injuries.one"] = "1 untreated injury",
            ["world.temple.injuries.many"] = "{0} untreated injuries",
            ["world.temple.position"] = "Patient {0} of {1}.",
            ["world.temple.empty"] = "No one needs treatment. {0} crowns available.",
            ["world.temple.empty.opened"] = "Temple. {0} Press Escape to return to town.",
            ["world.temple.injury"] = "{0}, {1} crowns, on {2}.",
            ["world.temple.injury.unaffordable"] = "Not enough crowns.",
            ["world.temple.injury.position"] = "Injury {0} of {1}.",
            ["world.temple.injury.opened"] = "Injuries. {0} Press Enter to pay for treatment; V or Escape to go back.",
            ["world.temple.result"] = "{0} treated on {1} for {2} crowns. {3} crowns remaining.",
            ["world.temple.error.money"] = "Not enough crowns to treat {0}.",
            // Taxidermist (crafting). The blueprint list is read-only until Enter
            // opens the craft action, because crafting both spends crowns and
            // consumes the trophies.
            ["world.craft.screen"] = "Taxidermist. {0} Use Up and Down to review the recipes, V for the details of one, Enter to craft it, Escape to return to town.",
            ["world.craft.blueprint"] = "{0}, {1} crowns.",
            ["world.craft.blocked.ingredients"] = "Missing ingredients.",
            ["world.craft.blocked.money"] = "Not enough crowns.",
            ["world.craft.details"] = "{0} ingredients, press V.",
            ["world.craft.position"] = "Recipe {0} of {1}.",
            ["world.craft.empty"] = "Nothing can be crafted yet. {0} crowns available.",
            ["world.craft.empty.opened"] = "Taxidermist. {0} Press Escape to return to town.",
            ["world.craft.details.none"] = "No details for {0}.",
            ["world.craft.detail.description"] = "{0}",
            ["world.craft.detail.ingredient"] = "{0} times {1}.",
            ["world.craft.detail.missing"] = "{0} still missing.",
            ["world.craft.detail.position"] = "Detail {0} of {1}.",
            ["world.craft.detail.opened"] = "Details. {0} V or Escape to go back.",
            ["world.craft.action"] = "Craft {0} for {1} crowns. {2} crowns available.",
            ["world.craft.action.blocked"] = "{0} cannot be crafted. {1}",
            ["world.craft.action.opened"] = "{0} Press Enter to confirm; V or Escape to go back.",
            ["world.craft.result"] = "{0} crafted for {1} crowns. {2} crowns remaining.",
            ["world.craft.error.money"] = "Not enough crowns to craft {0}.",
            ["world.craft.error.ingredients"] = "Missing ingredients for {0}.",
            // Harbour. Booking passage is the map's only fast travel, so Enter asks
            // once before it spends the crowns and moves the company.
            ["world.travel.screen"] = "Harbor. {0} Use Up and Down to review the destinations, V for the details of one, Enter to book passage, Escape to return to town.",
            // Name, owning faction (the banner a sighted player reads), fare. The
            // bearing follows, or "not yet seen" for a harbour still under fog.
            ["world.travel.destination"] = "{0}, {1}, {2} crowns.",
            ["world.travel.unknown"] = "Not yet seen.",
            ["world.travel.unaffordable"] = "Not enough crowns.",
            ["world.travel.position"] = "Destination {0} of {1}.",
            ["world.travel.empty"] = "No harbor can be reached from here. {0} crowns available.",
            ["world.travel.empty.opened"] = "Harbor. {0} Press Escape to return to town.",
            ["world.travel.detail"] = "{0}",
            ["world.travel.detail.position"] = "Detail {0} of {1}.",
            ["world.travel.detail.opened"] = "Details. {0} V or Escape to go back.",
            ["world.travel.details.none"] = "No details for {0}.",
            ["world.travel.confirm"] = "Sail to {0} for {1} crowns. {2} crowns available.",
            ["world.travel.confirm.blocked"] = "Not enough crowns.",
            ["world.travel.confirm.opened"] = "{0} Press Enter to confirm; V or Escape to go back.",
            ["world.travel.error.money"] = "Not enough crowns to sail to {0}: {1} needed, {2} available.",
            ["world.travel.error.gone"] = "{0} can no longer be reached from here.",
            ["world.travel.arrived"] = "Sailed to {0} for {1} crowns. {2} crowns remaining.",
            // Training hall. Three paid lessons per man, and a spoken reason for every
            // man vanilla silently leaves out of its list.
            ["world.training.screen"] = "Training Hall. {0} Use Up and Down to review your men, Enter to open a man's lessons, Escape to return to town.",
            ["world.training.man"] = "{0}, level {1}.",
            ["world.training.lessons"] = "{0} lessons.",
            ["world.training.position"] = "Man {0} of {1}.",
            ["world.training.reason.maxlevel"] = "Too experienced to learn here.",
            ["world.training.reason.trained"] = "Already training.",
            ["world.training.reason.slave"] = "A slave, and taught no further.",
            ["world.training.reason.none"] = "Cannot train here.",
            ["world.training.empty"] = "No one can train here. {0} crowns available.",
            ["world.training.empty.opened"] = "Training Hall. {0} Press Escape to return to town.",
            ["world.training.option"] = "{0}, {1} crowns, for {2}.",
            ["world.training.option.unaffordable"] = "Not enough crowns.",
            ["world.training.option.position"] = "Lesson {0} of {1}.",
            ["world.training.option.opened"] = "Lessons. {0} Press Enter to pay, V for what it teaches, Escape to go back.",
            ["world.training.blocked.maxlevel"] = "{0} is too experienced to learn anything here.",
            ["world.training.blocked.trained"] = "{0} is already training.",
            ["world.training.blocked.slave"] = "{0} is a slave, and will be taught no further.",
            ["world.training.blocked.none"] = "{0} cannot train here.",
            ["world.training.error.money"] = "Not enough crowns for {0}: {1} needed, {2} available.",
            ["world.training.result"] = "{0} paid for {1}: {2} crowns. {3} crowns remaining.",
            // World-map terrain names, keyed by Const.World.TerrainType (config/world.nut).
            ["world.terrain.0"] = "Impassable",
            ["world.terrain.1"] = "Ocean",
            ["world.terrain.2"] = "Plains",
            ["world.terrain.3"] = "Swamp",
            ["world.terrain.4"] = "Hills",
            ["world.terrain.5"] = "Forest",
            ["world.terrain.6"] = "Snowy forest",
            ["world.terrain.7"] = "Forest",
            ["world.terrain.8"] = "Autumn forest",
            ["world.terrain.9"] = "Mountains",
            ["world.terrain.10"] = "Urban",
            ["world.terrain.11"] = "Farmland",
            ["world.terrain.12"] = "Snow",
            ["world.terrain.13"] = "Badlands",
            ["world.terrain.14"] = "Tundra",
            ["world.terrain.15"] = "Steppe",
            ["world.terrain.16"] = "Shore",
            ["world.terrain.17"] = "Desert",
            ["world.terrain.18"] = "Oasis",
            // Appended by the map explorer to a tile the company has never come near.
            ["world.terrain.unexplored"] = "{0}, unexplored",
            // F1 key help. One key per row, navigated like every other list; Squirrel
            // owns which rows a surface has, this owns what each of them says. Keep a
            // row to one sentence: it is read while the player is looking for one key,
            // not studying the manual.
            ["help.screen"] = "{0} key help, {1} keys. {2} Use Up and Down to review, Escape or F1 to close.",
            ["help.position"] = "Key {0} of {1}.",
            ["help.closed"] = "Key help closed.",
            ["help.context.combat"] = "Battle",
            ["help.context.combat.sheet"] = "Character sheet",
            ["help.context.combat.inspect"] = "Unit inspection",
            ["help.context.combat.result"] = "Battle result",
            ["help.context.world"] = "World map",
            ["help.context.world.explorer"] = "Map explorer",
            ["help.context.world.survey"] = "Survey list",
            ["help.context.world.status"] = "Company status",
            ["help.context.world.sheet"] = "Character screen",
            ["help.context.world.town"] = "Settlement",
            ["help.context.world.market"] = "Market",
            ["help.context.world.recruit"] = "Recruitment",
            ["help.context.world.tavern"] = "Tavern",
            ["help.context.world.temple"] = "Temple",
            ["help.context.world.craft"] = "Taxidermist",
            ["help.context.world.travel"] = "Harbor",
            ["help.context.world.training"] = "Training hall",
            ["help.context.world.retinue"] = "Retinue",
            ["help.context.world.list"] = "List",
            ["help.context.world.event"] = "Event",
            ["help.context.world.encounter"] = "Encounter",
            ["help.context.menu"] = "Menu",
            ["help.context.dialog"] = "Confirmation",
            // Tactical combat.
            ["help.combat.cursor"] = "Q, W, E, A, S and D move the tile cursor to the six neighbours.",
            ["help.combat.recenter"] = "X recentres the cursor on the active man.",
            ["help.combat.enemies"] = "Z cycles the visible enemies by distance, Shift plus Z the other way.",
            ["help.combat.allies"] = "H cycles your other men by distance, Shift plus H the other way.",
            ["help.combat.inspect"] = "V inspects the unit under the cursor.",
            ["help.combat.inspectlist"] = "Shift plus V opens that inspection as a list, one fact per row.",
            ["help.combat.act"] = "G acts on the cursor tile: walk there, or use the armed skill.",
            ["help.combat.status"] = "T reads the active man's action points and fatigue.",
            ["help.combat.turnorder"] = "Tab reads the turn order for the round.",
            ["help.combat.threats"] = "B lists the visible enemies by distance.",
            ["help.combat.adjacent"] = "Shift plus B lists the enemies next to the cursor tile, with their clock directions.",
            ["help.combat.skills"] = "K reads the active man's skills, with costs and whether each can be used.",
            ["help.combat.hotkeys"] = "The number row and the numpad use skills 1 to 10, as in the unmodded game.",
            ["help.combat.sheet"] = "C or I opens the character sheet.",
            ["help.combat.endround"] = "R ends the round.",
            ["help.combat.wait"] = "Space waits this man's turn.",
            ["help.combat.sheet.move"] = "Up, Down, Home and End walk the sheet.",
            ["help.combat.sheet.details"] = "V opens the focused row's own details.",
            ["help.combat.sheet.equip"] = "Enter on a backpack slot opens its equip action; Enter again performs it.",
            ["help.combat.sheet.switch"] = "A and D, or Left and Right, or Tab, change brother without losing your place.",
            ["help.combat.sheet.close"] = "C, I or Escape closes the sheet.",
            ["help.combat.inspect.move"] = "Up, Down, Home and End walk the unit's facts.",
            ["help.combat.inspect.details"] = "V opens the focused row's own tooltip.",
            ["help.combat.inspect.close"] = "Shift plus V, or Escape, closes the list.",
            ["help.combat.result.move"] = "Up, Down, Home and End walk the outcome, the casualties, the survivors and the loot.",
            ["help.combat.result.activate"] = "Enter activates the focused button, or takes the focused item.",
            ["help.combat.result.details"] = "V reads the focused loot item's tooltip.",
            ["help.combat.result.lootall"] = "L takes everything.",
            ["help.combat.result.repeat"] = "R repeats the current row.",
            // World map.
            ["help.world.move"] = "Q, W, E, A, S and D walk the company one hex; hold one to keep walking.",
            ["help.world.march"] = "Shift plus a direction marches that way until something stops you.",
            ["help.world.brake"] = "Space stops the company and pauses the game.",
            ["help.world.enter"] = "Enter enters the place you are standing on, or engages a party at contact range.",
            ["help.world.places"] = "B lists the settlements and locations you know of.",
            ["help.world.parties"] = "Shift plus B lists the parties in sight.",
            ["help.world.status"] = "F2 opens company status and wounded brothers, including repair and healing times.",
            ["help.world.explorer"] = "M turns the map explorer on and off.",
            ["help.world.camp"] = "T makes or breaks camp.",
            ["help.world.campdetails"] = "Shift plus T explains the state of the camp.",
            ["help.world.sheet"] = "C or I opens the character screen.",
            ["help.world.obituary"] = "O opens the obituary.",
            ["help.world.relations"] = "R opens factions and relations.",
            ["help.world.retinue"] = "P opens the Retinue.",
            ["help.world.menu"] = "Escape opens the pause menu.",
            ["help.world.explorer.move"] = "Q, W, E, A, S and D move the cursor over the map, one hex at a time.",
            ["help.world.explorer.recenter"] = "X recentres the cursor on the company and reads its hex.",
            ["help.world.explorer.list"] = "V reads the cursor's hex as a list, one row at a time.",
            ["help.world.explorer.travel"] = "G sends the company to the cursor hex.",
            ["help.world.explorer.leave"] = "M leaves the explorer.",
            ["help.world.survey.move"] = "Up, Down, Home and End walk the list.",
            ["help.world.survey.details"] = "V opens the focused entry's details as a sub-list.",
            ["help.world.survey.activate"] = "Enter travels to the focused place, or chases the focused party.",
            ["help.world.survey.pages"] = "Page Down and Page Up switch between settlements and locations.",
            ["help.world.survey.close"] = "B closes the list.",
            ["help.world.status.move"] = "Up, Down, Home and End walk the facts.",
            ["help.world.status.sections"] = "Page Down and Page Up switch between company status and wounded brothers.",
            ["help.world.status.ambition"] = "Enter on the ambition row abandons it, when the game allows it.",
            ["help.world.status.contract"] = "Enter on the active contract row cancels it after confirmation.",
            ["help.world.status.close"] = "F2 closes the list.",
            ["help.world.sheet.sections"] = "Page Down and Page Up move between sheet, equipment, backpack, stash, perks and formation.",
            ["help.world.sheet.move"] = "Up, Down, Home and End walk the current section.",
            ["help.world.sheet.details"] = "V opens the focused row's own details.",
            ["help.world.sheet.actions"] = "Enter opens what can be done with the focused row.",
            ["help.world.sheet.switch"] = "A and D, or Left and Right, or Tab, change brother without losing your place.",
            ["help.world.sheet.close"] = "C, I or Escape closes the screen.",
            ["help.world.town.move"] = "Up, Down, Home and End walk the buildings and the contracts.",
            ["help.world.town.activate"] = "Enter opens the focused building or contract.",
            ["help.world.town.situations"] = "V reads what a situation of the town means.",
            ["help.world.town.leave"] = "Escape leaves the settlement.",
            ["help.world.market.pages"] = "Page Down and Page Up switch between overview, stock and company stash.",
            ["help.world.market.move"] = "Up, Down, Home and End walk the items.",
            ["help.world.market.actions"] = "Enter opens the actions for the focused item: buy, sell, repair, sort, filter.",
            ["help.world.market.details"] = "V reads the item's tooltip and compares it with what a brother wears.",
            ["help.world.market.compare"] = "A and D, or Left and Right, or Tab, change which brother that comparison uses.",
            ["help.world.market.back"] = "Escape returns to the settlement.",
            ["help.world.recruit.move"] = "Up, Down, Home and End walk the candidates.",
            ["help.world.recruit.details"] = "V opens the candidate's background and known traits.",
            ["help.world.recruit.actions"] = "Enter offers hiring the candidate or paying for a tryout.",
            ["help.world.recruit.back"] = "Escape returns to the settlement.",
            ["help.world.tavern.move"] = "Up and Down walk the two paid rounds.",
            ["help.world.tavern.buy"] = "Enter pays for the focused round.",
            ["help.world.tavern.reread"] = "V repeats the rumor or the report it produced.",
            ["help.world.tavern.back"] = "Escape returns to the settlement.",
            ["help.world.temple.move"] = "Up, Down, Home and End walk the wounded.",
            ["help.world.temple.injuries"] = "Enter opens that man's treatable injuries.",
            ["help.world.temple.pay"] = "Enter again pays for the focused treatment; V or Escape backs out.",
            ["help.world.temple.back"] = "Escape returns to the settlement.",
            ["help.world.craft.move"] = "Up, Down, Home and End walk the recipes.",
            ["help.world.craft.details"] = "V opens the recipe's description and ingredients.",
            ["help.world.craft.craft"] = "Enter opens the craft action; Enter again pays for it.",
            ["help.world.craft.back"] = "Escape returns to the settlement.",
            ["help.world.travel.move"] = "Up, Down, Home and End walk the destinations.",
            ["help.world.travel.details"] = "V opens the destination's description as a sub-list.",
            ["help.world.travel.sail"] = "Enter asks to confirm the passage; Enter again pays and sails.",
            ["help.world.travel.back"] = "Escape returns to the settlement.",
            ["help.world.training.move"] = "Up, Down, Home and End walk your men.",
            ["help.world.training.lessons"] = "Enter opens that man's three lessons, or says why he cannot train.",
            ["help.world.training.pay"] = "Enter again pays for the focused lesson.",
            ["help.world.training.details"] = "V reads what the focused lesson teaches.",
            ["help.world.training.back"] = "Escape leaves the lessons, then the building.",
            ["help.world.retinue.move"] = "Up, Down, Home and End walk the seats or the candidates.",
            ["help.world.retinue.activate"] = "Enter hires, replaces or buys the focused one.",
            ["help.world.retinue.back"] = "P or Escape goes back.",
            ["help.world.list.move"] = "Up, Down, Home and End walk the list.",
            ["help.world.list.close"] = "Escape closes the screen.",
            ["help.world.event.move"] = "Up and Down walk the options.",
            ["help.world.event.activate"] = "Enter chooses the focused option.",
            ["help.world.event.hotkeys"] = "The number keys 1 to 6 choose an option directly, as in the unmodded game.",
            ["help.world.encounter.move"] = "Up, Down, Home and End walk the scout report.",
            ["help.world.encounter.activate"] = "Enter runs the focused action: engage, or review the formation.",
            ["help.world.encounter.retreat"] = "Escape retreats, when the encounter allows it.",
            ["help.menu.move"] = "Up, Down, Home and End walk the entries.",
            ["help.menu.activate"] = "Enter activates the focused entry.",
            ["help.menu.adjust"] = "Left and Right change the focused setting, in Options.",
            ["help.menu.back"] = "Escape goes back one step.",
            ["help.dialog.move"] = "Up, Down, Home and End walk the choices.",
            ["help.dialog.activate"] = "Enter takes the focused choice.",
            ["help.dialog.cancel"] = "Escape takes the secondary choice.",
        };
    }
}

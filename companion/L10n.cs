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
            // On-demand readouts (phase 3.4).
            ["combat.status"] = "{0}. Health {1} of {2}. {3} of {4} action points. Fatigue {5} of {6}. Morale: {7}.",
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
            ["combat.inspect.body"] = "Health {0} of {1}. Head armor {2} of {3}. Body armor {4} of {5}. Fatigue {6} of {7}. Morale: {8}.",
            ["combat.inspect.timing.now"] = "Acting now.",
            ["combat.inspect.timing.done"] = "Turn done.",
            ["combat.inspect.timing.turns"] = "Acts in {0} turns.",
            ["combat.inspect.timing.turns.one"] = "Acts next.",
            ["combat.inspect.effects"] = "Effects: {0}.",
            ["combat.inspect.sight"] = "{0}. Not currently in sight.",
            ["combat.inspect.empty"] = "Nothing there.",
            ["combat.inspect.hidden"] = "Hidden opponent.",
            ["combat.inspect.object"] = "{0}.",
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
            ["combat.result.loot.heading"] = "Loot: {1} items.",
            ["combat.result.loot.heading.one"] = "Loot: 1 item.",
            ["combat.result.loot.item"] = "{0}.",
            ["combat.result.loot.none"] = "No loot.",
            ["combat.result.loot.taken"] = "All loot taken.",
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
            ["combat.dialog.button.confirm"] = "Yes, button.",
            ["combat.dialog.button.confirm.mono"] = "Ok, button.",
            ["combat.dialog.button.cancel"] = "No, button.",
            // World-map company/campaign list (phase 4.4, G then Up/Down).
            ["world.status.screen"] = "Company status. Use Up and Down to review. Press G to close.",
            ["world.status.closed"] = "Company status closed.",
            ["world.status.time.day"] = "Day {1}, daytime.",
            ["world.status.time.night"] = "Day {1}, night.",
            ["world.status.brothers"] = "{1} brothers.",
            ["world.status.brothers.one"] = "1 brother.",
            ["world.status.money"] = "Crowns: {1}.",
            ["world.status.wages"] = "Daily wages: {1} crowns.",
            ["world.status.food"] = "Food: {1}.",
            ["world.status.food.days"] = "{1} days of food left.",
            ["world.status.food.day"] = "1 day of food left.",
            ["world.status.food.none"] = "No food upkeep.",
            ["world.status.contract"] = "Contract: {0}.",
            ["world.status.contract.none"] = "No active contract.",
            ["world.status.objective"] = "Objective: {0}.",
            ["world.status.objectives.none"] = "No current objectives.",
            ["world.status.objectives.current.one"] = "Current objective: {0}.",
            ["world.status.objectives.current"] = "Current objectives: {0}.",
            ["world.status.objectives.updated.one"] = "Objective updated: {0}.",
            ["world.status.objectives.updated"] = "Objectives updated: {0}.",
            // World-map "what's in view" survey (phase 4.3, B then Up/Down). A
            // navigable list of visible parties and known settlements/locations, each
            // with its kind, distance and clock bearing. Distance/bearing reuse the
            // tactical tile.position phrases.
            ["world.survey.screen"] = "In view: {0}. Use Up and Down to review, V for details, and Enter to interact. Press B to close.",
            ["world.survey.empty"] = "Nothing in view.",
            ["world.survey.closed"] = "Survey closed.",
            ["world.survey.count.parties"] = "{0} parties",
            ["world.survey.count.parties.one"] = "1 party",
            ["world.survey.count.settlements"] = "{0} settlements",
            ["world.survey.count.settlements.one"] = "1 settlement",
            ["world.survey.count.locations"] = "{0} locations",
            ["world.survey.count.locations.one"] = "1 location",
            ["world.survey.item.enemy"] = "Enemy party, {0}",
            ["world.survey.item.ally"] = "Allied party, {0}",
            ["world.survey.item.neutral"] = "Party, {0}",
            ["world.survey.item.settlement"] = "Settlement, {0}",
            ["world.survey.item.location"] = "Location, {0}",
            ["world.survey.here"] = "At your position",
            ["world.survey.action.enemy"] = "Press Enter to engage or pursue.",
            ["world.survey.action.place"] = "Press Enter to approach or enter.",
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
            // Pause state, announced from the setPause funnel (Space, pause button...).
            ["world.pause.on"] = "Paused.",
            ["world.pause.off"] = "Unpaused.",
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
            ["world.town.building.locked"] = "{0}. Not accessible yet.",
            ["world.town.building.closed"] = "{0} is closed.",
            ["world.town.contract"] = "Contract: {0}.",
            ["world.town.contract.active"] = "Active contract: {0}.",
            ["world.town.leave"] = "Leave town, button.",
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
        };
    }
}

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
            ["combat.sheet.background"] = "Background: {0}.",
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
            ["combat.sheet.skills.entry"] = "{0}, {1} action points, {2} fatigue",
            ["combat.sheet.skills.none"] = "No skills.",
            ["combat.sheet.injuries"] = "Injuries: {0}.",
            ["combat.sheet.injuries.none"] = "No injuries.",
            ["combat.sheet.traits"] = "Traits: {0}.",
            ["combat.sheet.traits.none"] = "No traits.",
            ["combat.sheet.perks"] = "Perks: {0}.",
            ["combat.sheet.perks.none"] = "No perks.",
            ["combat.sheet.equipment"] = "Equipment: {0}.",
            ["combat.sheet.equipment.none"] = "No equipment.",
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
            // World-map "what's in view" survey (phase 4.3, B then Up/Down). A
            // navigable list of visible parties and known settlements/locations, each
            // with its kind, distance and clock bearing. Distance/bearing reuse the
            // tactical tile.position phrases.
            ["world.survey.screen"] = "In view: {0}. Use Up and Down to review. Press B to close.",
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
            // Town screen (phase 4.5), a navigable list of buildings and contracts.
            ["world.town.screen"] = "{0}. Use Up and Down to review, Enter to choose, Escape to leave.",
            ["world.town.building"] = "{0}, building.",
            ["world.town.building.locked"] = "{0}. Not accessible yet.",
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

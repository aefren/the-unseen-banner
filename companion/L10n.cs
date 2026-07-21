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
            ["event.screen"] = "{0}. {1}",
            ["event.option"] = "Option {1} of {2}: {0}",
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
            ["tile.edge"] = "Edge of the battlefield.",
            ["tile.position"] = "{0} tiles, {1} o'clock",
            ["tile.position.one"] = "1 tile, {0} o'clock",
            ["tile.no_enemies"] = "No enemies in sight.",
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
            // Turn and round events (phase 3.5).
            ["combat.turn.player"] = "Your turn: {0}, {1} action points.",
            ["combat.round"] = "Round {0}.",
            // Character sheet readout for the C/I screen (first pass).
            ["combat.sheet"] = "{0}. Maximum health {1}. Maximum fatigue {2}. Resolve {3}. Initiative {4}. Melee skill {5}. Ranged skill {6}. Melee defense {7}. Ranged defense {8}. Head armor {9}. Body armor {10}.",
        };
    }
}

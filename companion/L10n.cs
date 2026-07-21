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
        };
    }
}

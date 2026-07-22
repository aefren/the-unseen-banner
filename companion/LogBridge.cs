using System.Text.Json;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// Bridge plan B (docs/arquitectura-propuesta-y-roadmap.md, tarea 0.4): the
    /// game's own log.html is a live-appended HTML debug log shared with the
    /// engine and every other mod. We tail it and pick out only the lines we
    /// ourselves wrote via ::logInfo, marked with <see cref="Marker"/>, then
    /// speak them. If tarea 0.4 settles on a live WebSocket/XHR bridge instead,
    /// this is the only file that changes — Speech and the message shape stay.
    /// </summary>
    internal static class LogBridge
    {
        private const string Marker = "UB_MSG:";
        private const string EntryEnd = "</div>";

        // How often we re-check the file for growth. Not yet in a config file
        // (see L10n's own TODO — roadmap 5.1 introduces one); revisit then.
        private const int PollMilliseconds = 100;

        internal static void Watch(string path, CancellationToken token)
        {
            new Thread(() => Run(path, token)) { IsBackground = true }.Start();
        }

        private static void Run(string path, CancellationToken token)
        {
            long position = 0;
            try
            {
                if (File.Exists(path))
                {
                    using var initial = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                    // Start at end-of-file: we only want events from now on, not
                    // the whole session's history replayed on companion startup.
                    position = initial.Length;
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"[LogBridge] Could not open {path}: {e.Message}");
                return;
            }

            while (!token.IsCancellationRequested)
            {
                try
                {
                    using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                    if (fs.Length < position)
                    {
                        // The game truncates and rewrites log.html on every launch.
                        // Restart from the top of the new file — its early content is
                        // engine startup noise with no UB_MSG lines, so no replay risk.
                        position = 0;
                    }
                    if (fs.Length > position)
                    {
                        fs.Seek(position, SeekOrigin.Begin);
                        using var reader = new StreamReader(fs);
                        string chunk = reader.ReadToEnd();
                        position = fs.Length;
                        ProcessChunk(chunk);
                    }
                }
                catch (IOException)
                {
                    // The game holds this file open and writes to it continuously;
                    // an occasional lock conflict is expected. Retry next tick.
                }
                catch (Exception e)
                {
                    Console.WriteLine($"[LogBridge] Tail error: {e.Message}");
                }

                Thread.Sleep(PollMilliseconds);
            }
        }

        private static void ProcessChunk(string chunk)
        {
            int searchFrom = 0;
            while (true)
            {
                int markerIndex = chunk.IndexOf(Marker, searchFrom, StringComparison.Ordinal);
                if (markerIndex < 0) break;

                int jsonStart = markerIndex + Marker.Length;
                int jsonEnd = chunk.IndexOf(EntryEnd, jsonStart, StringComparison.Ordinal);
                if (jsonEnd < 0) break; // entry not fully written yet; pick it up next poll

                string json = chunk.Substring(jsonStart, jsonEnd - jsonStart);
                searchFrom = jsonEnd + EntryEnd.Length;

                HandleMessage(json);
            }
        }

        private static void HandleMessage(string json)
        {
            try
            {
                // The game writes log.html as HTML, so it may entity-escape the
                // quotes in our JSON payload; undo that before parsing.
                json = System.Net.WebUtility.HtmlDecode(json);
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                string canal = root.GetProperty("canal").GetString() ?? "interrupt";
                string texto = root.GetProperty("texto").GetString() ?? "";
                string categoria = GetOptionalString(root, "categoria");
                string valor = GetOptionalString(root, "valor");
                string detalle = GetOptionalString(root, "detalle");
                string hermano = GetOptionalString(root, "hermano");
                string spoken = categoria switch
                {
                    "tile.readout" => ComposeTileReadout(valor, texto, detalle),
                    "combat.skill.selected" => ComposeSkillSelected(texto, valor, detalle),
                    "combat.move" => ComposeMove(valor),
                    "combat.status" => ComposeStatus(texto, valor, detalle),
                    "combat.turnorder" => ComposeTurnOrder(texto),
                    "combat.enemies" => ComposeEnemies(texto, valor),
                    "combat.skills" => ComposeSkills(texto, valor),
                    "combat.inspect" => ComposeInspect(texto, valor, detalle),
                    "combat.sheet.mood" => L10n.F("combat.sheet.mood", L10n.T("combat.mood." + valor)),
                    "combat.sheet.skills" => ComposeSheetSkills(texto, valor),
                    "combat.sheet.injuries" => ComposeSheetList("combat.sheet.injuries", texto, valor),
                    "combat.sheet.traits" => ComposeSheetList("combat.sheet.traits", texto, valor),
                    "combat.sheet.perks" => ComposeSheetList("combat.sheet.perks", texto, valor),
                    "combat.sheet.equipment" => ComposeSheetList("combat.sheet.equipment", texto, valor),
                    "combat.result.casualties" => L10n.F("combat.result.casualties", JoinNames(texto)),
                    "combat.result.stats" => ComposeResultStats(texto),
                    "combat.result.loot" => ComposeResultLoot(texto, valor),
                    "menu.campaign" => ComposeCampaignEntry(texto, valor, detalle),
                    "menu.campaign.screen" => ComposeCampaignScreen(texto, valor),
                    "world.status" => ComposeWorldStatus(texto, valor, detalle),
                    _ => categoria.Length > 0
                        ? L10n.F(categoria, texto, valor, detalle)
                        : texto,
                };
                // When changing the brother shown on the tactical character sheet,
                // keep his name and the retained attribute in one utterance. Two
                // consecutive interrupt messages would make the attribute cut off
                // the name before NVDA could finish it.
                if (hermano.Length > 0)
                    spoken = L10n.F("combat.sheet.brother", hermano, spoken);
                Speech.Speak(spoken, interrupt: canal == "interrupt");
            }
            catch (Exception e)
            {
                Console.WriteLine($"[LogBridge] Malformed message ignored: {json} ({e.Message})");
            }
        }

        private static string GetOptionalString(JsonElement root, string name)
        {
            return root.TryGetProperty(name, out JsonElement value)
                ? value.GetString() ?? ""
                : "";
        }

        // Hex direction (0-5, from config/global.nut Const.Direction: N, NE, SE,
        // S, SW, NW) as a clock face read from the active man: N is 12 o'clock.
        private static readonly int[] ClockHours = { 12, 2, 4, 6, 8, 10 };

        /// <summary>Compose a tactical tile readout (phase 3.2). The Squirrel side
        /// sends only semantics — terrain as an enum integer, the occupant's
        /// already-localized game name, and a packed "kind|distance|direction"
        /// detail — so every spoken word here (terrain names, "ally"/"enemy", the
        /// clock position) stays in <see cref="L10n"/>. Kinds: "self", "ally",
        /// "enemy", anything else is empty. direction is -1 on the active man's
        /// own tile.</summary>
        private static string ComposeTileReadout(string terrain, string name, string detail)
        {
            string[] parts = detail.Split('|');
            string kind = parts.Length > 0 ? parts[0] : "";
            string distText = parts.Length > 1 ? parts[1] : "0";
            string dirText = parts.Length > 2 ? parts[2] : "-1";
            string hpText = parts.Length > 3 ? parts[3] : "";
            string hpMaxText = parts.Length > 4 ? parts[4] : "";

            string terrainText = L10n.T("tile.terrain." + terrain);
            string occupant = kind switch
            {
                "self" => L10n.F("tile.self", name),
                "ally" => L10n.F("tile.ally", name),
                "enemy" => L10n.F("tile.enemy", name),
                "object" => L10n.F("tile.object", name),
                _ => L10n.T("tile.empty"),
            };

            // Health clause, only for an actor (empty for scenery/empty tiles), spoken
            // right after the occupant name.
            if ((kind == "self" || kind == "ally" || kind == "enemy") && hpText.Length > 0)
                occupant += ", " + L10n.F("tile.health", hpText, hpMaxText);

            string position = ComposePosition(distText, dirText);
            string readout = position.Length > 0
                ? terrainText + ". " + occupant + ". " + position
                : terrainText + ". " + occupant + ".";

            // With a skill armed the Squirrel side packs two extra fields: whether
            // the tile is a legal target ("1"/"0") and, for an attackable actor on
            // it, the hit chance (an int, or "-" when it does not apply).
            string target = ComposeTarget(parts);
            return target.Length > 0 ? readout + " " + target : readout;
        }

        /// <summary>The target-preview clause of a tile readout while a skill is
        /// armed (phase 3.3): empty when no skill is armed, otherwise "valid" /
        /// "not a valid target" and the hit chance when there is an actor to hit.
        /// The two target fields sit at indices 5/6, after the always-present
        /// kind/distance/direction/hp/hpMax.</summary>
        private static string ComposeTarget(string[] parts)
        {
            if (parts.Length <= 5) return "";

            string targetable = parts[5];
            if (targetable == "0") return L10n.T("tile.target.invalid");
            if (targetable != "1") return "";

            string hitText = parts.Length > 6 ? parts[6] : "-";
            return int.TryParse(hitText, out int hit)
                ? L10n.F("tile.target.hit", hit)
                : L10n.T("tile.target.valid");
        }

        /// <summary>Compose a skill-armed announcement (phase 3.3). detail is
        /// "fatigue|targeted"; the "choose a target" cue is added only for a
        /// targeted skill, since a non-targeted one has already fired.</summary>
        private static string ComposeSkillSelected(string name, string ap, string detail)
        {
            string[] parts = detail.Split('|');
            string fatigue = parts.Length > 0 ? parts[0] : "0";
            bool targeted = parts.Length > 1 && parts[1] == "1";

            string basePart = L10n.F("combat.skill.selected", name, ap, fatigue);
            return targeted
                ? basePart + " " + L10n.T("combat.skill.choose_target")
                : basePart;
        }

        /// <summary>Compose a movement announcement (phase 3.3): the tile count the
        /// active man will actually travel this turn, singular-aware.</summary>
        private static string ComposeMove(string tilesText)
        {
            return tilesText == "1"
                ? L10n.T("combat.move.one")
                : L10n.F("combat.move", tilesText);
        }

        /// <summary>Turn a hex distance and direction (0-5, or -1 for none) into a
        /// spoken "3 tiles, 4 o'clock". Returns empty on the active man's own tile
        /// or when the direction is out of range.</summary>
        private static string ComposePosition(string distText, string dirText)
        {
            if (!int.TryParse(distText, out int dist) || dist <= 0) return "";
            if (!int.TryParse(dirText, out int dir) || dir < 0 || dir >= ClockHours.Length) return "";

            string hour = ClockHours[dir].ToString();
            return dist == 1
                ? L10n.F("tile.position.one", hour)
                : L10n.F("tile.position", dist, hour);
        }

        /// <summary>Compose the active man's status readout (phase 3.4): the T key.
        /// detail is "hp/hpmax|ap/apmax|fat/fatmax"; valor is the morale index the
        /// Squirrel side sends, mapped to a word here so it stays translatable.
        /// </summary>
        private static string ComposeStatus(string name, string moraleIndex, string detail)
        {
            string[] parts = detail.Split('|');
            (string cur, string max) Pair(int i)
            {
                if (i >= parts.Length) return ("0", "0");
                string[] p = parts[i].Split('/');
                return (p.Length > 0 ? p[0] : "0", p.Length > 1 ? p[1] : "0");
            }

            var (hp, hpMax) = Pair(0);
            var (ap, apMax) = Pair(1);
            var (fat, fatMax) = Pair(2);
            string morale = L10n.T("combat.morale." + moraleIndex);

            return L10n.F("combat.status", name, hp, hpMax, ap, apMax, fat, fatMax, morale);
        }

        /// <summary>Compose one row of the Load/Save campaign list. The name is
        /// already-rendered game text (cleaned downstream); detalle packs the game's
        /// own "day" and "date" labels as "day|date"; valor is "sel" for the selected
        /// row, "dis" for an incompatible one, empty otherwise. The New Savegame row
        /// arrives here too, with empty day/date.</summary>
        private static string ComposeCampaignEntry(string name, string state, string detail)
        {
            string[] p = detail.Split('|');
            string day = p.Length > 0 ? p[0] : "";
            string date = p.Length > 1 ? p[1] : "";

            string info = name;
            if (day.Length > 0) info += ", " + day;
            if (date.Length > 0) info += ", " + date;

            string suffix = state switch
            {
                "sel" => L10n.T("menu.campaign.selected"),
                "dis" => L10n.T("menu.campaign.disabled"),
                _ => "",
            };
            return suffix.Length > 0 ? info + ". " + suffix : info + ".";
        }

        /// <summary>Compose the Load/Save screen announcement: the dialog title plus
        /// how many saves are listed, singular/empty aware. The count is the raw row
        /// count, so on the Save screen it includes the New Savegame slot.</summary>
        private static string ComposeCampaignScreen(string title, string countText)
        {
            int.TryParse(countText, out int n);
            string count = n <= 0
                ? L10n.T("menu.campaign.screen.empty")
                : (n == 1 ? L10n.T("menu.campaign.screen.one")
                          : L10n.F("menu.campaign.screen.count", n));
            return L10n.F("menu.campaign.screen", title, count);
        }

        /// <summary>Compose the world-map company readout (phase 4.4): the g key.
        /// detalle packs brothers|money|dailyMoney|food|dailyFood|foodDays|day|isDay;
        /// valor is "1" when a contract is active and contractTitle carries its
        /// (BBCode-bearing, cleaned downstream) name. Built piecewise here rather
        /// than one format string so the singular/plural and the "no upkeep" and
        /// "no contract" cases each pick their own phrase.</summary>
        private static string ComposeWorldStatus(string contractTitle, string hasContract, string detail)
        {
            string[] p = detail.Split('|');
            string At(int i) => i < p.Length ? p[i] : "0";

            string brothers = At(0), money = At(1), dailyMoney = At(2),
                   food = At(3), foodDays = At(5), day = At(6), isDay = At(7);

            string time = L10n.T(isDay == "1" ? "world.status.day" : "world.status.night");
            string header = L10n.F(brothers == "1" ? "world.status.header.one" : "world.status.header",
                day, time, brothers);
            string wages = L10n.F("world.status.money", money, dailyMoney);

            string foodPart = foodDays == "-1"
                ? L10n.F("world.status.food.none", food)
                : L10n.F(foodDays == "1" ? "world.status.food.one" : "world.status.food", food, foodDays);

            string contract = hasContract == "1" && contractTitle.Trim().Length > 0
                ? L10n.F("world.status.contract", contractTitle)
                : L10n.T("world.status.contract.none");

            return header + " " + wages + " " + foodPart + " " + contract;
        }

        /// <summary>Compose the turn-order readout (phase 3.4): the Tab key. The
        /// text is newline-separated entries, each a one-char tag (s self, a ally,
        /// e enemy) followed by the already-localized name.</summary>
        private static string ComposeTurnOrder(string text)
        {
            var entries = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length == 0) continue;
                string tag = line.Substring(0, 1);
                string name = line.Substring(1);
                entries.Add(tag switch
                {
                    "s" => L10n.F("combat.turnorder.self", name),
                    "a" => L10n.F("combat.turnorder.ally", name),
                    _ => L10n.F("combat.turnorder.enemy", name),
                });
            }

            return L10n.F("combat.turnorder", string.Join(", ", entries));
        }

        /// <summary>Compose the visible-enemies readout (phase 3.4): the B key. The
        /// text is newline-separated "distance name" entries, nearest first; valor
        /// is the count.</summary>
        private static string ComposeEnemies(string text, string countText)
        {
            var entries = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length == 0) continue;
                int sp = line.IndexOf(' ');
                if (sp <= 0) continue;
                string dist = line.Substring(0, sp);
                string name = line.Substring(sp + 1);
                entries.Add(dist == "1"
                    ? L10n.F("combat.enemies.entry.one", name)
                    : L10n.F("combat.enemies.entry", name, dist));
            }

            string list = string.Join(", ", entries);
            return countText == "1"
                ? L10n.F("combat.enemies.one", list)
                : L10n.F("combat.enemies", countText, list);
        }

        /// <summary>Compose the active man's skills readout (the k key): the numbered
        /// action bar. text is newline-separated "slot\tname\tap\tfatigue\tusable"
        /// lines in hotkey order; valor is the count. A skill that cannot be used this
        /// instant (usable == "0") is flagged so the player knows what is greyed out.
        /// </summary>
        private static string ComposeSkills(string text, string countText)
        {
            var entries = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length == 0) continue;
                string[] f = line.Split('\t');
                if (f.Length < 4) continue;

                string entry = L10n.F("combat.skills.entry", f[0], f[1], f[2], f[3]);
                if (f.Length > 4 && f[4] == "0") entry += " " + L10n.T("combat.skills.unavailable");
                entries.Add(entry);
            }

            string list = string.Join(". ", entries);
            return countText == "1"
                ? L10n.F("combat.skills.one", list)
                : L10n.F("combat.skills", countText, list);
        }

        /// <summary>Compose the on-demand unit inspection (the v key): the same facts
        /// the mouse tooltip shows for any unit on the field, respecting fog of war.
        /// valor is "sight" (discovered but out of sight, name only) or "ok" (full).
        /// For the full case detail packs "kind|level|timing|hp|hpMax|fat|fatMax|
        /// armHead|armHeadMax|armBody|armBodyMax|morale|effects", where effects is a
        /// newline-separated list of already-localized names (possibly empty).</summary>
        private static string ComposeInspect(string name, string valor, string detail)
        {
            if (valor == "sight")
                return L10n.F("combat.inspect.sight", name);

            string[] p = detail.Split('|');
            string At(int i) => i < p.Length ? p[i] : "";

            string kind = At(0);
            string header = kind switch
            {
                "self" => L10n.F("combat.inspect.header.self", name, At(1)),
                "ally" => L10n.F("combat.inspect.header.ally", name, At(1)),
                _ => L10n.F("combat.inspect.header.enemy", name, At(1)),
            };

            string morale = L10n.T("combat.morale." + At(11));
            string body = L10n.F("combat.inspect.body",
                At(3), At(4), At(7), At(8), At(9), At(10), At(5), At(6), morale);

            string timing = At(2) switch
            {
                "now" => L10n.T("combat.inspect.timing.now"),
                "done" => L10n.T("combat.inspect.timing.done"),
                "1" => L10n.T("combat.inspect.timing.turns.one"),
                "none" => "",
                "" => "",
                string t => L10n.F("combat.inspect.timing.turns", t),
            };

            string result = header + " " + body;
            if (timing.Length > 0) result += " " + timing;

            string effects = JoinNames(At(12));
            if (effects.Length > 0) result += " " + L10n.F("combat.inspect.effects", effects);

            return result;
        }

        /// <summary>Compose the character sheet's active-skills entry. text is
        /// newline-separated "name\tap\tfatigue" lines; count is in valor. Unlike the
        /// k-key readout there is no slot number or usability flag — this is any
        /// brother's ability list, not the active man's live action bar.</summary>
        private static string ComposeSheetSkills(string text, string countText)
        {
            if (countText == "0" || text.Length == 0)
                return L10n.T("combat.sheet.skills.none");

            var entries = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length == 0) continue;
                string[] f = line.Split('\t');
                if (f.Length < 3) continue;
                entries.Add(L10n.F("combat.sheet.skills.entry", f[0], f[1], f[2]));
            }

            return L10n.F("combat.sheet.skills", string.Join(", ", entries));
        }

        /// <summary>Compose one list entry of the character sheet (injuries, traits,
        /// perks, equipment). text is a newline-separated list of already-localized
        /// names; count is in <paramref name="countText"/>. An empty list reads as
        /// the category's "none" phrase.</summary>
        private static string ComposeSheetList(string cat, string text, string countText)
        {
            if (countText == "0" || text.Length == 0)
                return L10n.T(cat + ".none");
            return L10n.F(cat, JoinNames(text));
        }

        /// <summary>Join a newline-separated list of already-localized game names
        /// into a comma-separated phrase, skipping blanks.</summary>
        private static string JoinNames(string text)
        {
            var names = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length != 0) names.Add(line);
            }

            return string.Join(", ", names);
        }

        /// <summary>Compose the post-combat statistics readout (phase 3.6). Each
        /// line is "name\tkills\txp\tleveled\twounded" (leveled/wounded 1 or 0),
        /// one per surviving brother.</summary>
        private static string ComposeResultStats(string text)
        {
            var entries = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length == 0) continue;
                string[] f = line.Split('\t');
                if (f.Length < 3) continue;

                string entry = L10n.F("combat.result.stats.entry", f[0], f[1], f[2]);
                if (f.Length > 3 && f[3] == "1") entry += ", " + L10n.T("combat.result.stats.leveled");
                if (f.Length > 4 && f[4] == "1") entry += ", " + L10n.T("combat.result.stats.wounded");
                entries.Add(entry);
            }

            return L10n.F("combat.result.stats", string.Join(". ", entries));
        }

        /// <summary>Compose the post-combat loot readout (phase 3.6): a
        /// newline-separated list of item names and the count in valor.</summary>
        private static string ComposeResultLoot(string text, string countText)
        {
            string list = JoinNames(text);
            return countText == "1"
                ? L10n.F("combat.result.loot.one", list)
                : L10n.F("combat.result.loot", countText, list);
        }
    }
}

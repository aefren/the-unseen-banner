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
                    "combat.engaged" => ComposeEngaged(texto, valor),
                    "combat.skills" => ComposeSkills(texto, valor),
                    "combat.inspect" => ComposeInspect(texto, valor, detalle),
                    "combat.sheet.mood" => L10n.F("combat.sheet.mood", L10n.T("combat.mood." + valor)),
                    "combat.sheet.skills" => ComposeSheetSkills(texto, valor),
                    "combat.sheet.injuries" => ComposeSheetList("combat.sheet.injuries", texto, valor),
                    "combat.sheet.traits" => ComposeSheetList("combat.sheet.traits", texto, valor),
                    "combat.sheet.perks" => ComposeSheetList("combat.sheet.perks", texto, valor),
                    "combat.sheet.equipment" => ComposeSheetList("combat.sheet.equipment", texto, valor),
                    "combat.result.stat" => ComposeResultStat(texto, valor, detalle),
                    "menu.campaign" => ComposeCampaignEntry(texto, valor, detalle),
                    "menu.campaign.screen" => ComposeCampaignScreen(texto, valor),
                    "world.survey.screen" => ComposeSurveyScreen(detalle),
                    "world.survey.item" => ComposeSurveyItem(texto, valor, detalle),
                    "world.obituary.entry" => ComposeObituaryEntry(texto, detalle),
                    "world.retinue.slot.follower" => ComposeRetinueSlot(texto, valor, detalle),
                    "world.retinue.hire.follower" => ComposeRetinueFollower(texto, valor, detalle),
                    "world.move.step" => L10n.F("world.move.step", L10n.T("world.terrain." + valor)),
                    "world.move.stopped" => L10n.F("world.move.stopped", L10n.T("world.terrain." + valor)),
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

        /// <summary>Compose the world-map survey header (phase 4.3, the B key). detalle
        /// packs the three counts as "parties|settlements|locations"; the header names
        /// how many of each are in view, or "Nothing in view" when all are zero. The
        /// per-category phrasing is singular/zero aware so it never reads "1 parties".
        /// </summary>
        private static string ComposeSurveyScreen(string detail)
        {
            string[] p = detail.Split('|');
            int At(int i) => i < p.Length && int.TryParse(p[i], out int n) ? n : 0;
            int parties = At(0), settlements = At(1), locations = At(2);

            if (parties == 0 && settlements == 0 && locations == 0)
                return L10n.T("world.survey.empty");

            var groups = new System.Collections.Generic.List<string>();
            if (parties > 0)
                groups.Add(parties == 1 ? L10n.T("world.survey.count.parties.one")
                                        : L10n.F("world.survey.count.parties", parties));
            if (settlements > 0)
                groups.Add(settlements == 1 ? L10n.T("world.survey.count.settlements.one")
                                            : L10n.F("world.survey.count.settlements", settlements));
            if (locations > 0)
                groups.Add(locations == 1 ? L10n.T("world.survey.count.locations.one")
                                          : L10n.F("world.survey.count.locations", locations));

            return L10n.F("world.survey.screen", string.Join(", ", groups));
        }

        /// <summary>Compose one survey entry (phase 4.3). texto is the entity's already-
        /// localized game name; valor is the kind (ally/enemy/neutral party, settlement,
        /// location); detalle is the "dist|dir" pair shared with the tactical tile
        /// readout, so <see cref="ComposePosition"/> is reused for "3 tiles, 2 o'clock".
        /// </summary>
        private static string ComposeSurveyItem(string name, string kind, string detail)
        {
            string[] p = detail.Split('|');
            string dist = p.Length > 0 ? p[0] : "0";
            string dir = p.Length > 1 ? p[1] : "-1";

            string head = kind switch
            {
                "enemy" => L10n.F("world.survey.item.enemy", name),
                "ally" => L10n.F("world.survey.item.ally", name),
                "neutral" => L10n.F("world.survey.item.neutral", name),
                "settlement" => L10n.F("world.survey.item.settlement", name),
                _ => L10n.F("world.survey.item.location", name),
            };

            // A location on the player's own tile (a Battle Site where he stands, say)
            // has distance 0, for which ComposePosition is empty; call that out as
            // "at your position" instead of dropping the clause and reading no location.
            string position = ComposePosition(dist, dir);
            if (position.Length == 0 && dist == "0")
                position = L10n.T("world.survey.here");

            return position.Length > 0 ? head + ". " + position + "." : head + ".";
        }

        /// <summary>Compose one row of the world-map obituary (phase 5.2).
        /// <paramref name="detail"/> packs "days|battles|kills|demise"; the name
        /// and demise are game-owned rendered text, while all labels and singular
        /// handling remain in <see cref="L10n"/>.</summary>
        private static string ComposeObituaryEntry(string name, string detail)
        {
            string[] p = detail.Split('|');
            int At(int i) => i < p.Length && int.TryParse(p[i], out int n) ? n : 0;
            int days = At(0), battles = At(1), kills = At(2);
            string demise = p.Length > 3
                ? string.Join("|", p, 3, p.Length - 3)
                : "";

            string daysText = days == 1
                ? L10n.T("world.obituary.days.one")
                : L10n.F("world.obituary.days", days);
            string battlesText = battles == 1
                ? L10n.T("world.obituary.battles.one")
                : L10n.F("world.obituary.battles", battles);
            string killsText = kills == 1
                ? L10n.T("world.obituary.kills.one")
                : L10n.F("world.obituary.kills", kills);
            string demiseText = L10n.F("world.obituary.demise", demise);

            return L10n.F("world.obituary.entry",
                name, daysText, battlesText, killsText, demiseText);
        }

        /// <summary>Compose one occupied seat on the P/Retinue main screen.
        /// <paramref name="detail"/> packs "description TAB newline-separated
        /// effects". Names and prose belong to the game; seat/action framing
        /// and labels remain localizable here.</summary>
        private static string ComposeRetinueSlot(string name, string seat, string detail)
        {
            string[] p = detail.Split('\t');
            string description = p.Length > 0 ? p[0] : "";
            string effects = p.Length > 1 ? JoinNames(p[1]) : "";

            var parts = new List<string>
            {
                L10n.F("world.retinue.slot.follower.base", name, seat)
            };
            if (description.Length > 0)
                parts.Add(L10n.F("world.retinue.slot.description", description));
            if (effects.Length > 0)
                parts.Add(L10n.F("world.retinue.slot.effects", effects));
            return string.Join(" ", parts);
        }

        /// <summary>Compose one candidate from the P/Retinue hire list. Detail
        /// packs "status TAB description TAB effects TAB requirements"; effects
        /// are newline-separated game strings and each requirement starts with
        /// 1 (met) or 0 (unmet). The compact wire format keeps every added label
        /// in <see cref="L10n"/>.</summary>
        private static string ComposeRetinueFollower(string name, string cost, string detail)
        {
            string[] p = detail.Split('\t');
            string status = p.Length > 0 ? p[0] : "locked";
            string description = p.Length > 1 ? p[1] : "";
            string effects = p.Length > 2 ? JoinNames(p[2]) : "";
            string requirements = p.Length > 3 ? p[3] : "";

            string statusKey = status switch
            {
                "available" => "world.retinue.hire.follower.available",
                "unaffordable" => "world.retinue.hire.follower.unaffordable",
                _ => "world.retinue.hire.follower.locked",
            };
            var parts = new List<string> { L10n.F(statusKey, name, cost) };
            if (description.Length > 0)
                parts.Add(L10n.F("world.retinue.hire.description", description));
            if (effects.Length > 0)
                parts.Add(L10n.F("world.retinue.hire.effects", effects));

            var requirementParts = new List<string>();
            foreach (string line in requirements.Split('\n'))
            {
                if (line.Length < 2) continue;
                string key = line[0] == '1'
                    ? "world.retinue.hire.requirement.met"
                    : "world.retinue.hire.requirement.unmet";
                requirementParts.Add(L10n.F(key, line.Substring(1)));
            }
            if (requirementParts.Count > 0)
                parts.Add(L10n.F("world.retinue.hire.requirements",
                    string.Join(", ", requirementParts)));

            return string.Join(" ", parts);
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

        /// <summary>Compose the "enemies around this tile" readout (Shift+B). The
        /// Squirrel side counts the hostiles hex-adjacent to the cursor tile, so the
        /// player can tell before moving there whether the tile is ringed by foes
        /// (adjacency means a free hit when he later steps off). text is newline-
        /// separated enemy names; valor is the count.</summary>
        private static string ComposeEngaged(string text, string countText)
        {
            var names = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length == 0) continue;
                names.Add(line);
            }

            string list = string.Join(", ", names);
            return countText == "1"
                ? L10n.F("combat.engaged.one", list)
                : L10n.F("combat.engaged", countText, list);
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

        /// <summary>Compose one survivor row in the navigable post-combat result
        /// list. detail packs "xp|leveled|wounded", with the flags as 1 or 0.</summary>
        private static string ComposeResultStat(string name, string kills, string detail)
        {
            string[] p = detail.Split('|');
            string xp = p.Length > 0 ? p[0] : "0";
            string entry = L10n.F("combat.result.stats.entry", name, kills, xp);
            if (p.Length > 1 && p[1] == "1") entry += ", " + L10n.T("combat.result.stats.leveled");
            if (p.Length > 2 && p[2] == "1") entry += ", " + L10n.T("combat.result.stats.wounded");
            return entry + ".";
        }
    }
}

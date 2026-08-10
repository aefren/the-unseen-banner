using System.Text.Json;
using System.Text.RegularExpressions;

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
        private static readonly Regex CombatRollSuffix = new(
            @" \(Chance:\s*(\d+),\s*Rolled:\s*(\d+)\)$",
            RegexOptions.CultureInvariant);

        // How often we re-check the file for growth. Not yet in a config file
        // (see L10n's own TODO — roadmap 6.0 introduces one); revisit then.
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
                string detalles = GetOptionalString(root, "detalles");
                string contexto = GetOptionalString(root, "contexto");
                string acciones = GetOptionalString(root, "acciones");
                string comparacion = GetOptionalString(root, "comparacion");
                string cadaver = GetOptionalString(root, "cadaver");
                string talento = GetOptionalString(root, "talento");
                string suelo = GetOptionalString(root, "suelo");
                string arma = GetOptionalString(root, "arma");
                string spoken = categoria switch
                {
                    "tile.readout" => ComposeTileReadout(
                        valor, texto, detalle, cadaver, comparacion, suelo, arma),
                    "combat.log" => ComposeCombatLog(texto),
                    "combat.skill.selected" => ComposeSkillSelected(texto, valor, detalle),
                    "combat.move" => ComposeMove(valor),
                    "combat.ground.item" => ComposeGroundItem(texto, valor, detalle),
                    "combat.status" => ComposeStatus(detalle),
                    "combat.turnorder" => ComposeTurnOrder(texto),
                    "combat.enemies" => ComposeEnemies(texto, valor),
                    "combat.engaged" => ComposeEngaged(texto, valor),
                    "combat.skills" => ComposeSkills(texto, valor),
                    "combat.inspect" => ComposeInspect(texto, valor, detalle, cadaver, arma),
                    "combat.inspect.menu.screen" => L10n.F(categoria,
                        EnemyWithWeapon(texto, valor)),
                    "combat.inspect.header.enemy" => L10n.F(categoria,
                        EnemyWithWeapon(texto, detalle), valor),
                    "combat.inspect.effects" => ComposeSheetList(
                        "combat.inspect.effects", texto, valor),
                    "combat.inspect.stats" => ComposeInspectStats(texto, valor, detalle),
                    "combat.inspect.bags" => ComposeInspectBags(texto, valor),
                    "combat.inspect.armor" => ComposeInspectArmor(texto, valor, detalle),
                    "combat.inspect.turn" => ComposeInspectTurn(
                        texto, valor, detalle, arma),
                    "combat.inspect.menu.morale"
                        => L10n.F(categoria, L10n.T("combat.morale." + valor)),
                    "combat.sheet.mood" => L10n.F("combat.sheet.mood", L10n.T("combat.mood." + valor)),
                    "combat.sheet.skills" => ComposeSheetSkills(texto, valor),
                    "combat.sheet.injuries" => ComposeSheetList("combat.sheet.injuries", texto, valor),
                    "combat.sheet.traits" => ComposeSheetList("combat.sheet.traits", texto, valor),
                    "combat.sheet.perks" => ComposeSheetList("combat.sheet.perks", texto, valor),
                    "combat.sheet.equipment" => ComposeSheetList("combat.sheet.equipment", texto, valor),
                    "world.character.equipment.slot" => ComposeEquipmentSlot(texto, valor, detalle),
                    "world.character.bag.slot" => ComposeBagSlot(texto, valor, detalle),
                    "world.character.stash.item" => ComposeStashItem(texto, valor),
                    "world.character.stash.commands" => ComposeStashCommands(valor),
                    "world.inventory.action" => ComposeInventoryAction(texto, valor, detalle),
                    "world.inventory.actions.none" => texto.Length > 0
                        ? L10n.F("world.inventory.actions.none", texto)
                        : L10n.T("world.inventory.actions.none_empty"),
                    "world.inventory.error" => L10n.T("world.inventory.error." + valor),
                    string key when key.StartsWith("world.inventory.result.", StringComparison.Ordinal)
                        => L10n.F(key, texto),
                    "world.market.screen" => ComposeMarketScreen(texto, valor, detalle),
                    "world.market.buy.item" => ComposeMarketItem(
                        texto, valor, detalle, hermano, comparacion, isBuying: true),
                    "world.market.sell.item" => ComposeMarketItem(
                        texto, valor, detalle, hermano, comparacion, isBuying: false),
                    "world.market.commands" => ComposeMarketCommands(valor, detalle),
                    "world.market.empty" => ComposeMarketEmpty(texto, detalle),
                    "world.market.action" => ComposeMarketAction(texto, valor, detalle),
                    "world.market.actions.none" => texto.Length > 0
                        ? L10n.F("world.market.actions.none", texto)
                        : L10n.T("world.market.actions.none_empty"),
                    "world.market.confirm" => ComposeMarketConfirmation(texto, valor, detalle),
                    "world.market.confirm.cancelled" => L10n.F(categoria, texto),
                    "world.market.error" => L10n.T("world.market.error." + valor),
                    string key when key.StartsWith("world.market.result.", StringComparison.Ordinal)
                        => L10n.F(key, texto, valor, detalle),
                    "world.recruit.candidate" => ComposeRecruitCandidate(texto, valor, detalle),
                    "world.recruit.empty" => ComposeRecruitEmpty(valor, detalle),
                    "world.recruit.action" => ComposeRecruitAction(texto, valor, detalle),
                    "world.recruit.actions.none" => L10n.F(categoria, texto),
                    "world.recruit.error" => L10n.T("world.recruit.error." + valor),
                    "world.tavern.action" => ComposeTavernAction(texto, valor, detalle),
                    "world.tavern.error" => L10n.T("world.tavern.error." + valor),
                    "world.temple.patient" => ComposeTemplePatient(texto, detalle),
                    "world.temple.empty" => ComposeTempleEmpty(valor, detalle),
                    "world.temple.injury" => ComposeTempleInjury(texto, valor, detalle),
                    "world.temple.result" => ComposeTempleResult(texto, valor, detalle),
                    "world.temple.error" => L10n.F("world.temple.error." + valor, texto),
                    "world.craft.blueprint" => ComposeCraftBlueprint(texto, valor, detalle),
                    "world.craft.empty" => ComposeCraftEmpty(valor, detalle),
                    "world.craft.detail.description"
                        => ComposeCraftDetail(L10n.F("world.craft.detail.description", texto), detalle),
                    "world.craft.detail.ingredient"
                        => ComposeCraftDetail(ComposeCraftIngredient(texto, valor), detalle),
                    "world.craft.details.none" => L10n.F(categoria, texto),
                    "world.craft.action" => ComposeCraftAction(texto, valor, detalle),
                    "world.craft.result" => L10n.F(categoria, texto, valor, detalle),
                    "world.craft.error" => L10n.F("world.craft.error." + valor, texto),
                    "world.travel.destination" => ComposeTravelDestination(texto, valor, detalle),
                    "world.travel.empty" => ComposeTravelEmpty(valor, detalle),
                    "world.travel.detail" => ComposeTravelDetail(texto, valor, detalle),
                    "world.travel.confirm" => ComposeTravelConfirm(texto, valor, detalle),
                    "world.travel.error" => ComposeTravelError(texto, valor, detalle),
                    "world.training.man" => ComposeTrainingMan(texto, detalle),
                    "world.training.empty" => ComposeTrainingEmpty(valor, detalle),
                    "world.training.option" => ComposeTrainingOption(texto, valor, detalle),
                    "world.training.blocked" => L10n.F("world.training.blocked." + valor, texto),
                    "world.training.error" => ComposeTrainingError(texto, valor, detalle),
                    "world.training.result" => ComposeTrainingResult(texto, valor, detalle),
                    string key when key.StartsWith("world.recruit.result.", StringComparison.Ordinal)
                        => L10n.F(key, texto, valor, detalle),
                    "world.character.perk" => ComposeWorldPerk(texto, valor, detalle),
                    "world.character.perks.summary" => L10n.F(categoria, valor, detalle),
                    "world.character.perks.summary.no_action" => L10n.T(categoria),
                    "world.character.perk.actions.none" => L10n.F(categoria, texto,
                        L10n.T("world.character.perk.state." + valor)),
                    string key when key.StartsWith("world.character.perk.result.",
                        StringComparison.Ordinal) => L10n.F(key, texto, valor),
                    "world.character.levelup.attribute"
                        => ComposeLevelUpAttribute(texto, valor, detalle),
                    "world.character.levelup.confirm"
                        => ComposeLevelUpConfirm(texto, valor, detalle),
                    "world.character.levelup.full"
                        => L10n.F(categoria, LevelUpAttributeName(texto), valor),
                    "world.character.levelup.cancelled" => L10n.F(categoria, texto),
                    "world.character.levelup.confirmed"
                        => ComposeLevelUpConfirmed(texto, valor),
                    string key when key.StartsWith("world.character.levelup.result.",
                        StringComparison.Ordinal)
                        => ComposeLevelUpChoice(key, texto, valor, detalle),
                    "world.character.dismiss.blocked"
                        => L10n.F("world.character.dismiss.blocked." + valor, texto),
                    "world.character.dismiss.cancelled"
                        or "world.character.dismiss.failed" => L10n.F(categoria, texto),
                    "world.character.dismiss.done" => ComposeDismissResult(texto, "", detalle),
                    "world.character.dismiss.done.paid"
                        => ComposeDismissResult(texto, valor, detalle),
                    string key when key.StartsWith("world.character.dismiss.option.",
                        StringComparison.Ordinal) => ComposeDismissOption(key, texto, valor, detalle),
                    "world.status.levelup.brother" => ComposeStatusLevelUp(texto, valor, detalle),
                    "world.status.money" => ComposeWorldMoney(valor, detalle),
                    "world.status.supplies" => ComposeWorldSupplies(valor, detalle),
                    "world.status.medicine" => ComposeWorldMedicine(valor, detalle),
                    "world.status.wounded.brother" => ComposeWoundedBrother(texto, detalle),
                    "world.character.formation.summary" => ComposeFormationSummary(valor, detalle),
                    "world.character.formation.slot" => ComposeFormationSlot(texto, valor, detalle),
                    "world.character.formation.target" => ComposeFormationTarget(texto, valor, detalle),
                    "world.character.formation.move.started"
                        => ComposeFormationMoveStarted(texto, valor, detalle),
                    "world.character.formation.move.cancelled" => L10n.F(categoria, texto),
                    "world.character.formation.result.move"
                        => ComposeFormationMoveResult(texto, valor, detalle),
                    "world.character.formation.result.swap"
                        => ComposeFormationSwapResult(texto, valor, detalle),
                    "world.character.formation.error.same" => L10n.F(categoria, texto),
                    "world.character.formation.error.maximum" => L10n.F(categoria, valor),
                    "world.character.formation.error.empty_source"
                        or "world.character.formation.error.invalid_target"
                        or "world.character.formation.error.minimum"
                        or "world.character.formation.error.stale"
                        or "world.character.formation.error.unavailable" => L10n.T(categoria),
                    "world.combat.dialog.screen" => ComposeWorldCombatDialogScreen(valor, detalle),
                    "world.combat.dialog.enemy" => ComposeWorldCombatDialogEnemy(
                        texto, valor, detalle),
                    "tooltip.detail" => ComposeTooltipDetail(texto, valor, detalle),
                    "combat.result.stat" => ComposeResultStat(texto, valor, detalle),
                    "combat.result.loot.item" => ComposeResultLootItem(texto, valor, detalle),
                    "world.town.screen" => ComposeTownScreen(texto, valor),
                    "world.town.arena.closed" => L10n.F("world.town.arena." + valor, texto),
                    "world.town.port.closed" => L10n.F("world.town.port." + valor, texto),
                    "menu.campaign" => ComposeCampaignEntry(texto, valor, detalle),
                    "menu.campaign.screen" => ComposeCampaignScreen(texto, valor),
                    "menu.map_seed.copy" => ClipboardService.TrySetText(texto)
                        ? L10n.F("menu.map_seed.copied", texto)
                        : L10n.T("menu.map_seed.copy_failed"),
                    "world.survey.places.screen" => ComposeSurveyPlacesScreen(valor, detalle),
                    "world.survey.parties.screen" => ComposeSurveyPartiesScreen(detalle),
                    "world.survey.item" => ComposeSurveyItem(texto, valor, detalle),
                    "world.discovery.single" => ComposeDiscoverySighting(texto, valor, detalle),
                    "world.threat.closing" => ComposeThreatClosing(texto, valor, detalle),
                    "world.upkeep.result" => ComposeUpkeepResult(valor),
                    "world.upkeep.warning" => ComposeUpkeepWarning(valor, detalle),
                    "world.discovery.summary" => ComposeDiscoverySummary(valor),
                    "world.obituary.entry" => ComposeObituaryEntry(texto, detalle),
                    "world.retinue.slot.follower" => ComposeRetinueSlot(texto, valor, detalle),
                    "world.retinue.hire.follower" => ComposeRetinueFollower(texto, valor, detalle),
                    "world.move.step" => ComposeMoveStep(texto, valor, detalle),
                    "world.move.stopped" => ComposeMoveStopped(texto, valor, detalle),
                    "world.cursor.tile" => ComposeCursorTile(texto, valor, detalle, recentered: false),
                    "world.cursor.recentered" => ComposeCursorTile(texto, valor, detalle, recentered: true),
                    "world.cursor.here" => ComposeCursorHere(valor, detalle),
                    "world.cursor.bearing" => L10n.F(categoria, PackedPosition(detalle)),
                    "world.cursor.travel" => ComposeCursorTravel(texto, valor, detalle),
                    "world.cursor.list.screen" => ComposeCursorListScreen(valor, detalle),
                    "world.cursor.list.terrain" => ComposeCursorTerrainRow(valor, detalle),
                    "world.cursor.list.path" => ComposePaths(valor, moving: false, withEffect: true),
                    "world.cursor.list.tracks" => ComposeCursorTracksRow(valor, detalle),
                    "world.tracks.summary" => ComposeTracksSummary(valor),
                    "world.roads.summary" => ComposeRoadsSummary(valor),
                    "help.row" => ComposeHelpRow(valor, detalle),
                    _ => categoria.Length > 0
                        ? L10n.F(categoria, texto, valor, detalle)
                        : texto,
                };
                spoken = AppendTalentStars(spoken, talento);
                spoken = AppendDetailsHint(spoken, detalles);
                spoken = AppendActionsHint(spoken, acciones);
                spoken = AppendIdentityHints(spoken, categoria, detalle);
                spoken = ComposeCharacterContext(spoken, contexto);
                // When changing the brother shown on the tactical character sheet,
                // keep his name and the retained attribute in one utterance. Two
                // consecutive interrupt messages would make the attribute cut off
                // the name before NVDA could finish it.
                if (hermano.Length > 0 &&
                    !categoria.StartsWith("world.market.", StringComparison.Ordinal))
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

        /// <summary>Add the discoverable V-key hint only to semantic rows that
        /// explicitly report one or more native tooltips. Rows with no details stay
        /// concise; pressing V on one still produces an audible unavailable cue.</summary>
        /// <summary>The talent stars vanilla draws beside an attribute, spoken right
        /// after its value. Zero maps to an empty string and is therefore silent: a
        /// brother always carries exactly three talents, so the rows that do speak
        /// already say which the other five are. Runs before the details and actions
        /// hints, so the row reads value, stars, then what the keys do.</summary>
        private static string AppendTalentStars(string spoken, string talent)
        {
            if (talent.Length == 0) return spoken;
            string stars = L10n.T("combat.sheet.talent." + talent);
            if (stars.Length == 0) return spoken;
            return spoken.Length > 0 ? spoken + " " + stars : stars;
        }

        private static string AppendDetailsHint(string spoken, string countText)
        {
            if (!int.TryParse(countText, out int count) || count <= 0)
                return spoken;

            string hint = count == 1
                ? L10n.T("tooltip.details.one")
                : L10n.F("tooltip.details.many", count);
            return spoken.Length > 0 ? spoken + " " + hint : hint;
        }

        private static string AppendActionsHint(string spoken, string countText)
        {
            if (!int.TryParse(countText, out int count) || count <= 0)
                return spoken;

            string hint = count == 1
                ? L10n.T("world.inventory.actions.one")
                : L10n.F("world.inventory.actions.many", count);
            return spoken.Length > 0 ? spoken + " " + hint : hint;
        }

        /// <summary>Hints that ride on the identity row, in the order Squirrel packs
        /// them and only while they are true: a pending level up, which is where
        /// vanilla draws its star, and Delete, which it only offers when the man can
        /// really be dismissed. They land after the Enter hint and before the position,
        /// so the row reads: who he is, what Enter does, what is waiting for him, what
        /// Delete does, where you are in the list.</summary>
        private static string AppendIdentityHints(string spoken, string categoria, string detalle)
        {
            if (categoria != "combat.sheet.identity") return spoken;
            foreach (string flag in detalle.Split('|', StringSplitOptions.RemoveEmptyEntries))
            {
                string key = flag switch
                {
                    "levelup" => "world.character.levelup.hint",
                    "dismiss" => "world.character.dismiss.hint",
                    _ => "",
                };
                if (key.Length == 0) continue;
                string hint = L10n.T(key);
                spoken = spoken.Length > 0 ? spoken + " " + hint : hint;
            }
            return spoken;
        }

        /// <summary>One row of the dismissal confirmation. Squirrel packs
        /// "index|total|opened|free|crowns"; "free" is vanilla's own distinction
        /// between dismissing a man who draws a wage and freeing one who does not.
        /// On opening, the warning about what dismissal costs is spoken first, so a
        /// player who pressed Delete by mistake hears it before anything else.</summary>
        private static string ComposeDismissOption(string key, string name, string cost, string detail)
        {
            string[] parts = detail.Split('|');
            string index = parts.Length > 0 ? parts[0] : "1";
            string total = parts.Length > 1 ? parts[1] : "3";
            bool opened = parts.Length > 2 && parts[2] == "1";
            bool free = parts.Length > 3 && parts[3] == "1";
            string money = parts.Length > 4 ? parts[4] : "";

            string option = key.EndsWith(".cancel", StringComparison.Ordinal)
                ? L10n.F(key, name)
                : L10n.F(free ? key + ".free" : key, name, cost, money);
            string result = option + " " + L10n.F("world.character.dismiss.position", index, total);
            if (!opened) return result;

            return L10n.F(free ? "world.character.dismiss.opened.free"
                : "world.character.dismiss.opened", name, result);
        }

        /// <summary>The outcome, from live state after the roster shrank: Squirrel
        /// packs "brothers-left|crowns".</summary>
        private static string ComposeDismissResult(string name, string cost, string detail)
        {
            string[] parts = detail.Split('|');
            string left = parts.Length > 0 ? parts[0] : "";
            string money = parts.Length > 1 ? parts[1] : "";
            return cost.Length > 0
                ? L10n.F("world.character.dismiss.done.paid", name, cost, left, money)
                : L10n.F("world.character.dismiss.done", name, left);
        }

        /// <summary>Append a world CharacterScreen row's position after its detail
        /// hint. Squirrel packs "section|index|total|announce-section"; the section
        /// name is included only on opening the screen or changing it with Page
        /// Up/Down, never while walking the list with Up/Down.</summary>
        private static string ComposeCharacterContext(string spoken, string context)
        {
            if (context.Length == 0) return spoken;
            string[] parts = context.Split('|');
            if (parts.Length < 3) return spoken;

            string position = L10n.F("world.character.position", parts[1], parts[2]);
            string result = spoken.Length > 0 ? spoken + " " + position : position;
            bool includeSection = parts.Length > 3 && parts[3] == "1";
            if (!includeSection) return result;

            string section = L10n.T("world.character.section." + parts[0]);
            return L10n.F("world.character.section.changed", section, result);
        }

        private static string WithItemAmount(string name, string amount)
        {
            string item = name.Length > 0 ? name : L10n.T("world.character.item.empty");
            return amount.Length > 0
                ? L10n.F("world.character.item.amount", item, amount)
                : item;
        }

        private static string ComposeEquipmentSlot(string name, string slot, string amount)
        {
            string slotName = L10n.T("world.character.equipment.slot." + slot);
            return L10n.F("world.character.equipment.slot", slotName,
                WithItemAmount(name, amount));
        }

        private static string ComposeBagSlot(string name, string slot, string amount)
        {
            return L10n.F("world.character.bag.slot", slot,
                WithItemAmount(name, amount));
        }

        private static string ComposeStashItem(string name, string amount)
        {
            return L10n.F("world.character.stash.item", WithItemAmount(name, amount));
        }

        private static string ComposeStashCommands(string filter)
        {
            return L10n.F("world.character.stash.commands",
                L10n.T("world.inventory.filter." + filter));
        }

        /// <summary>Compose one row in the explicit inventory action sub-list.
        /// Squirrel sends detail as "index|total|opened|cost"; the longer keyboard
        /// hint is included only when Enter first opens the list. Cost is populated
        /// only for tactical equipment changes.</summary>
        private static string ComposeInventoryAction(string itemName, string action, string detail)
        {
            string label = L10n.T("world.inventory.action." + action);
            string result = itemName.Length > 0
                ? L10n.F("world.inventory.action.for_item", label, itemName)
                : L10n.F("world.inventory.action.standalone", label);

            string[] parts = detail.Split('|');
            string index = parts.Length > 0 ? parts[0] : "1";
            string total = parts.Length > 1 ? parts[1] : "1";
            result += " " + L10n.F("world.inventory.action.position", index, total);
            string cost = parts.Length > 3 ? parts[3] : "";
            if (cost.Length > 0)
                result = L10n.F("combat.inventory.action.cost", result, cost);

            bool opened = parts.Length > 2 && parts[2] == "1";
            return opened ? L10n.F("world.inventory.action.opened", result) : result;
        }

        private static string ComposeGroundItem(string name, string cost, string detail)
        {
            string[] parts = detail.Split('|');
            string index = parts.Length > 0 ? parts[0] : "1";
            string total = parts.Length > 1 ? parts[1] : "1";
            bool opened = parts.Length > 2 && parts[2] == "1";
            string result = L10n.F("combat.ground.item", name, cost)
                + " " + L10n.F("combat.ground.position", index, total);
            return opened ? L10n.F("combat.ground.opened", result) : result;
        }

        /// <summary>Attribute names live here, not in the game: the native level-up
        /// dialog draws icons only, so Squirrel sends the attribute id and nothing
        /// readable.</summary>
        private static string LevelUpAttributeName(string id)
        {
            return id.Length > 0 ? L10n.T("world.character.levelup.attribute." + id) : "";
        }

        /// <summary>Wrap the focused entry of the attribute list with its position,
        /// and — only the first time, when Enter opened it — with the header naming
        /// whose increases these are and which keys drive the list. Squirrel packs
        /// "index|total|opened" at the tail of every entry's detail.</summary>
        private static string FrameLevelUpEntry(string spoken, string name, string[] parts, int at)
        {
            string index = parts.Length > at ? parts[at] : "1";
            string total = parts.Length > at + 1 ? parts[at + 1] : "1";
            bool opened = parts.Length > at + 2 && parts[at + 2] == "1";

            string result = spoken + " " + L10n.F("world.character.levelup.position", index, total);
            return opened ? L10n.F("world.character.levelup.opened", name, result) : result;
        }

        /// <summary>One attribute offered by a pending level up. Squirrel packs
        /// "current|max|increase|talent|chosen|index|total|opened"; talent is the 0-3
        /// star rating the dialog only draws as an icon, and it is what makes one
        /// attribute worth raising over another.</summary>
        private static string ComposeLevelUpAttribute(string name, string id, string detail)
        {
            string[] parts = detail.Split('|');
            string current = parts.Length > 0 ? parts[0] : "";
            string max = parts.Length > 1 ? parts[1] : "";
            string increase = parts.Length > 2 ? parts[2] : "";
            string talent = parts.Length > 3 ? parts[3] : "0";
            bool chosen = parts.Length > 4 && parts[4] == "1";

            string result = L10n.F("world.character.levelup.attribute",
                LevelUpAttributeName(id), current, max, increase);
            string stars = L10n.T("world.character.levelup.talent." + talent);
            if (stars.Length > 0) result += " " + stars;
            result += " " + L10n.T(chosen
                ? "world.character.levelup.attribute.chosen"
                : "world.character.levelup.attribute.free");
            return FrameLevelUpEntry(result, name, parts, 5);
        }

        /// <summary>The last entry of the list, the one that applies the choices. It
        /// reads back the three attributes and warns that this is permanent — on
        /// focus, before Enter, because afterwards nothing can take it back. Squirrel
        /// packs "chosen|max|index|total|opened" and the picks as "id:increase" pairs.</summary>
        private static string ComposeLevelUpConfirm(string name, string picks, string detail)
        {
            string[] parts = detail.Split('|');
            string chosen = parts.Length > 0 ? parts[0] : "0";
            string max = parts.Length > 1 ? parts[1] : "3";

            string result = chosen == max
                ? L10n.F("world.character.levelup.confirm", ComposeLevelUpPicks(picks))
                : L10n.F("world.character.levelup.confirm.pending", chosen, max);
            return FrameLevelUpEntry(result, name, parts, 2);
        }

        /// <summary>"id:increase" pairs as a spoken list: "Melee skill plus 3."</summary>
        private static string ComposeLevelUpPicks(string picks)
        {
            string raised = "";
            foreach (string pick in picks.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                string[] pair = pick.Split(':');
                if (pair.Length != 2) continue;
                if (raised.Length > 0) raised += " ";
                raised += L10n.F("world.character.levelup.raised",
                    LevelUpAttributeName(pair[0]), pair[1]);
            }
            return raised;
        }

        /// <summary>Outcome of choosing or unchoosing. Nothing has been spent yet, so
        /// the reply is how many of the three are now taken — and, on the third, where
        /// to go to apply them.</summary>
        private static string ComposeLevelUpChoice(string key, string id, string chosen, string max)
        {
            string result = L10n.F(key, LevelUpAttributeName(id), chosen, max);
            if (chosen == max) result += " " + L10n.T("world.character.levelup.result.ready");
            return result;
        }

        /// <summary>Outcome of the commit, from the choices as they were sent:
        /// Squirrel packs "id:increase" pairs separated by commas. The entity has
        /// already changed by the time this is spoken, which is why the amounts
        /// travel rather than being read back.</summary>
        private static string ComposeLevelUpConfirmed(string picks, string left)
        {
            string raised = ComposeLevelUpPicks(picks);
            string remaining = left switch
            {
                "0" => L10n.T("world.character.levelup.remaining.none"),
                "1" => L10n.T("world.character.levelup.remaining.one"),
                _ => L10n.F("world.character.levelup.remaining", left),
            };
            return L10n.F("world.character.levelup.confirmed", raised) + " " + remaining;
        }

        /// <summary>One brother on the F2 status list who still owes something a level
        /// gave him. The two debts are independent — spending the perk point leaves the
        /// attribute increases pending, and vice versa — so the row names which.
        /// Squirrel packs "level-ups|perk-points".</summary>
        private static string ComposeStatusLevelUp(string name, string what, string detail)
        {
            string[] parts = detail.Split('|');
            string levelUps = parts.Length > 0 ? parts[0] : "0";
            string points = parts.Length > 1 ? parts[1] : "0";

            string attributes = L10n.F(levelUps == "1"
                ? "world.status.levelup.attributes.one"
                : "world.status.levelup.attributes", levelUps);
            string perks = L10n.F(points == "1"
                ? "world.status.levelup.perks.one"
                : "world.status.levelup.perks", points);

            return what switch
            {
                "both" => L10n.F("world.status.levelup.brother.both", name, attributes, perks),
                "attributes" => L10n.F("world.status.levelup.brother", name, attributes),
                _ => L10n.F("world.status.levelup.brother", name, perks),
            };
        }

        /// <summary>The supplies row includes vanilla's live estimate for every
        /// equipped damaged item and every stash item marked for repair. Squirrel packs
        /// "hours|required supplies" from AssetManager.getRepairRequired().</summary>
        private static string ComposeWorldSupplies(string availableText, string detail)
        {
            // Preserve the historic {1} slot of world.status.supplies so existing
            // language overrides keep working after the row gained repair details.
            string result = L10n.F("world.status.supplies", "", availableText);
            string[] parts = detail.Split('|');
            if (parts.Length < 2 || !int.TryParse(parts[0], out int hours) ||
                !int.TryParse(parts[1], out int required) || required <= 0)
                return result;

            string duration = hours == 1
                ? L10n.T("world.status.repair.hour.one")
                : L10n.F("world.status.repair.hours", hours);
            result += " " + L10n.F("world.status.repair", duration, required);

            if (int.TryParse(availableText, out int available) && available < required)
                result += " " + L10n.T("world.status.repair.insufficient");
            return result;
        }

        /// <summary>The crowns row mirrors vanilla's topbar tooltip: daily wages and
        /// the floored number of complete payroll days covered by the current purse.
        /// Squirrel packs "daily wages|days"; -1 days means there is no wage upkeep.</summary>
        private static string ComposeWorldMoney(string availableText, string detail)
        {
            // Keep the historic {1} slot for existing language overrides.
            string result = L10n.F("world.status.money", "", availableText);
            string[] parts = detail.Split('|');
            if (parts.Length < 2 || !int.TryParse(parts[0], out int dailyWages) ||
                !int.TryParse(parts[1], out int days))
                return result;

            if (dailyWages <= 0)
                return result + " " + L10n.T("world.status.money.no_wages");

            result += " " + L10n.F("world.status.money.daily", dailyWages);
            result += " " + (days switch
            {
                <= 0 => L10n.T("world.status.money.insufficient"),
                1 => L10n.T("world.status.money.day.one"),
                _ => L10n.F("world.status.money.days", days),
            });
            return result;
        }

        /// <summary>The medicine row mirrors AssetManager.getHealingRequired(), the
        /// source of vanilla's topbar tooltip. Its estimate covers temporary injuries
        /// and sickness, not ordinary lost hitpoints. Squirrel packs
        /// "minimum days|maximum days|minimum medicine|maximum medicine".</summary>
        private static string ComposeWorldMedicine(string availableText, string detail)
        {
            // Keep the historic {1} slot for existing language overrides.
            string result = L10n.F("world.status.medicine", "", availableText);
            string[] parts = detail.Split('|');
            if (parts.Length < 4 || !int.TryParse(parts[0], out int daysMin) ||
                !int.TryParse(parts[1], out int daysMax) ||
                !int.TryParse(parts[2], out int medicineMin) ||
                !int.TryParse(parts[3], out int medicineMax) || medicineMin <= 0)
                return result;

            string duration = FormatDayRange(daysMin, daysMax);
            string required = medicineMin == medicineMax
                ? medicineMin.ToString()
                : L10n.F("world.status.healing.medicine.range", medicineMin, medicineMax);
            result += " " + L10n.F("world.status.healing", duration, required);

            if (int.TryParse(availableText, out int available))
            {
                if (available < medicineMin)
                    result += " " + L10n.T("world.status.healing.insufficient");
                else if (available < medicineMax)
                    result += " " + L10n.T("world.status.healing.possibly_insufficient");
            }
            return result;
        }

        private static string FormatDayRange(int minimum, int maximum)
        {
            if (minimum == maximum)
                return minimum == 1
                    ? L10n.T("world.status.healing.day.one")
                    : L10n.F("world.status.healing.days", minimum);
            return L10n.F("world.status.healing.days.range", minimum, maximum);
        }

        /// <summary>One row in F2's wounded-brothers category. detail is
        /// "hp|hpMax|light-wound days|injury lines"; each line is name, minimum days
        /// maximum days and any healing blocker separated by tabs, all read from the
        /// same APIs and conditions as vanilla's character and status-effect tooltips.</summary>
        private static string ComposeWoundedBrother(string name, string detail)
        {
            string[] parts = detail.Split(new[] { '|' }, 4);
            string hp = parts.Length > 0 ? parts[0] : "0";
            string hpMax = parts.Length > 1 ? parts[1] : "0";
            string lightDays = parts.Length > 2 ? parts[2] : "0";
            var facts = new List<string> { name + "." };

            if (hp != hpMax)
            {
                facts.Add(L10n.F("world.status.wounded.health", hp, hpMax));
                facts.Add(lightDays == "1"
                    ? L10n.T("world.status.wounded.light.tomorrow")
                    : L10n.F("world.status.wounded.light.days", lightDays));
            }

            if (parts.Length > 3 && parts[3].Length > 0)
            {
                foreach (string line in parts[3].Split('\n', StringSplitOptions.RemoveEmptyEntries))
                {
                    string[] injury = line.Split('\t');
                    if (injury.Length < 3) continue;
                    string blocker = injury.Length > 3 ? injury[3] : "ok";
                    string healing = blocker switch
                    {
                        "medicine" => L10n.F(
                            "world.status.wounded.injury.no_medicine", injury[0]),
                        "oath" => L10n.F(
                            "world.status.wounded.injury.oath", injury[0]),
                        _ when injury[1] == "1" && injury[2] == "1"
                            => L10n.F("world.status.wounded.injury.tomorrow", injury[0]),
                        _ when injury[1] == injury[2]
                            => L10n.F("world.status.wounded.injury.days", injury[0], injury[1]),
                        _ => L10n.F("world.status.wounded.injury.range",
                            injury[0], injury[1], injury[2]),
                    };
                    facts.Add(healing);
                }
            }

            return string.Join(" ", facts);
        }

        private static string ComposeMarketScreen(string name, string money, string description)
        {
            return L10n.F("world.market.screen", name, description, money);
        }

        private static string ComposeMarketItem(
            string name,
            string price,
            string detail,
            string brother,
            string comparison,
            bool isBuying)
        {
            string[] parts = detail.Split('|');
            string amount = parts.Length > 0 ? parts[0] : "";
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "1";
            bool announceSection = parts.Length > 3 && parts[3] == "1";
            bool comparisonApplies = parts.Length > 4 && parts[4] == "1";
            string section = isBuying ? "buy" : "sell";

            // price packs "asked|worth|paid": what this town wants or offers, what the item
            // is worth anywhere, and — for provisions and trading goods in your own stash —
            // what you paid for it. The last two are what decided the deal in the tooltip,
            // and needing V on every row to reach them made haggling by ear too slow.
            string[] money = price.Split('|');
            string asked = money.Length > 0 ? money[0] : price;
            string worth = money.Length > 1 ? money[1] : "";
            string paid = money.Length > 2 ? money[2] : "";

            string result = L10n.F(
                isBuying ? "world.market.buy.item" : "world.market.sell.item",
                WithItemAmount(name, amount),
                asked);

            // "Worth nothing" adds nothing the price did not already say.
            if (worth.Length > 0 && worth != "0")
                result += " " + L10n.F("world.market.value", worth);
            if (paid.Length > 0)
                result += " " + L10n.F("world.market.bought", paid);

            if (comparisonApplies && brother.Length > 0)
            {
                result += " " + (comparison.Length > 0
                    ? L10n.F("world.market.comparison.equipped", brother, comparison)
                    : L10n.F("world.market.comparison.empty", brother));
            }
            result += " " + L10n.F("world.market.position", index, total);
            return announceSection
                ? L10n.T("world.market.section." + section) + ". " + result
                : result;
        }

        private static string ComposeMarketCommands(string filter, string detail)
        {
            string result = L10n.F(
                "world.market.commands",
                L10n.T("world.inventory.filter." + filter));
            return AppendMarketPosition(result, "sell", detail);
        }

        private static string ComposeMarketEmpty(string section, string detail)
        {
            string label = L10n.T("world.market.section." + section);
            string result = L10n.F("world.market.empty", label);
            return AppendMarketPosition(result, section, detail);
        }

        /// <summary>Market command and empty rows use the same compact detail shape
        /// as item rows: amount|index|total|announce-section.</summary>
        private static string AppendMarketPosition(string spoken, string section, string detail)
        {
            string[] parts = detail.Split('|');
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "1";
            bool announceSection = parts.Length > 3 && parts[3] == "1";
            string result = spoken + " " + L10n.F("world.market.position", index, total);
            return announceSection
                ? L10n.T("world.market.section." + section) + ". " + result
                : result;
        }

        private static string ComposeMarketAction(string itemName, string action, string detail)
        {
            string[] parts = detail.Split('|');
            string price = parts.Length > 0 ? parts[0] : "";
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "1";
            bool opened = parts.Length > 3 && parts[3] == "1";
            bool priced = action is "buy" or "sell" or "repair";
            string label = priced
                ? L10n.F("world.market.action." + action, price)
                : L10n.T("world.market.action." + action);
            string result = itemName.Length > 0
                ? L10n.F("world.market.action.for_item", label, itemName)
                : L10n.F("world.market.action.standalone", label);
            result += " " + L10n.F("world.market.action.position", index, total);
            return opened ? L10n.F("world.market.action.opened", result) : result;
        }

        private static string ComposeMarketConfirmation(string itemName, string kind, string detail)
        {
            string[] parts = detail.Split('|');
            string choice = parts.Length > 0 ? parts[0] : "cancel";
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "2";
            string price = parts.Length > 3 ? parts[3] : "";
            bool opened = parts.Length > 4 && parts[4] == "1";
            string result = L10n.F("world.market.confirm." + kind, itemName, price)
                + " " + L10n.T("world.market.confirm.choice." + choice) + ". "
                + L10n.F("world.market.confirm.choice.position", index, total);
            return opened ? L10n.F("world.market.confirm.opened", result) : result;
        }

        /// <summary>Compose a recruit row from live game facts. Squirrel packs
        /// "level|hire|daily|tryout|tried|trait-count|index|total|opened|money".
        /// Hidden traits are never transmitted: before a native tryout we announce
        /// only that they remain unknown, preserving vanilla information parity.</summary>
        private static string ComposeRecruitCandidate(string name, string background, string detail)
        {
            string[] parts = detail.Split('|');
            string level = parts.Length > 0 ? parts[0] : "";
            string hire = parts.Length > 1 ? parts[1] : "";
            string daily = parts.Length > 2 ? parts[2] : "";
            string tryout = parts.Length > 3 ? parts[3] : "";
            bool tried = parts.Length > 4 && parts[4] == "1";
            int traitCount = parts.Length > 5 &&
                int.TryParse(parts[5], out int parsedTraits) ? parsedTraits : 0;
            string index = parts.Length > 6 ? parts[6] : "1";
            string total = parts.Length > 7 ? parts[7] : "1";
            bool opened = parts.Length > 8 && parts[8] == "1";
            string money = parts.Length > 9 ? parts[9] : "";

            string result = L10n.F("world.recruit.candidate",
                name, background, level, hire, daily);
            if (!tried)
            {
                result += " " + L10n.F("world.recruit.tryout.unknown", tryout);
            }
            else if (traitCount == 0)
            {
                result += " " + L10n.T("world.recruit.tryout.none");
            }
            else if (traitCount == 1)
            {
                result += " " + L10n.T("world.recruit.tryout.one");
            }
            else
            {
                result += " " + L10n.F("world.recruit.tryout.count", traitCount);
            }

            result += " " + L10n.F("world.recruit.position", index, total);
            return opened ? L10n.F("world.recruit.screen", money, result) : result;
        }

        private static string ComposeRecruitEmpty(string money, string detail)
        {
            string result = L10n.F("world.recruit.empty", money);
            return detail == "1"
                ? L10n.F("world.recruit.empty.opened", result)
                : result;
        }

        private static string ComposeRecruitAction(string candidateName, string action, string detail)
        {
            string[] parts = detail.Split('|');
            string price = parts.Length > 0 ? parts[0] : "";
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "1";
            bool opened = parts.Length > 3 && parts[3] == "1";

            string label = L10n.F("world.recruit.action." + action, price);
            string result = L10n.F("world.recruit.action.for_candidate",
                label, candidateName);
            result += " " + L10n.F("world.recruit.action.position", index, total);
            return opened ? L10n.F("world.recruit.action.opened", result) : result;
        }

        private static string ComposeTavernAction(string money, string action, string detail)
        {
            string[] parts = detail.Split('|');
            string price = parts.Length > 0 ? parts[0] : "";
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "1";
            bool opened = parts.Length > 3 && parts[3] == "1";
            bool hasResult = parts.Length > 4 && parts[4] == "1";

            string result = L10n.F("world.tavern.action." + action, price);
            result += " " + L10n.F("world.tavern.position", index, total);
            // Whether there is anything to re-read decides which of the two hints
            // makes sense: offering V when nothing was ever said only wastes breath.
            result += " " + L10n.T(hasResult ? "world.tavern.unread" : "world.tavern.unheard");
            return opened
                ? L10n.F("world.tavern.screen",
                    L10n.F("world.tavern.purse", money) + " " + result)
                : result;
        }

        private static string ComposeTemplePatient(string name, string detail)
        {
            string[] parts = detail.Split('|');
            int injuries = parts.Length > 0 &&
                int.TryParse(parts[0], out int parsedInjuries) ? parsedInjuries : 0;
            string total = parts.Length > 1 ? parts[1] : "";
            string index = parts.Length > 2 ? parts[2] : "1";
            string patients = parts.Length > 3 ? parts[3] : "1";
            bool opened = parts.Length > 4 && parts[4] == "1";
            string money = parts.Length > 5 ? parts[5] : "";

            string count = injuries == 1
                ? L10n.T("world.temple.injuries.one")
                : L10n.F("world.temple.injuries.many", injuries);
            string result = L10n.F("world.temple.patient", name, count, total);
            result += " " + L10n.F("world.temple.position", index, patients);
            return opened
                ? L10n.F("world.temple.screen",
                    L10n.F("world.tavern.purse", money) + " " + result)
                : result;
        }

        private static string ComposeTempleEmpty(string money, string detail)
        {
            string result = L10n.F("world.temple.empty", money);
            return detail == "1" ? L10n.F("world.temple.empty.opened", result) : result;
        }

        private static string ComposeTempleInjury(string injury, string brother, string detail)
        {
            string[] parts = detail.Split('|');
            string price = parts.Length > 0 ? parts[0] : "";
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "1";
            bool opened = parts.Length > 3 && parts[3] == "1";
            bool unaffordable = parts.Length > 4 && parts[4] == "1";

            string result = L10n.F("world.temple.injury", injury, price, brother);
            if (unaffordable)
                result += " " + L10n.T("world.temple.injury.unaffordable");
            result += " " + L10n.F("world.temple.injury.position", index, total);
            return opened ? L10n.F("world.temple.injury.opened", result) : result;
        }

        private static string ComposeTempleResult(string injury, string brother, string detail)
        {
            string[] parts = detail.Split('|');
            string price = parts.Length > 0 ? parts[0] : "";
            string money = parts.Length > 1 ? parts[1] : "";
            return L10n.F("world.temple.result", injury, brother, price, money);
        }

        /// <summary>One harbour destination. Carries the two things the dialog does not
        /// print but a sighted player has anyway: the owning faction, which he reads off
        /// the banner, and where the place lies, which he reads off the map. A
        /// destination still under fog says so instead of giving a bearing — the roster
        /// is filtered by alliance, not by discovery, and the map would not show him an
        /// undiscovered harbour either.</summary>
        /// <summary>The settlement screen's opening line. The situation count rides on
        /// the name rather than after the navigation hints, so it is heard before the
        /// player decides whether to walk down to those rows at all.</summary>
        private static string ComposeTownScreen(string name, string situations)
        {
            string head = name;
            if (int.TryParse(situations, out int count) && count > 0)
            {
                head = count == 1
                    ? L10n.F("world.town.situations.one", name)
                    : L10n.F("world.town.situations.many", name, count);
            }
            return L10n.F("world.town.screen", head);
        }

        private static string ComposeTravelDestination(string name, string faction, string detail)
        {
            string[] parts = detail.Split('|');
            string cost = parts.Length > 0 ? parts[0] : "";
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "1";
            bool opened = parts.Length > 3 && parts[3] == "1";
            string money = parts.Length > 4 ? parts[4] : "";
            bool unaffordable = parts.Length > 5 && parts[5] == "1";
            bool seen = parts.Length > 6 && parts[6] == "1";
            string dist = parts.Length > 7 ? parts[7] : "0";
            string dir = parts.Length > 8 ? parts[8] : "-1";

            string result = L10n.F("world.travel.destination", name, faction, cost);
            if (!seen)
            {
                result += " " + L10n.T("world.travel.unknown");
            }
            else
            {
                string position = ComposePosition(dist, dir);
                if (position.Length > 0) result += " " + position + ".";
            }
            if (unaffordable) result += " " + L10n.T("world.travel.unaffordable");
            result += " " + L10n.F("world.travel.position", index, total);
            return opened
                ? L10n.F("world.travel.screen",
                    L10n.F("world.tavern.purse", money) + " " + result)
                : result;
        }

        private static string ComposeTravelEmpty(string money, string detail)
        {
            string result = L10n.F("world.travel.empty", money);
            return detail == "1" ? L10n.F("world.travel.empty.opened", result) : result;
        }

        private static string ComposeTravelDetail(string text, string destination, string detail)
        {
            string[] parts = detail.Split('|');
            string index = parts.Length > 0 ? parts[0] : "1";
            string total = parts.Length > 1 ? parts[1] : "1";
            bool opened = parts.Length > 2 && parts[2] == "1";

            string result = L10n.F("world.travel.detail", text);
            if (total != "1")
                result += " " + L10n.F("world.travel.detail.position", index, total);
            return opened ? L10n.F("world.travel.detail.opened", result) : result;
        }

        private static string ComposeTravelConfirm(string name, string cost, string detail)
        {
            string[] parts = detail.Split('|');
            string money = parts.Length > 0 ? parts[0] : "";
            bool opened = parts.Length > 1 && parts[1] == "1";
            bool unaffordable = parts.Length > 2 && parts[2] == "1";

            string result = L10n.F("world.travel.confirm", name, cost, money);
            if (unaffordable) result += " " + L10n.T("world.travel.confirm.blocked");
            return opened ? L10n.F("world.travel.confirm.opened", result) : result;
        }

        private static string ComposeTravelError(string name, string reason, string detail)
        {
            string[] parts = detail.Split('|');
            string cost = parts.Length > 0 ? parts[0] : "";
            string money = parts.Length > 1 ? parts[1] : "";
            return L10n.F("world.travel.error." + reason, name, cost, money);
        }

        /// <summary>One man in the training hall. A man who cannot train says why:
        /// vanilla simply leaves him out of its list, which reads as a man gone
        /// missing when the list is heard rather than seen.
        /// </summary>
        private static string ComposeTrainingMan(string name, string detail)
        {
            string[] parts = detail.Split('|');
            string level = parts.Length > 0 ? parts[0] : "";
            int lessons = parts.Length > 1 &&
                int.TryParse(parts[1], out int parsedLessons) ? parsedLessons : 0;
            string index = parts.Length > 2 ? parts[2] : "1";
            string total = parts.Length > 3 ? parts[3] : "1";
            bool opened = parts.Length > 4 && parts[4] == "1";
            string money = parts.Length > 5 ? parts[5] : "";
            string reason = parts.Length > 6 && parts[6].Length > 0 ? parts[6] : "none";

            string result = L10n.F("world.training.man", name, level);
            result += " " + (lessons > 0
                ? L10n.F("world.training.lessons", lessons)
                : L10n.T("world.training.reason." + reason));
            result += " " + L10n.F("world.training.position", index, total);
            return opened
                ? L10n.F("world.training.screen",
                    L10n.F("world.tavern.purse", money) + " " + result)
                : result;
        }

        private static string ComposeTrainingEmpty(string money, string detail)
        {
            string result = L10n.F("world.training.empty", money);
            return detail == "1" ? L10n.F("world.training.empty.opened", result) : result;
        }

        private static string ComposeTrainingOption(string lesson, string brother, string detail)
        {
            string[] parts = detail.Split('|');
            string price = parts.Length > 0 ? parts[0] : "";
            string index = parts.Length > 1 ? parts[1] : "1";
            string total = parts.Length > 2 ? parts[2] : "1";
            bool opened = parts.Length > 3 && parts[3] == "1";
            bool unaffordable = parts.Length > 4 && parts[4] == "1";

            string result = L10n.F("world.training.option", lesson, price, brother);
            if (unaffordable) result += " " + L10n.T("world.training.option.unaffordable");
            result += " " + L10n.F("world.training.option.position", index, total);
            return opened ? L10n.F("world.training.option.opened", result) : result;
        }

        private static string ComposeTrainingError(string lesson, string reason, string detail)
        {
            string[] parts = detail.Split('|');
            string price = parts.Length > 0 ? parts[0] : "";
            string money = parts.Length > 1 ? parts[1] : "";
            return L10n.F("world.training.error." + reason, lesson, price, money);
        }

        private static string ComposeTrainingResult(string lesson, string brother, string detail)
        {
            string[] parts = detail.Split('|');
            string price = parts.Length > 0 ? parts[0] : "";
            string money = parts.Length > 1 ? parts[1] : "";
            return L10n.F("world.training.result", brother, lesson, price, money);
        }

        /// <summary>One row of the F1 key help. Squirrel sends only the row key and
        /// "context|index|total|opened": the text of every key, and the name of the
        /// surface, live here, so a translation covers the help with no mod change.
        /// A row whose string is missing falls back to its own key rather than
        /// swallowing the row, which keeps a stale list audible instead of silent.
        /// </summary>
        private static string ComposeHelpRow(string row, string detail)
        {
            string[] p = detail.Split('|');
            string context = p.Length > 0 ? p[0] : "";
            string index = p.Length > 1 ? p[1] : "1";
            string total = p.Length > 2 ? p[2] : "1";
            bool opened = p.Length > 3 && p[3] == "1";

            string body = L10n.T("help." + context + "." + row);
            string result = body + " " + L10n.F("help.position", index, total);
            return opened
                ? L10n.F("help.screen", L10n.T("help.context." + context), total, result)
                : result;
        }

        /// <summary>One blueprint row of the taxidermist's crafting list. detail is
        /// "craftable|affordable|index|total|opened|money|ingredients": the two flags
        /// are kept apart so the reason a recipe cannot be made right now can be
        /// named — that greyed-out entry is exactly what a blind player cannot
        /// see. The position closes the row, as in every other navigable list.
        /// </summary>
        private static string ComposeCraftBlueprint(string name, string cost, string detail)
        {
            string[] p = detail.Split('|');
            bool craftable = p.Length > 0 && p[0] == "1";
            bool affordable = p.Length > 1 && p[1] == "1";
            string index = p.Length > 2 ? p[2] : "1";
            string total = p.Length > 3 ? p[3] : "1";
            bool opened = p.Length > 4 && p[4] == "1";
            string money = p.Length > 5 ? p[5] : "";
            int ingredients = p.Length > 6 && int.TryParse(p[6], out int parsed) ? parsed : 0;

            string result = L10n.F("world.craft.blueprint", name, cost);
            if (!craftable) result += " " + L10n.T("world.craft.blocked.ingredients");
            else if (!affordable) result += " " + L10n.T("world.craft.blocked.money");
            if (ingredients > 0) result += " " + L10n.F("world.craft.details", ingredients);
            result += " " + L10n.F("world.craft.position", index, total);
            return opened
                ? L10n.F("world.craft.screen",
                    L10n.F("world.tavern.purse", money) + " " + result)
                : result;
        }

        private static string ComposeCraftEmpty(string money, string detail)
        {
            string result = L10n.F("world.craft.empty", money);
            return detail == "1" ? L10n.F("world.craft.empty.opened", result) : result;
        }

        /// <summary>Close a V sub-list row with its position, and frame the first one
        /// with how to get back out. detail is "index|total|opened".</summary>
        private static string ComposeCraftDetail(string body, string detail)
        {
            string[] p = detail.Split('|');
            string index = p.Length > 0 ? p[0] : "1";
            string total = p.Length > 1 ? p[1] : "1";
            bool opened = p.Length > 2 && p[2] == "1";

            string result = body + " " + L10n.F("world.craft.detail.position", index, total);
            return opened ? L10n.F("world.craft.detail.opened", result) : result;
        }

        /// <summary>An ingredient row: the item's own name, how many the recipe wants
        /// and how many of those the stash is still short of. The missing count is
        /// the game's — counted off the very array whose icons it greys out.</summary>
        private static string ComposeCraftIngredient(string name, string counts)
        {
            string[] p = counts.Split('|');
            string num = p.Length > 0 ? p[0] : "1";
            int missing = p.Length > 1 && int.TryParse(p[1], out int parsed) ? parsed : 0;

            string result = L10n.F("world.craft.detail.ingredient", num, name);
            if (missing > 0) result += " " + L10n.F("world.craft.detail.missing", missing);
            return result;
        }

        /// <summary>The craft action opened with Enter. detail is
        /// "opened|blockReason|money"; an empty reason means it can be made.</summary>
        private static string ComposeCraftAction(string name, string cost, string detail)
        {
            string[] p = detail.Split('|');
            bool opened = p.Length > 0 && p[0] == "1";
            string reason = p.Length > 1 ? p[1] : "";
            string money = p.Length > 2 ? p[2] : "";

            string result = reason.Length > 0
                ? L10n.F("world.craft.action.blocked", name, L10n.T("world.craft.blocked." + reason))
                : L10n.F("world.craft.action", name, cost, money);
            return opened ? L10n.F("world.craft.action.opened", result) : result;
        }

        private static string ComposeWorldPerk(string name, string state, string tier)
        {
            return L10n.F("world.character.perk", name, tier,
                L10n.T("world.character.perk.state." + state));
        }

        private static string ComposeFormationSlot(string name, string line, string detail)
        {
            string[] parts = detail.Split('|');
            string position = parts.Length > 0 ? parts[0] : "";
            bool selected = parts.Length > 1 && parts[1] == "1";
            string occupant = name.Length > 0 ? name : L10n.T("world.character.item.empty");
            string result = L10n.F("world.character.formation.slot",
                L10n.T("world.character.formation.line." + line), position, occupant);
            if (selected)
            {
                result += " " + L10n.T("world.character.formation.selected");
            }
            return name.Length > 0
                ? result + " " + L10n.T("world.character.formation.move.hint")
                : result;
        }

        private static string ComposeFormationSummary(string active, string detail)
        {
            string[] parts = detail.Split('|');
            string maximum = parts.Length > 0 ? parts[0] : "";
            string reserves = parts.Length > 1 ? parts[1] : "";
            return L10n.F("world.character.formation.summary", active, maximum, reserves);
        }

        private static string ComposeFormationMoveStarted(
            string name,
            string line,
            string position)
        {
            return L10n.F("world.character.formation.move.started",
                name, L10n.T("world.character.formation.line." + line), position);
        }

        private static string ComposeFormationTarget(string name, string line, string detail)
        {
            string[] parts = detail.Split('|');
            string position = parts.Length > 0 ? parts[0] : "";
            string source = parts.Length > 1 ? parts[1] : "";
            bool sameSlot = parts.Length > 2 && parts[2] == "1";
            string occupant = name.Length > 0 ? name : L10n.T("world.character.item.empty");
            string slot = L10n.F("world.character.formation.slot",
                L10n.T("world.character.formation.line." + line), position, occupant);
            return sameSlot
                ? L10n.F("world.character.formation.target.source", slot, source)
                : L10n.F("world.character.formation.target", slot, source);
        }

        private static string ComposeFormationMoveResult(
            string name,
            string line,
            string position)
        {
            return L10n.F("world.character.formation.result.move",
                name, L10n.T("world.character.formation.line." + line), position);
        }

        private static string ComposeFormationSwapResult(
            string source,
            string target,
            string detail)
        {
            string[] parts = detail.Split('|');
            string line = parts.Length > 0 ? parts[0] : "";
            string position = parts.Length > 1 ? parts[1] : "";
            return L10n.F("world.character.formation.result.swap",
                source, target, L10n.T("world.character.formation.line." + line), position);
        }

        private static string ComposeWorldCombatDialogScreen(string kind, string detail)
        {
            string[] fields = detail.Split('|');
            int count = fields.Length > 0 &&
                int.TryParse(fields[0], out int parsedCount) ? parsedCount : 0;
            bool formation = fields.Length > 1 && fields[1] == "1";
            bool canDisengage = fields.Length > 2 && fields[2] == "1";
            var parts = new List<string>
            {
                L10n.T("world.combat.dialog.title." + kind),
                count == 0
                    ? L10n.T("world.combat.dialog.report.unknown")
                    : count == 1
                        ? L10n.T("world.combat.dialog.report.one")
                        : L10n.F("world.combat.dialog.report.many", count)
            };
            if (formation)
                parts.Add(L10n.T("world.combat.dialog.formation.available"));
            parts.Add(L10n.T(canDisengage
                ? "world.combat.dialog.controls.retreat"
                : "world.combat.dialog.controls.forced"));
            return string.Join(" ", parts);
        }

        private static string ComposeWorldCombatDialogEnemy(
            string name,
            string index,
            string total)
        {
            return L10n.F("world.combat.dialog.enemy", index, total, name);
        }

        /// <summary>Compose an entry in a multi-tooltip sub-list. Squirrel packs
        /// detail as "total|parent-category"; the category remains useful to the JS
        /// tooltip filter but is deliberately not spoken. Put the position after
        /// the native rendered body, matching all other navigable list positions.</summary>
        private static string ComposeTooltipDetail(string text, string index, string detail)
        {
            string[] parts = detail.Split(new[] { '|' }, 2);
            string total = parts.Length > 0 ? parts[0] : "1";
            return L10n.F("tooltip.detail", text, index, total);
        }

        // Hex direction (0-5, from config/global.nut Const.Direction: N, NE, SE,
        // S, SW, NW) as a clock face read from the active man: N is 12 o'clock.
        private static readonly int[] ClockHours = { 12, 2, 4, 6, 8, 10 };

        /// <summary>Compose a tactical tile readout (phase 3.2). The Squirrel side
        /// sends only semantics — terrain as an enum integer, the occupant's
        /// already-localized game name, a packed
        /// "kind|distance|direction|hp|hpMax|mMorale" detail, the corpse name as its
        /// own JSON field (names are player-editable and may contain delimiters),
        /// and newline-separated names of the live items in tile.Items —
        /// so every spoken word here (terrain names, "ally"/"enemy", the
        /// clock position) stays in <see cref="L10n"/>. Kinds: "self", "ally",
        /// "enemy", anything else is empty. direction is -1 on the active man's
        /// own tile.</summary>
        private static string ComposeTileReadout(
            string terrain,
            string name,
            string detail,
            string corpseName,
            string extras,
            string groundItems,
            string weapon)
        {
            string[] parts = detail.Split('|');
            string kind = parts.Length > 0 ? parts[0] : "";
            string distText = parts.Length > 1 ? parts[1] : "0";
            string dirText = parts.Length > 2 ? parts[2] : "-1";
            string hpText = parts.Length > 3 ? parts[3] : "";
            string hpMaxText = parts.Length > 4 ? parts[4] : "";
            string moraleText = parts.Length > 5
                && parts[5].StartsWith("m", StringComparison.Ordinal)
                    ? parts[5].Substring(1)
                    : "";
            string terrainText = L10n.T("tile.terrain." + terrain);
            string occupant = kind switch
            {
                "self" => L10n.F("tile.self", name),
                "ally" => L10n.F("tile.ally", name),
                "enemy" => L10n.F("tile.enemy", EnemyWithWeapon(name, weapon)),
                "object" => L10n.F("tile.object", name),
                _ => L10n.T("tile.empty"),
            };

            // Health clause, only for an actor (empty for scenery/empty tiles), spoken
            // right after the occupant name.
            if ((kind == "self" || kind == "ally" || kind == "enemy") && hpText.Length > 0)
                occupant += ", " + L10n.F("tile.health", hpText, hpMaxText);
            if ((kind == "self" || kind == "ally" || kind == "enemy")
                && moraleText.Length > 0)
                occupant += ", " + L10n.F("tile.morale",
                    L10n.T("combat.morale." + moraleText));

            string position = ComposePosition(distText, dirText);
            string readout = terrainText + ". " + occupant + ".";
            // Height leads the readout instead of trailing it: it is a property of the
            // ground, heard in the same breath as the terrain, and the answer to "is
            // this the hex I want" starts with it. The other two extras stay at the
            // end, where they do not delay the words the player navigates by.
            string elevation = ComposeTileElevation(extras);
            if (elevation.Length > 0) readout = elevation + " " + readout;
            if (corpseName.Length > 0)
                readout += " " + L10n.F("tile.corpse", corpseName) + ".";
            string ground = ComposeTileGroundItems(groundItems);
            if (ground.Length > 0) readout += " " + ground + ".";
            if (position.Length > 0)
                readout += " " + position + ".";

            // With a skill armed the Squirrel side packs two extra fields: whether
            // the tile is a legal target ("1"/"0") and, for an attackable actor on
            // it, the hit chance (an int, or "-" when it does not apply).
            string target = ComposeTarget(parts);
            if (target.Length > 0) readout += " " + target;

            // Zone of control and movement cost close the readout, after everything it
            // already said. They are additions to a sweep the player already knows by
            // ear, so they must never delay the words he is listening for — he
            // interrupts through them, he does not wait for them.
            string more = ComposeTileExtras(extras);
            return more.Length > 0 ? readout + " " + more : readout;
        }

        /// <summary>Add an enemy's main-hand weapon without changing the name of
        /// an unarmed enemy. Both values are game-owned localized strings; only the
        /// connector is ours and therefore lives in L10n.</summary>
        private static string EnemyWithWeapon(string name, string weapon)
        {
            return weapon.Length > 0
                ? L10n.F("combat.enemy.with_weapon", name, weapon)
                : name;
        }

        /// <summary>Name the objects the engine currently renders on this hex and
        /// exposes as its ground inventory. Unlike Corpse.Items, these can be picked
        /// up during battle by an actor standing on the tile.</summary>
        private static string ComposeTileGroundItems(string packed)
        {
            if (string.IsNullOrEmpty(packed)) return "";

            var names = new List<string>();
            foreach (string raw in packed.Split('\n'))
            {
                string name = raw.TrimEnd('\r');
                if (name.Length > 0) names.Add(name);
            }

            if (names.Count == 0) return "";
            return names.Count == 1
                ? L10n.F("tile.ground.one", names[0])
                : L10n.F("tile.ground.many", JoinWithAnd(names));
        }

        /// <summary>The height clause that opens a tile readout. Relative to the
        /// active man and silent when level with him, which is the common case.
        /// </summary>
        private static string ComposeTileElevation(string extras)
        {
            if (string.IsNullOrEmpty(extras)) return "";

            string[] p = extras.Split('|');
            if (p.Length == 0 || !int.TryParse(p[0], out int elevation) || elevation == 0)
                return "";

            int levels = Math.Abs(elevation);
            return levels == 1
                ? L10n.T(elevation > 0 ? "tile.elevation.higher.one" : "tile.elevation.lower.one")
                : L10n.F(elevation > 0 ? "tile.elevation.higher" : "tile.elevation.lower", levels);
        }

        /// <summary>The two tactical facts that close a tile readout, packed by
        /// Squirrel as "elevation|zoneOfControl|kind[|ap|fatigue|complete]" (the
        /// elevation slot is read by <see cref="ComposeTileElevation"/> instead). The
        /// zone of control is silent when no enemy holds the tile; the movement clause
        /// is absent ("" kind) on the man's own tile, on an occupied tile and while a
        /// skill is armed, where the target preview already answers the question.
        /// </summary>
        private static string ComposeTileExtras(string extras)
        {
            if (string.IsNullOrEmpty(extras)) return "";

            string[] p = extras.Split('|');
            var parts = new List<string>();

            if (p.Length > 1 && int.TryParse(p[1], out int zoc) && zoc > 0)
            {
                parts.Add(zoc == 1 ? L10n.T("tile.zoc.one") : L10n.F("tile.zoc", zoc));
            }

            string kind = p.Length > 2 ? p[2] : "";
            if (kind == "none") parts.Add(L10n.T("tile.move.none"));
            else if (kind == "far") parts.Add(L10n.T("tile.move.far"));
            else if (kind == "cost")
            {
                string ap = p.Length > 3 ? p[3] : "0";
                string fatigue = p.Length > 4 ? p[4] : "0";
                bool complete = p.Length <= 5 || p[5] == "1";
                parts.Add(complete
                    ? L10n.F("tile.move.cost", ap, fatigue)
                    : L10n.F("tile.move.partial", ap, fatigue));
            }

            return string.Join(" ", parts);
        }

        /// <summary>The target-preview clause of a tile readout while a skill is
        /// armed (phase 3.3): empty when no skill is armed, otherwise "valid" /
        /// "not a valid target" and the hit chance when there is an actor to hit.
        /// New messages put morale at index 5 (marked with an m), then the target
        /// fields at 6/7. The fallback index keeps an older mod readable while the
        /// companion is being restarted during development.</summary>
        private static string ComposeTarget(string[] parts)
        {
            int targetIndex = parts.Length > 5
                && parts[5].StartsWith("m", StringComparison.Ordinal) ? 6 : 5;
            if (parts.Length <= targetIndex) return "";

            string targetable = parts[targetIndex];
            if (targetable == "0") return L10n.T("tile.target.invalid");
            if (targetable != "1") return "";

            string hitText = parts.Length > targetIndex + 1 ? parts[targetIndex + 1] : "-";
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

        /// <summary>Shorten only the vanilla hit-roll suffix while preserving the
        /// already-rendered combat sentence. Unrecognized lines pass through unchanged.</summary>
        private static string ComposeCombatLog(string text)
        {
            Match match = CombatRollSuffix.Match(text);
            if (!match.Success) return text;

            return text[..match.Index] + " " + L10n.F("combat.log.rolls",
                match.Groups[1].Value, match.Groups[2].Value);
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

        /// <summary>Compose the active man's terse live-resource readout: the T key.
        /// detail is "ap/apmax|fat/fatmax". V owns identity and the slower-changing
        /// combat facts, so T answers only what is spent repeatedly during a turn.</summary>
        private static string ComposeStatus(string detail)
        {
            string[] parts = detail.Split('|');
            (string cur, string max) Pair(int i)
            {
                if (i >= parts.Length) return ("0", "0");
                string[] p = parts[i].Split('/');
                return (p.Length > 0 ? p[0] : "0", p.Length > 1 ? p[1] : "0");
            }

            var (ap, apMax) = Pair(0);
            var (fat, fatMax) = Pair(1);

            return L10n.F("combat.status", ap, apMax, fat, fatMax);
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

        /// <summary>Compose the world-map step cue. <paramref name="terrain"/> is the
        /// tile type, sent only when it actually changed, and <paramref name="place"/>
        /// the settlement, camp or ruin standing on the tile, sent whenever there is
        /// one. They arrive together and are spoken as one utterance on purpose: as two
        /// messages the second would either cut the first off or be discarded by the
        /// next interrupt.</summary>
        private static string ComposeMoveStep(string place, string terrain, string detail)
        {
            string[] p = detail.Split('|');
            string spoken = terrain.Length > 0
                ? L10n.F("world.move.step", L10n.T("world.terrain." + terrain))
                : string.Empty;

            // Crossing onto or off a road or a river. Neither changes the terrain type, so
            // this is the only thing that reports it while marching; it sits between the
            // terrain and the place for the same reason height opens a tactical tile — it
            // is a property of the ground underfoot.
            string paths = ComposePaths(p.Length > 1 ? p[1] : "", moving: true);
            if (paths.Length > 0)
                spoken = spoken.Length > 0 ? spoken + " " + paths : paths;

            return AppendPlace(spoken, place, p.Length > 0 ? p[0] : "");
        }

        /// <summary>As <see cref="ComposeMoveStep"/> for the cue that ends a movement
        /// order. The terrain is always present here; it deliberately repeats what the
        /// step cue just said, since this one interrupts it.</summary>
        private static string ComposeMoveStopped(string place, string terrain, string kind)
        {
            string spoken = L10n.F("world.move.stopped", L10n.T("world.terrain." + terrain));
            return AppendPlace(spoken, place, kind);
        }

        /// <summary>Append the name of the place occupying the tile, if any. Landmarks
        /// say so, because standing on one is not an opportunity to do anything.</summary>
        private static string AppendPlace(string spoken, string place, string kind)
        {
            if (place.Length == 0) return spoken;
            string named = kind == "landmark"
                ? L10n.F("world.move.passing.landmark", place)
                : L10n.F("world.move.passing", place);
            return spoken.Length > 0 ? spoken + " " + named : named;
        }

        /// <summary>Split a packed "dist|dir" pair and word it as a position, so the
        /// clock vocabulary of the tactical readout serves the map cursor too.</summary>
        private static string PackedPosition(string detail)
        {
            string[] p = detail.Split('|');
            return ComposePosition(p.Length > 0 ? p[0] : "0", p.Length > 1 ? p[1] : "-1");
        }

        /// <summary>Name a world tile's terrain, marking a tile the company has never
        /// come near. The flag is not decoration: vanilla refuses to route through
        /// unexplored ground and marches in a straight line instead, so knowing a tile
        /// is still dark tells the player how travelling there will behave.</summary>
        private static string TerrainWord(string terrain, bool fog)
        {
            string name = L10n.T("world.terrain." + terrain);
            return fog ? L10n.F("world.terrain.unexplored", name) : name;
        }

        /// <summary>Name a place the way the B survey names it, without the trailing
        /// stop, so the same wording can end a sentence or sit inside one.</summary>
        private static string ComposeCursorPlace(string name, string kind)
        {
            return kind switch
            {
                "settlement" => L10n.F("world.survey.item.settlement", name),
                "landmark" => L10n.F("world.survey.item.landmark", name),
                _ => L10n.F("world.survey.item.location", name),
            };
        }

        /// <summary>Name a kind of footprint. With a Lookout hired the game itself puts
        /// the exact party type in words, and only then; without him a sighted player
        /// still reads the sprite, of which there are only four — men, greenskins, beasts
        /// and undead — so that is exactly what the family table holds.</summary>
        private static string TrackName(string type, bool lookout)
        {
            return L10n.T((lookout ? "world.footprints.exact." : "world.footprints.family.")
                + type);
        }

        /// <summary>Join names as "a", "a and b", "a, b and c".</summary>
        private static string JoinWithAnd(List<string> names)
        {
            if (names.Count == 0) return "";
            if (names.Count == 1) return names[0];
            return L10n.F("list.and",
                string.Join(", ", names.GetRange(0, names.Count - 1)), names[^1]);
        }

        /// <summary>Word the footprints crossing a tile. packed holds ';'-separated
        /// "type:dirs" entries, dirs being the hex directions that trail runs. An empty
        /// list after the colon means the trail continues into no neighbouring tile,
        /// which is said out loud rather than left silent. A bare type with no colon is
        /// only produced by mod versions older than this companion; it degrades to the
        /// collapsed names alone instead of inventing headings.
        ///
        /// Several exact types share one family word (brigands and nomads are both
        /// simply men on the map), so entries are merged by the word they produce and
        /// their directions unioned; otherwise the same family would be announced twice.
        /// </summary>
        private static string ComposeCursorTracks(string packed, bool lookout)
        {
            if (packed.Length == 0) return "";

            bool detailed = packed.Contains(':');
            var names = new List<string>();
            var dirsByName = new Dictionary<string, List<int>>();

            foreach (string entry in packed.Split(';'))
            {
                if (entry.Length == 0) continue;
                string[] e = entry.Split(':', 2);
                string name = TrackName(e[0], lookout);
                if (!dirsByName.ContainsKey(name))
                {
                    names.Add(name);
                    dirsByName[name] = new List<int>();
                }
                if (e.Length < 2) continue;
                foreach (string d in e[1].Split(','))
                {
                    if (int.TryParse(d, out int dir) && dir >= 0 && dir < ClockHours.Length
                        && !dirsByName[name].Contains(dir))
                        dirsByName[name].Add(dir);
                }
            }

            if (names.Count == 0) return "";
            if (!detailed) return L10n.F("world.cursor.tracks", JoinWithAnd(names));

            var parts = new List<string>();
            foreach (string name in names)
            {
                string spoken = L10n.F("world.cursor.tracks", name);
                var hours = dirsByName[name].ConvertAll(
                    d => L10n.F("world.cursor.trail.hour", ClockHours[d]));
                parts.Add(hours.Count == 0
                    ? spoken + " " + L10n.T("world.cursor.trail.none")
                    : spoken + " " + L10n.F("world.cursor.trail", JoinWithAnd(hours)));
            }
            return string.Join(" ", parts);
        }

        /// <summary>Word the roads and rivers of a tile. packed holds ';'-separated
        /// "kind:state:dirs" entries — kind road or river, state "on" for a feature the
        /// tile carries, "near" for one only a neighbour carries, "off" for one just left
        /// behind while marching — and dirs the hex directions it runs, read as clock
        /// hours the way a footprint trail is. An "on" entry with no directions is a road
        /// that ends on this tile, which is said rather than left silent: it is the
        /// difference between a junction and a dead end.
        ///
        /// <paramref name="moving"/> picks the wording for a company crossing onto one
        /// rather than a cursor describing one. <paramref name="withEffect"/> adds what
        /// the feature does to travel speed, and is used only by the V list, the one
        /// surface built to take a single fact at a time.</summary>
        private static string ComposePaths(string packed, bool moving, bool withEffect = false)
        {
            if (packed.Length == 0) return "";

            var parts = new List<string>();
            foreach (string entry in packed.Split(';'))
            {
                if (entry.Length == 0) continue;
                string[] e = entry.Split(':', 3);
                if (e.Length < 2) continue;

                string kind = e[0];
                if (kind != "road" && kind != "river") continue;
                string state = e[1];

                if (state == "off")
                {
                    parts.Add(L10n.T("world.path." + kind + ".left"));
                    continue;
                }

                var hours = new List<string>();
                foreach (string d in (e.Length > 2 ? e[2] : "").Split(','))
                {
                    if (int.TryParse(d, out int dir) && dir >= 0 && dir < ClockHours.Length)
                        hours.Add(L10n.F("world.cursor.trail.hour", ClockHours[dir]));
                }

                string spoken;
                if (state == "near")
                {
                    // A neighbouring road with no direction would be a claim with nothing
                    // behind it; the tile itself carries none, so there is nothing to say.
                    if (hours.Count == 0) continue;
                    spoken = L10n.F("world.path." + kind + ".near", JoinWithAnd(hours));
                }
                else
                {
                    string stem = moving ? ".entered" : ".on";
                    spoken = hours.Count == 0
                        ? L10n.T("world.path." + kind + stem + ".end")
                        : L10n.F("world.path." + kind + stem, JoinWithAnd(hours));
                }

                if (withEffect) spoken += " " + L10n.T("world.path." + kind + ".effect");
                parts.Add(spoken);
            }

            return string.Join(" ", parts);
        }

        /// <summary>Word the parties standing on the cursor tile: the nearest one by
        /// name and kind, and a count for the rest. Squirrel packs "count,kind,name"
        /// with the name last, so a comma inside a party name is harmless.</summary>
        private static string ComposeCursorParties(string packed)
        {
            if (packed.Length == 0) return "";

            string[] p = packed.Split(',', 3);
            if (p.Length < 3 || !int.TryParse(p[0], out int count) || count <= 0) return "";

            string head = p[1] switch
            {
                "enemy" => L10n.F("world.survey.item.enemy", p[2]),
                "ally" => L10n.F("world.survey.item.ally", p[2]),
                _ => L10n.F("world.survey.item.neutral", p[2]),
            };
            if (count == 1) return head + ".";

            string more = count == 2
                ? L10n.T("world.cursor.parties.more.one")
                : L10n.F("world.cursor.parties.more", count - 1);
            return head + ". " + more;
        }

        /// <summary>Compose a map-explorer cursor readout (phase 4.6): everything the
        /// tile holds, as one utterance. Squirrel packs
        /// "fog|placeKind|self|parties|tracks|lookout" and sends the place name as its
        /// own field; only clauses with something to say are spoken, so an ordinary hex
        /// is just its terrain. The bearing is deliberately absent — Shift+X answers
        /// that on demand, and repeating it on every hex of a sweep is noise.</summary>
        private static string ComposeCursorTile(string place, string terrain, string detail,
            bool recentered)
        {
            string[] p = detail.Split('|');
            string At(int i) => i < p.Length ? p[i] : "";

            var parts = new List<string>();
            if (recentered) parts.Add(L10n.T("world.cursor.recentered"));
            parts.Add(TerrainWord(terrain, At(0) == "1") + ".");

            string paths = ComposePaths(At(6), moving: false);
            if (paths.Length > 0) parts.Add(paths);

            if (At(2) == "1") parts.Add(L10n.T("world.cursor.list.self"));
            if (place.Length > 0) parts.Add(ComposeCursorPlace(place, At(1)) + ".");

            string parties = ComposeCursorParties(At(3));
            if (parties.Length > 0) parts.Add(parties);

            string tracks = ComposeCursorTracks(At(4), At(5) == "1");
            if (tracks.Length > 0) parts.Add(tracks);

            return string.Join(" ", parts);
        }

        /// <summary>Compose the X readout on the plain map: the terrain the company
        /// stands on and, only when there are any, the footprints crossing that hex
        /// with the direction each trail runs. detail packs "tracks|lookout|paths". No fog
        /// clause — the company cannot be standing on an unexplored tile.</summary>
        private static string ComposeCursorHere(string terrain, string detail)
        {
            string[] p = detail.Split('|');
            string At(int i) => i < p.Length ? p[i] : "";

            var parts = new List<string> { TerrainWord(terrain, false) + "." };

            string paths = ComposePaths(At(2), moving: false);
            if (paths.Length > 0) parts.Add(paths);

            string tracks = ComposeCursorTracks(At(0), At(1) == "1");
            if (tracks.Length > 0) parts.Add(tracks);

            return string.Join(" ", parts);
        }

        /// <summary>Compose the confirmation for G, which sends the company to the
        /// cursor. detail packs "placeKind|dist|dir|fog"; the target is named by the
        /// place standing there when there is one, and by its terrain otherwise.
        /// </summary>
        private static string ComposeCursorTravel(string place, string terrain, string detail)
        {
            string[] p = detail.Split('|');
            string At(int i) => i < p.Length ? p[i] : "";

            string target = place.Length > 0
                ? ComposeCursorPlace(place, At(0))
                : TerrainWord(terrain, At(3) == "1");

            string spoken = L10n.F("world.cursor.travel", target);
            string position = ComposePosition(At(1), At(2));
            return position.Length > 0 ? spoken + " " + position + "." : spoken;
        }

        /// <summary>Compose the cursor tile list header: where the tile is relative to
        /// the company, how many rows it has, and the controls.</summary>
        private static string ComposeCursorListScreen(string countText, string detail)
        {
            string position = PackedPosition(detail);
            string where = position.Length > 0
                ? L10n.F("world.cursor.list.where", position)
                : L10n.T("world.cursor.list.where.here");
            return L10n.F("world.cursor.list.screen", where, countText);
        }

        private static string ComposeCursorTerrainRow(string terrain, string fog)
        {
            return L10n.F("world.cursor.list.terrain", TerrainWord(terrain, fog == "1"));
        }

        /// <summary>Compose one footprint row of the cursor tile list: the kind of
        /// prints and, reconstructed from the neighbouring tiles, where the trail runs.
        /// detail packs "dirs|lookout", dirs being hex directions read as clock hours.
        /// This is what makes a trail followable: two of them usually answer where it
        /// came from and where it went.</summary>
        private static string ComposeCursorTracksRow(string type, string detail)
        {
            string[] p = detail.Split('|');
            string dirs = p.Length > 0 ? p[0] : "";
            string spoken = L10n.F("world.cursor.tracks",
                TrackName(type, p.Length > 1 && p[1] == "1"));

            var hours = new List<string>();
            foreach (string d in dirs.Split(','))
            {
                if (int.TryParse(d, out int dir) && dir >= 0 && dir < ClockHours.Length)
                    hours.Add(L10n.F("world.cursor.trail.hour", ClockHours[dir]));
            }

            return hours.Count == 0
                ? spoken + " " + L10n.T("world.cursor.trail.none")
                : spoken + " " + L10n.F("world.cursor.trail", JoinWithAnd(hours));
        }

        /// <summary>Compose Shift+F's footprint overview. The Squirrel side packs
        /// "here|north,northeast,southeast,south,southwest,northwest" counts, using
        /// the same 0-5 direction order as every world hex. Each count is a live
        /// footprint type on one visible tile; malformed or empty input safely
        /// degrades to the no-tracks result.</summary>
        private static string ComposeTracksSummary(string packed)
        {
            string[] fields = packed.Split('|', 2);
            int.TryParse(fields.Length > 0 ? fields[0] : "", out int here);
            string[] counts = fields.Length > 1 ? fields[1].Split(',') : Array.Empty<string>();
            var parts = new List<string>();

            if (here > 0)
            {
                parts.Add(here == 1
                    ? L10n.T("world.tracks.here.one")
                    : L10n.F("world.tracks.here.many", here));
            }

            for (int dir = 0; dir < ClockHours.Length && dir < counts.Length; dir++)
            {
                if (!int.TryParse(counts[dir], out int count) || count <= 0) continue;
                string direction = L10n.T("world.tracks.direction." + dir);
                parts.Add(count == 1
                    ? L10n.F("world.tracks.one", direction)
                    : L10n.F("world.tracks.many", count, direction));
            }

            return parts.Count == 0
                ? L10n.T("world.tracks.none")
                : L10n.F("world.tracks.summary", JoinWithAnd(parts));
        }

        /// <summary>Compose Shift+R's road overview. The packed shape and direction
        /// order are deliberately identical to Shift+F; each directional count is one
        /// discovered road hex inside the company's current vision circle.</summary>
        private static string ComposeRoadsSummary(string packed)
        {
            string[] fields = packed.Split('|', 2);
            int.TryParse(fields.Length > 0 ? fields[0] : "", out int here);
            string[] counts = fields.Length > 1 ? fields[1].Split(',') : Array.Empty<string>();
            var parts = new List<string>();

            if (here > 0)
                parts.Add(L10n.T("world.roads.here"));

            for (int dir = 0; dir < ClockHours.Length && dir < counts.Length; dir++)
            {
                if (!int.TryParse(counts[dir], out int count) || count <= 0) continue;
                string direction = L10n.T("world.tracks.direction." + dir);
                parts.Add(count == 1
                    ? L10n.F("world.roads.one", direction)
                    : L10n.F("world.roads.many", count, direction));
            }

            return parts.Count == 0
                ? L10n.T("world.roads.none")
                : L10n.F("world.roads.summary", JoinWithAnd(parts));
        }

        /// <summary>Compose the static-place explorer header. B starts on settlements;
        /// Page Up/Down cycle <paramref name="section"/> through locations and landmarks.
        /// The landmark category carries an extra note: its entries are travel targets,
        /// but unlike settlements and locations they cannot be entered.</summary>
        private static string ComposeSurveyPlacesScreen(string section, string countText)
        {
            string label = L10n.T("world.survey.section." + section);
            string spoken = L10n.F("world.survey.places.screen", label, countText);
            if (section == "landmarks")
                spoken += " " + L10n.T("world.survey.section.landmarks.note");
            return spoken;
        }

        /// <summary>Compose the visible-party explorer header opened with Shift+B.
        /// The empty case is announced directly by Squirrel and never opens a list.</summary>
        private static string ComposeSurveyPartiesScreen(string countText)
        {
            return L10n.F("world.survey.parties.screen", countText);
        }

        /// <summary>Compose one survey entry (phase 4.3). texto is the entity's already-
        /// localized game name; valor is the kind (ally/enemy/neutral party, settlement,
        /// location, landmark); detalle is the "dist|dir" pair shared with the tactical
        /// tile readout, so <see cref="ComposePosition"/> is reused for "3 tiles, 2
        /// o'clock". Landmarks get their own approach-only action hint because travelling
        /// to one does not attempt to enter it.</summary>
        private static string ComposeSurveyItem(string name, string kind, string detail)
        {
            string[] p = detail.Split('|');
            string dist = p.Length > 0 ? p[0] : "0";
            string dir = p.Length > 1 ? p[1] : "-1";
            // Only settlements carry a fourth token: the owning faction, which the map
            // draws as the banner beside them. Empty for everything else.
            string faction = p.Length > 2 ? p[2] : "";

            // The places screen already announces its category, so repeating
            // "Settlement", "Location" or "Landmark" on every row only delays the
            // useful part: the name. Party rows still need their kind because Shift+B
            // mixes enemies, allies and neutral parties in a single list.
            string head = kind switch
            {
                "enemy" => L10n.F("world.survey.item.enemy", name),
                "ally" => L10n.F("world.survey.item.ally", name),
                "neutral" => L10n.F("world.survey.item.neutral", name),
                "settlement" => faction.Length > 0
                    ? L10n.F("world.survey.item.settlement.owned.in_category", name, faction)
                    : name,
                "landmark" => name,
                _ => name,
            };

            // A location on the player's own tile (a Battle Site where he stands, say)
            // has distance 0, for which ComposePosition is empty; call that out as
            // "at your position" instead of dropping the clause and reading no location.
            string position = ComposePosition(dist, dir);
            if (position.Length == 0 && dist == "0")
                position = L10n.T("world.survey.here");

            string action = kind switch
            {
                "enemy" => L10n.T("world.survey.action.enemy"),
                "settlement" or "location" => L10n.T("world.survey.action.place"),
                "landmark" => L10n.T("world.survey.action.landmark"),
                _ => string.Empty,
            };
            string spoken = position.Length > 0 ? head + ". " + position + "." : head + ".";
            return action.Length > 0 ? spoken + " " + action : spoken;
        }

        /// <summary>Compose what the day's settlement cost the company: how many men
        /// went hungry and how many went unpaid, packed as "hungry|unpaid". Only the
        /// non-zero halves are spoken; the message is not sent at all when both are.
        /// </summary>
        private static string ComposeUpkeepResult(string packed)
        {
            string[] p = packed.Split('|');
            var parts = new List<string>();

            if (p.Length > 0 && int.TryParse(p[0], out int hungry) && hungry > 0)
                parts.Add(hungry == 1
                    ? L10n.T("world.upkeep.hungry.one")
                    : L10n.F("world.upkeep.hungry", hungry));

            if (p.Length > 1 && int.TryParse(p[1], out int unpaid) && unpaid > 0)
                parts.Add(unpaid == 1
                    ? L10n.T("world.upkeep.unpaid.one")
                    : L10n.F("world.upkeep.unpaid", unpaid));

            return string.Join(" ", parts);
        }

        /// <summary>Compose the warning for the day ahead. food is the days of rations
        /// left, empty when there is nothing to warn about (or no upkeep at all); wages
        /// packs "needed|purse" and is empty when tomorrow's payroll is covered.</summary>
        private static string ComposeUpkeepWarning(string food, string wages)
        {
            var parts = new List<string>();

            if (food.Length > 0 && int.TryParse(food, out int days))
                parts.Add(days <= 0
                    ? L10n.T("world.upkeep.food.none")
                    : (days == 1 ? L10n.T("world.upkeep.food.one")
                                 : L10n.F("world.upkeep.food", days)));

            if (wages.Length > 0)
            {
                string[] w = wages.Split('|');
                parts.Add(L10n.F("world.upkeep.wages", w.Length > 0 ? w[0] : "0",
                    w.Length > 1 ? w[1] : "0"));
            }

            return string.Join(" ", parts);
        }

        /// <summary>Compose a threat proximity alert: a hostile party already in sight
        /// that has crossed a proximity band inwards. valor says which kind of crossing it
        /// was — "contact" for the innermost band, "closing" for the rest — rather than a
        /// band number, so moving the thresholds never reaches this side. Only the
        /// innermost changes the wording: the distance is spoken anyway, and the band's
        /// job is the tone, not a gradation the player could act on differently.</summary>
        private static string ComposeThreatClosing(string name, string band, string detail)
        {
            string[] p = detail.Split('|');
            string head = band == "contact"
                ? L10n.F("world.threat.contact", name)
                : L10n.F("world.threat.closing", name);

            string position = ComposePosition(p.Length > 0 ? p[0] : "0",
                p.Length > 1 ? p[1] : "-1");
            return position.Length > 0 ? head + " " + position + "." : head;
        }

        /// <summary>Compose an ambient discovery ping: a settlement, location, landmark
        /// or enemy party newly entering the player's sight while travelling, queued so
        /// it never cuts off another announcement. texto is the entity's already-
        /// localized name; valor is its kind; detalle is the shared "dist|dir" pair.
        /// Unlike <see cref="ComposeSurveyItem"/> this carries no action hint — it is a
        /// passing cue, not a row in an interactive list.</summary>
        private static string ComposeDiscoverySighting(string name, string kind, string detail)
        {
            string[] p = detail.Split('|');
            string dist = p.Length > 0 ? p[0] : "0";
            string dir = p.Length > 1 ? p[1] : "-1";

            string head = kind switch
            {
                "enemy" => L10n.F("world.discovery.enemy", name),
                "settlement" => L10n.F("world.discovery.settlement", name),
                "landmark" => L10n.F("world.discovery.landmark", name),
                _ => L10n.F("world.discovery.location", name),
            };

            string position = ComposePosition(dist, dir);
            if (position.Length == 0 && dist == "0")
                position = L10n.T("world.survey.here");

            // Full stop between the sighting and where it is, not a space: the position
            // is itself a comma phrase ("3 tiles, 10 o'clock"), so running the two
            // together gave one long unpunctuated line that a screen reader reads flat.
            return position.Length > 0 ? head + ". " + position + "." : head + ".";
        }

        /// <summary>Compose the short count used when several sightings land in the same
        /// scan (fast travel, arriving near a cluster) — read as one queued line instead
        /// of a full row per sighting; the detail is one B/Shift+B press away. detalle
        /// packs "places|enemies", places covering settlements, locations and
        /// landmarks together since none of them carries a hostility distinction.</summary>
        private static string ComposeDiscoverySummary(string detail)
        {
            string[] p = detail.Split('|');
            int.TryParse(p.Length > 0 ? p[0] : "0", out int places);
            int.TryParse(p.Length > 1 ? p[1] : "0", out int enemies);

            var parts = new List<string>();
            if (places > 0)
                parts.Add(places == 1
                    ? L10n.T("world.discovery.summary.places.one")
                    : L10n.F("world.discovery.summary.places", places));
            if (enemies > 0)
                parts.Add(enemies == 1
                    ? L10n.T("world.discovery.summary.enemies.one")
                    : L10n.F("world.discovery.summary.enemies", enemies));

            return L10n.F("world.discovery.summary", JoinWithAnd(parts));
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
        /// text is newline-separated "distance TAB name TAB weapon" entries,
        /// nearest first; valor is the count. The old space-separated shape remains
        /// readable during development while the game and companion restart.</summary>
        private static string ComposeEnemies(string text, string countText)
        {
            var entries = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length == 0) continue;
                string dist;
                string name;
                string weapon = "";
                string[] fields = line.Split('\t');
                if (fields.Length >= 2)
                {
                    dist = fields[0];
                    name = fields[1];
                    if (fields.Length > 2) weapon = fields[2];
                }
                else
                {
                    int sp = line.IndexOf(' ');
                    if (sp <= 0) continue;
                    dist = line.Substring(0, sp);
                    name = line.Substring(sp + 1);
                }
                name = EnemyWithWeapon(name, weapon);
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
        /// separated "name\tweapon\tdirection" rows, where direction is the same
        /// 0-5 hex bearing used by the tactical cursor; valor is the count.</summary>
        private static string ComposeEngaged(string text, string countText)
        {
            var entries = new System.Collections.Generic.List<string>();
            foreach (string line in text.Split('\n'))
            {
                if (line.Length == 0) continue;
                string[] fields = line.Split('\t');
                string name = fields[0];
                string weapon = fields.Length > 2 ? fields[1] : "";
                int directionIndex = fields.Length > 2 ? 2 : 1;
                name = EnemyWithWeapon(name, weapon);
                if (fields.Length > directionIndex
                    && int.TryParse(fields[directionIndex], out int dir)
                    && dir >= 0
                    && dir < ClockHours.Length)
                {
                    entries.Add(L10n.F("combat.engaged.entry", name, ClockHours[dir]));
                }
                else
                {
                    // Keep old messages readable if the mod and companion are
                    // momentarily on different versions during development.
                    entries.Add(name);
                }
            }

            string list = string.Join(", ", entries);
            return countText == "1"
                ? L10n.F("combat.engaged.one", list)
                : L10n.F("combat.engaged", countText, list);
        }

        /// <summary>Compose the active man's skills readout (Shift+S): the numbered
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
        /// For the full case detail packs "kind|level|timing|hp|hpMax|armHead|
        /// armHeadMax|armBody|armBodyMax|equipment|morale|effects". Equipment and
        /// effects are newline-separated lists of game-owned names (possibly empty).
        /// The corpse name is a separate JSON field because character names are
        /// player-editable and may contain the packed detail delimiter.</summary>
        private static string ComposeInspect(
            string name, string valor, string detail, string corpseName, string weapon)
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
                _ => L10n.F("combat.inspect.header.enemy",
                    EnemyWithWeapon(name, weapon), At(1)),
            };

            string morale = L10n.T("combat.morale." + At(10));
            string body = L10n.F("combat.inspect.body",
                At(3), At(4), At(5), At(6), At(7), At(8), morale);
            string equipment = JoinNames(At(9));
            string equipmentText = equipment.Length > 0
                ? L10n.F("combat.sheet.equipment", equipment)
                : L10n.T("combat.sheet.equipment.none");

            string timing = At(2) switch
            {
                "now" => L10n.T("combat.inspect.timing.now"),
                "done" => L10n.T("combat.inspect.timing.done"),
                "1" => L10n.T("combat.inspect.timing.turns.one"),
                "none" => "",
                "" => "",
                string t => L10n.F("combat.inspect.timing.turns", t),
            };

            string result = header + " " + body + " " + equipmentText;
            if (timing.Length > 0) result += " " + timing;

            string effects = JoinNames(At(11));
            if (effects.Length > 0) result += " " + L10n.F("combat.inspect.effects", effects);
            if (corpseName.Length > 0)
                result += " " + L10n.F("combat.inspect.corpse", corpseName);

            return result;
        }

        /// <summary>Shift+D uses the same four values and arithmetic as the visible
        /// character sheet. The mod packs armor damage, head-hit chance and vision
        /// in detail; an empty damage minimum means the unit is unarmed.</summary>
        private static string ComposeInspectStats(string damageMin, string damageMax,
            string detail)
        {
            string[] p = detail.Split('|');
            string armorDamage = p.Length > 0 ? p[0] : "0";
            string headHit = p.Length > 1 ? p[1] : "0";
            string vision = p.Length > 2 ? p[2] : "0";

            string damage = damageMin.Length > 0 && damageMax.Length > 0
                ? L10n.F("combat.sheet.damage", "", damageMin, damageMax)
                : L10n.T("combat.sheet.damage.none");
            return damage + " "
                + L10n.F("combat.sheet.armordamage", "", armorDamage) + " "
                + L10n.F("combat.sheet.headhit", "", headHit) + " "
                + L10n.F("combat.sheet.vision", "", vision);
        }

        /// <summary>Shift+A always names the first two physical bag slots, including
        /// empty ones, so the listener can distinguish which position holds an item.</summary>
        private static string ComposeInspectBags(string bag1, string bag2)
        {
            string empty = L10n.T("world.character.item.empty");
            return L10n.F("combat.inspect.bags",
                bag1.Length > 0 ? bag1 : empty,
                bag2.Length > 0 ? bag2 : empty);
        }

        /// <summary>Shift+W reads body then head armor. Item names come from the
        /// worn slots, while current/max values come from the actor so damage and
        /// non-item natural armor remain accurate.</summary>
        private static string ComposeInspectArmor(string bodyName, string headName,
            string detail)
        {
            string[] p = detail.Split('|');
            string bodyCurrent = p.Length > 0 ? p[0] : "0";
            string bodyMax = p.Length > 1 ? p[1] : "0";
            string headCurrent = p.Length > 2 ? p[2] : "0";
            string headMax = p.Length > 3 ? p[3] : "0";

            string ArmorName(string name, string maximum)
            {
                if (name.Length > 0) return name;
                return maximum != "0"
                    ? L10n.T("combat.inspect.armor.natural")
                    : L10n.T("combat.inspect.armor.none");
            }

            return L10n.F("combat.inspect.armor.body",
                    ArmorName(bodyName, bodyMax), bodyCurrent, bodyMax)
                + " " + L10n.F("combat.inspect.armor.head",
                    ArmorName(headName, headMax), headCurrent, headMax);
        }

        /// <summary>Shift+T reads the native turn-timing state and current fatigue
        /// for the combatant under the cursor. Timing uses the same phrases as V.</summary>
        private static string ComposeInspectTurn(string name, string timing,
            string detail, string weapon)
        {
            string timingText = timing switch
            {
                "now" => L10n.T("combat.inspect.timing.now"),
                "done" => L10n.T("combat.inspect.timing.done"),
                "1" => L10n.T("combat.inspect.timing.turns.one"),
                "none" or "" => L10n.T("combat.inspect.timing.unavailable"),
                _ => L10n.F("combat.inspect.timing.turns", timing),
            };

            string[] p = detail.Split('|');
            string current = p.Length > 0 ? p[0] : "0";
            string maximum = p.Length > 1 ? p[1] : "0";
            string fatigue = L10n.F("combat.inspect.turn.fatigue", current, maximum);
            return L10n.F("combat.inspect.turn",
                EnemyWithWeapon(name, weapon), timingText, fatigue);
        }

        /// <summary>Compose the character sheet's active-skills entry. text is
        /// newline-separated "name\tap\tfatigue" lines; count is in valor. Unlike the
        /// Shift+S readout there is no slot number or usability flag — this is any
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

        /// <summary>Compose one loot row on the post-combat screen. detail packs
        /// "index|total|condition|conditionMax|value|amount"; condition is empty for
        /// items that do not degrade, so durability is only spoken when it exists.
        /// The category text comes from the game itself and is spoken verbatim.</summary>
        private static string ComposeResultLootItem(string name, string category, string detail)
        {
            string[] p = detail.Split('|');
            string index = p.Length > 0 ? p[0] : "1";
            string total = p.Length > 1 ? p[1] : "1";
            string condition = p.Length > 2 ? p[2] : "";
            string conditionMax = p.Length > 3 ? p[3] : "";
            string value = p.Length > 4 ? p[4] : "";
            string amount = p.Length > 5 ? p[5] : "";

            string result = L10n.F("combat.result.loot.item",
                WithItemAmount(name, amount), category);
            if (condition.Length > 0 && conditionMax.Length > 0)
                result += " " + L10n.F("combat.result.loot.item.condition", condition, conditionMax);
            if (value.Length > 0 && value != "0")
                result += " " + L10n.F("combat.result.loot.item.value", value);
            result += " " + L10n.F("combat.result.loot.item.position", index, total);
            return result + " " + L10n.T("combat.result.loot.item.take");
        }
    }
}

// The Unseen Banner — accessibility mod for blind players.
// Preload: registers the mod with Modern Hooks and wires the smoke test
// for phase 0.2 (trivial Squirrel hook + trivial injected JS).

::UnseenBanner <- {
	ID = "mod_unseen_banner",
	Name = "The Unseen Banner",
	Version = "0.1.0",
	Mod = null,
	JSConnection = null,
	MenuNav = null,
	EventNav = null,
	TileCursor = null,
	CombatLog = null,
	Combat = null,
	Readout = null,
	CombatResult = null,
	SheetNav = null
};

::UnseenBanner.Mod = ::Hooks.register(::UnseenBanner.ID, ::UnseenBanner.Version, ::UnseenBanner.Name);
::UnseenBanner.Mod.require("mod_modern_hooks >= 0.6.0");

::Hooks.registerJS("ui/mods/mod_unseen_banner/smoke_test.js");
::Hooks.registerJS("ui/mods/mod_unseen_banner/menu_nav.js");
::Hooks.registerJS("ui/mods/mod_unseen_banner/event_nav.js");
::Hooks.registerCSS("ui/mods/mod_unseen_banner/menu_nav.css");

// Single choke point for every message sent to the companion app, so the
// bridge protocol (docs/arquitectura-propuesta-y-roadmap.md, "Protocolo de
// mensajes") is encoded in exactly one place instead of once per hook.
// Plan B bridge (tarea 0.4): written via ::logInfo into log.html, which the
// companion tails and parses looking for this marker.
::UnseenBanner.jsonEscape <- function(_s)
{
	local out = "";
	local n = _s.len();
	for (local i = 0; i < n; i += 1)
	{
		local ch = _s.slice(i, i + 1);
		if (ch == "\"") out += "\\\"";
		else if (ch == "\\") out += "\\\\";
		else if (ch == "\n") out += "\\n";
		else if (ch == "\r") out += "\\r";
		else if (ch == "\t") out += "\\t";
		else out += ch;
	}
	return out;
}

::UnseenBanner.sendMessage <- function(_canal, _texto, _categoria = null, _valor = null, _detalle = null, _hermano = null)
{
	local json = "{\"canal\":\"" + ::UnseenBanner.jsonEscape(_canal) + "\",\"texto\":\"" + ::UnseenBanner.jsonEscape(_texto) + "\"";
	if (_categoria != null) json += ",\"categoria\":\"" + ::UnseenBanner.jsonEscape(_categoria) + "\"";
	if (_valor != null) json += ",\"valor\":\"" + ::UnseenBanner.jsonEscape(_valor) + "\"";
	if (_detalle != null) json += ",\"detalle\":\"" + ::UnseenBanner.jsonEscape(_detalle) + "\"";
	if (_hermano != null) json += ",\"hermano\":\"" + ::UnseenBanner.jsonEscape(_hermano) + "\"";
	json += "}";
	::logInfo("UB_MSG:" + json);
}

::logInfo("UnseenBanner: preload executed (Squirrel layer alive).");

::UnseenBanner.Mod.queue(function() {
	::logInfo("UnseenBanner: queued function executed (Modern Hooks queue alive).");
});

// JS -> Squirrel bridge for the smoke test: the injected JS registers a fake
// screen named UnseenBannerConnection and calls onJSLoaded() once connected.
::UnseenBanner.JSConnection = {
	m = {
		JSHandle = null
	},
	function connect()
	{
		this.m.JSHandle = ::UI.connect("UnseenBannerConnection", this);
	},
	function onJSLoaded()
	{
		::logInfo("UnseenBanner: injected JS is alive and reached Squirrel (JS -> SQ round-trip OK).");
	}
};

// Main-menu keyboard cursor (first real feature). The engine does NOT
// forward raw keyboard to Coherent's DOM (verified live: document keydown
// never fires; the game's own states receive keys via onKeyInput instead),
// so the flow is: engine key -> our onKeyInput hook below -> asyncCall into
// menu_nav.js, which moves a cursor over the visible menu's buttons and
// reports the focused button's rendered label back here; we forward it to
// the companion on the interrupt channel (CLAUDE.md: "Interrupt... para
// navegación de foco/cursor").
::UnseenBanner.MenuNav = {
	m = {
		JSHandle = null,
		ActiveModule = null
	},
	// The menu modules this cursor drives across every surface that hosts them: the
	// main menu (main_menu_state) and the world/tactical pause menus. OptionsMenuModule
	// itself is shared by all three. Every one inherits ui_module, so the ui_module
	// hook below already reports them here by ID — activeness is just "one of these is
	// fully shown", regardless of which state hosts it.
	RecognizedModules = {
		MainMenuModule = true,
		NewCampaignModule = true,
		LoadCampaignModule = true,
		SaveCampaignModule = true,
		OptionsMenuModule = true
	},
	function connect()
	{
		this.m.JSHandle = ::UI.connect("UnseenBannerMenuNav", this);
	},
	function sendKey(_name)
	{
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onKeyForwarded", _name);
		}
	},
	function isActive()
	{
		return this.m.ActiveModule != null;
	},
	function handlesKey(_code)
	{
		return _code in ::UnseenBanner.KeyCodes
			|| (this.m.ActiveModule == "OptionsMenuModule"
				&& _code in ::UnseenBanner.OptionsKeyCodes);
	},
	function getKeyName(_code)
	{
		if (_code in ::UnseenBanner.KeyCodes)
		{
			return ::UnseenBanner.KeyCodes[_code];
		}
		return ::UnseenBanner.OptionsKeyCodes[_code];
	},
	// Called from a state hook when the surface itself goes away, so a stale module
	// never keeps the cursor "active" after the screen is gone.
	function reset()
	{
		this.m.ActiveModule = null;
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onStateExited", null);
		}
	},
	function onModuleShown(_id)
	{
		if (_id in this.RecognizedModules)
		{
			this.m.ActiveModule = _id;
			if (this.m.JSHandle != null)
			{
				this.m.JSHandle.asyncCall("onModuleShown", _id);
			}
		}
	},
	function onModuleHidden(_id)
	{
		// Modules that animate together (e.g. main menu sliding out as a submenu
		// slides in) each report their hide; only the one still marked active clears
		// the state, so the incoming module's onModuleShown is not undone.
		if (this.m.ActiveModule == _id)
		{
			this.m.ActiveModule = null;
		}
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onModuleHidden", _id);
		}
	},
	// Receives a single table from JS (SQ.call only carries one args value).
	function onMenuAnnouncement(_data)
	{
		::UnseenBanner.sendMessage("interrupt", _data.texto, _data.categoria, _data.valor, _data.detalle);
	}
};

// World event screen (phase 1.1): reads the event's title and body when it
// appears and adds an Up/Down/Enter cursor over its option buttons. The screen
// lives inside world_state; keys are stolen from that state's onKeyInput (see
// the hook below) and forwarded to event_nav.js. The engine's native number
// keys 1-6 keep selecting buttons directly, untouched.
::UnseenBanner.EventNav = {
	m = {
		JSHandle = null,
		Active = false
	},
	function connect()
	{
		this.m.JSHandle = ::UI.connect("UnseenBannerEventNav", this);
	},
	function isActive()
	{
		return this.m.Active;
	},
	function sendKey(_name)
	{
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onKeyForwarded", _name);
		}
	},
	function onEventShown()
	{
		this.m.Active = true;
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onEventShown", null);
		}
	},
	function onEventHidden()
	{
		this.m.Active = false;
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onEventHidden", null);
		}
	},
	// Receives a single table from JS (SQ.call only carries one args value).
	// Interrupt channel: the event screen is modal, so its narration takes
	// over from whatever was being said, exactly like the menu screen.
	function onEventAnnouncement(_data)
	{
		::UnseenBanner.sendMessage("interrupt", _data.texto, _data.categoria, _data.valor, _data.detalle);
	}
};

// World-map company/campaign readout (phase 4.4). A single key speaks the party
// status that the map's topbar shows a sighted player: the day and time of day,
// how many brothers, money and daily wages, food and how many days it lasts, and
// the active contract. Pull, not push: nothing narrates until the key is pressed.
// Every fact is a Squirrel API (World.Assets / World.getTime / World.Contracts /
// the player roster), so nothing is scraped from the DOM; the companion owns the
// framing words. Driven from world_state.onKeyInput (see the hook below), only on
// the plain map (no event screen up).
//
// Key: g (code 17). g is unbound on the world map in vanilla — the letters the
// map already claims are c/f/i/o/p/r/t (character, ?, inventory, obituary, perks,
// relations, camp). Eventually remappable through MSU keybinds (roadmap fase 5).
::UnseenBanner.WorldStatus <- {
	Keys = {
		[17] = "status"   // g
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function announce()
	{
		local assets = ::World.Assets;
		local money = assets.getMoney();
		local dailyMoney = assets.getDailyMoneyCost();
		local food = assets.getFood();
		local dailyFood = assets.getDailyFoodCost();
		// Days of food left at the current rate; -1 signals "no upkeep" (an empty
		// roster) so the companion can drop the days clause instead of dividing by
		// zero.
		local foodDays = dailyFood > 0 ? (food / dailyFood).tointeger() : -1;
		local brothers = ::World.getPlayerRoster().getSize();

		local time = ::World.getTime();
		local day = time.Days;
		local isDay = time.IsDaytime ? 1 : 0;

		// The contract title carries BBCode/colour markup, so it rides in `texto`,
		// the field the companion runs through clean() before speaking. valor is 1
		// only when a contract is active. The numbers pack pipe-separated in detalle.
		local contract = ::World.Contracts.getActiveContract();
		local title = contract != null ? contract.getTitle() : "";

		local detail = brothers + "|" + money + "|" + dailyMoney + "|"
			+ food + "|" + dailyFood + "|" + foodDays + "|" + day + "|" + isDay;
		::UnseenBanner.sendMessage("interrupt", title, "world.status",
			(contract != null ? "1" : "0"), detail);
	}
};

// Tactical tile cursor (phase 3.2). A keyboard cursor over the hex grid so a
// blind player can survey the battlefield: it starts on the active man and
// walks the six hex neighbours, announcing each tile's terrain and what stands
// on it (nothing / an ally / an enemy, respecting the fog of war). Pure
// Squirrel — every fact (tile type, occupant, active man) is a Squirrel API,
// so there is nothing to scrape from the DOM.
//
// Keys are the letter cluster Q/W/E/A/S/D (numpad is the game's own skill
// hotkeys, so it cannot be reused here) plus X to recentre on the active man.
// The letters double as the vanilla camera pan, which fires on key press; we
// consume press and release (see the tactical_state hook) so panning never
// fights the cursor, while the arrow keys keep panning for a sighted tester.
::UnseenBanner.TileCursor = {
	m = {
		CursorTile = null,
		LastActiveID = -1,
		EnemyIndex = -1,
		// Skill armed on the active man while the cursor is being moved, so the
		// readout can add "valid target, N% to hit" for the tile under it. Set
		// afresh from tactical_state on every key, null when nothing is armed.
		CurrentSkill = null
	},
	// Engine key code -> hex direction (Const.Direction: N=0, NE=1, SE=2, S=3,
	// SW=4, NW=5). Q/W/E map to the upper three neighbours, A/S/D to the lower.
	DirKeys = {
		[33] = 0,   // w  -> N
		[15] = 1,   // e  -> NE
		[14] = 2,   // d  -> SE
		[29] = 3,   // s  -> S
		[11] = 4,   // a  -> SW
		[27] = 5    // q  -> NW
	},
	RecenterKeys = {
		[34] = true // x -> recentre on the active man
	},
	// z steps through the living, visible enemies sorted by distance from the
	// active man: z alone to the farther, Shift+z to the nearer. c is left
	// untouched (it opens the vanilla character screen).
	CycleKeys = {
		[36] = true // z
	},
	// v inspects the unit standing on the cursor tile — the same facts the mouse
	// hover tooltip shows (armour, health, morale, fatigue, status effects, when it
	// acts), respecting fog of war. Works for enemies and allies alike, so a blind
	// player can size up any unit on the field, not just survey where it stands.
	InspectKeys = {
		[32] = true // v
	},
	function handles(_code)
	{
		return (_code in this.DirKeys) || (_code in this.RecenterKeys) || (_code in this.CycleKeys);
	},
	function handlesInspect(_code)
	{
		return _code in this.InspectKeys;
	},
	function reset()
	{
		this.m.CursorTile = null;
		this.m.LastActiveID = -1;
		this.m.EnemyIndex = -1;
		this.m.CurrentSkill = null;
	},
	// Re-anchor on the active man on the first key of a turn (or the first key
	// ever), so the cursor always starts from a known reference and any tile held
	// from a previous turn/battle is dropped before use. A new turn also restarts
	// enemy cycling from the nearest. Shared by onKey and getTile so acting on the
	// focused tile never reads a stale cursor.
	function ensureAnchored(_active)
	{
		if (this.m.CursorTile == null || this.m.LastActiveID != _active.getID())
		{
			this.m.CursorTile = _active.getTile();
			this.m.LastActiveID = _active.getID();
			this.m.EnemyIndex = -1;
		}
	},
	function getTile(_active)
	{
		this.ensureAnchored(_active);
		return this.m.CursorTile;
	},
	function onKey(_code, _active, _entities, _shift = false, _state = null)
	{
		// A targeted skill armed on the active man turns the survey into a target
		// preview: announce() then adds validity + hit chance for the cursor tile.
		this.m.CurrentSkill = null;
		if (_state != null && _state.getSelectedSkillID() != null)
		{
			this.m.CurrentSkill = _active.getSkills().getSkillByID(_state.getSelectedSkillID());
		}

		this.ensureAnchored(_active);

		if (_code in this.RecenterKeys)
		{
			this.m.CursorTile = _active.getTile();
			this.announce(_active);
			return;
		}

		if (_code in this.CycleKeys)
		{
			this.cycleEnemy(_shift ? -1 : 1, _active, _entities);
			return;
		}

		local dir = this.DirKeys[_code];
		if (this.m.CursorTile.hasNextTile(dir))
		{
			this.m.CursorTile = this.m.CursorTile.getNextTile(dir);
			this.announce(_active);
		}
		else
		{
			::UnseenBanner.sendMessage("interrupt", "", "tile.edge");
		}
	},
	function cycleEnemy(_step, _active, _entities)
	{
		local activeTile = _active.getTile();
		local scored = [];
		foreach( e in _entities.getAllHostilesAsArray() )
		{
			if (e != null && e.isAlive() && !e.isHiddenToPlayer() && e.getTile() != null)
			{
				scored.push({ e = e, d = activeTile.getDistanceTo(e.getTile()) });
			}
		}

		if (scored.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "tile.no_enemies");
			return;
		}

		scored.sort(function ( _a, _b )
		{
			if (_a.d > _b.d) return 1;
			if (_a.d < _b.d) return -1;
			return 0;
		});

		this.m.EnemyIndex += _step;
		if (this.m.EnemyIndex < 0) this.m.EnemyIndex = scored.len() - 1;
		if (this.m.EnemyIndex >= scored.len()) this.m.EnemyIndex = 0;

		this.m.CursorTile = scored[this.m.EnemyIndex].e.getTile();
		this.announce(_active);
	},
	function announce(_active)
	{
		local tile = this.m.CursorTile;
		local name = "";
		local kind = "empty";
		local hp = "";
		local hpMax = "";

		// A non-empty tile can hold an actor OR a non-actor object (cover and
		// decorations such as a brush), so the actor-only API must be gated by an
		// isKindOf check — the vanilla hover logic does exactly the same. Calling
		// getID/isPlayerControlled on a decoration throws and swallows the whole
		// readout, which is why some tiles went silent. isHiddenToPlayer exists on
		// both, so fog-of-war is honoured for either.
		if (!tile.IsEmpty)
		{
			local e = tile.getEntity();
			if (e != null && !e.isHiddenToPlayer())
			{
				name = e.getName();
				if (::isKindOf(e, "actor"))
				{
					if (_active != null && e.getID() == _active.getID())
						kind = "self";
					else if (e.isPlayerControlled())
						kind = "ally";
					else
						kind = "enemy";

					// Current health, appended right after the name so surveying the
					// field (X to recentre, Z/Shift+Z to cycle enemies, or any cursor
					// step onto a unit) says at once how hurt it is.
					hp = "" + e.getHitpoints();
					hpMax = "" + e.getHitpointsMax();
				}
				else
				{
					// Cover or scenery on the tile — worth calling out (it affects
					// line of sight and defence) but it is not a combatant.
					kind = "object";
				}
			}
		}

		// Distance in hex tiles and the hex bearing (0-5) from the active man to
		// the cursor. dir stays -1 on his own tile, which the companion reads as
		// "no direction". The companion turns dir into a clock position and holds
		// every spoken word, so no terrain/position string is hardcoded here.
		local dist = 0;
		local dir = -1;
		local activeTile = _active != null ? _active.getTile() : null;
		if (activeTile != null)
		{
			dist = activeTile.getDistanceTo(tile);
			if (dist > 0) dir = activeTile.getDirectionTo(tile);
		}

		// hp/hpMax are empty for empty tiles and scenery; the companion only voices
		// the health clause for an actor. They sit before the optional target fields
		// so those stay at the tail regardless of whether a unit is present.
		local detail = kind + "|" + dist + "|" + dir + "|" + hp + "|" + hpMax;

		// With a skill armed, tack on two more fields so the companion can say
		// whether the tile is a legal target and, for an attackable actor on it,
		// the hit chance the game itself would show. isUsableOn folds in range,
		// line of sight and the skill's own onVerifyTarget, so it is the single
		// source of truth the mouse cursor uses too.
		if (this.m.CurrentSkill != null)
		{
			local targetable = this.m.CurrentSkill.isUsableOn(tile) ? "1" : "0";
			local hit = "-";
			if (targetable == "1" && !tile.IsEmpty)
			{
				local e = tile.getEntity();
				if (e != null && ::isKindOf(e, "actor") && !e.isHiddenToPlayer() && e.isAttackable())
					hit = "" + this.m.CurrentSkill.getHitchance(e);
			}
			detail += "|" + targetable + "|" + hit;
		}

		::UnseenBanner.sendMessage("interrupt", name, "tile.readout", "" + tile.Type, detail);
	},
	// On-demand detail for whatever stands on the cursor tile (the v key). Reads the
	// same funnel the mouse tooltip is built from (actor.getTooltip), honouring fog
	// of war exactly as vanilla does: a dead/removed unit or an empty tile is
	// nothing; an undiscovered enemy is "Hidden opponent"; a discovered-but-unseen
	// one gives only its name. Everything else gets the full readout. Cover/scenery
	// on the tile is not a combatant, so it is called out by name only. All facts
	// are Squirrel actor APIs — nothing is scraped from the DOM.
	function inspect(_active)
	{
		this.ensureAnchored(_active);
		local tile = this.m.CursorTile;

		if (tile == null || tile.IsEmpty)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.empty");
			return;
		}

		local e = tile.getEntity();
		if (e == null)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.empty");
			return;
		}

		if (!::isKindOf(e, "actor"))
		{
			// Cover or decoration — worth naming (it affects line of sight and
			// defence) but there are no combat stats to read.
			::UnseenBanner.sendMessage("interrupt", e.getName(), "combat.inspect.object");
			return;
		}

		if (!e.isAlive() || e.isDying() || !e.isPlacedOnMap())
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.empty");
			return;
		}

		if (!e.isDiscovered())
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.hidden");
			return;
		}

		local name = e.getName();
		if (e.isHiddenToPlayer())
		{
			// Discovered before but not currently in sight: name only, no live stats.
			::UnseenBanner.sendMessage("interrupt", name, "combat.inspect", "sight", "");
			return;
		}

		local kind = "enemy";
		if (_active != null && e.getID() == _active.getID()) kind = "self";
		else if (e.isPlayerControlled()) kind = "ally";

		// When it next acts, mirroring the tooltip's "Acting right now / Turn done /
		// Acts in N turns" line. getTurnsUntilActive returns the slot index in this
		// round's queue (0 = acting now), or null once it has acted or drops out.
		local timing = "none";
		local activeE = ::Tactical.TurnSequenceBar.getActiveEntity();
		if (activeE != null && activeE.getID() == e.getID())
		{
			timing = "now";
		}
		else if (e.isTurnDone())
		{
			timing = "done";
		}
		else
		{
			local t = ::Tactical.TurnSequenceBar.getTurnsUntilActive(e.getID());
			if (t != null && t > 0) timing = "" + t;
		}

		// Status effects and temporary injuries, exactly the set the tooltip lists.
		local effects = "";
		local ec = 0;
		local ses = e.getSkills().query(::Const.SkillType.StatusEffect | ::Const.SkillType.TemporaryInjury, false, true);
		foreach( s in ses )
		{
			if (s == null) continue;
			if (ec > 0) effects += "\n";
			effects += s.getName();
			ec += 1;
		}

		local detail = kind + "|" + e.getLevel()
			+ "|" + timing
			+ "|" + e.getHitpoints() + "|" + e.getHitpointsMax()
			+ "|" + e.getFatigue() + "|" + e.getFatigueMax()
			+ "|" + e.getArmor(::Const.BodyPart.Head) + "|" + e.getArmorMax(::Const.BodyPart.Head)
			+ "|" + e.getArmor(::Const.BodyPart.Body) + "|" + e.getArmorMax(::Const.BodyPart.Body)
			+ "|" + e.getMoraleState()
			+ "|" + effects;

		::UnseenBanner.sendMessage("interrupt", name, "combat.inspect", "ok", detail);
	}
};

// Combat log (phase 3.1). The tactical event log is the funnel every combat
// line already flows through as fully rendered, localized text ("X uses Y and
// hits Z", deaths, morale, round starts...). We forward each line verbatim on
// the queue channel — the FIFO lesson from F&H1: combat lines must all be
// spoken, in order, nothing dropped. No JS: the text is already in Squirrel,
// so this reads it at the source instead of re-scraping the DOM. BBCode color
// tags in the text are stripped by TextCleaner on the companion side.
::UnseenBanner.CombatLog = {
	function onLine(_text)
	{
		if (_text == null) return;
		// Skip the blank spacer lines the log uses between blocks; they carry
		// no words and would only add dead air to the speech queue.
		if (typeof _text != "string" || this.strip(_text) == "") return;
		::UnseenBanner.sendMessage("queue", _text);
	}
	// Whitespace-only check without a regex dependency (plain Squirrel).
	function strip(_s)
	{
		local out = "";
		local n = _s.len();
		for (local i = 0; i < n; i += 1)
		{
			local ch = _s.slice(i, i + 1);
			if (ch != " " && ch != "\n" && ch != "\r" && ch != "\t") out += ch;
		}
		return out;
	}
};

// Acting on the focused tile (phase 3.3). The tile cursor lets a blind player
// survey the field; this is the other half — committing to a tile. One key, G
// (the letter cluster's numpad is the vanilla skill hotkeys and enter/F already
// end the turn, so G is the free ergonomic neighbour of the cursor cluster):
//   - with a skill armed (selected by its number hotkey), G uses it on the
//     cursor tile via the game's own executeEntitySkill, which validates the
//     target and, on a bad one, logs "Invalid target!" — already narrated by the
//     combat log, so nothing is announced twice here;
//   - with nothing armed, G walks the active man to the cursor tile, reusing the
//     engine navigator exactly as a mouse click would (compute the path, then
//     hand off to the TravelPath action state that tactical_state.onUpdate
//     already drains frame by frame).
// Skill *selection* itself is narrated from the setActionStateBySkill funnel
// below, not here.
::UnseenBanner.Combat = {
	ActKeys = {
		[17] = true // g -> act on the focused tile
	},
	function handles(_code)
	{
		return _code in this.ActKeys;
	},
	function onKey(_code, _active, _state, _cursorTile)
	{
		if (!(_code in this.ActKeys)) return;

		// No cursor move yet this turn: fall back to the man's own tile, so a
		// self-targeted skill still fires and a move is simply a no-op.
		if (_cursorTile == null) _cursorTile = _active.getTile();

		if (_state.getSelectedSkillID() != null)
		{
			_state.executeEntitySkill(_active, _cursorTile);
		}
		else
		{
			this.moveActiveTo(_active, _state, _cursorTile);
		}
	},
	// Mirrors tactical_state.computeEntityPath's navigator setup and then trips
	// the TravelPath state the way executeEntityTravel does. Kept faithful to the
	// vanilla settings block on purpose: the navigator is native (no .nut to
	// reuse), so this is the one place the mod restates engine internals.
	function moveActiveTo(_active, _state, _tile)
	{
		if (_tile.ID == _active.getTile().ID)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.move.here");
			return;
		}

		if (!_tile.IsDiscovered)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.move.blocked");
			return;
		}

		if (_active.getCurrentProperties().IsRooted)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.move.rooted");
			return;
		}

		// NB: Tactical/Const are root-table globals, not state members. Vanilla
		// code reads them as "this.Tactical" only because indexing `this` falls
		// back to the root table; indexing a local (_state.Tactical) does not.
		local nav = ::Tactical.getNavigator();
		local settings = nav.createSettings();
		settings.ActionPointCosts = _active.getActionPointCosts();
		settings.FatigueCosts = _active.getFatigueCosts();
		settings.FatigueCostFactor = ::Const.Movement.FatigueCostFactor;
		settings.ActionPointCostPerLevel = _active.getLevelActionPointCost();
		settings.FatigueCostPerLevel = _active.getLevelFatigueCost();
		settings.ZoneOfControlCost = 4;
		settings.AlliedFactions = _active.getAlliedFactions();
		settings.Faction = _active.getFaction();
		settings.AllowZoneOfControlPassing = true;
		settings.IsPlayer = true;

		if (!nav.findPath(_active.getTile(), _tile, settings, 0))
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.move.blocked");
			return;
		}

		// findPath alone only tells the navigator a route exists; buildVisualisation
		// is the call that actually commits it as the path travel() walks. Every
		// vanilla path (mouse click -> computeEntityPath) makes both calls before
		// ever reaching travel(), so skipping this one silently no-ops the move.
		nav.buildVisualisation(_active, settings, _active.getActionPoints(), _active.getFatigueMax() - _active.getFatigue());

		settings.ZoneOfControlCost = 0;
		local costs = nav.getCostForPath(_active, settings, _active.getActionPoints(), _active.getFatigueMax() - _active.getFatigue());

		if (costs.Tiles == 0)
		{
			// A path exists but not a single tile of it is affordable this turn.
			nav.clearVisualisation();
			::UnseenBanner.sendMessage("interrupt", "", "combat.move.no_ap");
			return;
		}

		_state.m.LastTileSelected = _tile;
		_state.m.CurrentActionState = ::Const.Tactical.ActionState.TravelPath;
		_state.m.ActiveEntityNeedsUpdate = true;
		nav.clearVisualisation();
		::Tactical.getHighlighter().clear();
		::Tactical.getShaker().cancel(_active);

		if (::Tactical.getCamera().Level < _tile.Level)
		{
			::Tactical.getCamera().Level = _tile.Level;
		}

		::UnseenBanner.sendMessage("interrupt", "" + costs.Tiles, "combat.move");
	},
	// Narrates a skill the moment it is armed and awaiting a target. Called from
	// the setActionStateBySkill hook once the vanilla logic has run.
	function onSkillActivated(_skill, _state)
	{
		local targeted = _skill.isTargeted() ? "1" : "0";
		::UnseenBanner.sendMessage("interrupt", _skill.getName(), "combat.skill.selected",
			"" + _skill.getActionPointCost(), _skill.getFatigueCost() + "|" + targeted);
	}
};

// On-demand readouts (phase 3.4) and the character-sheet readout for the C/I
// screen. Everything here is pull, not push: dedicated keys speak the active
// man's live resources, the turn order, or the visible enemies, and opening the
// tactical character screen speaks the shown man's attribute sheet. All facts
// are Squirrel APIs (actor + properties + turn sequence bar), so nothing is
// scraped from the DOM; the companion owns every connective word. List readouts
// pack their entries newline-separated in the message text (game names never
// contain newlines), each line tagged so the companion can localize the framing.
::UnseenBanner.Readout = {
	// t = active man's status, tab = turn order, b = visible enemies, k = active
	// man's usable skills. t and b are bound in vanilla to purely visual overlay
	// toggles (skill trees / blocked tiles); our hook consumes them during the
	// player's turn, which a sighted tester loses but a blind player never needs.
	// tab is unbound in vanilla; k is free.
	Keys = {
		[30] = "status",   // t
		[38] = "turnorder", // tab
		[12] = "enemies",  // b
		[21] = "skills"    // k
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function onKey(_code, _active, _entities)
	{
		local what = this.Keys[_code];
		if (what == "status") this.status(_active);
		else if (what == "turnorder") this.turnOrder(_active);
		else if (what == "enemies") this.enemies(_active, _entities);
		else if (what == "skills") this.skills(_active);
	},
	function status(_active)
	{
		// Health, action points, fatigue as current/max pairs plus the morale
		// index (the companion maps it to a word). This is the readout that
		// answers "how many action points do I have left" without a screen.
		local detail = _active.getHitpoints() + "/" + _active.getHitpointsMax()
			+ "|" + _active.getActionPoints() + "/" + _active.getActionPointsMax()
			+ "|" + _active.getFatigue() + "/" + _active.getFatigueMax();
		::UnseenBanner.sendMessage("interrupt", _active.getName(), "combat.status",
			"" + _active.getMoraleState(), detail);
	},
	function turnOrder(_active)
	{
		// The remaining turn queue for this round (index 0 is whoever is acting).
		// Hidden enemies are left out to keep fog-of-war parity. Each line is
		// "s"/"a"/"e" (self/ally/enemy) + the already-localized name.
		local entities = ::Tactical.TurnSequenceBar.getCurrentEntities();
		local text = "";
		local count = 0;
		foreach( e in entities )
		{
			if (e == null || !e.isAlive() || e.isHiddenToPlayer()) continue;

			local tag = "e";
			if (_active != null && e.getID() == _active.getID()) tag = "s";
			else if (e.isPlayerControlled()) tag = "a";

			if (count > 0) text += "\n";
			text += tag + e.getName();
			count += 1;
		}

		if (count == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.turnorder.empty");
			return;
		}

		::UnseenBanner.sendMessage("interrupt", text, "combat.turnorder");
	},
	function enemies(_active, _entities)
	{
		// Visible, living hostiles sorted nearest-first. Each line is the hex
		// distance from the active man, a space, then the name.
		local activeTile = _active.getTile();
		local scored = [];
		foreach( e in _entities.getAllHostilesAsArray() )
		{
			if (e != null && e.isAlive() && !e.isHiddenToPlayer() && e.getTile() != null)
			{
				scored.push({ e = e, d = activeTile.getDistanceTo(e.getTile()) });
			}
		}

		if (scored.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.enemies.empty");
			return;
		}

		scored.sort(function ( _a, _b )
		{
			if (_a.d > _b.d) return 1;
			if (_a.d < _b.d) return -1;
			return 0;
		});

		local text = "";
		for (local i = 0; i < scored.len(); i += 1)
		{
			if (i > 0) text += "\n";
			text += scored[i].d + " " + scored[i].e.getName();
		}

		::UnseenBanner.sendMessage("interrupt", text, "combat.enemies", "" + scored.len());
	},
	// The active man's usable skills — the numbered action bar read aloud (the k
	// key). queryActives() is the exact list, in the exact order, that the number
	// hotkeys index into (setActionStateBySkillIndex), so slot N here is the key the
	// player presses. Each line is "slot\tname\tap\tfatigue\tusable", where usable is
	// 1 only when the skill can actually be used this instant (affordable AP+fatigue
	// and not otherwise blocked), so the readout answers "what can I do right now".
	function skills(_active)
	{
		local list = _active.getSkills().queryActives();
		local text = "";
		local count = 0;
		for (local i = 0; i < list.len(); i += 1)
		{
			local s = list[i];
			if (s == null) continue;
			local usable = (s.isUsable() && s.isAffordable()) ? "1" : "0";
			if (count > 0) text += "\n";
			text += (i + 1) + "\t" + s.getName() + "\t" + s.getActionPointCost()
				+ "\t" + s.getFatigueCost() + "\t" + usable;
			count += 1;
		}

		if (count == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.skills.empty");
			return;
		}

		::UnseenBanner.sendMessage("interrupt", text, "combat.skills", "" + count);
	}
};

// The tactical character screen (C/I) as a keyboard-navigable list (roadmap 2.2 /
// completing 3.4). Vanilla renders the shown brother's whole sheet to a texture no
// screen reader can see, but every fact it is built from is a Squirrel actor API,
// so we rebuild the sheet as an ordered list of one-fact-per-entry lines and let
// the player walk it with Up/Down or jump with Home/End, reading one attribute at
// a time. A/D (and the left/right/Tab the screen already binds) switch brother;
// we drive the same vanilla switch so the visible sheet keeps up, and mirror the
// move on our own copy of the roster to know which brother is now shown — the
// selection lives in the screen's JS, unreadable from here, but the roster order
// (getInstancesOfFaction, the exact source the screen queries) is reproducible, so
// an identical +1/-1 wrap from the same start stays in lockstep. The item index is
// preserved across brother switches so the same attribute can be compared quickly.
::UnseenBanner.SheetNav <- {
	m = {
		Brothers = null,
		BroIndex = 0,
		Items = null,
		ItemIndex = 0,
		Active = false
	},
	// d / right / Tab -> next brother; a / left -> previous. Same keys the vanilla
	// character screen already uses, so muscle memory carries over.
	NextKeys = {
		[14] = true, // d
		[50] = true, // right
		[38] = true  // tab
	},
	PrevKeys = {
		[11] = true, // a
		[48] = true  // left
	},
	// Up / Down walk the sheet list one entry at a time; Home / End jump to its
	// boundaries. Engine codes come from MSU's KeyMapSQ, not DOM/ASCII key codes.
	MoveKeys = {
		[44] = "end",
		[45] = "home",
		[49] = "up",
		[51] = "down"
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return (_code in this.NextKeys) || (_code in this.PrevKeys) || (_code in this.MoveKeys);
	},
	function isMove(_code)
	{
		return _code in this.MoveKeys;
	},
	function isNext(_code)
	{
		return _code in this.NextKeys;
	},
	function reset()
	{
		this.m.Active = false;
		this.m.Brothers = null;
		this.m.Items = null;
		this.m.BroIndex = 0;
		this.m.ItemIndex = 0;
	},
	// Called when the screen becomes visible. _active is the man whose sheet the
	// screen opens on (the active brother in battle, or null in battle preparation,
	// where it defaults to the first of the roster — the same one the screen shows).
	function open(_active)
	{
		local raw = ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.Player);
		local list = [];
		if (raw != null)
		{
			foreach( b in raw )
			{
				if (b != null) list.push(b);
			}
		}
		this.m.Brothers = list;

		this.m.BroIndex = 0;
		if (_active != null)
		{
			for (local i = 0; i < list.len(); i += 1)
			{
				if (list[i].getID() == _active.getID())
				{
					this.m.BroIndex = i;
					break;
				}
			}
		}

		this.m.Active = true;
		this.buildItems();
		this.m.ItemIndex = 0;
		this.announceItem();
	},
	function close()
	{
		this.reset();
	},
	function current()
	{
		if (this.m.Brothers == null || this.m.Brothers.len() == 0) return null;
		return this.m.Brothers[this.m.BroIndex];
	},
	// Mirror a brother switch the same way the vanilla screen does (next/previous
	// non-null with wrap; the tactical roster is dense, so a plain modular step
	// matches). Rebuild the sheet for the new man but preserve the item index, then
	// announce his name and the same attribute in one interrupt message. Keeping it
	// as one message matters: a second interrupt would cut the name off.
	function switchBrother(_next)
	{
		if (this.m.Brothers == null || this.m.Brothers.len() == 0) return;
		local itemIndex = this.m.ItemIndex;
		local n = this.m.Brothers.len();
		if (_next) this.m.BroIndex = (this.m.BroIndex + 1) % n;
		else this.m.BroIndex = (this.m.BroIndex - 1 + n) % n;

		this.buildItems();
		this.m.ItemIndex = itemIndex;
		if (this.m.Items != null && this.m.Items.len() > 0)
		{
			if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
			if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		}
		this.announceItem(true);
	},
	// Move within the current sheet, clamping at the ends (no wrap, so the edges are
	// discoverable), or jump straight to either edge. Re-reading the same entry at
	// an edge is intentional feedback.
	function move(_code)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.ItemIndex -= 1;
		else if (dir == "down") this.m.ItemIndex += 1;
		else if (dir == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;

		this.announceItem();
	},
	function announceItem(_includeBrother = false)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		// Identity already contains the brother's name, so do not say it twice when
		// that is the retained item.
		local bro = _includeBrother && it.cat != "combat.sheet.identity" ? this.current() : null;
		local name = bro != null ? bro.getName() : null;
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle, name);
	},
	// Build the ordered list of sheet entries for the shown brother. Each entry is a
	// tagged line the companion localizes; the framing words ("Resolve", "Head
	// armor"...) stay on that side, this only supplies the numbers and the already
	// localized game names. Attributes come first (what the user asked to read one
	// by one), then injuries, traits, perks and worn equipment as list entries.
	// Player-only facts (background, mood, XP, perks, traits) are gated by class so
	// a non-brother player-faction unit still gets a valid, reduced sheet.
	function buildItems()
	{
		local bro = this.current();
		local items = [];
		if (bro == null)
		{
			this.m.Items = items;
			return;
		}

		local isPlayer = ::isKindOf(bro, "player");
		local p = bro.getCurrentProperties();

		local function entry(_cat, _texto, _valor, _detalle)
		{
			return { cat = _cat, texto = _texto, valor = _valor, detalle = _detalle };
		}

		items.push(entry("combat.sheet.identity", bro.getName(), "" + bro.getLevel(), ""));

		if (isPlayer)
		{
			local bg = bro.getBackground();
			items.push(entry("combat.sheet.background", bg != null ? bg.getName() : "", "", ""));
			items.push(entry("combat.sheet.xp", "", "" + bro.getXP(), "" + bro.getXPForNextLevel()));
			items.push(entry("combat.sheet.mood", "", "" + bro.getMoodState(), ""));
		}

		items.push(entry("combat.sheet.hp", "", "" + bro.getHitpoints(), "" + bro.getHitpointsMax()));
		items.push(entry("combat.sheet.fatigue", "", "" + bro.getFatigue(), "" + bro.getFatigueMax()));
		items.push(entry("combat.sheet.resolve", "", "" + p.getBravery(), ""));
		items.push(entry("combat.sheet.initiative", "", "" + p.getInitiative(), ""));
		items.push(entry("combat.sheet.mskill", "", "" + p.getMeleeSkill(), ""));
		items.push(entry("combat.sheet.rskill", "", "" + p.getRangedSkill(), ""));
		items.push(entry("combat.sheet.mdef", "", "" + p.getMeleeDefense(), ""));
		items.push(entry("combat.sheet.rdef", "", "" + p.getRangedDefense(), ""));
		items.push(entry("combat.sheet.armor.head", "", "" + bro.getArmor(::Const.BodyPart.Head), "" + bro.getArmorMax(::Const.BodyPart.Head)));
		items.push(entry("combat.sheet.armor.body", "", "" + bro.getArmor(::Const.BodyPart.Body), "" + bro.getArmorMax(::Const.BodyPart.Body)));

		// Active skills, so any brother's abilities can be read here — not just the
		// active man's via the k key. Same source (queryActives) the numbered action
		// bar uses, but without the "usable now" flag: it is not this man's turn.
		items.push(this.skillsEntry(bro));

		items.push(this.listEntry(bro, "combat.sheet.injuries",
			::Const.SkillType.Injury | ::Const.SkillType.PermanentInjury | ::Const.SkillType.TemporaryInjury | ::Const.SkillType.SemiInjury));

		if (isPlayer)
		{
			items.push(this.listEntry(bro, "combat.sheet.traits", ::Const.SkillType.Trait));
			items.push(this.listEntry(bro, "combat.sheet.perks", ::Const.SkillType.Perk));
		}

		items.push(this.equipEntry(bro));

		this.m.Items = items;
	},
	// One list entry (injuries / traits / perks): the already-localized skill names
	// newline-joined in the text, the count in valor so the companion can say
	// "none" or pluralize.
	function listEntry(_bro, _cat, _mask)
	{
		local skills = _bro.getSkills().query(_mask, false, true);
		local text = "";
		local n = 0;
		foreach( s in skills )
		{
			if (s == null) continue;
			if (n > 0) text += "\n";
			text += s.getName();
			n += 1;
		}
		return { cat = _cat, texto = text, valor = "" + n, detalle = "" };
	},
	// Active skills for the sheet: each line is "name\tap\tfatigue" (no slot number,
	// since a non-active brother's hotkeys are not live, and no usability flag).
	function skillsEntry(_bro)
	{
		local list = _bro.getSkills().queryActives();
		local text = "";
		local n = 0;
		foreach( s in list )
		{
			if (s == null) continue;
			if (n > 0) text += "\n";
			text += s.getName() + "\t" + s.getActionPointCost() + "\t" + s.getFatigueCost();
			n += 1;
		}
		return { cat = "combat.sheet.skills", texto = text, valor = "" + n, detalle = "" };
	},
	// Worn equipment: the fixed slots the paperdoll shows (weapon, shield/offhand,
	// helmet, body armour, accessory), in reading order, names newline-joined.
	function equipEntry(_bro)
	{
		local inv = _bro.getItems();
		local slots = [
			::Const.ItemSlot.Mainhand,
			::Const.ItemSlot.Offhand,
			::Const.ItemSlot.Head,
			::Const.ItemSlot.Body,
			::Const.ItemSlot.Accessory
		];
		local text = "";
		local n = 0;
		foreach( sl in slots )
		{
			local it = inv.getItemAtSlot(sl);
			if (it == null) continue;
			if (n > 0) text += "\n";
			text += it.getName();
			n += 1;
		}
		return { cat = "combat.sheet.equipment", texto = text, valor = "" + n, detalle = "" };
	}
};

// Post-combat result screen (the Victory/Defeat screen with its statistics and
// loot). Once the battle ends the tactical state swallows every key, so this
// screen is mouse-only in vanilla — unreachable by a blind player. Flatten its
// Statistics and Loot panels into one semantic list: outcome, each casualty,
// each survivor's statistics, each loot item, then the real action buttons.
// Up/Down reads one entry at a time and Enter activates the focused button. The
// old L/R shortcuts remain available for loot-all and repeating the current row.
// The outcome and all names are the game's own text; framing words stay in L10n.
::UnseenBanner.CombatResult = {
	m = {
		Items = null,
		ItemIndex = 0,
		CanLoot = false
	},
	Keys = {
		[49] = "up",
		[51] = "down",
		[39] = "activate", // enter -> activate the focused button
		[22] = "lootall",  // l -> retain the direct loot-all shortcut
		[28] = "repeat"    // r -> repeat the focused row
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function reset()
	{
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.CanLoot = false;
	},
	function item(_cat, _texto = "", _valor = "", _detalle = "", _action = null)
	{
		return {
			cat = _cat,
			texto = _texto,
			valor = _valor,
			detalle = _detalle,
			action = _action
		};
	},
	function open(_screen)
	{
		this.reset();
		this.buildItems(_screen);
		this.announceItem();
	},
	function close()
	{
		this.reset();
	},
	function onKey(_code, _state)
	{
		local screen = _state.m.TacticalCombatResultScreen;
		if (screen == null) return;

		local what = this.Keys[_code];
		if (what == "up" || what == "down") this.move(what);
		else if (what == "activate") this.activate(screen);
		else if (what == "lootall") this.lootAll(screen);
		else if (what == "repeat") this.announceItem();
	},
	function buildItems(_screen)
	{
		local result = [];

		// Outcome first, as the game's own sentence ("Victory. The enemy was
		// destroyed in 3 rounds"), plus the short navigation hint spoken once.
		local info = _screen.onQueryCombatInformation();
		if (info != null)
		{
			local line = info.title;
			if (info.subTitle != null && info.subTitle != "") line += ". " + info.subTitle;
			result.push(this.item("combat.result.screen", line));
			this.m.CanLoot = info.loot;
		}

		// Casualties are not in vanilla's statistics panel, which only contains
		// survivors. Give each fallen brother a row so a long death toll never turns
		// into one uninterruptible announcement.
		local casualties = ::Tactical.getCasualtyRoster().getAll();
		local deadCount = 0;
		if (casualties != null)
		{
			foreach( c in casualties )
			{
				if (c == null) continue;
				result.push(this.item("combat.result.casualty", c.getName()));
				deadCount += 1;
			}
		}
		if (deadCount == 0)
		{
			result.push(this.item("combat.result.casualties.none"));
		}

		// Per-survivor statistics mirror the panel: name, kills, XP, plus whether
		// the brother levelled up or came out wounded. One brother is one row.
		result.push(this.item("combat.result.stats.heading"));
		local roster = ::Tactical.CombatResultRoster;
		local statCount = 0;
		if (roster != null)
		{
			foreach( bro in roster )
			{
				if (bro == null) continue;
				local cs = bro.getCombatStats();
				local level = bro.isLeveled() ? "1" : "0";
				local wound = bro.getDaysWounded() > 0 ? "1" : "0";
				result.push(this.item("combat.result.stat", bro.getName(), "" + cs.Kills,
					"" + cs.XPGained + "|" + level + "|" + wound));
				statCount += 1;
			}
		}
		if (statCount == 0)
		{
			result.push(this.item("combat.result.stats.none"));
		}

		// Loot also becomes a heading plus one item per row. The action buttons are
		// appended only after all information, as in every other accessible list.
		local items = ::Tactical.CombatResultLoot.getItems();
		local lootCount = 0;
		if (items != null)
		{
			foreach( item in items )
			{
				if (item == null) continue;
				lootCount += 1;
			}
		}

		if (lootCount == 0)
		{
			result.push(this.item("combat.result.loot.none"));
		}
		else
		{
			local heading = lootCount == 1 ? "combat.result.loot.heading.one" : "combat.result.loot.heading";
			result.push(this.item(heading, "", "" + lootCount));
			foreach( item in items )
			{
				if (item == null) continue;
				result.push(this.item("combat.result.loot.item", item.getName()));
			}
		}

		if (this.m.CanLoot)
		{
			local lootButton = lootCount == 0
				? "combat.result.button.lootall.disabled"
				: "combat.result.button.lootall";
			result.push(this.item(lootButton, "", "", "", "lootall"));
		}
		result.push(this.item("combat.result.button.continue", "", "", "", "continue"));
		this.m.Items = result;
	},
	function move(_direction)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		if (_direction == "up") this.m.ItemIndex -= 1;
		else this.m.ItemIndex += 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
	},
	function activate(_screen)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local action = this.m.Items[this.m.ItemIndex].action;
		if (action == "lootall") this.lootAll(_screen);
		else if (action == "continue") _screen.onLeaveButtonPressed();
		else this.announceItem();
	},
	function selectAction(_action)
	{
		if (this.m.Items == null) return;
		for (local i = 0; i < this.m.Items.len(); i += 1)
		{
			if (this.m.Items[i].action == _action)
			{
				this.m.ItemIndex = i;
				return;
			}
		}
	},
	function lootAll(_screen)
	{
		if (!this.m.CanLoot || ::Tactical.CombatResultLoot.isEmpty())
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.result.loot.none");
			return;
		}

		// Same call the vanilla "loot all" button makes; it moves what fits into
		// the stash. Report by whether anything is left rather than by parsing its
		// UI-data return, so a full stash is called out.
		_screen.onLootAllItemsButtonPressed();
		_screen.loadItemLists();
		this.buildItems(_screen);
		this.selectAction("lootall");

		if (::Tactical.CombatResultLoot.isEmpty())
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.result.loot.taken");
		}
		else
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.result.loot.partial");
		}
	}
};

// Key-repeat gate for our tactical hotkeys. During active combat the engine
// swallows the RELEASE event (state 0) of any key that still carries a native
// binding — camera pan (Q/W/E/A/S/D), overlay toggles (T/B), brother switch
// (A/D) — and only delivers the PRESS (state 1), which then auto-repeats while the
// key is held. Verified live via a key-log: V and the arrows (no native binding)
// deliver a release; T/B/A/D do not, so a release-driven handler never fires for
// them without a modifier held. So we act on the press instead, and this gate
// debounces the auto-repeat by real wall-clock time (real, not virtual, so it
// still ticks while the character screen pauses the game). A delivered release
// clears the entry, so a deliberate re-tap of a key that DOES report release fires
// again at once.
::UnseenBanner.KeyGate <- {
	m = {
		Last = {}
	},
	// Minimum seconds between two firings of the same held key. Long enough to
	// swallow the ~40 ms auto-repeat, short enough that hold-to-repeat still feels
	// responsive and deliberate taps are never dropped.
	RepeatSeconds = 0.2,
	function shouldFire(_code, _now)
	{
		if (_code in this.m.Last && _now - this.m.Last[_code] < this.RepeatSeconds)
		{
			return false;
		}
		this.m.Last[_code] <- _now;
		return true;
	},
	function release(_code)
	{
		if (_code in this.m.Last) delete this.m.Last[_code];
	},
	function reset()
	{
		this.m.Last = {};
	}
};

// Engine key codes (see MSU's KeyMapSQ, the reference for this enum).
// Tunable/remappable keys should eventually go through MSU keybinds and its
// settings UI (roadmap fase 5, "toda constante afinable va a config").
::UnseenBanner.KeyCodes <- {
	[39] = "enter",
	[49] = "up",
	[51] = "down"
};

// Left / Right are adjustment keys only inside Options. Keeping them out of the
// shared KeyCodes table prevents the event cursor and New Campaign flow from
// stealing native horizontal input they do not handle.
::UnseenBanner.OptionsKeyCodes <- {
	[48] = "left",
	[50] = "right"
};

::UnseenBanner.Mod.hook("scripts/root_state", function(q) {
	local onInit = q.onInit;
	q.onInit = @() function()
	{
		::UnseenBanner.JSConnection.connect();
		::UnseenBanner.MenuNav.connect();
		::UnseenBanner.EventNav.connect();
		::logInfo("UnseenBanner: root_state.onInit hook fired (class hooking alive).");
		onInit();
	}
});

// Module lifecycle is the deterministic point at which the animated DOM is
// ready. Hooking the common base avoids polling and keeps the announcement
// aligned with the screen the player can actually interact with.
::UnseenBanner.Mod.hook("scripts/ui/screens/ui_module", function(q) {
	q.onModuleShown = @(__original) function()
	{
		__original();
		::UnseenBanner.MenuNav.onModuleShown(this.m.ID);
	}

	q.onModuleHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.MenuNav.onModuleHidden(this.m.ID);
	}
});

::UnseenBanner.Mod.hook("scripts/states/main_menu_state", function(q) {
	q.onInit = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		__original();
	}

	q.onFinish = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		__original();
	}

	q.onKeyInput = @(__original) function( _key )
	{
		// Only steal keys while a menu handled by menu_nav.js is fully shown.
		// All other submenus keep their native keyboard behavior.
		//
		// State 0 is key release (1 = press, repeated while held) — same
		// event the vanilla menu uses for its own escape handling, and it
		// cannot flood the JS side with key-repeat.
		if (_key.getState() == 0
			&& ::UnseenBanner.MenuNav.handlesKey(_key.getKey())
			&& ::UnseenBanner.MenuNav.isActive()
			&& this.isKeyInputPermitted())
		{
			::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(_key.getKey()));
			return true;
		}

		return __original(_key);
	}
});

// The event screen notifies the backend when its slide-in finishes
// (onScreenShown) and after it hides (onScreenHidden). Those are the
// deterministic points at which the DOM is populated and stable, so we
// announce there and clear the cursor on hide.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/world_event_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.EventNav.onEventShown();
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.EventNav.onEventHidden();
	}
});

// Post-combat result screen (phase 3.6). onScreenShown is the deterministic point
// at which the screen is fully up (same pattern as the event screen), so its
// flattened result list is built there. onScreenHidden clears the cursor. Keys are
// handled from tactical_state.onKeyInput, where the engine routes keyboard while
// the battle is ending.
::UnseenBanner.Mod.hook("scripts/ui/screens/tactical/tactical_combat_result_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.CombatResult.open(this);
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.CombatResult.close();
	}
});

// The event screen has no state of its own; it is shown inside world_state, so
// its keyboard cursor is driven from world_state.onKeyInput. Up/Down/Enter are
// stolen only while the event is up; every other key (including the native 1-6
// button shortcuts) keeps its normal behavior.
::UnseenBanner.Mod.hook("scripts/states/world_state", function(q) {
	// MenuNav's "active" flag is a menu module being shown, cleared when it hides.
	// But entering gameplay tears menu modules down without a reliable hide event:
	// loading a save from the main menu only hides main_menu_state (no onFinish), and
	// loading from the in-game pause menu reuses this very world_state. Either way the
	// LoadCampaignModule's onModuleHidden never fires, so ActiveModule would stay set
	// and its guard would silently swallow the world-map keys (e.g. G reads nothing).
	// Reset at both gameplay entry points so the map always starts with no menu held:
	// onInit for a fresh state (new campaign, load from main menu), and the loading
	// screen for an in-game reload of the same state.
	q.onInit = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		__original();
	}

	q.loading_screen_onScreenShown = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		__original();
	}

	q.onFinish = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		__original();
	}

	q.onKeyInput = @(__original) function( _key )
	{
		if (_key.getState() == 0
			&& _key.getKey() in ::UnseenBanner.KeyCodes
			&& ::UnseenBanner.EventNav.isActive())
		{
			::UnseenBanner.EventNav.sendKey(::UnseenBanner.KeyCodes[_key.getKey()]);
			return true;
		}

		// In-game menus (pause menu, load, save) run through the same keyboard cursor
		// as the main menu. They are shown inside world_state, so keys are stolen here
		// while one is fully up; Escape (41) is left to the native handler, which pops
		// the menu stack (submenu -> pause menu -> resume). The event screen and a menu
		// are never up at once.
		if (_key.getState() == 0
			&& ::UnseenBanner.MenuNav.handlesKey(_key.getKey())
			&& !::UnseenBanner.EventNav.isActive()
			&& ::UnseenBanner.MenuNav.isActive())
		{
			::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(_key.getKey()));
			return true;
		}

		// Company/campaign readout (phase 4.4), only on the plain map (no event or
		// menu screen up). Fire on release, exactly like the event cursor above: this
		// is the same state and the map delivers the release of g (which carries no
		// native map binding, so nothing swallows it — that swallowing is a
		// tactical-combat quirk). Consume both states so the key stays ours.
		local code = _key.getKey();
		if (!::UnseenBanner.EventNav.isActive() && !::UnseenBanner.MenuNav.isActive()
			&& ::UnseenBanner.WorldStatus.handles(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.WorldStatus.announce();
			}

			return true;
		}

		return __original(_key);
	}
});

// Combat log funnel (phase 3.1). Every combat line the game writes to the
// tactical event log passes through log() / logEx() on this module, so we tap
// both and forward the text to the companion. log_newline() is left alone: it
// only emits blank separators. hasBigButtons-style DOM scraping is unnecessary
// because the text arrives here already rendered and localized.
::UnseenBanner.Mod.hook("scripts/ui/screens/tactical/modules/topbar/tactical_screen_topbar_event_log", function(q) {
	q.log = @(__original) function( _text )
	{
		__original(_text);
		::UnseenBanner.CombatLog.onLine(_text);
	}

	q.logEx = @(__original) function( _text )
	{
		__original(_text);
		::UnseenBanner.CombatLog.onLine(_text);
	}
});

// Tile cursor (phase 3.2). onInit resets the cursor for each fresh battle.
// onKeyInput drives it: while it is the player's turn and input is free, the
// Q/W/E/A/S/D/X cluster moves the cursor instead of panning the camera. We
// consume both press and release of those keys (the vanilla camera pan fires
// on press) so panning never fights the cursor; the arrow keys are left alone,
// so a sighted tester can still pan. Every other key falls through untouched,
// including the number-row and numpad skill hotkeys.
::UnseenBanner.Mod.hook("scripts/states/tactical_state", function(q) {
	q.onInit = @(__original) function()
	{
		__original();
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.TileCursor.reset();
		::UnseenBanner.SheetNav.reset();
		::UnseenBanner.CombatResult.reset();
		::UnseenBanner.KeyGate.reset();
	}

	q.onFinish = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.CombatResult.reset();
		__original();
	}

	q.onKeyInput = @(__original) function( _key )
	{
		local code = _key.getKey();

		// Post-combat result screen. The state swallows every key once the battle
		// has ended (isBattleEnded short-circuits its own onKeyInput), so this must
		// run before every other cursor to keep list navigation and its buttons
		// reachable even if another UI module left stale navigation state behind.
		if (this.m.TacticalCombatResultScreen != null
			&& this.m.TacticalCombatResultScreen.isVisible()
			&& ::UnseenBanner.CombatResult.handles(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.CombatResult.onKey(code, this);
			}
			return true;
		}

		// The tactical pause menu uses the same modules as the other menu surfaces.
		// Consume both key states while one is up so native camera bindings cannot
		// leak through, but act only on release to avoid the press auto-repeat. The
		// arrow releases were verified to reach this hook even in tactical combat.
		if (::UnseenBanner.MenuNav.isActive() && ::UnseenBanner.MenuNav.handlesKey(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(code));
			}
			return true;
		}

		// Character screen (C/I) as a keyboard-navigable sheet. Up/Down walk the shown
		// brother's attribute list, Home/End jump to its boundaries, and the switch
		// keys change brother while retaining the current item. Only our nav keys are
		// stolen — close and start-battle keep their native behavior. This runs before
		// __original because the screen is shown from within this state, which swallows
		// the keyboard while it is up.
		if (this.isInCharacterScreen()
			&& ::UnseenBanner.SheetNav.isActive()
			&& ::UnseenBanner.SheetNav.handles(code))
		{
			// Act on the press (state 1), gated against auto-repeat: the screen pauses
			// the game and swallows the release of the brother-switch keys, so a
			// release-driven handler would never fire (see KeyGate). Consume both
			// states so no vanilla behavior leaks through.
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					if (::UnseenBanner.SheetNav.isMove(code))
					{
						::UnseenBanner.SheetNav.move(code);
					}
					else
					{
						local next = ::UnseenBanner.SheetNav.isNext(code);
						if (next) this.m.CharacterScreen.switchToNextBrother();
						else this.m.CharacterScreen.switchToPreviousBrother();
						::UnseenBanner.SheetNav.switchBrother(next);
					}
				}
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		local isCursorKey = ::UnseenBanner.TileCursor.handles(code);
		local isInspectKey = ::UnseenBanner.TileCursor.handlesInspect(code);
		local isActKey = ::UnseenBanner.Combat.handles(code);
		local isReadoutKey = ::UnseenBanner.Readout.handles(code);
		if ((isCursorKey || isInspectKey || isActKey || isReadoutKey)
			&& !this.isInLoadingScreen()
			&& !this.isBattleEnded()
			&& !this.isInCharacterScreen()
			&& !this.isInputLocked()
			&& !this.m.MenuStack.hasBacksteps())
		{
			local active = this.Tactical.TurnSequenceBar.getActiveEntity();
			if (active != null && active.isPlayerControlled())
			{
				// Act on the press (state 1), gated against auto-repeat: during active
				// combat the engine swallows the release of natively-bound keys (camera
				// pan Q/W/E/A/S/D, overlay toggles T/B), so a release-driven handler
				// only fires with a modifier held (see KeyGate). Consume both states so
				// no vanilla behavior (panning, toggles) leaks through on a held key.
				if (_key.getState() == 1)
				{
					if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
					{
						if (isCursorKey)
							::UnseenBanner.TileCursor.onKey(code, active, this.Tactical.Entities, (_key.getModifier() & 1) != 0, this);
						else if (isInspectKey)
							::UnseenBanner.TileCursor.inspect(active);
						else if (isActKey)
							::UnseenBanner.Combat.onKey(code, active, this, ::UnseenBanner.TileCursor.getTile(active));
						else
							::UnseenBanner.Readout.onKey(code, active, this.Tactical.Entities);
					}
				}
				else if (_key.getState() == 0)
				{
					::UnseenBanner.KeyGate.release(code);
				}
				return true;
			}
		}

		return __original(_key);
	}

	// Skill selection funnel (phase 3.3). Both the number/numpad hotkeys and
	// clicking a skill button end up in setActionStateBySkill, so it is the one
	// place to catch a skill being armed. cancelEntitySkill is the matching funnel
	// for a skill being let go (re-pressing its hotkey, right-click, or cancelling
	// the action), so the deselection is announced from there. Using a skill
	// (executeEntitySkill) clears the selection on its own without either funnel,
	// and its effect is already spoken by the combat log, so it stays silent here.
	q.setActionStateBySkill = @(__original) function( _activeEntity, _skill )
	{
		// Capture the id before __original runs: a non-targeted skill executes
		// inside it and its weak reference can go stale, so calling _skill.getID()
		// again afterwards throws and swallows the announcement.
		local skillID = _skill.getID();

		// A toggle-off (same skill, already selected) is a deselection handled by
		// cancelEntitySkill.
		local wasThisSelected = this.m.SelectedSkillID == skillID
			&& this.m.CurrentActionState == this.Const.Tactical.ActionState.SkillSelected;

		__original(_activeEntity, _skill);

		// Announce only once the skill is genuinely armed and awaiting a target —
		// which is exactly the targeted case 3.3 is about (valid targets + hit
		// chance before confirming). This also sidesteps every early-return in the
		// vanilla method (battle ended, mid-travel, mid-skill): those leave the
		// state untouched, so this condition stays false. A non-targeted skill
		// fires immediately (clearing SelectedSkillID, so this stays false) and is
		// narrated by the combat log instead; the armed skill is still live here.
		if (!wasThisSelected
			&& this.m.SelectedSkillID == skillID
			&& this.m.CurrentActionState == this.Const.Tactical.ActionState.SkillSelected)
		{
			::UnseenBanner.Combat.onSkillActivated(_skill, this);
		}
	}

	q.cancelEntitySkill = @(__original) function( _activeEntity )
	{
		local name = "";
		if (this.m.SelectedSkillID != null)
		{
			local skill = _activeEntity.getSkills().getSkillByID(this.m.SelectedSkillID);
			if (skill != null) name = skill.getName();
		}

		__original(_activeEntity);

		if (name != "")
		{
			::UnseenBanner.sendMessage("interrupt", name, "combat.skill.deselected");
		}
	}

	// Turn and round events (phase 3.5). A brother becoming active is the moment a
	// blind player most needs called out — the combat log narrates hits, morale,
	// wounds and deaths already, but never "it is now your turn". This funnel fires
	// exactly when an entity fully takes the first slot (and, for player units, is
	// where vanilla unlocks input), so it is the natural place to announce a turn.
	// Only player-controlled turns are spoken; narrating every enemy turn would
	// drown out the log. Queue channel: a turn event must not be dropped and should
	// fall in order with the combat lines around it.
	q.turnsequencebar_onEntityEnteredFirstSlotFully = @(__original) function( _entity )
	{
		__original(_entity);

		if (_entity != null && _entity.isPlayerControlled() && _entity.isAlive())
		{
			::UnseenBanner.sendMessage("queue", _entity.getName(), "combat.turn.player",
				"" + _entity.getActionPoints());
		}
	}

	q.turnsequencebar_onNextRound = @(__original) function( _round )
	{
		__original(_round);
		::UnseenBanner.sendMessage("queue", "" + _round, "combat.round");
	}

});

// Character sheet (the C/I screen). The screen's Visible flag flips only in
// onScreenShown — the asynchronous callback Coherent fires once the show
// animation is done — so hooking the state's showCharacterScreen and checking
// isVisible() right after show() never triggers (it is still false there; this
// exact bug ate the sheet readout once). onScreenShown/onScreenHidden are the
// deterministic points, the same pattern as the event and combat-result screens.
// The class is shared with the world's own character screen, so the tactical
// gate is ::Tactical.isActive(); the world sheet remains roadmap 2.2.
::UnseenBanner.Mod.hook("scripts/ui/screens/character/character_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();

		if (::Tactical.isActive())
		{
			// In battle the screen opens on the active brother; in battle
			// preparation there is none and SheetNav falls back to the first of
			// the roster — the same man the screen shows.
			::UnseenBanner.SheetNav.open(::Tactical.TurnSequenceBar.getActiveEntity());
		}
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.SheetNav.close();
	}
});

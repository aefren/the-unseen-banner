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
	CombatResult = null
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

::UnseenBanner.sendMessage <- function(_canal, _texto, _categoria = null, _valor = null, _detalle = null)
{
	local json = "{\"canal\":\"" + ::UnseenBanner.jsonEscape(_canal) + "\",\"texto\":\"" + ::UnseenBanner.jsonEscape(_texto) + "\"";
	if (_categoria != null) json += ",\"categoria\":\"" + ::UnseenBanner.jsonEscape(_categoria) + "\"";
	if (_valor != null) json += ",\"valor\":\"" + ::UnseenBanner.jsonEscape(_valor) + "\"";
	if (_detalle != null) json += ",\"detalle\":\"" + ::UnseenBanner.jsonEscape(_detalle) + "\"";
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
		ActiveModule = null,
		InMainMenuState = false
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
		return this.m.InMainMenuState && (this.m.ActiveModule == "MainMenuModule" || this.m.ActiveModule == "NewCampaignModule");
	},
	function enterMainMenuState()
	{
		this.m.InMainMenuState = true;
		this.m.ActiveModule = null;
	},
	function leaveMainMenuState()
	{
		this.m.InMainMenuState = false;
		this.m.ActiveModule = null;
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onStateExited", null);
		}
	},
	function onModuleShown(_id)
	{
		if (this.m.InMainMenuState && (_id == "MainMenuModule" || _id == "NewCampaignModule"))
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
		if (!this.m.InMainMenuState) return;

		// Main and New Campaign animate at the same time. Only the module that
		// is still active may clear the state when its hide animation finishes.
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
	function handles(_code)
	{
		return (_code in this.DirKeys) || (_code in this.RecenterKeys) || (_code in this.CycleKeys);
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

		local detail = kind + "|" + dist + "|" + dir;

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
	// t = active man's status, tab = turn order, b = visible enemies. t and b are
	// bound in vanilla to purely visual overlay toggles (skill trees / blocked
	// tiles); our hook consumes them during the player's turn, which a sighted
	// tester loses but a blind player never needs. tab is unbound in vanilla.
	Keys = {
		[30] = "status",   // t
		[38] = "turnorder", // tab
		[12] = "enemies"   // b
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
	// Attribute sheet of the man shown on the tactical character screen (C/I).
	// A first pass: it speaks the core attributes the sheet is built around, read
	// straight from the actor's current properties. Full per-brother navigation
	// and perks/equipment remain the larger DOM task (roadmap 2.4).
	function sheet(_active)
	{
		local p = _active.getCurrentProperties();
		local detail = _active.getHitpointsMax() + "|" + _active.getFatigueMax()
			+ "|" + p.getBravery() + "|" + p.getInitiative()
			+ "|" + p.getMeleeSkill() + "|" + p.getRangedSkill()
			+ "|" + p.getMeleeDefense() + "|" + p.getRangedDefense()
			+ "|" + _active.getArmor(::Const.BodyPart.Head)
			+ "|" + _active.getArmor(::Const.BodyPart.Body);
		::UnseenBanner.sendMessage("interrupt", _active.getName(), "combat.sheet", "", detail);
	}
};

// Post-combat result screen (the Victory/Defeat screen with its statistics and
// loot). Once the battle ends the tactical state swallows every key, so this
// screen is mouse-only in vanilla — unreachable by a blind player. Two halves:
// the whole screen is read aloud when it appears, and three keys make it
// operable — enter continues, l takes all the loot, r repeats the readout.
// The outcome line is the game's own rendered text (forwarded verbatim like the
// combat log); every other word is the companion's.
::UnseenBanner.CombatResult = {
	Keys = {
		[39] = "continue", // enter -> leave, same as the Continue button
		[22] = "lootall",  // l -> take all loot into the stash
		[28] = "repeat"    // r -> read the outcome and statistics again
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function onKey(_code, _state)
	{
		local screen = _state.m.TacticalCombatResultScreen;
		if (screen == null) return;

		local what = this.Keys[_code];
		if (what == "continue") screen.onLeaveButtonPressed();
		else if (what == "lootall") this.lootAll(screen);
		else if (what == "repeat") this.announce(screen);
	},
	function announce(_screen)
	{
		// Outcome first, as the game's own sentence ("Victory. The enemy was
		// destroyed in 3 rounds.").
		local info = _screen.onQueryCombatInformation();
		if (info != null)
		{
			local line = info.title;
			if (info.subTitle != null && info.subTitle != "") line += ". " + info.subTitle;
			::UnseenBanner.sendMessage("queue", line + ".");
		}

		// Casualties: the dead are not on the statistics panel (only survivors
		// are), yet losing a brother is the fact that matters most. Their deaths
		// were already narrated by the combat log, but a roll-up confirms it.
		local casualties = ::Tactical.getCasualtyRoster().getAll();
		local dead = "";
		local deadCount = 0;
		foreach( c in casualties )
		{
			if (c == null) continue;
			if (deadCount > 0) dead += "\n";
			dead += c.getName();
			deadCount += 1;
		}
		if (deadCount > 0)
		{
			::UnseenBanner.sendMessage("queue", dead, "combat.result.casualties", "" + deadCount);
		}

		// Per-survivor statistics, mirroring the panel: name, kills, xp, plus
		// whether they levelled up or came out wounded. One tab-separated line
		// each (names never contain tabs), newline between them.
		local roster = ::Tactical.CombatResultRoster;
		local stats = "";
		local statCount = 0;
		if (roster != null)
		{
			foreach( bro in roster )
			{
				if (bro == null) continue;
				local cs = bro.getCombatStats();
				local level = bro.isLeveled() ? "1" : "0";
				local wound = bro.getDaysWounded() > 0 ? "1" : "0";
				if (statCount > 0) stats += "\n";
				stats += bro.getName() + "\t" + cs.Kills + "\t" + cs.XPGained + "\t" + level + "\t" + wound;
				statCount += 1;
			}
		}
		if (statCount > 0)
		{
			::UnseenBanner.sendMessage("queue", stats, "combat.result.stats");
		}

		this.announceLoot(_screen);
	},
	function announceLoot(_screen)
	{
		local items = ::Tactical.CombatResultLoot.getItems();
		local loot = "";
		local lootCount = 0;
		if (items != null)
		{
			foreach( item in items )
			{
				if (item == null) continue;
				if (lootCount > 0) loot += "\n";
				loot += item.getName();
				lootCount += 1;
			}
		}

		if (lootCount == 0)
		{
			::UnseenBanner.sendMessage("queue", "", "combat.result.loot.none");
		}
		else
		{
			::UnseenBanner.sendMessage("queue", loot, "combat.result.loot", "" + lootCount);
		}

		// Close with the key hint so a first-time player knows the screen is
		// operable and how. Cheap to repeat on the r key.
		::UnseenBanner.sendMessage("queue", "", "combat.result.hint");
	},
	function lootAll(_screen)
	{
		if (::Tactical.CombatResultLoot.isEmpty())
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.result.loot.none");
			return;
		}

		// Same call the vanilla "loot all" button makes; it moves what fits into
		// the stash. Report by whether anything is left rather than by parsing its
		// UI-data return, so a full stash is called out.
		_screen.onLootAllItemsButtonPressed();

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

// Engine key codes (see MSU's KeyMapSQ, the reference for this enum).
// Tunable/remappable keys should eventually go through MSU keybinds and its
// settings UI (roadmap fase 5, "toda constante afinable va a config").
::UnseenBanner.KeyCodes <- {
	[39] = "enter",
	[49] = "up",
	[51] = "down"
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
		::UnseenBanner.MenuNav.enterMainMenuState();
		__original();
	}

	q.onFinish = @(__original) function()
	{
		::UnseenBanner.MenuNav.leaveMainMenuState();
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
			&& _key.getKey() in ::UnseenBanner.KeyCodes
			&& ::UnseenBanner.MenuNav.isActive()
			&& this.isKeyInputPermitted())
		{
			::UnseenBanner.MenuNav.sendKey(::UnseenBanner.KeyCodes[_key.getKey()]);
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
// at which the screen is fully up (same pattern as the event screen), so the
// outcome, casualties, per-survivor statistics and loot are read there. The keys
// that operate it are handled from tactical_state.onKeyInput above, since that is
// where the engine routes keyboard while the battle is ending.
::UnseenBanner.Mod.hook("scripts/ui/screens/tactical/tactical_combat_result_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.CombatResult.announce(this);
	}
});

// The event screen has no state of its own; it is shown inside world_state, so
// its keyboard cursor is driven from world_state.onKeyInput. Up/Down/Enter are
// stolen only while the event is up; every other key (including the native 1-6
// button shortcuts) keeps its normal behavior.
::UnseenBanner.Mod.hook("scripts/states/world_state", function(q) {
	q.onKeyInput = @(__original) function( _key )
	{
		if (_key.getState() == 0
			&& _key.getKey() in ::UnseenBanner.KeyCodes
			&& ::UnseenBanner.EventNav.isActive())
		{
			::UnseenBanner.EventNav.sendKey(::UnseenBanner.KeyCodes[_key.getKey()]);
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
		::UnseenBanner.TileCursor.reset();
	}

	q.onKeyInput = @(__original) function( _key )
	{
		local code = _key.getKey();

		// Post-combat result screen. The state swallows every key once the battle
		// has ended (isBattleEnded short-circuits its own onKeyInput), so this must
		// run before __original to keep Continue / loot / repeat reachable.
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

		local isCursorKey = ::UnseenBanner.TileCursor.handles(code);
		local isActKey = ::UnseenBanner.Combat.handles(code);
		local isReadoutKey = ::UnseenBanner.Readout.handles(code);
		if ((isCursorKey || isActKey || isReadoutKey)
			&& !this.isInLoadingScreen()
			&& !this.isBattleEnded()
			&& !this.isInCharacterScreen()
			&& !this.isInputLocked()
			&& !this.m.MenuStack.hasBacksteps())
		{
			local active = this.Tactical.TurnSequenceBar.getActiveEntity();
			if (active != null && active.isPlayerControlled())
			{
				// Act on release only (state 0), matching the cursor keys, so a
				// held key never fires the action twice; the press is still
				// consumed so no vanilla behavior leaks through.
				if (_key.getState() == 0)
				{
					if (isCursorKey)
						::UnseenBanner.TileCursor.onKey(code, active, this.Tactical.Entities, (_key.getModifier() & 1) != 0, this);
					else if (isActKey)
						::UnseenBanner.Combat.onKey(code, active, this, ::UnseenBanner.TileCursor.getTile(active));
					else
						::UnseenBanner.Readout.onKey(code, active, this.Tactical.Entities);
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

	// Character sheet readout (the C/I screen). The tactical screen only opens it
	// for the active, player-controlled brother, so that is who we read. Announced
	// straight from Squirrel actor APIs — the DOM sheet is unreadable, but the same
	// facts it is built from are all queryable here.
	q.showCharacterScreen = @(__original) function( _forced = false )
	{
		local wasVisible = this.m.CharacterScreen.isVisible();
		__original(_forced);

		if (!wasVisible && this.m.CharacterScreen.isVisible())
		{
			local active = this.Tactical.TurnSequenceBar.getActiveEntity();
			if (active != null && active.isPlayerControlled())
			{
				::UnseenBanner.Readout.sheet(active);
			}
		}
	}
});


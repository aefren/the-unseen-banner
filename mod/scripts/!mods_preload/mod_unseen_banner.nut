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
	SheetNav = null,
	WorldCombatDialogNav = null,
	DialogNav = null,
	TacticalDialogNav = null,
	TooltipNav = null
};

::UnseenBanner.Mod = ::Hooks.register(::UnseenBanner.ID, ::UnseenBanner.Version, ::UnseenBanner.Name);
::UnseenBanner.Mod.require("mod_modern_hooks >= 0.6.0");

::Hooks.registerJS("ui/mods/mod_unseen_banner/smoke_test.js");
::Hooks.registerJS("ui/mods/mod_unseen_banner/menu_nav.js");
::Hooks.registerJS("ui/mods/mod_unseen_banner/event_nav.js");
::Hooks.registerJS("ui/mods/mod_unseen_banner/retinue_nav.js");
::Hooks.registerJS("ui/mods/mod_unseen_banner/tooltip_nav.js");
::Hooks.registerJS("ui/mods/mod_unseen_banner/character_edit_nav.js");
::Hooks.registerJS("ui/mods/mod_unseen_banner/world_combat_dialog_nav.js");
::Hooks.registerCSS("ui/mods/mod_unseen_banner/menu_nav.css");

// Single choke point for every message sent to the companion app, so the
// bridge protocol (docs/arquitectura-propuesta-y-roadmap.md, "Protocolo de
// mensajes") is encoded in exactly one place instead of once per hook.
// Plan B bridge (tarea 0.4): written via ::logInfo into log.html, which the
// companion tails and parses looking for this marker.
::UnseenBanner.jsonEscape <- function(_s)
{
	// Coerce anything non-string to its string form first: some game IDs (e.g. a
	// contract's getID()) are integers, and calling .len()/.slice() on an int throws
	// ("the index 'len' does not exist"), which aborts the whole announcement. Every
	// field of the message protocol is a JSON string, so this is always the right thing.
	if (typeof _s != "string") _s = "" + _s;
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

::UnseenBanner.sendMessage <- function(_canal, _texto, _categoria = null, _valor = null, _detalle = null, _hermano = null, _detalles = null, _contexto = null, _acciones = null, _comparacion = null)
{
	local json = "{\"canal\":\"" + ::UnseenBanner.jsonEscape(_canal) + "\",\"texto\":\"" + ::UnseenBanner.jsonEscape(_texto) + "\"";
	if (_categoria != null) json += ",\"categoria\":\"" + ::UnseenBanner.jsonEscape(_categoria) + "\"";
	if (_valor != null) json += ",\"valor\":\"" + ::UnseenBanner.jsonEscape(_valor) + "\"";
	if (_detalle != null) json += ",\"detalle\":\"" + ::UnseenBanner.jsonEscape(_detalle) + "\"";
	if (_hermano != null) json += ",\"hermano\":\"" + ::UnseenBanner.jsonEscape(_hermano) + "\"";
	if (_detalles != null) json += ",\"detalles\":\"" + ::UnseenBanner.jsonEscape(_detalles) + "\"";
	if (_contexto != null) json += ",\"contexto\":\"" + ::UnseenBanner.jsonEscape(_contexto) + "\"";
	if (_acciones != null) json += ",\"acciones\":\"" + ::UnseenBanner.jsonEscape(_acciones) + "\"";
	if (_comparacion != null) json += ",\"comparacion\":\"" + ::UnseenBanner.jsonEscape(_comparacion) + "\"";
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

// Generic tooltip funnel (phase 2.1). Nothing here depends on hover or a mouse:
// an accessible cursor asks JS to show one native tooltip by its stable game ID,
// tooltip_nav.js lets vanilla query and render it, then reads the final localized
// DOM. Ordinary visual hovers remain silent. Squirrel owns no tooltip wording;
// it only forwards the rendered snapshot to central cleanup/L10n.
::UnseenBanner.TooltipNav = {
	m = {
		JSHandle = null
	},
	function connect()
	{
		this.m.JSHandle = ::UI.connect("UnseenBannerTooltipNav", this);
	},
	function show(_tooltip, _index, _total, _group)
	{
		if (this.m.JSHandle == null || _tooltip == null) return;
		this.m.JSHandle.asyncCall("showDetail", {
			tooltip = _tooltip,
			indice = _index,
			total = _total,
			grupo = _group
		});
	},
	function hide()
	{
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("hideDetail", null);
		}
	},
	// Keep the visible native CharacterScreen tab synchronized with the semantic
	// section selected by Page Up/Down. This only toggles vanilla's Inventory/Perks
	// panels; it never clicks, equips, spends a point or mutates game state.
	function showCharacterSection(_section)
	{
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("showCharacterSection", _section);
		}
	},
	function onTooltipHookReady()
	{
		::logInfo("UnseenBanner: generic rendered-DOM tooltip hook is ready.");
	},
	// Receives a single table because SQ.call transports one args value.
	function onTooltipAnnouncement(_data)
	{
		if (_data == null || !("texto" in _data) || _data.texto == "") return;
		local index = "indice" in _data ? "" + _data.indice : "1";
		local total = "total" in _data ? "" + _data.total : "1";
		local group = "grupo" in _data ? _data.grupo : "";
		if (total.tointeger() > 1)
		{
			::UnseenBanner.sendMessage("interrupt", _data.texto, "tooltip.detail",
				index, total + "|" + group);
		}
		else
		{
			::UnseenBanner.sendMessage("interrupt", _data.texto, "tooltip.content");
		}
	},
	function onTooltipUnavailable()
	{
		::UnseenBanner.sendMessage("interrupt", "", "tooltip.unavailable");
	}
};

// Native name editor bridge. The CharacterScreen already owns a fully functional
// Change Name & Title popup and routes focused text input through the engine. This
// bridge only opens that popup from SheetNav, selects the current name for quick
// replacement and reports save/cancel; the native datasource remains responsible
// for validation, persistence and updating every visible roster label.
::UnseenBanner.CharacterEdit <- {
	m = {
		JSHandle = null,
		Active = false,
		OriginalName = "",
		SuppressNextEnterRelease = false
	},
	function connect()
	{
		this.m.JSHandle = ::UI.connect("UnseenBannerCharacterEdit", this);
	},
	function isActive()
	{
		return this.m.Active;
	},
	function onEditorConfirming()
	{
		// The native popup saves on Enter's press. Its later release returns to
		// world_state after the popup has disappeared; suppress that release so it
		// cannot be mistaken for a fresh request to open the editor again.
		this.m.SuppressNextEnterRelease = true;
	},
	function consumeSuppressedEnterRelease()
	{
		if (!this.m.SuppressNextEnterRelease) return false;
		this.m.SuppressNextEnterRelease = false;
		return true;
	},
	function open(_bro)
	{
		if (this.m.Active) return;
		if (this.m.JSHandle == null || _bro == null)
		{
			this.onEditorUnavailable();
			return;
		}
		this.m.Active = true;
		this.m.OriginalName = _bro.getName();
		this.m.JSHandle.asyncCall("openNameEditor", {
			entityId = _bro.getID()
		});
	},
	function onEditorOpened()
	{
		if (!this.m.Active) return;
		::UnseenBanner.sendMessage("interrupt", this.m.OriginalName,
			"world.character.rename.opened");
	},
	function onEditorUnavailable()
	{
		this.m.Active = false;
		this.m.OriginalName = "";
		::UnseenBanner.sendMessage("interrupt", "",
			"world.character.rename.unavailable");
	},
	function onEditorClosed(_data)
	{
		if (!this.m.Active) return;
		local original = this.m.OriginalName;
		this.m.Active = false;
		this.m.OriginalName = "";

		if (_data != null && "saved" in _data && _data.saved
			&& "name" in _data && _data.name != "")
		{
			::UnseenBanner.SheetNav.onNameEdited(_data.name);
			::UnseenBanner.sendMessage("interrupt", original,
				"world.character.rename.saved", _data.name);
		}
		else
		{
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.rename.cancelled");
		}
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

// Active-contract objectives (phase 4.4). The world panel is fed by
// contract.getUIBulletpoints(), whose objective texts have already passed through
// contract.buildText() (town/employer placeholders resolved) and are exactly the
// source rendered on screen. Keep the last rendered signature so the common panel
// refresh funnel can announce genuine changes without speaking on every redraw.
::UnseenBanner.ContractObjectives <- {
	m = {
		ContractID = null,
		Signature = null
	},
	function reset()
	{
		this.m.ContractID = null;
		this.m.Signature = null;
	},
	function getTexts(_contract)
	{
		local texts = [];
		if (_contract == null) return texts;

		// Request objectives only; payment is useful contract detail but does not
		// answer the immediate "what do I do next?" question this readout solves.
		local lists = _contract.getUIBulletpoints(true, false);
		if (lists == null) return texts;

		foreach( list in lists )
		{
			if (list == null || list.items == null) continue;
			foreach( item in list.items )
			{
				if (item != null && item.text != null && item.text != "")
					texts.push(item.text);
			}
		}
		return texts;
	},
	function join(_texts)
	{
		local out = "";
		foreach( i, text in _texts )
		{
			if (i > 0) out += "\n";
			out += text;
		}
		return out;
	},
	function observe(_contract)
	{
		if (_contract == null)
		{
			this.reset();
			return;
		}

		local texts = this.getTexts(_contract);
		local id = "" + _contract.getID();
		local joined = this.join(texts);
		local signature = id + "\n" + joined;
		if (this.m.Signature == signature) return;

		local isUpdate = this.m.Signature != null && this.m.ContractID == id;
		this.m.ContractID = id;
		this.m.Signature = signature;

		// An objective change is a game event, not cursor focus: queue it so it
		// cannot cut off another result/event announcement. Empty objectives are
		// kept in the signature but stay silent; contract completion has its own UI.
		if (texts.len() == 0) return;
		local category = isUpdate
			? (texts.len() == 1 ? "world.status.objectives.updated.one" : "world.status.objectives.updated")
			: (texts.len() == 1 ? "world.status.objectives.current.one" : "world.status.objectives.current");
		::UnseenBanner.sendMessage("queue", joined, category);
	}
};

// World-map company/campaign readout (phase 4.4). The map's topbar status is a
// short semantic list: day and time of day, brother count, crowns, daily wages,
// food, days of food, and the active contract with its current objectives. Pull,
// not push: G opens/closes the list and Up/Down read one fact at a time. Every
// fact is a Squirrel API (World.Assets / World.getTime / World.Contracts / the
// player roster), so nothing is scraped from the DOM; the companion owns the
// framing words.
//
// Key: g (code 17). g is unbound on the world map in vanilla — the letters the
// map already claims are c/f/i/o/p/r/t (character, ?, inventory, obituary, perks,
// relations, camp). Eventually remappable through MSU keybinds (roadmap fase 5).
::UnseenBanner.WorldStatus <- {
	m = {
		Items = null,
		ItemIndex = 0,
		Active = false
	},
	ToggleKey = 17, // g
	MoveKeys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end"
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return _code == this.ToggleKey || (this.m.Active && _code in this.MoveKeys);
	},
	function reset()
	{
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
	},
	function item(_cat, _texto = "", _valor = "", _detalle = "")
	{
		return { cat = _cat, texto = _texto, valor = _valor, detalle = _detalle };
	},
	function open()
	{
		local assets = ::World.Assets;
		local money = assets.getMoney();
		local dailyMoney = assets.getDailyMoneyCost();
		local food = assets.getFood();
		local dailyFood = assets.getDailyFoodCost();
		// Days of food left at the current rate; -1 signals "no upkeep" (an empty
		// roster) so it gets a meaningful row without dividing by zero.
		local foodDays = dailyFood > 0 ? (food / dailyFood).tointeger() : -1;
		local brothers = ::World.getPlayerRoster().getSize();

		local time = ::World.getTime();
		local day = time.Days;
		local timeCat = time.IsDaytime ? "world.status.time.day" : "world.status.time.night";

		// Contract titles carry BBCode/colour markup, so they ride in `texto`, the
		// field the companion runs through clean() before speaking.
		local contract = ::World.Contracts.getActiveContract();
		local title = contract != null ? contract.getTitle() : "";

		local items = [];
		items.push(this.item("world.status.screen"));
		items.push(this.item(timeCat, "", "" + day));
		items.push(this.item(brothers == 1 ? "world.status.brothers.one" : "world.status.brothers", "", "" + brothers));
		items.push(this.item("world.status.money", "", "" + money));
		items.push(this.item("world.status.wages", "", "" + dailyMoney));
		items.push(this.item("world.status.food", "", "" + food));
		if (foodDays < 0) items.push(this.item("world.status.food.none"));
		else items.push(this.item(foodDays == 1 ? "world.status.food.day" : "world.status.food.days", "", "" + foodDays));
		items.push(this.item(contract != null ? "world.status.contract" : "world.status.contract.none", title));
		if (contract != null)
		{
			local objectives = ::UnseenBanner.ContractObjectives.getTexts(contract);
			if (objectives.len() == 0)
				items.push(this.item("world.status.objectives.none"));
			else
				foreach( objective in objectives )
					items.push(this.item("world.status.objective", objective));
		}

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem();
	},
	function close(_announce = false)
	{
		this.reset();
		if (_announce) ::UnseenBanner.sendMessage("interrupt", "", "world.status.closed");
	},
	function onKey(_code)
	{
		if (_code == this.ToggleKey)
		{
			if (this.m.Active) this.close(true);
			else this.open();
			return;
		}

		if (!this.m.Active || !(_code in this.MoveKeys)) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.ItemIndex -= 1;
		else if (dir == "down") this.m.ItemIndex += 1;
		else if (dir == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
	}
};

// World-map perception readout (phase 4.3, "what's in view"). The text precursor to
// the sonar (4.1): a navigable list of everything the player can perceive on the map
// — visible parties (threats, caravans, allies), known settlements and known
// locations (camps, ruins, sites) — each with its kind, distance in hex tiles and a
// clock bearing from the party. Pull, not push: B opens/closes the list and Up/Down
// read one entry at a time, exactly like WorldStatus (a navigable list, never a single
// Tolk dump). Fog of war is honoured (roadmap 4.2): parties must be currently in sight
// (the same isHiddenToPlayer / visibility test the mouse click uses), settlements and
// locations must have their tile discovered. Producing this typed classification here
// is precisely what the sonar will later reuse to pick a sound per category, which is
// why the world is done by text first.
//
// Key: b (code 12), free on the world map in vanilla (the map claims c/f/i/o/p/r/t and
// G is our company status). Mutually exclusive with WorldStatus so Up/Down never has
// two owners: opening one closes the other (done in the world_state hook). Enter acts
// on the focused row: it pursues an enemy party, or approaches/enters a settlement or
// location through the same AutoAttack/AutoEnterLocation funnels as a mouse click.
::UnseenBanner.WorldSurvey <- {
	m = {
		Items = null,
		ItemIndex = 0,
		Active = false,
		// Detail mode: when non-null, V has drilled into the focused entity and Detail
		// holds its flattened tooltip as its own navigable sub-list. The survey list and
		// its index are kept underneath so V again restores exactly where the player was.
		Detail = null,
		DetailIndex = 0
	},
	ToggleKey = 12, // b
	InspectKey = 32, // v -> inspect the focused entity (toggles the detail sub-list)
	InteractKey = 39, // enter -> pursue/enter the focused world entity
	MoveKeys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end"
	},
	// Radius of the party scan, in world units. 400 is the wide sweep the event and
	// ambition managers use to find nearby parties (event_manager.nut), comfortably
	// past the player's own vision radius; the isHiddenToPlayer filter below is what
	// actually enforces sight, so this only needs to be generous.
	ScanRadius = 400.0,
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return _code == this.ToggleKey
			|| (this.m.Active && (_code == this.InspectKey
				|| _code == this.InteractKey || _code in this.MoveKeys));
	},
	function reset()
	{
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
		this.m.Detail = null;
		this.m.DetailIndex = 0;
	},
	function inDetail()
	{
		return this.m.Detail != null;
	},
	function item(_cat, _texto = "", _valor = "", _detalle = "", _entity = null)
	{
		return { cat = _cat, texto = _texto, valor = _valor, detalle = _detalle, entity = _entity };
	},
	// Distance in hex tiles and the clock bearing (hex direction 0-5) from the player
	// to a target tile, packed as "dist|dir" for the companion — the same encoding the
	// tactical tile readout uses, so the companion's ComposePosition is reused verbatim.
	function posDetail(_playerTile, _tile)
	{
		local dist = _playerTile.getDistanceTo(_tile);
		local dir = dist > 0 ? _playerTile.getDirectionTo(_tile) : -1;
		return dist + "|" + dir;
	},
	// Sort a list of { e, d } records nearest-first (ascending hex distance).
	function sortByDistance(_scored)
	{
		_scored.sort(function ( _a, _b )
		{
			if (_a.d > _b.d) return 1;
			if (_a.d < _b.d) return -1;
			return 0;
		});
	},
	function open()
	{
		local player = ::World.State.getPlayer();
		local playerTile = player.getTile();
		local playerID = player.getID();
		local playerPos = player.getPos();

		// Visible parties: everything the mouse click would let you interact with —
		// in sight (not hidden by fog), with non-zero visibility. Kind splits into
		// ally / enemy (attackable and not allied) / neutral (a caravan, say).
		local parties = [];
		foreach( e in ::World.getAllEntitiesAtPos(playerPos, this.ScanRadius) )
		{
			if (e == null || !e.isParty() || e.getID() == playerID) continue;
			if (e.isHiddenToPlayer() || e.getVisibilityMult() <= 0.0) continue;
			if (e.getTile() == null) continue;
			parties.push({ e = e, d = playerTile.getDistanceTo(e.getTile()) });
		}
		this.sortByDistance(parties);

		// Known settlements: static, so "discovered" (the game's own per-entity fog
		// flag, isDiscovered — the one it gates onEnter and discovery events on) is the
		// useful set for navigation. NB: the tile's IsDiscovered flag is a different
		// thing (per-tile fog reveal) and is set map-wide for settlement/location tiles
		// from the start, so filtering on it listed the whole map (145 entries on day 1).
		local settlements = [];
		foreach( s in ::World.EntityManager.getSettlements() )
		{
			if (s == null || !s.isAlive() || s.getTile() == null) continue;
			if (!s.isDiscovered()) continue;
			settlements.push({ e = s, d = playerTile.getDistanceTo(s.getTile()) });
		}
		this.sortByDistance(settlements);

		// Known, active locations (camps, ruins, legendary sites); undiscovered or
		// inactive ones are left out for the same fog-of-war parity (roadmap 4.2).
		local locations = [];
		foreach( l in ::World.EntityManager.getLocations() )
		{
			if (l == null || !l.isAlive() || !l.isActive() || l.getTile() == null) continue;
			if (!l.isDiscovered()) continue;
			locations.push({ e = l, d = playerTile.getDistanceTo(l.getTile()) });
		}
		this.sortByDistance(locations);

		local items = [];
		// Header first: the three counts, so the player hears the shape of what is
		// around before walking the list (parties|settlements|locations).
		items.push(this.item("world.survey.screen", "", "",
			parties.len() + "|" + settlements.len() + "|" + locations.len()));

		// Parties first (threats matter most, mirroring the sonar hierarchy), then
		// settlements, then locations; each group already nearest-first. Each row keeps a
		// reference to its entity so V can pull the live tooltip on demand.
		foreach( r in parties )
		{
			local e = r.e;
			local kind = e.isAlliedWithPlayer() ? "ally" : (e.isAttackable() ? "enemy" : "neutral");
			items.push(this.item("world.survey.item", e.getName(), kind, this.posDetail(playerTile, e.getTile()), e));
		}
		foreach( r in settlements )
		{
			items.push(this.item("world.survey.item", r.e.getName(), "settlement", this.posDetail(playerTile, r.e.getTile()), r.e));
		}
		foreach( r in locations )
		{
			items.push(this.item("world.survey.item", r.e.getName(), "location", this.posDetail(playerTile, r.e.getTile()), r.e));
		}

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem();
	},
	function close(_announce = false)
	{
		this.reset();
		if (_announce) ::UnseenBanner.sendMessage("interrupt", "", "world.survey.closed");
	},
	function onKey(_code, _state = null)
	{
		if (_code == this.ToggleKey)
		{
			if (this.m.Active) this.close(true);
			else this.open();
			return;
		}

		if (!this.m.Active) return;

		// V drills into the focused entity, or backs out of the detail sub-list.
		if (_code == this.InspectKey)
		{
			if (this.inDetail()) this.exitDetail();
			else this.inspect();
			return;
		}

		// Enter acts on the entity row underneath the optional detail sub-list. Keeping
		// that target stable means the player may inspect a camp or party with V and
		// engage it directly without first backing out. A successful order closes B so
		// map input is immediately available again; a stale/non-interactable row stays
		// open after its explanatory cue.
		if (_code == this.InteractKey)
		{
			local it = this.m.Items[this.m.ItemIndex];
			if (it.entity == null)
			{
				::UnseenBanner.sendMessage("interrupt", "", "world.interact.none");
				return;
			}
			// Use the actual world_state object supplied by its input hook. World.State
			// is a WeakTableRef proxy; calling native methods such as enterLocation
			// through that proxy changes their `this` and hides engine helpers.
			local state = _state != null ? _state : ::World.State;
			if (::UnseenBanner.WorldEnter.tryInteract(state, it.entity))
			{
				this.reset();
			}
			return;
		}

		if (!(_code in this.MoveKeys)) return;

		// Move within whichever list is active: the entity detail while inspecting, else
		// the survey list.
		local items = this.inDetail() ? this.m.Detail : this.m.Items;
		if (items == null || items.len() == 0) return;
		local idx = this.inDetail() ? this.m.DetailIndex : this.m.ItemIndex;

		local dir = this.MoveKeys[_code];
		if (dir == "up") idx -= 1;
		else if (dir == "down") idx += 1;
		else if (dir == "home") idx = 0;
		else idx = items.len() - 1;

		if (idx < 0) idx = 0;
		if (idx >= items.len()) idx = items.len() - 1;

		if (this.inDetail()) this.m.DetailIndex = idx;
		else this.m.ItemIndex = idx;
		this.announceItem();
	},
	// Drill into the focused survey entity: pull its live tooltip and present it as a
	// navigable sub-list (V again backs out). The header row has no entity; a party that
	// died or dropped out of sight since the list was built is reported gone rather than
	// throwing.
	function inspect()
	{
		local it = this.m.Items[this.m.ItemIndex];
		if (it.entity == null)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.inspect.none");
			return;
		}
		if (!it.entity.isAlive())
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.inspect.gone");
			return;
		}

		local lines = this.buildDetail(it.entity);
		local detail = [];
		// Header first (a nav hint), then one line per non-empty tooltip entry.
		detail.push(this.item("world.inspect.screen", "", "" + lines.len()));
		foreach( t in lines ) detail.push(this.item("world.inspect.item", t));

		this.m.Detail = detail;
		this.m.DetailIndex = 0;
		this.announceItem();
	},
	function exitDetail()
	{
		this.m.Detail = null;
		this.m.DetailIndex = 0;
		this.announceItem(); // re-announce the survey row we drilled from
	},
	// Flatten an entity's tooltip (the same funnel the mouse hover uses) into plain text
	// lines, dropping empties. Title, description, troop composition, faction hints — all
	// already localized game text; the companion's clean() strips their BBCode and icons.
	function buildDetail(_entity)
	{
		local lines = [];
		local tt = _entity.getTooltip();
		if (tt == null) return lines;
		foreach( e in tt )
		{
			if (e == null || !("text" in e)) continue;
			local t = e.text;
			if (t == null || t == "") continue;
			lines.push(t);
		}
		return lines;
	},
	function announceItem()
	{
		local items = this.inDetail() ? this.m.Detail : this.m.Items;
		if (items == null || items.len() == 0) return;
		local idx = this.inDetail() ? this.m.DetailIndex : this.m.ItemIndex;
		local it = items[idx];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
	}
};

// World-map directional movement (phase 4.0). The overworld is hexagonal like the
// battlefield (6 neighbours), so the party is walked with the same Q/W/E/A/S/D
// cluster the tactical tile cursor uses (W=N, E=NE, D=SE, S=S, A=SW, Q=NW). Each
// step is issued through the engine's own navigator exactly as a mouse click would
// (findPath + setPath, world_state.onMouseInput), never a teleport — so terrain
// cost, roads and passability are the game's, not ours. That also gives a clean
// completion signal: the party clears its path when it arrives (party.onUpdate), so
// !hasPath() means the step is done.
//
// Semantics (decided jul 2026): a short tap = one tile; holding the key keeps
// walking; Shift+dir latches a continuous march; Space (the vanilla pause key)
// brakes and pauses. Movement is announced — the terrain of a tile is spoken when it
// changes as the party walks, and a distinct "Stopped" cue is spoken when the order
// completes (a single step, a release, a brake or an obstacle), so a blind player
// always knows the order finished. The same arrival machinery will serve the future
// auto-walk-to-a-place order (roadmap 4.3 beacon).
//
// The engine advances party movement on VIRTUAL time, which is frozen while paused,
// so issuing a step unpauses the game (Space pauses it back). Q/W/A/S/D double as the
// vanilla camera pan (fired on key press); we consume both key states so panning
// never competes, exactly like the tactical cursor. Driven from world_state:
// onKeyInput starts/stops steps, onUpdate polls for arrival.
::UnseenBanner.WorldMove <- {
	m = {
		Heading = -1,      // hex dir 0-5 currently being walked, -1 = idle
		HeadingKey = -1,   // engine code that set Heading, to match its own release
		Continuous = false, // Shift-latched march: ignore the key release, walk on
		Pending = false,   // a step path is in flight (we set it, not yet arrived)
		Blocked = false,   // the current heading hit a wall; hold intent but stop trying
		LastTerrain = -1,  // last terrain type announced, so only changes are spoken
		SelfUnpause = false // set while WE unpause to move, so the pause hook stays quiet
	},
	// Engine key code -> hex direction (Const.Direction: N=0, NE=1, SE=2, S=3, SW=4,
	// NW=5), the same mapping as the tactical tile cursor for shared muscle memory.
	DirKeys = {
		[33] = 0,   // w  -> N
		[15] = 1,   // e  -> NE
		[14] = 2,   // d  -> SE
		[29] = 3,   // s  -> S
		[11] = 4,   // a  -> SW
		[27] = 5    // q  -> NW
	},
	// The vanilla pause toggles (space and its aliases); we brake our march on these
	// and let the native pause toggle run.
	BrakeKeys = {
		[42] = true,
		[40] = true,
		[10] = true
	},
	function handlesDir(_code)
	{
		return _code in this.DirKeys;
	},
	function handlesBrake(_code)
	{
		return _code in this.BrakeKeys;
	},
	function isMoving()
	{
		return this.m.Heading != -1 || this.m.Pending;
	},
	// Clears only our own bookkeeping; does NOT touch the party (which may not exist
	// yet at state init). Used on entering/leaving the world state.
	function reset()
	{
		this.m.Heading = -1;
		this.m.HeadingKey = -1;
		this.m.Continuous = false;
		this.m.Pending = false;
		this.m.Blocked = false;
		this.m.LastTerrain = -1;
		this.m.SelfUnpause = false;
	},
	function clearHeading()
	{
		this.m.Heading = -1;
		this.m.HeadingKey = -1;
		this.m.Continuous = false;
		this.m.Blocked = false;
	},
	// Start one hex step in _dir via the navigator, mirroring the mouse click's own
	// settings. Returns true if a step is now in flight; false (with an announcement)
	// when the neighbour is off the map or the navigator finds no way onto it (ocean,
	// impassable) — the same passability the mouse obeys.
	function issueStep(_dir)
	{
		local player = ::World.State.getPlayer();
		if (player == null) return false;

		local from = player.getTile();
		if (!from.hasNextTile(_dir))
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.move.edge");
			return false;
		}

		local to = from.getNextTile(_dir);
		local nav = ::World.getNavigator();
		local settings = nav.createSettings();
		settings.ActionPointCosts = ::Const.World.TerrainTypeNavCost;
		settings.RoadMult = 1.0 / ::Const.World.MovementSettings.RoadMult;
		local path = nav.findPath(from, to, settings, 0);

		if (path.isEmpty())
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.move.blocked");
			return false;
		}

		player.setPath(path);
		this.m.Pending = true;

		// Movement runs on virtual time, frozen while paused; unpause so the party
		// actually walks. Space pauses it back and brakes (onBrake). Flag it as our own
		// unpause so the setPause hook does not announce "Unpaused" on every step.
		if (::World.State.isPaused())
		{
			this.m.SelfUnpause = true;
			::World.State.setPause(false);
		}
		return true;
	},
	// A direction key was pressed. Set the heading (Shift latches a march) and, if no
	// step is already in flight, start one now. The key auto-repeats while held (that
	// is how the vanilla camera pans): a repeat of the same key must not start a second
	// step nor re-announce a wall, so it is a no-op while a step is pending or the way
	// is already known blocked. LastTerrain being -1 marks "idle", so the origin tile
	// is captured once at the start of a fresh move and only later terrain changes are
	// spoken.
	function onDirKey(_code, _shift)
	{
		local isRepeat = (_code == this.m.HeadingKey);
		this.m.Heading = this.DirKeys[_code];
		this.m.HeadingKey = _code;
		this.m.Continuous = _shift;

		if (this.m.Pending) return;
		if (isRepeat && this.m.Blocked) return;

		if (this.m.LastTerrain == -1)
		{
			local player = ::World.State.getPlayer();
			if (player != null) this.m.LastTerrain = player.getTile().Type;
		}
		this.m.Blocked = !this.issueStep(this.m.Heading);
	},
	// A direction key was released. A plain hold stops chaining once the current step
	// lands; a Shift-latched march ignores the release and walks on until braked. Only
	// the key that owns the current heading clears it, so releasing an older key does
	// not cancel a newer heading. If nothing is in flight (idle, or stuck at a wall
	// already announced), just go quiet — the completion cue only fires for a step that
	// was actually travelling (handled in onArrived).
	function onRelease(_code)
	{
		if (_code == this.m.HeadingKey && !this.m.Continuous)
		{
			this.m.Heading = -1;
			this.m.HeadingKey = -1;
			this.m.Blocked = false;
			if (!this.m.Pending) this.m.LastTerrain = -1;
		}
	},
	// Space (and the other pause keys): stop the march at once. Silent on purpose — the
	// same Space press pauses the game, and the setPause hook then announces "Paused",
	// which would cut a "Stopped" cue on the interrupt channel anyway. Natural stops (a
	// tap, a release, an obstacle) still get their "Stopped" from onArrived. Returns
	// whether we were moving, so the caller can still let the native pause toggle run.
	function onBrake()
	{
		if (!this.isMoving()) return false;

		local player = ::World.State.getPlayer();
		if (player != null)
		{
			player.setPath(null);
			player.setDestination(null);
		}
		this.clearHeading();
		this.m.Pending = false;
		this.m.LastTerrain = -1;
		return true;
	},
	// Polled from world_state.onUpdate every frame, but only while a step is in flight.
	// The party clears its path on arrival, so !hasPath() is the "step landed" signal.
	function tick()
	{
		if (!this.m.Pending) return;

		local player = ::World.State.getPlayer();
		if (player == null)
		{
			this.m.Pending = false;
			return;
		}
		if (player.hasPath()) return; // still walking to the step tile

		this.m.Pending = false;
		this.onArrived(player);
	},
	function onArrived(_player)
	{
		if (this.m.Heading != -1)
		{
			// Still walking: announce the tile only when the terrain changes (so a long
			// march does not read the same word every tile), then take the next step.
			local t = _player.getTile().Type;
			if (t != this.m.LastTerrain)
			{
				this.m.LastTerrain = t;
				::UnseenBanner.sendMessage("interrupt", "", "world.move.step", "" + t);
			}
			// Hit a wall while still holding the heading: issueStep already said
			// "blocked"; mark it so the held key does not retry every frame, and keep the
			// intent so a change of direction (or release) resolves it. No "stopped" cue —
			// the order did not complete, the party just cannot go this way.
			if (!this.issueStep(this.m.Heading)) this.m.Blocked = true;
		}
		else
		{
			// Order complete (a single tap, or the key was released): the distinct cue
			// that tells the player the order finished.
			this.announceStopped(_player);
			this.m.LastTerrain = -1;
		}
	},
	function announceStopped(_player)
	{
		::UnseenBanner.sendMessage("interrupt", "", "world.move.stopped", "" + _player.getTile().Type);
	}
};

// Interacting with a world entity (phase 4.5). In vanilla this is armed by a mouse
// CLICK (world_state.onMouseInput): enemy parties use AutoAttack so the chase follows
// a moving target; static settlements/locations use AutoEnterLocation plus a path,
// then enterLocation on arrival. Our keyboard movement never passes through that
// mouse funnel, so both orders are reproduced here with the native state fields and
// navigator. Plain-map Enter still enters an enterable entity on the party's current
// tile; Enter inside the B survey acts on its focused entity at any distance.
::UnseenBanner.WorldEnter <- {
	EnterKey = 39, // enter
	function isEscorting(_state)
	{
		return _state.m.EscortedEntity != null && !_state.m.EscortedEntity.isNull();
	},
	function announceUnavailable(_cat = "world.interact.unavailable", _name = "")
	{
		::UnseenBanner.sendMessage("interrupt", _name, _cat);
	},
	function stopCurrentOrder(_state)
	{
		::UnseenBanner.WorldMove.reset();
		_state.m.AutoEnterLocation = null;
		_state.m.AutoAttack = null;
		_state.m.LastAutoAttackPath = 0.0;
	},
	function ensureTravelRunning(_state)
	{
		// Keyboard travel is an executable order, like WorldMove's directional step:
		// unpause it so "Approaching/Pursuing" never leaves the party silently parked.
		if (_state.isPaused())
		{
			::UnseenBanner.WorldMove.m.SelfUnpause = true;
			_state.setPause(false);
		}
	},
	function routeTo(_state, _entity)
	{
		local player = _state.m.Player;
		local targetTile = _entity.getTile();
		if (player == null || targetTile == null) return false;

		// getVecDistance belongs to the native script environment and is not exposed
		// as a member on the hooked world-state instance. Compare squared coordinates
		// locally to preserve its direct-movement threshold without taking a square root.
		local targetPos = _entity.getPos();
		local playerPos = player.getPos();
		local dx = targetPos.X - playerPos.X;
		local dy = targetPos.Y - playerPos.Y;
		local directRadius = ::Const.World.MovementSettings.PlayerDirectMoveRadius;
		if (dx * dx + dy * dy <= directRadius * directRadius)
		{
			player.setPath(null);
			player.setDestination(targetPos);
			return true;
		}

		local nav = ::World.getNavigator();
		local settings = nav.createSettings();
		settings.ActionPointCosts = ::Const.World.TerrainTypeNavCost;
		settings.RoadMult = 1.0 / ::Const.World.MovementSettings.RoadMult;
		local path = nav.findPath(player.getTile(), targetTile, settings, 0);
		if (path.isEmpty())
		{
			player.setPath(null);
			player.setDestination(null);
			return false;
		}

		player.setDestination(null);
		player.setPath(path);
		return true;
	},
	function tryInteract(_state, _entity)
	{
		if (_state == null || _entity == null || !_entity.isAlive()
			|| _entity.getTile() == null)
		{
			this.announceUnavailable("world.interact.gone");
			return false;
		}

		if (_entity.isParty()) return this.tryAttackParty(_state, _entity);
		return this.tryEnterLocation(_state, _entity);
	},
	function tryAttackParty(_state, _party)
	{
		local player = _state.m.Player;
		if (player == null || _party.isHiddenToPlayer()
			|| _party.getVisibilityMult() == 0.0)
		{
			this.announceUnavailable("world.interact.gone");
			return false;
		}
		if (this.isEscorting(_state))
		{
			this.announceUnavailable("world.interact.escorting");
			return false;
		}
		if (!_party.isAttackable() || _party.isAlliedWith(player))
		{
			this.announceUnavailable();
			return false;
		}

		local inRange = player.getDistanceTo(_party)
			<= ::Const.World.CombatSettings.CombatPlayerDistance;
		this.stopCurrentOrder(_state);
		// Always arm AutoAttack, even at contact range. world_state.onUpdate is the
		// native combat-entry funnel: it rechecks the live target, calls
		// onEnteringCombatWithPlayer and opens the Prepare for Combat dialog.
		// WeakTableRef is a native global class, not a callable member on the hooked
		// state object (compiled world_state methods resolve it through their own
		// environment). Construct the exact wrapper AutoAttack expects explicitly.
		_state.m.AutoAttack = ::WeakTableRef(_party);
		this.ensureTravelRunning(_state);
		::UnseenBanner.sendMessage("interrupt", _party.getName(),
			inRange ? "world.interact.engaging" : "world.interact.pursuing");
		return true;
	},
	function tryEnterLocation(_state, _location)
	{
		local player = _state.m.Player;
		if (player == null || !_location.isDiscovered())
		{
			this.announceUnavailable("world.interact.gone");
			return false;
		}

		// Exact eligibility used by world_state.onMouseInput. This includes towns,
		// hostile camps, unvisited ruins and locations with a bespoke on-enter event.
		if (!_location.isEnterable() && !_location.isAttackable()
			&& _location.isVisited() && _location.getOnEnterCallback() == null)
		{
			this.announceUnavailable();
			return false;
		}

		local sameTile = _location.getTile().isSameTileAs(player.getTile());
		local inRange = player.getDistanceTo(_location)
			<= ::Const.World.CombatSettings.CombatPlayerDistance;
		local escorting = this.isEscorting(_state);
		if (escorting && (!sameTile || !inRange || !_location.isAlliedWithPlayer()))
		{
			this.announceUnavailable("world.interact.escorting");
			return false;
		}

		this.stopCurrentOrder(_state);
		if (sameTile && inRange)
		{
			::UnseenBanner.sendMessage("interrupt", _location.getName(),
				"world.interact.entering");
			if (!_state.enterLocation(_location))
			{
				this.announceUnavailable();
				return false;
			}
			return true;
		}

		if (!this.routeTo(_state, _location))
		{
			this.announceUnavailable("world.interact.no_route", _location.getName());
			return false;
		}

		_state.m.AutoEnterLocation = ::WeakTableRef(_location);
		if (_location.isEnterable() && _location.isAlliedWithPlayer())
		{
			_state.m.WorldTownScreen.getMainDialogModule().preload(_location);
		}
		this.ensureTravelRunning(_state);
		::UnseenBanner.sendMessage("interrupt", _location.getName(),
			"world.interact.approaching");
		return true;
	},
	function tryEnter(_state)
	{
		local player = _state.m.Player;
		if (player == null) return false;
		local playerTile = player.getTile();
		local entities = ::World.getAllEntitiesAndOneLocationAtPos(player.getPos(), 1.0);

		// Contact enemies take priority. Previously plain Enter skipped every party,
		// which left a hostile party announced "At your position" but impossible to
		// engage without a mouse.
		foreach( e in entities )
		{
			if (e == null || e.getID() == player.getID()) continue;
			if (!e.isParty() || !e.isAlive() || e.getTile() == null) continue;
			if (!e.getTile().isSameTileAs(playerTile)
				|| player.getDistanceTo(e)
					> ::Const.World.CombatSettings.CombatPlayerDistance) continue;
			if (!e.isAttackable() || e.isAlliedWith(player)
				|| e.isHiddenToPlayer() || e.getVisibilityMult() == 0.0) continue;
			return this.tryAttackParty(_state, e);
		}

		// Then mirror the mouse's complete location eligibility, not just
		// isEnterable(): hostile camps and event/ruin locations deliberately return
		// false from isEnterable but must still reach enterLocation to start their
		// event or combat.
		foreach( e in entities )
		{
			if (e == null || e.getID() == player.getID() || e.isParty()) continue;
			if (e.getTile() == null || !e.getTile().isSameTileAs(playerTile)) continue;
			if (player.getDistanceTo(e)
				> ::Const.World.CombatSettings.CombatPlayerDistance) continue;
			if (!e.isEnterable() && !e.isAttackable()
				&& e.isVisited() && e.getOnEnterCallback() == null) continue;
			return this.tryEnterLocation(_state, e);
		}
		return false;
	}
};

// Town screen (phase 4.5). The settlement screen is a mouse-only grid of building
// slots plus a list of contracts; vanilla renders it to a texture no screen reader
// can see. Flatten it into one navigable list: the town name, each building by name,
// each open contract by title, and a Leave action. Up/Down/Home/End walk it, Enter
// activates. A contract opens through the game's own onContractClicked, which shows
// it as the very event screen EventNav already narrates (phase 1.1), so taking and
// turning in contracts works end to end. Phase 2.3b opens shop buildings and phase
// 4.5 opens recruitment through their native slot callbacks; other building
// sub-dialogs (tavern...) remain mouse-only and announce that limitation instead of
// opening a keyboard trap.
// Escape leaves the town on its own (the native menu-stack pop), so it is left alone.
::UnseenBanner.WorldTown <- {
	m = {
		Items = null,
		ItemIndex = 0,
		Active = false
	},
	Keys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end",
		[39] = "activate" // enter
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function reset()
	{
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
	},
	function item(_cat, _texto = "", _valor = "", _action = null, _payload = null)
	{
		return {
			cat = _cat,
			texto = _texto,
			valor = _valor,
			action = _action,
			payload = _payload
		};
	},
	function open(_town)
	{
		this.reset();
		if (_town == null) return;

		// enterLocation stores the town as a WeakTableRef (LastEnteredTown). Its _get
		// proxies METHOD calls (getName/getContracts work), but raw member access like
		// `.m.Buildings` does not resolve through it, so the building loop silently found
		// nothing. Unwrap to the underlying weakref, which transparently dereferences
		// both methods and members, so `.m.Buildings` reads the real settlement's slots.
		local town = (_town instanceof ::WeakTableRef) ? _town.get() : _town;
		if (town == null) return;

		local items = [];
		items.push(this.item("world.town.screen", town.getName()));

		// Buildings: retain the native slot index so accessible shops can enter through
		// WorldTownScreen.onSlotClicked, the exact same funnel as a mouse click.
		// No `in` guard here on purpose: the game's inherit()/new() builds an instance's
		// m table DELEGATING to the parent class's m, and Squirrel's `in` operator does
		// not follow delegates — so `"Buildings" in town.m` was false even though
		// town.m.Buildings resolves fine through the delegate chain. This screen only
		// ever opens for settlements, which always define Buildings.
		foreach( index, b in town.m.Buildings )
		{
			if (b == null || b.isHidden()) continue;
			items.push(this.item("world.town.building", b.getName(), "", "building", {
				slot = index,
				building = b
			}));
		}

		// Contracts: name + id. The active one is kept (tagged apart) rather than
		// skipped, so a blind player can re-open it to hand it in and get paid — the
		// turn-in that the screenshot objective ("return to X to get paid") needs. Enter
		// opens the contract's own event screen (EventNav narrates it), the mouse's path.
		//
		// NB: use getName(), not getTitle(). getTitle() runs buildText(), which for an
		// open (not-yet-started) contract dereferences m.Home — null at this point —
		// and throws ("the index 'getNameOnly' does not exist"), aborting the whole list
		// build so nothing became navigable. The game itself never titles contracts in
		// this list (it shows banner icons); the title is only resolved once the contract
		// is opened. getName() is the raw m.Name, always a clean plain title ("Escort
		// Caravan", "Return Item"...) with no placeholders, so it is safe and readable.
		local contracts = town.getContracts();
		if (contracts != null)
		{
			foreach( c in contracts )
			{
				if (c == null) continue;
				local cat = c.isActive() ? "world.town.contract.active" : "world.town.contract";
				items.push(this.item(cat, c.getName(), c.getID(), "contract"));
			}
		}

		items.push(this.item("world.town.leave", "", "", "leave"));

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem();
	},
	function close()
	{
		this.reset();
	},
	function onKey(_code, _state)
	{
		if (!this.m.Active) return;
		local what = this.Keys[_code];
		if (what == "activate")
		{
			this.activate(_state);
			return;
		}

		if (this.m.Items == null || this.m.Items.len() == 0) return;
		if (what == "up") this.m.ItemIndex -= 1;
		else if (what == "down") this.m.ItemIndex += 1;
		else if (what == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	function activate(_state)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		if (it.action == "contract")
		{
			// Opens the contract's event screen; EventNav takes over from there.
			_state.m.WorldTownScreen.onContractClicked(it.valor);
		}
		else if (it.action == "leave")
		{
			// The same funnel the Leave button uses (pops the town off the menu stack).
			_state.town_screen_main_dialog_module_onLeaveButtonClicked();
		}
		else if (it.action == "building")
		{
			local building = it.payload != null ? it.payload.building : null;
			if (building == null || building.getTooltip() == null)
			{
				::UnseenBanner.sendMessage("interrupt", it.texto, "world.town.building.closed");
			}
			else if (building.getStash() != null)
			{
				_state.m.WorldTownScreen.onSlotClicked(it.payload.slot);
			}
			else if (building.getID() == "building.crowd")
			{
				// The crowd building owns the settlement's recruit roster. Enter
				// through the exact same slot callback as a mouse click; the
				// showHireDialog hook below installs the accessible cursor.
				_state.m.WorldTownScreen.onSlotClicked(it.payload.slot);
			}
			else
			{
				::UnseenBanner.sendMessage("interrupt", it.texto, "world.town.building.locked");
			}
		}
		else
		{
			this.announceItem(); // header row: re-read
		}
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor);
	}
};

// Recruitment navigation (phase 4.5). The native screen is a mouse-only list of
// candidates with Hire and Try Out buttons. Keep the game authoritative: this
// cursor only flattens the live settlement roster, exposes the same native
// background/trait tooltips and calls town_hire_dialog_module's own endpoints.
//
// Up/Down/Home/End move through candidates; Enter opens an explicit action list;
// V opens the rendered native background/trait details. Escape at candidate level
// is left to the native MenuStack, while V/Escape cancel accessible sub-lists.
::UnseenBanner.WorldHire <- {
	m = {
		Screen = null,
		Module = null,
		Items = null,
		ItemIndex = 0,
		DetailMode = false,
		DetailIndex = 0,
		ActionMode = false,
		Actions = null,
		ActionIndex = 0,
		Active = false
	},
	InspectKey = 32, // v
	ActionKey = 39, // enter
	EscapeKey = 41,
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
	function isCurrent(_screen)
	{
		return this.m.Active && _screen != null && this.m.Screen == _screen
			&& _screen.m.LastActiveModule == this.m.Module;
	},
	function handles(_code)
	{
		if (!this.m.Active) return false;
		return _code == this.InspectKey
			|| _code == this.ActionKey
			|| (_code == this.EscapeKey && (this.m.ActionMode || this.m.DetailMode))
			|| _code in this.MoveKeys;
	},
	function reset()
	{
		this.m.Screen = null;
		this.m.Module = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
		this.m.ActionMode = false;
		this.m.Actions = null;
		this.m.ActionIndex = 0;
		this.m.Active = false;
		::UnseenBanner.TooltipNav.hide();
	},
	function open(_screen, _module)
	{
		this.reset();
		if (_screen == null || _module == null) return;

		this.m.Screen = _screen;
		this.m.Module = _module;
		this.buildItems(null, 0);
		this.m.Active = true;
		this.announceItem(true);
	},
	function close()
	{
		this.reset();
	},
	function currentRow()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return null;
		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len())
			this.m.ItemIndex = this.m.Items.len() - 1;
		return this.m.Items[this.m.ItemIndex];
	},
	function backgroundDetail(_entity)
	{
		return {
			contentType = "ui-element",
			entityId = _entity.getID(),
			elementId = "character-backgrounds.generic",
			elementOwner = "hire-screen"
		};
	},
	function unknownTraitsDetail()
	{
		return {
			contentType = "ui-element",
			elementId = "world-town-screen.hire-dialog-module.UnknownTraits"
		};
	},
	function traitDetail(_entity, _traitID)
	{
		return {
			contentType = "status-effect",
			entityId = _entity.getID(),
			statusEffectId = _traitID
		};
	},
	function makeRow(_entity)
	{
		local traits = _entity.getHiringTraits();
		local details = [this.backgroundDetail(_entity)];
		if (_entity.isTryoutDone())
		{
			foreach( trait in traits )
			{
				details.push(this.traitDetail(_entity, trait.id));
			}
		}
		else
		{
			details.push(this.unknownTraitsDetail());
		}

		return {
			key = "" + _entity.getID(),
			name = _entity.getName(),
			background = _entity.getBackground().getNameOnly(),
			level = "" + _entity.getLevel(),
			hireCost = "" + ::Math.ceil(_entity.getHiringCost()
				* ::World.Assets.m.HiringCostMult),
			dailyCost = "" + _entity.getDailyCost(),
			tryoutCost = "" + _entity.getTryoutCost(),
			tried = _entity.isTryoutDone(),
			traitCount = traits.len(),
			details = details,
			entity = _entity,
			entityID = _entity.getID()
		};
	},
	function buildItems(_preferredID = null, _fallbackIndex = 0)
	{
		local rows = [];
		if (this.m.Module != null)
		{
			local roster = ::World.getRoster(this.m.Module.m.RosterID);
			if (roster != null)
			{
				local entities = roster.getAll();
				if (entities != null)
				{
					foreach( entity in entities )
					{
						if (entity != null) rows.push(this.makeRow(entity));
					}
				}
			}
		}

		this.m.Items = rows;
		this.m.ItemIndex = _fallbackIndex;
		if (_preferredID != null)
		{
			for (local i = 0; i < rows.len(); i += 1)
			{
				if (rows[i].entityID == _preferredID)
				{
					this.m.ItemIndex = i;
					break;
				}
			}
		}
		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (rows.len() > 0 && this.m.ItemIndex >= rows.len())
			this.m.ItemIndex = rows.len() - 1;
	},
	function move(_code)
	{
		if (this.m.Items == null || this.m.Items.len() == 0)
		{
			this.announceItem();
			return;
		}

		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.ItemIndex -= 1;
		else if (dir == "down") this.m.ItemIndex += 1;
		else if (dir == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;
		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len())
			this.m.ItemIndex = this.m.Items.len() - 1;
		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		this.announceItem();
	},
	function leaveDetails()
	{
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
	},
	function toggleDetails()
	{
		if (this.m.DetailMode)
		{
			this.leaveDetails();
			::UnseenBanner.TooltipNav.hide();
			this.announceItem();
			return;
		}

		local row = this.currentRow();
		if (row == null || row.details.len() == 0)
		{
			::UnseenBanner.TooltipNav.onTooltipUnavailable();
			return;
		}
		this.m.DetailIndex = 0;
		if (row.details.len() > 1) this.m.DetailMode = true;
		this.showDetail();
	},
	function moveDetail(_code)
	{
		local row = this.currentRow();
		if (row == null || row.details.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.DetailIndex -= 1;
		else if (dir == "down") this.m.DetailIndex += 1;
		else if (dir == "home") this.m.DetailIndex = 0;
		else this.m.DetailIndex = row.details.len() - 1;
		if (this.m.DetailIndex < 0) this.m.DetailIndex = 0;
		if (this.m.DetailIndex >= row.details.len())
			this.m.DetailIndex = row.details.len() - 1;
		this.showDetail();
	},
	function showDetail()
	{
		local row = this.currentRow();
		if (row == null || row.details.len() == 0) return;
		::UnseenBanner.TooltipNav.show(row.details[this.m.DetailIndex],
			this.m.DetailIndex + 1, row.details.len(), "world.recruit.details");
	},
	function action(_execute, _label, _name, _price, _entityID)
	{
		return {
			execute = _execute,
			label = _label,
			name = _name,
			price = _price,
			entityID = _entityID
		};
	},
	function buildActions(_row)
	{
		local actions = [];
		if (_row == null) return actions;
		actions.push(this.action("hire", "hire", _row.name, _row.hireCost,
			_row.entityID));
		if (!_row.tried)
		{
			actions.push(this.action("tryout", "tryout", _row.name,
				_row.tryoutCost, _row.entityID));
		}
		return actions;
	},
	function openActions()
	{
		local row = this.currentRow();
		if (row == null)
		{
			this.announceItem();
			return;
		}
		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		this.m.Actions = this.buildActions(row);
		if (this.m.Actions.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", row.name,
				"world.recruit.actions.none");
			return;
		}
		this.m.ActionMode = true;
		this.m.ActionIndex = 0;
		this.announceAction(true);
	},
	function leaveActions(_announceParent = false)
	{
		this.m.ActionMode = false;
		this.m.Actions = null;
		this.m.ActionIndex = 0;
		if (_announceParent) this.announceItem();
	},
	function moveAction(_code)
	{
		if (this.m.Actions == null || this.m.Actions.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.ActionIndex -= 1;
		else if (dir == "down") this.m.ActionIndex += 1;
		else if (dir == "home") this.m.ActionIndex = 0;
		else this.m.ActionIndex = this.m.Actions.len() - 1;
		if (this.m.ActionIndex < 0) this.m.ActionIndex = 0;
		if (this.m.ActionIndex >= this.m.Actions.len())
			this.m.ActionIndex = this.m.Actions.len() - 1;
		this.announceAction();
	},
	function announceAction(_opened = false)
	{
		if (this.m.Actions == null || this.m.Actions.len() == 0) return;
		local action = this.m.Actions[this.m.ActionIndex];
		local detail = action.price + "|" + (this.m.ActionIndex + 1)
			+ "|" + this.m.Actions.len() + "|" + (_opened ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", action.name,
			"world.recruit.action", action.label, detail);
	},
	function actionError(_result)
	{
		if (typeof _result != "table" || !("Result" in _result))
			return "unavailable";
		if (_result.Result == ::Const.UI.Error.NotEnoughMoney) return "money";
		if (_result.Result == ::Const.UI.Error.NotEnoughRosterSpace) return "roster";
		if (_result.Result == ::Const.UI.Error.RosterEntryNotFound) return "missing";
		return "unavailable";
	},
	function refreshNative()
	{
		if (this.m.Module == null || this.m.Screen == null) return;
		local data = this.m.Module.queryHireInformation();
		// Vanilla updates assets before recalculating the selected recruit's button
		// availability. Preserve that order so Hire/Try Out do not use stale crowns
		// after an accessible action.
		this.m.Screen.updateAssets();
		if (data != null && "Roster" in data)
			this.m.Module.m.JSHandle.asyncCall("loadFromData", data.Roster);
	},
	function executeAction()
	{
		if (!this.m.ActionMode || this.m.Actions == null
			|| this.m.Actions.len() == 0) return;

		local action = this.m.Actions[this.m.ActionIndex];
		local fallback = this.m.ItemIndex;
		local result = action.execute == "hire"
			? this.m.Module.onHireRosterEntry(action.entityID)
			: this.m.Module.onTryoutRosterEntry(action.entityID);
		this.leaveActions(false);

		if (typeof result != "table" || !("Result" in result) || result.Result != 0)
		{
			this.buildItems(null, fallback);
			::UnseenBanner.sendMessage("interrupt", action.name,
				"world.recruit.error", this.actionError(result));
			return;
		}

		this.refreshNative();
		this.buildItems(action.execute == "tryout" ? action.entityID : null,
			fallback);
		::UnseenBanner.sendMessage("interrupt", action.name,
			"world.recruit.result." + action.execute, action.price,
			"" + ::World.Assets.getMoney());
	},
	function announceItem(_opened = false)
	{
		local row = this.currentRow();
		if (row == null)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.recruit.empty",
				"" + ::World.Assets.getMoney(), _opened ? "1" : "0");
			return;
		}

		local detail = row.level + "|" + row.hireCost + "|" + row.dailyCost
			+ "|" + row.tryoutCost + "|" + (row.tried ? "1" : "0")
			+ "|" + row.traitCount + "|" + (this.m.ItemIndex + 1)
			+ "|" + this.m.Items.len() + "|" + (_opened ? "1" : "0")
			+ "|" + ::World.Assets.getMoney();
		::UnseenBanner.sendMessage("interrupt", row.name,
			"world.recruit.candidate", row.background, detail, null,
			"" + row.details.len(), null, "" + this.buildActions(row).len());
	},
	function onKey(_code)
	{
		if (!this.m.Active) return;
		if (this.m.ActionMode)
		{
			if (_code == this.InspectKey || _code == this.EscapeKey)
			{
				this.leaveActions(true);
				return;
			}
			if (_code == this.ActionKey)
			{
				this.executeAction();
				return;
			}
			if (_code in this.MoveKeys)
			{
				this.moveAction(_code);
				return;
			}
			this.leaveActions(false);
		}
		if (this.m.DetailMode && _code == this.EscapeKey)
		{
			this.leaveDetails();
			::UnseenBanner.TooltipNav.hide();
			this.announceItem();
			return;
		}
		if (_code == this.InspectKey)
		{
			this.toggleDetails();
			return;
		}
		if (_code == this.ActionKey)
		{
			this.openActions();
			return;
		}
		if (_code in this.MoveKeys)
		{
			if (this.m.DetailMode) this.moveDetail(_code);
			else this.move(_code);
		}
	}
};

// Market navigation (phase 2.3b). A shop is represented as three linear sections:
// overview, stock to buy and company stash to sell/repair. Page Up/Down changes
// section; Up/Down/Home/End moves within it; Enter opens an explicit action list;
// V reads the focused item's native rendered tooltip. A/D, Left/Right and Tab cycle
// the brother used for comparison. When an equivalent item is equipped, V exposes
// the market item and equipped item as a two-entry tooltip list.
//
// All mutations call town_shop_dialog_module's native endpoints. This preserves
// prices, unique/precious confirmation policy, stash capacity, achievements and
// repair rules; the accessible layer only chooses an endpoint and rebuilds its
// semantic rows from live state afterwards.
::UnseenBanner.WorldShop <- {
	m = {
		Screen = null,
		Module = null,
		Sections = null,
		SectionIndex = 0,
		Items = null,
		ItemIndex = 0,
		Brothers = null,
		BroIndex = 0,
		DetailMode = false,
		DetailIndex = 0,
		ActionMode = false,
		Actions = null,
		ActionIndex = 0,
		ConfirmMode = false,
		ConfirmAction = null,
		ConfirmIndex = 0,
		Active = false
	},
	InspectKey = 32, // v
	ActionKey = 39, // enter
	EscapeKey = 41,
	MoveKeys = {
		[44] = "end",
		[45] = "home",
		[49] = "up",
		[51] = "down"
	},
	SectionKeys = {
		[46] = "prev",
		[47] = "next"
	},
	NextKeys = {
		[14] = true, // d
		[50] = true, // right
		[38] = true  // tab
	},
	PrevKeys = {
		[11] = true, // a
		[48] = true  // left
	},
	ShopOwner = "world-town-screen-shop-dialog-module.shop",
	StashOwner = "world-town-screen-shop-dialog-module.stash",
	function isActive()
	{
		return this.m.Active;
	},
	function isCurrent(_screen)
	{
		return this.m.Active && _screen != null && this.m.Screen == _screen
			&& _screen.m.LastActiveModule == this.m.Module;
	},
	function handles(_code)
	{
		if (!this.m.Active) return false;
		return _code == this.InspectKey
			|| _code == this.ActionKey
			|| (_code == this.EscapeKey && (this.m.ActionMode || this.m.ConfirmMode))
			|| _code in this.MoveKeys
			|| _code in this.SectionKeys
			|| _code in this.NextKeys
			|| _code in this.PrevKeys;
	},
	function reset()
	{
		this.m.Screen = null;
		this.m.Module = null;
		this.m.Sections = null;
		this.m.SectionIndex = 0;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Brothers = null;
		this.m.BroIndex = 0;
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
		this.m.ActionMode = false;
		this.m.Actions = null;
		this.m.ActionIndex = 0;
		this.m.ConfirmMode = false;
		this.m.ConfirmAction = null;
		this.m.ConfirmIndex = 0;
		this.m.Active = false;
		::UnseenBanner.TooltipNav.hide();
	},
	function open(_screen, _module)
	{
		this.reset();
		if (_screen == null || _module == null || _module.getShop() == null) return;

		this.m.Screen = _screen;
		this.m.Module = _module;
		this.m.Brothers = [];
		// Comparison only needs the live company roster. Formation is unrelated
		// to trading and getFormation() throws while a new brother still has the
		// sentinel position 255 instead of a slot in its 27-entry result.
		local roster = ::World.getPlayerRoster().getAll();
		if (roster != null)
		{
			foreach( bro in roster )
			{
				if (bro != null) this.m.Brothers.push(bro);
			}
		}

		this.buildSections();
		this.m.SectionIndex = 0;
		this.m.Active = true;
		this.activateSection(0, false, false);
		this.announceItem(true);
	},
	function close()
	{
		this.reset();
	},
	function currentBrother()
	{
		if (this.m.Brothers == null || this.m.Brothers.len() == 0) return null;
		if (this.m.BroIndex < 0 || this.m.BroIndex >= this.m.Brothers.len())
			this.m.BroIndex = 0;
		return this.m.Brothers[this.m.BroIndex];
	},
	function currentSection()
	{
		if (this.m.Sections == null || this.m.Sections.len() == 0) return null;
		if (this.m.SectionIndex < 0 || this.m.SectionIndex >= this.m.Sections.len())
			return null;
		return this.m.Sections[this.m.SectionIndex];
	},
	function row(_key, _cat, _texto = "", _precio = "", _cantidad = "",
		_details = null, _payload = null, _comparison = null)
	{
		return {
			key = _key,
			cat = _cat,
			texto = _texto,
			precio = _precio,
			cantidad = _cantidad,
			details = _details != null ? _details : [],
			payload = _payload,
			comparison = _comparison
		};
	},
	function section(_id, _rows, _saved)
	{
		if (_rows.len() == 0)
			_rows.push(this.row(_id + ":empty", "world.market.empty", _id));

		local result = { id = _id, items = _rows, index = 0 };
		if (_saved != null && _id in _saved)
		{
			result.index = _saved[_id].index;
			local key = _saved[_id].key;
			if (key != "")
			{
				for (local i = 0; i < _rows.len(); i += 1)
				{
					if (_rows[i].key == key)
					{
						result.index = i;
						break;
					}
				}
			}
		}
		if (result.index < 0) result.index = 0;
		if (result.index >= _rows.len()) result.index = _rows.len() - 1;
		return result;
	},
	function capturePositions()
	{
		local saved = {};
		if (this.m.Sections == null) return saved;
		local current = this.currentSection();
		if (current != null) current.index = this.m.ItemIndex;
		foreach( section in this.m.Sections )
		{
			local index = section.index;
			if (index < 0) index = 0;
			if (index >= section.items.len()) index = section.items.len() - 1;
			local key = section.items.len() > 0 ? section.items[index].key : "";
			saved[section.id] <- { index = index, key = key };
		}
		return saved;
	},
	function itemAmount(_item)
	{
		return _item != null && _item.isAmountShown() ? "" + _item.getAmountString() : "";
	},
	function filterName(_filter)
	{
		if (_filter == ::Const.Items.ItemFilter.Weapons) return "weapons";
		if (_filter == ::Const.Items.ItemFilter.Armor) return "armor";
		if (_filter == ::Const.Items.ItemFilter.Misc) return "misc";
		if (_filter == ::Const.Items.ItemFilter.Usable) return "usable";
		return "all";
	},
	function itemDetail(_item, _owner, _bro = null)
	{
		return {
			contentType = "ui-item",
			entityId = _bro != null ? _bro.getID() : null,
			itemId = _item.getInstanceID(),
			itemOwner = _owner
		};
	},
	function comparisonFor(_item)
	{
		local result = {
			applicable = false,
			brother = null,
			item = null
		};
		local bro = this.currentBrother();
		if (bro == null || _item == null) return result;

		local slot = _item.getSlotType();
		if (slot == ::Const.ItemSlot.None || slot == ::Const.ItemSlot.Bag) return result;

		result.applicable = true;
		result.brother = bro;
		local equipped = bro.getItems().getItemAtSlot(slot);
		if (equipped != null && equipped != -1) result.item = equipped;
		return result;
	},
	function marketItemRow(_source, _index, _item)
	{
		local owner = _source == "buy" ? this.ShopOwner : this.StashOwner;
		local comparison = this.comparisonFor(_item);
		local details = [this.itemDetail(_item, owner)];
		if (comparison.item != null)
			details.push(this.itemDetail(comparison.item, "entity", comparison.brother));

		return this.row(_source + ":" + _item.getInstanceID(),
			_source == "buy" ? "world.market.buy.item" : "world.market.sell.item",
			_item.getName(),
			"" + (_source == "buy" ? _item.getBuyPrice() : _item.getSellPrice()),
			this.itemAmount(_item),
			details, {
				source = _source,
				index = _index,
				item = _item,
				itemId = _item.getInstanceID()
			}, comparison);
	},
	function buildBuyRows()
	{
		local rows = [];
		local shop = this.m.Module != null ? this.m.Module.getShop() : null;
		local stash = shop != null ? shop.getStash() : null;
		if (stash == null) return rows;
		foreach( index, item in stash.getItems() )
		{
			if (item == null || item == -1) continue;
			rows.push(this.marketItemRow("buy", index, item));
		}
		return rows;
	},
	function buildSellRows()
	{
		local rows = [];
		if (this.m.Module == null) return rows;
		local filter = this.m.Module.m.InventoryFilter;
		rows.push(this.row("sell:commands", "world.market.commands", "",
			this.filterName(filter), "", [], { source = "commands" }));

		local stash = ::World.Assets.getStash();
		if (stash == null) return rows;
		foreach( index, item in stash.getItems() )
		{
			if (item == null || item == -1) continue;
			if (filter != ::Const.Items.ItemFilter.All
				&& (item.getItemType() & filter) == 0) continue;
			rows.push(this.marketItemRow("sell", index, item));
		}
		return rows;
	},
	function buildSections(_saved = null)
	{
		local overview = [];
		local shop = this.m.Module != null ? this.m.Module.getShop() : null;
		if (shop != null)
		{
			overview.push(this.row("overview", "world.market.screen",
				shop.getName(), "" + ::World.Assets.getMoney(), shop.getDescription()));
		}
		this.m.Sections = [
			this.section("overview", overview, _saved),
			this.section("buy", this.buildBuyRows(), _saved),
			this.section("sell", this.buildSellRows(), _saved)
		];
	},
	function activateSection(_index, _announce = true, _saveOld = true)
	{
		if (this.m.Sections == null || this.m.Sections.len() == 0) return;
		local old = this.currentSection();
		if (_saveOld && old != null) old.index = this.m.ItemIndex;
		if (_index < 0) _index = 0;
		if (_index >= this.m.Sections.len()) _index = this.m.Sections.len() - 1;
		this.m.SectionIndex = _index;
		local section = this.m.Sections[_index];
		this.m.Items = section.items;
		this.m.ItemIndex = section.index;
		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		section.index = this.m.ItemIndex;
		::UnseenBanner.TooltipNav.hide();
		if (_announce) this.announceItem(true);
	},
	function moveSection(_code)
	{
		local next = this.SectionKeys[_code] == "next";
		local index = this.m.SectionIndex + (next ? 1 : -1);
		if (index < 0) index = 0;
		if (index >= this.m.Sections.len()) index = this.m.Sections.len() - 1;
		this.activateSection(index);
	},
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
		local section = this.currentSection();
		if (section != null) section.index = this.m.ItemIndex;
		::UnseenBanner.TooltipNav.hide();
		this.announceItem();
	},
	function switchBrother(_next)
	{
		if (this.m.Brothers == null || this.m.Brothers.len() == 0)
		{
			this.announceItem();
			return;
		}
		local saved = this.capturePositions();
		local n = this.m.Brothers.len();
		if (_next) this.m.BroIndex = (this.m.BroIndex + 1) % n;
		else this.m.BroIndex = (this.m.BroIndex - 1 + n) % n;
		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		this.buildSections(saved);
		this.activateSection(this.m.SectionIndex, false, false);
		this.announceItem();
	},
	function repairPrice(_item)
	{
		local price = (_item.getConditionMax() - _item.getCondition())
			* ::Const.World.Assets.CostToRepairPerPoint;
		local value = _item.m.Value
			* (1.0 - _item.getCondition() / _item.getConditionMax())
			* 0.2
			* ::World.State.getCurrentTown().getPriceMult()
			* ::Const.Difficulty.SellPriceMult[::World.Assets.getEconomicDifficulty()];
		return ::Math.max(price, value);
	},
	function action(_execute, _label, _result, _name, _price, _payload)
	{
		return {
			execute = _execute,
			label = _label,
			result = _result,
			name = _name,
			price = _price,
			payload = _payload
		};
	},
	function buildActions(_row)
	{
		local actions = [];
		local payload = _row != null ? _row.payload : null;
		if (payload == null) return actions;
		if (payload.source == "commands")
		{
			actions.push(this.action("sort", "sort", "sort", "", "", payload));
			actions.push(this.action("filter_all", "filter_all", "filter_all", "", "", payload));
			actions.push(this.action("filter_weapons", "filter_weapons", "filter_weapons", "", "", payload));
			actions.push(this.action("filter_armor", "filter_armor", "filter_armor", "", "", payload));
			actions.push(this.action("filter_misc", "filter_misc", "filter_misc", "", "", payload));
			actions.push(this.action("filter_usable", "filter_usable", "filter_usable", "", "", payload));
		}
		else if (payload.source == "buy")
		{
			actions.push(this.action("buy", "buy", "buy", payload.item.getName(),
				"" + payload.item.getBuyPrice(), payload));
		}
		else if (payload.source == "sell")
		{
			if (payload.item.isSellable())
				actions.push(this.action("sell", "sell", "sell", payload.item.getName(),
					"" + payload.item.getSellPrice(), payload));
			if (this.m.Module.getShop().isRepairOffered()
				&& payload.item.getConditionMax() > 1
				&& payload.item.getCondition() < payload.item.getConditionMax())
			{
				actions.push(this.action("repair", "repair", "repair", payload.item.getName(),
					"" + this.repairPrice(payload.item), payload));
			}
		}
		return actions;
	},
	function openActions()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		local row = this.m.Items[this.m.ItemIndex];
		local actions = this.buildActions(row);
		if (actions.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt",
				row.cat == "world.market.empty" ? "" : row.texto,
				"world.market.actions.none");
			return;
		}
		this.m.ActionMode = true;
		this.m.Actions = actions;
		this.m.ActionIndex = 0;
		this.announceAction(true);
	},
	function leaveActions(_announceParent = false)
	{
		this.m.ActionMode = false;
		this.m.Actions = null;
		this.m.ActionIndex = 0;
		if (_announceParent) this.announceItem();
	},
	function moveAction(_code)
	{
		if (this.m.Actions == null || this.m.Actions.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.ActionIndex -= 1;
		else if (dir == "down") this.m.ActionIndex += 1;
		else if (dir == "home") this.m.ActionIndex = 0;
		else this.m.ActionIndex = this.m.Actions.len() - 1;
		if (this.m.ActionIndex < 0) this.m.ActionIndex = 0;
		if (this.m.ActionIndex >= this.m.Actions.len())
			this.m.ActionIndex = this.m.Actions.len() - 1;
		this.announceAction();
	},
	function announceAction(_opened = false)
	{
		if (this.m.Actions == null || this.m.Actions.len() == 0) return;
		local action = this.m.Actions[this.m.ActionIndex];
		local detail = action.price + "|" + (this.m.ActionIndex + 1)
			+ "|" + this.m.Actions.len() + "|" + (_opened ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", action.name, "world.market.action",
			action.label, detail);
	},
	function beginConfirmation(_action, _kind)
	{
		this.leaveActions(false);
		this.m.ConfirmMode = true;
		this.m.ConfirmAction = _action;
		this.m.ConfirmAction.confirmKind <- _kind;
		this.m.ConfirmIndex = 0; // safe default: cancel
		this.announceConfirmation(true);
	},
	function leaveConfirmation(_announceParent = false)
	{
		this.m.ConfirmMode = false;
		this.m.ConfirmAction = null;
		this.m.ConfirmIndex = 0;
		if (_announceParent) this.announceItem();
	},
	function moveConfirmation(_code)
	{
		local dir = this.MoveKeys[_code];
		if (dir == "up" || dir == "home") this.m.ConfirmIndex = 0;
		else this.m.ConfirmIndex = 1;
		this.announceConfirmation();
	},
	function announceConfirmation(_opened = false)
	{
		if (!this.m.ConfirmMode || this.m.ConfirmAction == null) return;
		local choice = this.m.ConfirmIndex == 0 ? "cancel" : "sell";
		local detail = choice + "|" + (this.m.ConfirmIndex + 1)
			+ "|2|" + this.m.ConfirmAction.price + "|" + (_opened ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", this.m.ConfirmAction.name,
			"world.market.confirm", this.m.ConfirmAction.confirmKind, detail);
	},
	function confirm()
	{
		if (!this.m.ConfirmMode || this.m.ConfirmAction == null) return;
		if (this.m.ConfirmIndex == 0)
		{
			local name = this.m.ConfirmAction.name;
			this.leaveConfirmation(false);
			::UnseenBanner.sendMessage("interrupt", name, "world.market.confirm.cancelled");
			return;
		}
		local action = this.m.ConfirmAction;
		this.leaveConfirmation(false);
		this.performTrade(action);
	},
	function tradeError(_result)
	{
		if (typeof _result != "table" || !("Result" in _result)) return "unavailable";
		if (_result.Result == ::Const.UI.Error.NotEnoughMoney) return "money";
		if (_result.Result == ::Const.UI.Error.NotEnoughStashSpace) return "space";
		return "unavailable";
	},
	function refreshNative()
	{
		if (this.m.Module == null || this.m.Screen == null) return;
		this.m.Module.m.JSHandle.asyncCall("loadFromData",
			this.m.Module.queryShopInformation());
		this.m.Screen.updateAssets();
	},
	function refreshSemantic(_saved, _section)
	{
		this.buildSections(_saved);
		this.activateSection(_section, false, false);
	},
	function announceError(_code)
	{
		::UnseenBanner.sendMessage("interrupt", "", "world.market.error", _code);
	},
	function requestSell(_action)
	{
		local payload = _action.payload;
		local canSwap = this.m.Module.onCanSwapItem([
			payload.index, this.StashOwner, null, this.ShopOwner
		]);
		if (typeof canSwap != "table" || !("Result" in canSwap))
		{
			this.leaveActions(false);
			this.announceError("unavailable");
			return;
		}
		if (canSwap.Result == ::Const.UI.Swap.CanSwap)
		{
			this.leaveActions(false);
			this.performTrade(_action);
		}
		else if (canSwap.Result == ::Const.UI.Swap.ConfirmNoReplaceSwap)
		{
			this.beginConfirmation(_action, "unique");
		}
		else if (canSwap.Result == ::Const.UI.Swap.ConfirmReplaceSwap)
		{
			this.beginConfirmation(_action, "precious");
		}
		else
		{
			this.leaveActions(false);
			this.announceError("cannot_sell");
		}
	},
	function performTrade(_action)
	{
		local payload = _action.payload;
		local saved = this.capturePositions();
		local section = this.m.SectionIndex;
		local sourceOwner = _action.execute == "buy" ? this.ShopOwner : this.StashOwner;
		local targetOwner = _action.execute == "buy" ? this.StashOwner : this.ShopOwner;
		local result = this.m.Module.onSwapItem([
			payload.index, sourceOwner, null, targetOwner
		]);
		if (typeof result != "table" || !("Result" in result) || result.Result != 0)
		{
			this.announceError(this.tradeError(result));
			return;
		}
		this.refreshNative();
		this.refreshSemantic(saved, section);
		::UnseenBanner.sendMessage("interrupt", _action.name,
			"world.market.result." + _action.result, _action.price,
			"" + ::World.Assets.getMoney());
	},
	function executeAction()
	{
		if (!this.m.ActionMode || this.m.Actions == null || this.m.Actions.len() == 0)
			return;
		local action = this.m.Actions[this.m.ActionIndex];
		if (action.execute == "sell")
		{
			this.requestSell(action);
			return;
		}
		if (action.execute == "buy")
		{
			this.leaveActions(false);
			this.performTrade(action);
			return;
		}

		local saved = this.capturePositions();
		local section = this.m.SectionIndex;
		local success = true;
		if (action.execute == "repair")
		{
			local result = this.m.Module.onRepairItem(action.payload.index);
			success = typeof result == "table" && "Item" in result;
			if (success) this.refreshNative();
		}
		else if (action.execute == "sort") this.m.Module.onSortButtonClicked();
		else if (action.execute == "filter_all") this.m.Module.onFilterAll();
		else if (action.execute == "filter_weapons") this.m.Module.onFilterWeapons();
		else if (action.execute == "filter_armor") this.m.Module.onFilterArmor();
		else if (action.execute == "filter_misc") this.m.Module.onFilterMisc();
		else if (action.execute == "filter_usable") this.m.Module.onFilterUsable();
		else success = false;

		this.leaveActions(false);
		if (!success)
		{
			this.announceError(action.execute == "repair" ? "repair" : "unavailable");
			return;
		}
		this.refreshSemantic(saved, section);
		::UnseenBanner.sendMessage("interrupt", action.name,
			"world.market.result." + action.result, action.price,
			"" + ::World.Assets.getMoney());
	},
	function leaveDetails()
	{
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
	},
	function toggleDetails()
	{
		if (this.m.DetailMode)
		{
			this.leaveDetails();
			::UnseenBanner.TooltipNav.hide();
			this.announceItem();
			return;
		}
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local details = this.m.Items[this.m.ItemIndex].details;
		if (details.len() == 0)
		{
			::UnseenBanner.TooltipNav.onTooltipUnavailable();
			return;
		}
		this.m.DetailIndex = 0;
		if (details.len() > 1) this.m.DetailMode = true;
		this.showDetail();
	},
	function moveDetail(_code)
	{
		local details = this.m.Items[this.m.ItemIndex].details;
		if (details.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.DetailIndex -= 1;
		else if (dir == "down") this.m.DetailIndex += 1;
		else if (dir == "home") this.m.DetailIndex = 0;
		else this.m.DetailIndex = details.len() - 1;
		if (this.m.DetailIndex < 0) this.m.DetailIndex = 0;
		if (this.m.DetailIndex >= details.len()) this.m.DetailIndex = details.len() - 1;
		this.showDetail();
	},
	function showDetail()
	{
		local row = this.m.Items[this.m.ItemIndex];
		if (row.details.len() == 0) return;
		::UnseenBanner.TooltipNav.show(row.details[this.m.DetailIndex],
			this.m.DetailIndex + 1, row.details.len(), "world.market.item");
	},
	function announceItem(_includeSection = false)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local row = this.m.Items[this.m.ItemIndex];
		if (row.cat == "world.market.screen")
		{
			::UnseenBanner.sendMessage("interrupt", row.texto, row.cat,
				row.precio, row.cantidad);
			return;
		}

		local section = this.currentSection();
		local detail = row.cantidad + "|" + (this.m.ItemIndex + 1)
			+ "|" + this.m.Items.len() + "|" + (_includeSection ? "1" : "0");
		if (row.cat == "world.market.commands" || row.cat == "world.market.empty")
		{
			::UnseenBanner.sendMessage("interrupt", row.texto, row.cat,
				row.precio, detail, null, "" + row.details.len(), null,
				"" + this.buildActions(row).len());
			return;
		}

		local comparison = row.comparison;
		local broName = comparison != null && comparison.applicable
			&& comparison.brother != null ? comparison.brother.getName() : null;
		local comparedName = comparison != null && comparison.item != null
			? comparison.item.getName() : null;
		detail += "|" + (comparison != null && comparison.applicable ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", row.texto, row.cat,
			row.precio, detail, broName, "" + row.details.len(), null,
			"" + this.buildActions(row).len(), comparedName);
	},
	function onKey(_code)
	{
		if (!this.m.Active) return;
		if (this.m.ConfirmMode)
		{
			if (_code == this.InspectKey || _code == this.EscapeKey)
			{
				this.leaveConfirmation(true);
				return;
			}
			if (_code == this.ActionKey)
			{
				this.confirm();
				return;
			}
			if (_code in this.MoveKeys)
			{
				this.moveConfirmation(_code);
				return;
			}
			return;
		}
		if (this.m.ActionMode)
		{
			if (_code == this.InspectKey || _code == this.EscapeKey)
			{
				this.leaveActions(true);
				return;
			}
			if (_code == this.ActionKey)
			{
				this.executeAction();
				return;
			}
			if (_code in this.MoveKeys)
			{
				this.moveAction(_code);
				return;
			}
			this.leaveActions(false);
		}
		if (_code == this.InspectKey)
		{
			this.toggleDetails();
			return;
		}
		if (_code == this.ActionKey)
		{
			this.leaveDetails();
			this.openActions();
			return;
		}
		if (_code in this.SectionKeys)
		{
			this.leaveDetails();
			this.moveSection(_code);
			return;
		}
		if (_code in this.MoveKeys)
		{
			if (this.m.DetailMode) this.moveDetail(_code);
			else this.move(_code);
			return;
		}
		if (_code in this.NextKeys || _code in this.PrevKeys)
		{
			this.switchBrother(_code in this.NextKeys);
		}
	}
};

// Obituary screen (phase 5.2). Vanilla renders a read-only table with one row per
// fallen brother: name, days with the company, battles, kills and demise. The
// backend already exposes that exact table through World.Statistics.getFallen(),
// so keep this in Squirrel and flatten each visual row into one spoken list item.
//
// Up/Down/Home/End act on key press, not release, for immediate navigation. A
// short repeat gate still permits deliberate hold-to-repeat without flooding the
// interrupt channel. O and Escape are deliberately absent from Keys: vanilla owns
// both closing paths and keeps the visible screen/menu stack in sync.
::UnseenBanner.WorldObituary <- {
	m = {
		Items = null,
		ItemIndex = 0,
		Active = false
	},
	Keys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end"
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function reset()
	{
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
	},
	function releaseKeys()
	{
		foreach( code, action in this.Keys )
		{
			::UnseenBanner.KeyGate.release(code);
		}
	},
	function item(_cat, _texto = "", _valor = "", _detalle = "")
	{
		return { cat = _cat, texto = _texto, valor = _valor, detalle = _detalle };
	},
	function open(_screen)
	{
		this.reset();
		this.releaseKeys();
		if (_screen == null) return;

		// This is the same data object vanilla passes to its JS show() call, so the
		// auditory list and the visible obituary always contain the same people in
		// the same newest-first order (statistics_manager inserts deaths at index 0).
		local data = _screen.convertFallenToUIData();
		local fallen = data != null ? data.Fallen : null;
		local count = fallen != null ? fallen.len() : 0;
		local items = [];
		local header = count == 0
			? "world.obituary.screen.empty"
			: (count == 1 ? "world.obituary.screen.one" : "world.obituary.screen");
		items.push(this.item(header, "", "" + count));

		if (fallen != null)
		{
			foreach( f in fallen )
			{
				if (f == null) continue;
				// Pack the numeric columns and already-rendered demise text; the
				// companion supplies every framing word and handles singulars.
				local detail = "" + f.TimeWithCompany + "|" + f.Battles + "|" + f.Kills + "|" + f.KilledBy;
				items.push(this.item("world.obituary.entry", f.Name, "", detail));
			}
		}

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem();
	},
	function close()
	{
		this.releaseKeys();
		this.reset();
	},
	function onKey(_code)
	{
		if (!this.m.Active || this.m.Items == null || this.m.Items.len() == 0) return;
		local what = this.Keys[_code];
		if (what == "up") this.m.ItemIndex -= 1;
		else if (what == "down") this.m.ItemIndex += 1;
		else if (what == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
	}
};

// Factions & Relations screen (phase 5.2). Vanilla lays this out as a faction
// list on the left and a selected-faction details panel on the right. Flatten
// that two-pane mouse UI into a single semantic list: screen header, company
// renown/reputation, then each faction's relation, motto, description and the
// named characters whose portraits vanilla exposes through hover tooltips.
//
// As with the verified obituary, Up/Down/Home/End act on keydown for immediate
// response and controlled hold-to-repeat; R and Escape remain native close keys.
::UnseenBanner.WorldRelations <- {
	m = {
		Items = null,
		ItemIndex = 0,
		Active = false
	},
	Keys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end"
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function reset()
	{
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
	},
	function releaseKeys()
	{
		foreach( code, action in this.Keys )
		{
			::UnseenBanner.KeyGate.release(code);
		}
	},
	function item(_cat, _texto = "", _valor = "", _detalle = "")
	{
		return { cat = _cat, texto = _texto, valor = _valor, detalle = _detalle };
	},
	function open(_screen)
	{
		this.reset();
		this.releaseKeys();
		if (_screen == null) return;

		// convertFactionsToUIData is the screen's own show() payload: it already
		// filters hidden/undiscovered factions, sorts them exactly as vanilla and
		// resolves every game-owned label through the active localization.
		local data = _screen.convertFactionsToUIData();
		if (data == null) return;
		local factions = data.Factions;
		local count = factions != null ? factions.len() : 0;
		local items = [];
		local header = count == 0
			? "world.relations.screen.empty"
			: (count == 1 ? "world.relations.screen.one" : "world.relations.screen");
		items.push(this.item(header, "", "" + count));
		items.push(this.item("world.relations.renown", data.BusinessReputation));
		items.push(this.item("world.relations.reputation", data.MoralReputation));

		if (factions != null)
		{
			foreach( f in factions )
			{
				if (f == null) continue;
				items.push(this.item("world.relations.faction", f.Name, f.Relation, "" + f.RelationNum));

				if (f.Motto != null && f.Motto != "")
					items.push(this.item("world.relations.motto", f.Motto, f.Name));
				if (f.Description != null && f.Description != "")
					items.push(this.item("world.relations.description", f.Description, f.Name));

				// The detail pane shows one portrait per member of this same faction
				// roster; their names are otherwise available only by mouse hover.
				local source = ::World.FactionManager.getFaction(f.ID);
				if (source == null) continue;
				local members = source.getRoster().getAll();
				if (members == null) continue;
				foreach( member in members )
				{
					if (member == null) continue;
					items.push(this.item("world.relations.member", member.getName(), f.Name));
				}
			}
		}

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem();
	},
	function close()
	{
		this.releaseKeys();
		this.reset();
	},
	function onKey(_code)
	{
		if (!this.m.Active || this.m.Items == null || this.m.Items.len() == 0) return;
		local what = this.Keys[_code];
		if (what == "up") this.m.ItemIndex -= 1;
		else if (what == "down") this.m.ItemIndex += 1;
		else if (what == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
	}
};

// Retinue screen (phase 5.2, P). Vanilla presents a scenic camp with a clickable
// cart and five follower portraits, then a mouse-only two-pane hire dialog. Turn
// both surfaces into semantic lists while keeping their visible native screens
// and backend actions as the source of truth:
//
//   main: header, seats/assets, cart, five follower seats
//   hire: header, money, one complete row per available follower
//
// Up/Down/Home/End and Enter act on keydown for immediate navigation. P and
// Escape remain native on the main/hire screens (hire -> main -> map). Buying a
// cart already opens vanilla's shared confirmation dialog; hiring gains the same
// safe confirmation step before crowns are spent. retinue_nav.js mirrors the
// Squirrel cursor into the visual selection without owning any game action.
::UnseenBanner.WorldRetinue <- {
	m = {
		Screen = null,
		Items = null,
		ItemIndex = 0,
		Mode = "",
		Active = false,
		DialogPending = false,
		DialogItem = null,
		PendingResult = null,
		PendingFocusKind = "",
		PendingFocusValue = null
	},
	Keys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end",
		[39] = "activate"
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function isDialogPending()
	{
		return this.m.DialogPending;
	},
	function getDialogItem()
	{
		return this.m.DialogItem;
	},
	function item(_cat, _texto = "", _valor = "", _detalle = "", _action = null, _payload = null, _visual = "", _rosterIndex = -1)
	{
		return {
			cat = _cat,
			texto = _texto,
			valor = _valor,
			detalle = _detalle,
			action = _action,
			payload = _payload,
			visual = _visual,
			rosterIndex = _rosterIndex
		};
	},
	function releaseKeys()
	{
		foreach( code, action in this.Keys )
		{
			::UnseenBanner.KeyGate.release(code);
		}
	},
	function clearNavigation()
	{
		this.releaseKeys();
		this.m.Screen = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Mode = "";
		this.m.Active = false;
	},
	function reset()
	{
		this.clearNavigation();
		this.m.DialogPending = false;
		this.m.DialogItem = null;
		this.m.PendingResult = null;
		this.m.PendingFocusKind = "";
		this.m.PendingFocusValue = null;
	},
	function onScreenHidden()
	{
		// A native confirmation temporarily hides the campfire screen. Preserve
		// its pending result/focus so the rebuilt main screen can report the
		// purchase; a real P/Escape close clears everything.
		if (this.m.DialogPending) this.clearNavigation();
		else this.reset();
	},
	function onDialogClosed()
	{
		this.m.DialogPending = false;
		this.m.DialogItem = null;
	},
	function joinStrings(_values)
	{
		local result = "";
		if (_values == null) return result;
		foreach( value in _values )
		{
			if (value == null || value == "") continue;
			if (result != "") result += "\n";
			result += value;
		}
		return result;
	},
	function joinRequirements(_values)
	{
		local result = "";
		if (_values == null) return result;
		foreach( value in _values )
		{
			if (value == null || value.Text == null || value.Text == "") continue;
			if (result != "") result += "\n";
			result += (value.IsSatisfied ? "1" : "0") + value.Text;
		}
		return result;
	},
	function openMain(_screen)
	{
		this.clearNavigation();
		if (_screen == null) return;
		this.m.Screen = _screen;
		this.m.Mode = "main";

		local retinue = ::World.Retinue;
		local slots = retinue.getCurrentFollowersForUI();
		local items = [];
		local hired = retinue.getNumberOfCurrentFollowers();
		local unlocked = retinue.getNumberOfUnlockedSlots();
		items.push(this.item("world.retinue.screen"));
		items.push(this.item("world.retinue.seats", "" + hired, "" + unlocked, "" + slots.len()));
		items.push(this.item("world.retinue.money", "" + ::World.Assets.getMoney()));
		items.push(this.item("world.retinue.renown", ::World.Assets.getBusinessReputationAsText(), "" + ::World.Assets.getBusinessReputation()));

		local upgrades = retinue.getInventoryUpgrades();
		local cartName = ::Const.Strings.InventoryHeader[upgrades];
		if (upgrades < ::Const.World.InventoryUpgradeCosts.len())
		{
			items.push(this.item(
				"world.retinue.cart.upgrade",
				cartName,
				::Const.Strings.InventoryUpgradeHeader[upgrades],
				"" + ::Const.World.InventoryUpgradeCosts[upgrades],
				"cart",
				upgrades,
				"cart"
			));
		}
		else
		{
			items.push(this.item("world.retinue.cart.max", cartName, "", "", null, null, "cart"));
		}

		foreach( i, slot in slots )
		{
			local seat = "" + (i + 1);
			if (slot.ID == "locked")
			{
				local reputationIndex = ::Const.FollowerSlotRequirements[i];
				items.push(this.item(
					"world.retinue.slot.locked",
					seat,
					::Const.Strings.BusinessReputation[reputationIndex],
					"" + ::Const.BusinessReputation[reputationIndex],
					null,
					i,
					"slot"
				));
			}
			else if (slot.ID == "free")
			{
				items.push(this.item("world.retinue.slot.free", seat, "", "", "slot", i, "slot"));
			}
			else
			{
				local follower = retinue.getFollower(slot.ID);
				if (follower == null) continue;
				local detail = follower.getDescription() + "\t" + this.joinStrings(follower.getEffects());
				items.push(this.item(
					"world.retinue.slot.follower",
					follower.getName(),
					seat,
					detail,
					"slot",
					i,
					"slot"
				));
			}
		}

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.restorePendingFocus();
		this.m.Active = true;
		this.syncVisualFocus();

		if (this.m.PendingResult != null)
		{
			local result = this.m.PendingResult;
			this.m.PendingResult = null;
			this.m.PendingFocusKind = "";
			this.m.PendingFocusValue = null;
			::UnseenBanner.sendMessage("interrupt", result.texto, result.cat, result.valor, result.detalle);
		}
		else
		{
			this.announceItem();
		}
	},
	function openHire(_screen, _module)
	{
		this.clearNavigation();
		if (_screen == null || _module == null) return;
		this.m.Screen = _screen;
		this.m.Mode = "hire";

		local data = _module.queryHireInformation();
		local roster = data != null ? data.Roster : null;
		local count = roster != null ? roster.len() : 0;
		local slot = _module.m.CurrentSlot;
		local current = ::World.Retinue.getCurrentFollowersForUI()[slot];
		local items = [];
		if (current.ID == "free")
		{
			items.push(this.item("world.retinue.hire.screen.free", "" + (slot + 1), "" + count));
		}
		else
		{
			local oldFollower = ::World.Retinue.getFollower(current.ID);
			local oldName = oldFollower != null ? oldFollower.getName() : "";
			items.push(this.item("world.retinue.hire.screen.replace", "" + (slot + 1), "" + count, oldName));
		}
		items.push(this.item("world.retinue.money", "" + ::World.Assets.getMoney()));

		if (roster != null)
		{
			foreach( i, follower in roster )
			{
				if (follower == null) continue;
				local status = !follower.IsUnlocked
					? "locked"
					: (::World.Assets.getMoney() < follower.Cost ? "unaffordable" : "available");
				local detail = status
					+ "\t" + follower.Description
					+ "\t" + this.joinStrings(follower.Effects)
					+ "\t" + this.joinRequirements(follower.Requirements);
				items.push(this.item(
					"world.retinue.hire.follower",
					follower.Name,
					"" + follower.Cost,
					detail,
					status == "available" ? "hire" : null,
					follower.ID,
					"follower",
					i
				));
			}
		}

		if (count == 0)
		{
			items.push(this.item("world.retinue.hire.none"));
		}

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.syncVisualFocus();
		this.announceItem();
	},
	function restorePendingFocus()
	{
		if (this.m.Items == null || this.m.PendingFocusKind == "") return;
		foreach( i, it in this.m.Items )
		{
			if (it.visual != this.m.PendingFocusKind) continue;
			if (this.m.PendingFocusKind == "cart" || it.payload == this.m.PendingFocusValue)
			{
				this.m.ItemIndex = i;
				return;
			}
		}
	},
	function onKey(_code)
	{
		if (!this.m.Active || this.m.Items == null || this.m.Items.len() == 0) return;
		local what = this.Keys[_code];
		if (what == "activate")
		{
			this.activate();
			return;
		}
		if (what == "up") this.m.ItemIndex -= 1;
		else if (what == "down") this.m.ItemIndex += 1;
		else if (what == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		this.syncVisualFocus();
		this.announceItem();
	},
	function activate()
	{
		if (this.m.Items == null || this.m.Items.len() == 0 || this.m.Screen == null) return;
		local it = this.m.Items[this.m.ItemIndex];
		if (this.m.Mode == "main" && it.action == "slot")
		{
			this.m.Screen.onSlotClicked(it.payload);
		}
		else if (this.m.Mode == "main" && it.action == "cart")
		{
			this.beginCartUpgrade();
		}
		else if (this.m.Mode == "hire" && it.action == "hire")
		{
			this.beginHire(it.payload);
		}
		else
		{
			this.announceItem();
		}
	},
	function beginCartUpgrade()
	{
		local upgrades = ::World.Retinue.getInventoryUpgrades();
		if (upgrades >= ::Const.World.InventoryUpgradeCosts.len())
		{
			this.announceItem();
			return;
		}
		this.m.DialogPending = true;
		this.m.DialogItem = null;
		this.m.Screen.getMainDialogModule().onCartClicked();
	},
	function beginHire(_id)
	{
		local follower = ::World.Retinue.getFollower(_id);
		if (follower == null)
		{
			this.announceItem();
			return;
		}
		follower.evaluate();
		if (!follower.isUnlocked() || ::World.Assets.getMoney() < follower.getCost())
		{
			this.announceItem();
			return;
		}

		local hireModule = this.m.Screen.getHireDialogModule();
		local slot = hireModule.m.CurrentSlot;
		local current = ::World.Retinue.getCurrentFollowersForUI()[slot];
		if (current.ID == "free")
		{
			this.m.DialogItem = this.item(
				"world.retinue.hire.confirm.free",
				follower.getName(),
				"" + follower.getCost(),
				"" + (slot + 1)
			);
		}
		else
		{
			local oldFollower = ::World.Retinue.getFollower(current.ID);
			local oldName = oldFollower != null ? oldFollower.getName() : "";
			this.m.DialogItem = this.item(
				"world.retinue.hire.confirm.replace",
				follower.getName(),
				"" + follower.getCost(),
				oldName
			);
		}

		this.m.DialogPending = true;
		local followerID = follower.getID();
		local followerName = follower.getName();
		this.m.Screen.getMainDialogModule().showDialogPopup(
			followerName,
			follower.getDescription(),
			function()
			{
				::UnseenBanner.WorldRetinue.finishHire(hireModule, followerID, followerName, slot);
			},
			null
		);
	},
	function finishHire(_module, _id, _name, _slot)
	{
		local result = _module.onHireFollower(_id);
		if (result != null && result.Result == 0)
		{
			this.m.PendingResult = this.item(
				"world.retinue.hire.done",
				_name,
				"" + ::World.Assets.getMoney(),
				"" + (_slot + 1)
			);
			this.m.PendingFocusKind = "slot";
			this.m.PendingFocusValue = _slot;
		}
		else
		{
			this.m.PendingResult = this.item("world.retinue.hire.failed", _name);
		}
	},
	function onCartUpgraded()
	{
		local upgrades = ::World.Retinue.getInventoryUpgrades();
		this.m.PendingResult = this.item(
			"world.retinue.cart.done",
			::Const.Strings.InventoryHeader[upgrades],
			"" + ::World.Assets.getMoney()
		);
		this.m.PendingFocusKind = "cart";
		this.m.PendingFocusValue = null;
	},
	function syncVisualFocus()
	{
		if (this.m.Screen == null || this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		if (this.m.Mode == "main")
		{
			local module = this.m.Screen.getMainDialogModule();
			if (module == null || module.m.JSHandle == null) return;
			module.m.JSHandle.asyncCall("setAccessibilityFocus", {
				Type = it.visual,
				Index = it.payload
			});
		}
		else if (this.m.Mode == "hire")
		{
			local module = this.m.Screen.getHireDialogModule();
			if (module == null || module.m.JSHandle == null) return;
			module.m.JSHandle.asyncCall("setAccessibilityFocus", it.rosterIndex);
		}
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
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
		AllyIndex = -1,
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
	EnemyCycleKeys = {
		[36] = true // z
	},
	// h mirrors the enemy cycle for allies: h advances through living allies by
	// distance from the active man, Shift+h walks the same list backwards. The
	// active man is excluded because x already recentres on him.
	AllyCycleKeys = {
		[18] = true // h
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
		return (_code in this.DirKeys)
			|| (_code in this.RecenterKeys)
			|| (_code in this.EnemyCycleKeys)
			|| (_code in this.AllyCycleKeys);
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
		this.m.AllyIndex = -1;
		this.m.CurrentSkill = null;
	},
	// Re-anchor on the active man on the first key of a turn (or the first key
	// ever), so the cursor always starts from a known reference and any tile held
	// from a previous turn/battle is dropped before use. A new turn also restarts
	// enemy/ally cycling from the nearest. Shared by onKey and getTile so acting on
	// the focused tile never reads a stale cursor.
	function ensureAnchored(_active)
	{
		if (this.m.CursorTile == null || this.m.LastActiveID != _active.getID())
		{
			this.m.CursorTile = _active.getTile();
			this.m.LastActiveID = _active.getID();
			this.m.EnemyIndex = -1;
			this.m.AllyIndex = -1;
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

		if (_code in this.EnemyCycleKeys)
		{
			this.cycleEnemy(_shift ? -1 : 1, _active, _entities);
			return;
		}

		if (_code in this.AllyCycleKeys)
		{
			this.cycleAlly(_shift ? -1 : 1, _active, _entities);
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
	function cycleAlly(_step, _active, _entities)
	{
		local activeTile = _active.getTile();
		local activeID = _active.getID();
		local scored = [];
		foreach( e in _entities.getAllInstancesAsArray() )
		{
			if (e != null
				&& e.getID() != activeID
				&& e.isAlive()
				&& e.isPlacedOnMap()
				&& (e.isPlayerControlled() || e.isAlliedWithPlayer())
				&& e.getTile() != null)
			{
				scored.push({ e = e, d = activeTile.getDistanceTo(e.getTile()) });
			}
		}

		if (scored.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "tile.no_allies");
			return;
		}

		scored.sort(function ( _a, _b )
		{
			if (_a.d > _b.d) return 1;
			if (_a.d < _b.d) return -1;
			return 0;
		});

		this.m.AllyIndex += _step;
		if (this.m.AllyIndex < 0) this.m.AllyIndex = scored.len() - 1;
		if (this.m.AllyIndex >= scored.len()) this.m.AllyIndex = 0;

		this.m.CursorTile = scored[this.m.AllyIndex].e.getTile();
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
					else if (e.isPlayerControlled() || e.isAlliedWithPlayer())
						kind = "ally";
					else
						kind = "enemy";

					// Current health, appended right after the name so surveying the
					// field (X to recentre, Z/Shift+Z to cycle enemies, H/Shift+H to
					// cycle allies, or any cursor step onto a unit) says at once how hurt it is.
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
	// man's usable skills. Shift+b is a second, closely related readout: the
	// enemies hex-adjacent to the cursor tile ("who is around here"), so it lives
	// on the same key as b (nearby enemies) with the modifier. t and b are bound
	// in vanilla to purely visual overlay toggles (skill trees / blocked tiles);
	// our hook consumes them during the player's turn, which a sighted tester
	// loses but a blind player never needs. tab is unbound in vanilla; k is free.
	Keys = {
		[30] = "status",   // t
		[38] = "turnorder", // tab
		[12] = "enemies",  // b (Shift+b -> engaged)
		[21] = "skills"    // k
	},
	function handles(_code)
	{
		return _code in this.Keys;
	},
	function onKey(_code, _active, _entities, _shift = false)
	{
		local what = this.Keys[_code];
		if (what == "status") this.status(_active);
		else if (what == "turnorder") this.turnOrder(_active);
		else if (what == "enemies")
		{
			if (_shift) this.engaged(_active, _entities);
			else this.enemies(_active, _entities);
		}
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
	function engaged(_active, _entities)
	{
		// Enemies hex-adjacent to the CURSOR tile, not the active man: the player
		// walks the hex cursor (Q/W/E/A/S/D) to a tile he is thinking of moving to
		// and asks "how many enemies are around here". This matters because in
		// Battle Brothers a brother adjacent to an enemy takes a free hit when he
		// later steps off, so a tile ringed by foes is a trap. With the cursor left
		// on the active man (its default / X-recentre position) it answers the same
		// question for where he stands right now. Reuses the b readout's hostile
		// set (getAllHostilesAsArray, honouring fog of war) filtered to hex distance
		// 1 from the cursor tile. Each line carries "name\tdirection", where direction
		// is the same 0-5 hex bearing used by the tactical cursor; the companion turns
		// it into the shared 12/2/4/6/8/10 clock vocabulary.
		local tile = ::UnseenBanner.TileCursor.getTile(_active);
		local enemies = [];
		foreach( e in _entities.getAllHostilesAsArray() )
		{
			if (e == null || !e.isAlive() || e.isHiddenToPlayer() || e.getTile() == null) continue;
			if (tile.getDistanceTo(e.getTile()) != 1) continue;
			enemies.push({
				name = e.getName(),
				dir = tile.getDirectionTo(e.getTile())
			});
		}

		if (enemies.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.engaged.none");
			return;
		}

		local text = "";
		for (local i = 0; i < enemies.len(); i += 1)
		{
			if (i > 0) text += "\n";
			text += enemies[i].name + "\t" + enemies[i].dir;
		}

		::UnseenBanner.sendMessage("interrupt", text, "combat.engaged", "" + enemies.len());
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

// The shared tactical/world character screen (C/I) as a keyboard-navigable list
// (roadmap 2.2 / completing 3.4). Vanilla renders the shown brother's whole sheet
// to a texture no screen reader can see, but every fact it is built from is a
// Squirrel actor API, so we rebuild the sheet as an ordered list of
// one-fact-per-entry lines and let the player walk it with Up/Down or jump with
// Home/End, reading one attribute at a time. A/D (and the left/right/Tab the
// screen already binds) switch brother; we drive the same vanilla switch so the
// visible sheet keeps up, and mirror the move on our own copy of the roster to
// know which brother is now shown. Tactical uses getInstancesOfFaction; world
// passes World.Assets.getFormation(), the exact sources queried by the native
// screen in their respective modes. Filtering null formation slots preserves the
// same order and next/previous wrap. The item index is preserved across brother
// switches so the same attribute can be compared quickly.
::UnseenBanner.SheetNav <- {
	m = {
		Brothers = null,
		BroIndex = 0,
		Sections = null,
		SectionIndex = 0,
		Items = null,
		ItemIndex = 0,
		DetailMode = false,
		DetailIndex = 0,
		ActionMode = false,
		Actions = null,
		ActionIndex = 0,
		FormationMoveMode = false,
		FormationSourceID = null,
		FormationSourceSlot = -1,
		FormationSourceName = "",
		Screen = null,
		WorldMode = false,
		Active = false
	},
	InspectKey = 32, // v -> open/close the focused entry's native tooltip details
	ActionKey = 39, // Enter -> rename, open/confirm an action or place a brother
	CancelKey = 41, // Escape -> cancel an armed formation move
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
	SectionKeys = {
		[46] = "prev", // Page Up
		[47] = "next"  // Page Down
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return _code == this.InspectKey
			|| (_code == this.ActionKey
				&& (this.m.ActionMode || this.isTacticalBagRow()
					|| (this.m.WorldMode && (this.isInventorySection()
						|| this.isIdentityRow() || this.isFormationSection()))))
			|| (_code == this.CancelKey && this.m.FormationMoveMode)
			|| (this.m.WorldMode && _code in this.SectionKeys)
			|| (_code in this.NextKeys)
			|| (_code in this.PrevKeys)
			|| (_code in this.MoveKeys);
	},
	function isMove(_code)
	{
		return _code in this.MoveKeys;
	},
	// Opening the native rename popup and both stages of a formation move happen
	// on keyup. Otherwise the press which opens/arms the next state can immediately
	// confirm it as well. Escape also waits for keyup while a move is armed, so its
	// release cannot leak through and close the whole CharacterScreen.
	function isReleaseHandledKey(_code)
	{
		return (_code == this.ActionKey
				&& (this.isIdentityRow() || this.isFormationSection()))
			|| (_code == this.CancelKey && this.m.FormationMoveMode);
	},
	function onReleaseHandledKey(_code, _screen)
	{
		if (_code == this.ActionKey && this.isIdentityRow())
		{
			if (::UnseenBanner.CharacterEdit.consumeSuppressedEnterRelease()) return;
			if (::UnseenBanner.CharacterEdit.isActive()) return;
		}
		this.onKey(_code, _screen);
	},
	function isNext(_code)
	{
		return _code in this.NextKeys;
	},
	function reset()
	{
		this.m.Active = false;
		this.m.Brothers = null;
		this.m.Sections = null;
		this.m.SectionIndex = 0;
		this.m.Items = null;
		this.m.BroIndex = 0;
		this.m.ItemIndex = 0;
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
		this.m.ActionMode = false;
		this.m.Actions = null;
		this.m.ActionIndex = 0;
		this.resetFormationMove();
		this.m.Screen = null;
		this.m.WorldMode = false;
		::UnseenBanner.TooltipNav.hide();
	},
	// Called when the screen becomes visible. _active is the man whose sheet the
	// screen opens on in battle. _roster is supplied by world mode; null keeps the
	// verified tactical source. With no selected actor, both native modes default
	// to the first non-null entry in their source roster.
	function open(_active, _roster = null, _screen = null, _initialSection = null)
	{
		local raw = _roster != null
			? _roster
			: ::Tactical.Entities.getInstancesOfFaction(::Const.Faction.Player);
		local list = [];
		if (raw != null)
		{
			foreach( b in raw )
			{
				if (b != null) list.push(b);
			}
		}
		this.m.Brothers = list;
		this.m.WorldMode = _roster != null;
		this.m.Screen = _screen;

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
		if (this.m.WorldMode)
		{
			this.buildWorldSections();
			local initialIndex = 0;
			if (_initialSection != null)
			{
				for (local i = 0; i < this.m.Sections.len(); i += 1)
				{
					if (this.m.Sections[i].id == _initialSection)
					{
						initialIndex = i;
						break;
					}
				}
			}
			this.activateSection(initialIndex, false, false);
		}
		else
		{
			this.buildItems();
			this.m.ItemIndex = 0;
		}
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
		this.announceItem(false, this.m.WorldMode);
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
	// One input dispatcher shared by tactical and world CharacterScreen. V never
	// reaches vanilla: it enters/leaves our detail list or opens the only detail.
	// The native brother switch is still invoked by the state so the visible UI
	// and this semantic cursor remain in lockstep.
	function onKey(_code, _screen)
	{
		if (this.m.FormationMoveMode)
		{
			if (_code == this.InspectKey || _code == this.CancelKey)
			{
				this.cancelFormationMove(true);
				return;
			}
			if (_code == this.ActionKey)
			{
				this.commitFormationMove(_screen);
				return;
			}

			// Moving to another section or brother abandons the pending operation.
			// The destination cursor itself uses Up/Down/Home/End and remains armed.
			if ((_code in this.SectionKeys) || (_code in this.NextKeys)
				|| (_code in this.PrevKeys))
			{
				this.cancelFormationMove(false);
			}
		}

		if (this.m.ActionMode)
		{
			if (_code == this.InspectKey)
			{
				this.leaveActions(true);
				return;
			}
			if (_code == this.ActionKey)
			{
				this.executeAction(_screen);
				return;
			}
			if (_code in this.MoveKeys)
			{
				this.moveAction(_code);
				return;
			}

			// Page navigation and brother switching leave the action sub-list first,
			// then continue through their ordinary CharacterScreen path below.
			this.leaveActions(false);
		}

		if (_code == this.InspectKey)
		{
			this.toggleDetails();
			return;
		}

		if (_code == this.ActionKey)
		{
			if (this.isIdentityRow())
			{
				this.leaveDetails();
				::UnseenBanner.TooltipNav.hide();
				::UnseenBanner.CharacterEdit.open(this.current());
				return;
			}
			if (this.isFormationSection())
			{
				this.beginFormationMove(_screen);
				return;
			}
			this.openActions();
			return;
		}

		if (this.m.WorldMode && _code in this.SectionKeys)
		{
			this.leaveDetails();
			::UnseenBanner.TooltipNav.hide();
			this.moveSection(_code);
			return;
		}

		if (_code in this.MoveKeys)
		{
			if (this.m.DetailMode) this.moveDetail(_code);
			else
			{
				::UnseenBanner.TooltipNav.hide();
				this.move(_code);
			}
			return;
		}

		// A/D, Left/Right and Tab always leave a nested detail list before changing
		// brother, retaining the parent sheet category for quick comparison.
		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		local next = this.isNext(_code);
		if (next) _screen.switchToNextBrother();
		else _screen.switchToPreviousBrother();
		this.switchBrother(next);
	},
	// Mirror a brother switch the same way the vanilla screen does (next/previous
	// non-null with wrap; the tactical roster is dense, so a plain modular step
	// matches). Rebuild the sheet for the new man but preserve the item index, then
	// announce his name and the same attribute in one interrupt message. Keeping it
	// as one message matters: a second interrupt would cut the name off.
	function switchBrother(_next)
	{
		if (this.m.Brothers == null || this.m.Brothers.len() == 0) return;
		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		local itemIndex = this.m.ItemIndex;
		local saved = this.m.WorldMode ? this.captureSectionPositions() : null;
		local n = this.m.Brothers.len();
		if (_next) this.m.BroIndex = (this.m.BroIndex + 1) % n;
		else this.m.BroIndex = (this.m.BroIndex - 1 + n) % n;

		if (this.m.WorldMode)
		{
			this.buildWorldSections(saved);
			this.activateSection(this.m.SectionIndex, false, false);
		}
		else
		{
			this.buildItems();
			this.m.ItemIndex = itemIndex;
		}
		if (this.m.Items != null && this.m.Items.len() > 0)
		{
			if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
			if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		}
		this.announceItem(true);
	},
	function leaveDetails()
	{
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
	},
	function leaveActions(_announceParent = false)
	{
		this.m.ActionMode = false;
		this.m.Actions = null;
		this.m.ActionIndex = 0;
		if (_announceParent) this.announceItem();
	},
	function currentSection()
	{
		if (this.m.Sections == null || this.m.Sections.len() == 0) return null;
		if (this.m.SectionIndex < 0 || this.m.SectionIndex >= this.m.Sections.len()) return null;
		return this.m.Sections[this.m.SectionIndex];
	},
	function isInventorySection()
	{
		local section = this.currentSection();
		if (section == null) return false;
		return section.id == "equipment" || section.id == "bag" || section.id == "stash";
	},
	function isFormationSection()
	{
		local section = this.currentSection();
		return this.m.WorldMode && section != null && section.id == "formation";
	},
	function isIdentityRow()
	{
		if (!this.m.WorldMode || this.m.Items == null || this.m.Items.len() == 0)
			return false;
		local section = this.currentSection();
		if (section == null || section.id != "sheet") return false;
		return this.m.Items[this.m.ItemIndex].cat == "combat.sheet.identity";
	},
	function isTacticalBagRow()
	{
		if (this.m.WorldMode || this.m.Items == null || this.m.Items.len() == 0)
			return false;
		local row = this.m.Items[this.m.ItemIndex];
		return "payload" in row && row.payload != null && row.payload.source == "bag";
	},
	function onNameEdited(_name)
	{
		if (_name == null || _name == "" || !this.isIdentityRow()) return;
		this.m.Items[this.m.ItemIndex].texto = _name;
	},
	function resetFormationMove()
	{
		this.m.FormationMoveMode = false;
		this.m.FormationSourceID = null;
		this.m.FormationSourceSlot = -1;
		this.m.FormationSourceName = "";
	},
	function cancelFormationMove(_announce)
	{
		if (!this.m.FormationMoveMode) return;
		local name = this.m.FormationSourceName;
		this.resetFormationMove();
		if (_announce)
		{
			::UnseenBanner.sendMessage("interrupt", name,
				"world.character.formation.move.cancelled");
		}
	},
	function formationLine(_slot)
	{
		return _slot < 9 ? "front" : (_slot < 18 ? "back" : "reserve");
	},
	function formationPosition(_slot)
	{
		return (_slot % 9) + 1;
	},
	function findInFormation(_formation, _id)
	{
		if (_formation == null || _id == null) return null;
		for (local i = 0; i < _formation.len(); i += 1)
		{
			local bro = _formation[i];
			if (bro != null && bro.getID() == _id)
				return { actor = bro, slot = i };
		}
		return null;
	},
	function selectBrotherByID(_id, _screen)
	{
		if (_id == null || this.m.Brothers == null) return false;
		for (local i = 0; i < this.m.Brothers.len(); i += 1)
		{
			if (this.m.Brothers[i].getID() == _id)
			{
				this.m.BroIndex = i;
				if (_screen != null && _screen.m.JSDataSourceHandle != null)
					_screen.m.JSDataSourceHandle.asyncCall("selectedBrotherById", _id);
				return true;
			}
		}
		return false;
	},
	function rebuildBrothersFromFormation(_formation, _selectedID)
	{
		local list = [];
		if (_formation != null)
		{
			foreach( bro in _formation )
			{
				if (bro != null) list.push(bro);
			}
		}
		this.m.Brothers = list;
		this.m.BroIndex = 0;
		if (_selectedID == null) return;
		for (local i = 0; i < list.len(); i += 1)
		{
			if (list[i].getID() == _selectedID)
			{
				this.m.BroIndex = i;
				break;
			}
		}
	},
	// Refresh both sides from live state after a native roster-position mutation.
	// Stable formation keys preserve the destination cursor and the entity ID
	// preserves the selected brother even though vanilla reload defaults to first.
	function refreshFormation(_selectedID, _screen, _saved)
	{
		local formation = ::World.Assets.getFormation();
		this.rebuildBrothersFromFormation(formation, _selectedID);
		this.buildWorldSections(_saved);
		local formationIndex = 0;
		for (local i = 0; i < this.m.Sections.len(); i += 1)
		{
			if (this.m.Sections[i].id == "formation")
			{
				formationIndex = i;
				break;
			}
		}
		this.activateSection(formationIndex, false, false);

		if (_screen != null)
		{
			_screen.loadBrothersList();
			if (_selectedID != null && _screen.m.JSDataSourceHandle != null)
				_screen.m.JSDataSourceHandle.asyncCall("selectedBrotherById", _selectedID);
		}
		return formation;
	},
	// Accessible equivalent of beginning a native drag: Enter on an occupied slot
	// arms that brother as the source, then Up/Down chooses a destination.
	function beginFormationMove(_screen)
	{
		if (!this.isFormationSection() || this.m.Items == null
			|| this.m.Items.len() == 0) return;
		local row = this.m.Items[this.m.ItemIndex];
		local payload = row.payload;
		if (payload == null || payload.source != "formation"
			|| payload.entityID == null)
		{
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.formation.error.empty_source");
			return;
		}

		local formation = ::World.Assets.getFormation();
		local live = this.findInFormation(formation, payload.entityID);
		if (live == null)
		{
			local selected = this.current();
			local selectedID = selected != null ? selected.getID() : null;
			local saved = this.captureSectionPositions();
			this.resetFormationMove();
			this.refreshFormation(selectedID, _screen, saved);
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.formation.error.stale");
			return;
		}

		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		local saved = this.captureSectionPositions();
		this.selectBrotherByID(live.actor.getID(), _screen);
		this.buildWorldSections(saved);
		this.activateSection(this.m.SectionIndex, false, false);
		this.m.FormationMoveMode = true;
		this.m.FormationSourceID = live.actor.getID();
		this.m.FormationSourceSlot = live.slot;
		this.m.FormationSourceName = live.actor.getName();
		::UnseenBanner.sendMessage("interrupt", this.m.FormationSourceName,
			"world.character.formation.move.started",
			this.formationLine(live.slot), "" + this.formationPosition(live.slot));
	},
	// Confirm the armed drag through CharacterScreen's native backend endpoint.
	// The two guards intentionally mirror the vanilla JS drop handler exactly.
	function commitFormationMove(_screen)
	{
		if (!this.m.FormationMoveMode || !this.isFormationSection()
			|| this.m.Items == null || this.m.Items.len() == 0) return;
		local row = this.m.Items[this.m.ItemIndex];
		local payload = row.payload;
		if (payload == null || payload.source != "formation")
		{
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.formation.error.invalid_target");
			return;
		}

		local formation = ::World.Assets.getFormation();
		local live = this.findInFormation(formation, this.m.FormationSourceID);
		if (live == null || _screen == null)
		{
			local selectedID = this.m.FormationSourceID;
			local saved = this.captureSectionPositions();
			this.resetFormationMove();
			this.refreshFormation(selectedID, _screen, saved);
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.formation.error.stale");
			return;
		}

		local source = live.actor;
		local sourceSlot = live.slot;
		local targetSlot = payload.slot;
		if (sourceSlot == targetSlot)
		{
			::UnseenBanner.sendMessage("interrupt", source.getName(),
				"world.character.formation.error.same");
			return;
		}

		local target = formation[targetSlot];
		local active = 0;
		for (local i = 0; i <= 17 && i < formation.len(); i += 1)
		{
			if (formation[i] != null) active += 1;
		}
		if (target == null && sourceSlot > 17 && targetSlot <= 17
			&& active >= ::World.Assets.getBrothersMaxInCombat())
		{
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.formation.error.maximum",
				"" + ::World.Assets.getBrothersMaxInCombat());
			return;
		}
		if (target == null && sourceSlot <= 17 && targetSlot > 17 && active == 1)
		{
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.formation.error.minimum");
			return;
		}

		local sourceID = source.getID();
		local sourceName = source.getName();
		local targetName = target != null ? target.getName() : "";
		local saved = this.captureSectionPositions();
		_screen.onUpdateRosterPosition([sourceID, targetSlot]);
		if (target != null)
			_screen.onUpdateRosterPosition([target.getID(), sourceSlot]);

		this.resetFormationMove();
		local updated = this.refreshFormation(sourceID, _screen, saved);
		local moved = targetSlot < updated.len() && updated[targetSlot] != null
			&& updated[targetSlot].getID() == sourceID;
		if (!moved)
		{
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.formation.error.unavailable");
			return;
		}

		local line = this.formationLine(targetSlot);
		local position = "" + this.formationPosition(targetSlot);
		if (target == null)
		{
			::UnseenBanner.sendMessage("interrupt", sourceName,
				"world.character.formation.result.move", line, position);
		}
		else
		{
			::UnseenBanner.sendMessage("interrupt", sourceName,
				"world.character.formation.result.swap", targetName,
				line + "|" + position);
		}
	},
	// Each section owns its last cursor position. Page navigation therefore returns
	// to the element the player left, and rebuilding for another brother restores
	// by stable key first (slot, perk ID, item instance ID or formation position).
	function activateSection(_index, _announce = true, _saveOld = true)
	{
		if (!this.m.WorldMode || this.m.Sections == null || this.m.Sections.len() == 0) return;
		local old = this.currentSection();
		if (_saveOld && old != null) old.index = this.m.ItemIndex;

		if (_index < 0) _index = 0;
		if (_index >= this.m.Sections.len()) _index = this.m.Sections.len() - 1;
		this.m.SectionIndex = _index;
		local section = this.m.Sections[_index];
		this.m.Items = section.items;
		this.m.ItemIndex = section.index;
		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.Items != null && this.m.Items.len() > 0 && this.m.ItemIndex >= this.m.Items.len())
			this.m.ItemIndex = this.m.Items.len() - 1;
		section.index = this.m.ItemIndex;
		::UnseenBanner.TooltipNav.showCharacterSection(section.id);
		if (_announce) this.announceItem(false, true);
	},
	function moveSection(_code)
	{
		if (this.m.Sections == null || this.m.Sections.len() == 0) return;
		local next = this.SectionKeys[_code] == "next";
		local index = this.m.SectionIndex + (next ? 1 : -1);
		// Clamp, rather than wrap, so the first and final sections are audible
		// boundaries. Re-reading their current row is intentional edge feedback.
		if (index < 0) index = 0;
		if (index >= this.m.Sections.len()) index = this.m.Sections.len() - 1;
		this.activateSection(index);
	},
	function captureSectionPositions()
	{
		local saved = {};
		if (this.m.Sections == null) return saved;
		local current = this.currentSection();
		if (current != null) current.index = this.m.ItemIndex;
		foreach( section in this.m.Sections )
		{
			local index = section.index;
			if (index < 0) index = 0;
			if (section.items.len() > 0 && index >= section.items.len()) index = section.items.len() - 1;
			local key = section.items.len() > 0 ? section.items[index].key : "";
			saved[section.id] <- { index = index, key = key };
		}
		return saved;
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
		local section = this.currentSection();
		if (section != null) section.index = this.m.ItemIndex;

		this.announceItem();
	},
	function action(_execute, _label, _result, _name, _payload, _cost = "")
	{
		return {
			execute = _execute,
			label = _label,
			result = _result,
			name = _name,
			payload = _payload,
			cost = _cost
		};
	},
	function tacticalEquipCost(_item)
	{
		local bro = this.current();
		if (this.m.WorldMode || bro == null || _item == null) return "";
		local inventory = bro.getItems();
		return "" + inventory.getActionCost([
			_item,
			inventory.getItemAtSlot(_item.getSlotType()),
			inventory.getItemAtSlot(_item.getBlockedSlotType())
		]);
	},
	function buildActions(_row)
	{
		local payload = _row != null ? _row.payload : null;
		local actions = [];

		if (payload != null && payload.source == "commands")
		{
			actions.push(this.action("sort", "sort", "sort", "", payload));
			actions.push(this.action("filter_all", "filter_all", "filter_all", "", payload));
			actions.push(this.action("filter_weapons", "filter_weapons", "filter_weapons", "", payload));
			actions.push(this.action("filter_armor", "filter_armor", "filter_armor", "", payload));
			actions.push(this.action("filter_misc", "filter_misc", "filter_misc", "", payload));
			actions.push(this.action("filter_usable", "filter_usable", "filter_usable", "", payload));
		}
		else if (payload != null && payload.item != null)
		{
			local item = payload.item;
			local name = item.getName();
			local slot = item.getSlotType();
			local equipable = slot != ::Const.ItemSlot.None && slot != ::Const.ItemSlot.Bag;

			if (payload.source == "stash")
			{
				if (item.isUsable())
					actions.push(this.action("use_stash", "use", "use", name, payload));
				else if (equipable)
					actions.push(this.action("equip_stash", "equip", "equip", name, payload));

				if (item.isAllowedInBag())
					actions.push(this.action("stash_to_bag", "move_bag", "move_bag", name, payload));

				if (item.getConditionMax() > 1 && item.getCondition() < item.getConditionMax())
				{
					local marked = item.isToBeRepaired();
					actions.push(this.action(marked ? "repair_unmark" : "repair_mark",
						marked ? "repair_unmark" : "repair_mark",
						marked ? "repair_unmark" : "repair_mark", name, payload));
				}
			}
			else if (payload.source == "bag")
			{
				if (equipable)
					actions.push(this.action("equip_bag", "equip", "equip", name, payload,
						this.tacticalEquipCost(item)));
				if (this.m.WorldMode)
					actions.push(this.action("bag_to_stash", "move_stash", "move_stash", name, payload));
			}
			else if (payload.source == "equipment")
			{
				if (item.isAllowedInBag())
					actions.push(this.action("equipment_to_bag", "move_bag", "move_bag", name, payload));
				actions.push(this.action("equipment_to_stash", "move_stash", "move_stash", name, payload));
			}
		}
		return actions;
	},
	// Phase 2.3 inventory actions. Enter opens an explicit sub-list instead of
	// mutating immediately: consumables and equipment changes therefore require a
	// deliberate second Enter. V returns to the parent item without changing state.
	function openActions()
	{
		local canOpen = this.m.WorldMode
			? this.isInventorySection()
			: this.isTacticalBagRow();
		if (!canOpen || this.m.Items == null || this.m.Items.len() == 0) return;

		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		local row = this.m.Items[this.m.ItemIndex];
		local actions = this.buildActions(row);
		if (actions.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", row.texto, "world.inventory.actions.none");
			return;
		}

		this.m.ActionMode = true;
		this.m.Actions = actions;
		this.m.ActionIndex = 0;
		this.announceAction(true);
	},
	function moveAction(_code)
	{
		if (!this.m.ActionMode || this.m.Actions == null || this.m.Actions.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.ActionIndex -= 1;
		else if (dir == "down") this.m.ActionIndex += 1;
		else if (dir == "home") this.m.ActionIndex = 0;
		else this.m.ActionIndex = this.m.Actions.len() - 1;

		if (this.m.ActionIndex < 0) this.m.ActionIndex = 0;
		if (this.m.ActionIndex >= this.m.Actions.len()) this.m.ActionIndex = this.m.Actions.len() - 1;
		this.announceAction();
	},
	function announceAction(_opened = false)
	{
		if (!this.m.ActionMode || this.m.Actions == null || this.m.Actions.len() == 0) return;
		local action = this.m.Actions[this.m.ActionIndex];
		local detail = (this.m.ActionIndex + 1) + "|" + this.m.Actions.len()
			+ "|" + (_opened ? "1" : "0") + "|" + action.cost;
		::UnseenBanner.sendMessage("interrupt", action.name, "world.inventory.action",
			action.label, detail);
	},
	function mutationSucceeded(_result)
	{
		return typeof _result == "table" && !("error" in _result);
	},
	function mutationErrorCode(_result)
	{
		if (typeof _result == "table" && "error" in _result)
			return "code" in _result ? "" + _result.code : "0";
		return "0";
	},
	// Call CharacterScreen's own UI endpoints. They are the vanilla funnels that
	// enforce two-handed/offhand displacement, bag and stash capacity, consumable
	// behavior, AP costs and rollback on failure. On success loadData refreshes the
	// visible UI, then the semantic lists are rebuilt from live state.
	function executeAction(_screen)
	{
		if (!this.m.ActionMode || this.m.Actions == null || this.m.Actions.len() == 0
			|| _screen == null) return;

		local action = this.m.Actions[this.m.ActionIndex];
		local payload = action.payload;
		local bro = this.current();
		local saved = this.m.WorldMode ? this.captureSectionPositions() : null;
		local oldSection = this.m.SectionIndex;
		local oldItemIndex = this.m.ItemIndex;
		local result = null;
		local success = false;

		if (payload == null || (payload.source != "commands" && bro == null))
		{
			this.leaveActions(false);
			::UnseenBanner.sendMessage("interrupt", "", "world.inventory.error", "0");
			return;
		}

		switch(action.execute)
		{
		case "equip_stash":
		case "use_stash":
			result = _screen.onEquipInventoryItem([
				bro.getID(), payload.itemId, payload.sourceIndex
			]);
			success = this.mutationSucceeded(result);
			break;

		case "stash_to_bag":
			result = _screen.onDropInventoryItemIntoBag([
				bro.getID(), payload.itemId, payload.sourceIndex, null
			]);
			success = this.mutationSucceeded(result);
			break;

		case "equip_bag":
			result = _screen.onEquipBagItem([
				bro.getID(), payload.itemId, payload.slotIndex
			]);
			success = this.mutationSucceeded(result);
			break;

		case "bag_to_stash":
			result = _screen.onDropBagItemIntoInventory([
				bro.getID(), payload.itemId, payload.slotIndex, null
			]);
			success = this.mutationSucceeded(result);
			break;

		case "equipment_to_bag":
			result = _screen.onDropPaperdollItemIntoBag([
				bro.getID(), payload.itemId, null
			]);
			success = this.mutationSucceeded(result);
			break;

		case "equipment_to_stash":
			result = _screen.onDropPaperdollItem([
				bro.getID(), payload.itemId, null
			]);
			success = this.mutationSucceeded(result);
			break;

		case "repair_mark":
		case "repair_unmark":
			_screen.onRepairInventoryItem(payload.itemId);
			success = payload.item.isToBeRepaired() == (action.execute == "repair_mark");
			break;

		case "sort":
			_screen.onSortButtonClicked();
			success = true;
			break;

		case "filter_all":
			_screen.onFilterAll();
			success = true;
			break;

		case "filter_weapons":
			_screen.onFilterWeapons();
			success = true;
			break;

		case "filter_armor":
			_screen.onFilterArmor();
			success = true;
			break;

		case "filter_misc":
			_screen.onFilterMisc();
			success = true;
			break;

		case "filter_usable":
			_screen.onFilterUsable();
			success = true;
			break;
		}

		this.leaveActions(false);
		if (!success)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.inventory.error",
				this.mutationErrorCode(result));
			return;
		}

		_screen.loadData();
		if (this.m.WorldMode)
		{
			this.buildWorldSections(saved);
			this.activateSection(oldSection, false, false);
			::UnseenBanner.sendMessage("interrupt", action.name,
				"world.inventory.result." + action.result);
		}
		else
		{
			this.buildItems();
			this.m.ItemIndex = oldItemIndex;
			if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
			if (this.m.Items.len() > 0 && this.m.ItemIndex >= this.m.Items.len())
				this.m.ItemIndex = this.m.Items.len() - 1;
			::UnseenBanner.sendMessage("interrupt", action.name,
				"combat.inventory.result." + action.result,
				bro != null ? "" + bro.getActionPoints() : "");
		}
	},
	function announceItem(_includeBrother = false, _includeSection = false)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		local category = it.cat;
		local text = it.texto;
		local value = it.valor;
		local detail = it.detalle;
		if (this.m.FormationMoveMode && this.isFormationSection()
			&& it.payload != null && it.payload.source == "formation")
		{
			category = "world.character.formation.target";
			value = it.payload.line;
			detail = it.payload.position + "|" + this.m.FormationSourceName
				+ "|" + (it.payload.slot == this.m.FormationSourceSlot ? "1" : "0");
		}
		// Identity already contains the brother's name, so do not say it twice when
		// that is the retained item.
		local bro = _includeBrother && category != "combat.sheet.identity" ? this.current() : null;
		local name = bro != null ? bro.getName() : null;
		// While choosing a destination V cancels the move; do not advertise the
		// ordinary V-for-details action on an occupied target.
		local detailCount = !this.m.FormationMoveMode
			? it.details.len()
			: 0;
		local actionCount = 0;
		if ((this.m.WorldMode && this.isInventorySection()) || this.isTacticalBagRow())
			actionCount = this.buildActions(it).len();
		else if (this.isIdentityRow())
			actionCount = 1;
		local context = null;
		local section = this.currentSection();
		if (this.m.WorldMode && section != null)
		{
			context = section.id + "|" + (this.m.ItemIndex + 1) + "|" + this.m.Items.len()
				+ "|" + (_includeSection ? "1" : "0");
		}
		::UnseenBanner.sendMessage("interrupt", text, category, value, detail,
			name, "" + detailCount, context, "" + actionCount);
	},
	// V on a row with several native tooltips enters a nested list; V again backs
	// out and re-announces the parent row. A single tooltip is shown/read directly
	// without changing modes, so the player's Up/Down cursor remains on the sheet.
	function toggleDetails()
	{
		if (this.m.DetailMode)
		{
			this.leaveDetails();
			::UnseenBanner.TooltipNav.hide();
			this.announceItem();
			return;
		}

		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		if (it.details.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "tooltip.unavailable");
			return;
		}

		this.m.DetailIndex = 0;
		this.m.DetailMode = it.details.len() > 1;
		this.showDetail();
	},
	function moveDetail(_code)
	{
		if (!this.m.DetailMode || this.m.Items == null || this.m.Items.len() == 0) return;
		local details = this.m.Items[this.m.ItemIndex].details;
		if (details.len() == 0) return;

		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.DetailIndex -= 1;
		else if (dir == "down") this.m.DetailIndex += 1;
		else if (dir == "home") this.m.DetailIndex = 0;
		else this.m.DetailIndex = details.len() - 1;

		if (this.m.DetailIndex < 0) this.m.DetailIndex = 0;
		if (this.m.DetailIndex >= details.len()) this.m.DetailIndex = details.len() - 1;
		this.showDetail();
	},
	function showDetail()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		if (it.details.len() == 0) return;
		if (this.m.DetailIndex < 0 || this.m.DetailIndex >= it.details.len()) this.m.DetailIndex = 0;
		local group = it.cat;
		local section = this.currentSection();
		if (this.m.WorldMode && section != null && section.detailGroup != "")
			group = section.detailGroup;
		else if (this.isTacticalBagRow())
			group = "world.character.bag";
		::UnseenBanner.TooltipNav.show(it.details[this.m.DetailIndex],
			this.m.DetailIndex + 1, it.details.len(), group);
	},
	function uiElementDetail(_bro, _elementID)
	{
		return {
			contentType = "ui-element",
			entityId = _bro.getID(),
			elementId = _elementID
		};
	},
	function rosterDetail(_bro)
	{
		return { contentType = "roster-entity", entityId = _bro.getID() };
	},
	function skillDetail(_bro, _skill)
	{
		return {
			contentType = "skill",
			entityId = _bro.getID(),
			skillId = _skill.getID()
		};
	},
	function statusDetail(_bro, _skill)
	{
		return {
			contentType = "status-effect",
			entityId = _bro.getID(),
			statusEffectId = _skill.getID()
		};
	},
	function itemDetail(_bro, _item, _owner = "entity")
	{
		return {
			contentType = "ui-item",
			entityId = _bro.getID(),
			itemId = _item.getInstanceID(),
			itemOwner = _owner
		};
	},
	function perkDetail(_bro, _perk)
	{
		return {
			contentType = "ui-perk",
			entityId = _bro.getID(),
			perkId = _perk.ID
		};
	},
	function row(_key, _cat, _texto = "", _valor = "", _detalle = "", _details = null,
		_payload = null)
	{
		return {
			key = _key,
			cat = _cat,
			texto = _texto,
			valor = _valor,
			detalle = _detalle,
			details = _details != null ? _details : [],
			payload = _payload
		};
	},
	function section(_id, _items, _detailGroup, _saved)
	{
		if (_items.len() == 0)
			_items.push(this.row(_id + ":empty", "world.character.empty"));

		local result = {
			id = _id,
			items = _items,
			detailGroup = _detailGroup,
			index = 0
		};
		if (_saved == null || !(_id in _saved)) return result;

		local old = _saved[_id];
		local found = -1;
		for (local i = 0; i < _items.len(); i += 1)
		{
			if (_items[i].key == old.key)
			{
				found = i;
				break;
			}
		}
		result.index = found >= 0 ? found : old.index;
		if (result.index < 0) result.index = 0;
		if (result.index >= _items.len()) result.index = _items.len() - 1;
		return result;
	},
	// Phase 2.4 world CharacterScreen sections, extended by phase 2.3 inventory
	// actions and the keyboard formation editor. Tactical keeps its flat sheet but
	// now shares the same V-driven native-tooltip funnel. Perks remain read-only;
	// equipment, backpack and stash expose an explicit Enter menu in world mode.
	function buildWorldSections(_saved = null)
	{
		this.buildItems();
		local sheet = [];
		foreach( it in this.m.Items )
		{
			// Perks and worn equipment now have their own element-by-element sections.
			// The remaining sheet still includes stats, skills, injuries and traits.
			if (it.cat == "combat.sheet.perks" || it.cat == "combat.sheet.equipment") continue;
			sheet.push(it);
		}

		this.m.Sections = [
			this.section("sheet", sheet, "", _saved),
			this.section("equipment", this.buildEquipmentRows(), "world.character.equipment", _saved),
			this.section("bag", this.buildBagRows(), "world.character.bag", _saved),
			this.section("stash", this.buildStashRows(), "world.character.stash", _saved),
			this.section("perks", this.buildPerkRows(), "world.character.perks", _saved),
			this.section("formation", this.buildFormationRows(), "world.character.formation", _saved)
		];
		if (this.m.SectionIndex < 0) this.m.SectionIndex = 0;
		if (this.m.SectionIndex >= this.m.Sections.len()) this.m.SectionIndex = this.m.Sections.len() - 1;
	},
	function itemAmount(_item)
	{
		return _item != null && _item.isAmountShown() ? "" + _item.getAmountString() : "";
	},
	function buildEquipmentRows()
	{
		local bro = this.current();
		local rows = [];
		if (bro == null) return rows;
		local inv = bro.getItems();
		local slots = [
			{ id = "mainhand", value = ::Const.ItemSlot.Mainhand },
			{ id = "offhand", value = ::Const.ItemSlot.Offhand },
			{ id = "head", value = ::Const.ItemSlot.Head },
			{ id = "body", value = ::Const.ItemSlot.Body },
			{ id = "accessory", value = ::Const.ItemSlot.Accessory },
			{ id = "ammo", value = ::Const.ItemSlot.Ammo }
		];
		foreach( slot in slots )
		{
			local item = inv.getItemAtSlot(slot.value);
			rows.push(this.row("equipment:" + slot.id, "world.character.equipment.slot",
				item != null ? item.getName() : "", slot.id,
				item != null ? this.itemAmount(item) : "",
				item != null ? [this.itemDetail(bro, item)] : [],
				item != null ? {
					source = "equipment",
					item = item,
					itemId = item.getInstanceID(),
					sourceIndex = null,
					slotIndex = slot.value
				} : null));
		}
		return rows;
	},
	function buildBagRows()
	{
		local bro = this.current();
		local rows = [];
		if (bro == null) return rows;
		local inv = bro.getItems();
		for (local i = 0; i < inv.getUnlockedBagSlots(); i += 1)
		{
			local item = inv.getItemAtBagSlot(i);
			local occupied = item != null && item != -1;
			rows.push(this.row("bag:" + i, "world.character.bag.slot",
				occupied ? item.getName() : "", "" + (i + 1),
				occupied ? this.itemAmount(item) : "",
				occupied ? [this.itemDetail(bro, item)] : [],
				occupied ? {
					source = "bag",
					item = item,
					itemId = item.getInstanceID(),
					sourceIndex = null,
					slotIndex = i
				} : null));
		}
		return rows;
	},
	function stashFilterName(_filter)
	{
		if (_filter == ::Const.Items.ItemFilter.Weapons) return "weapons";
		if (_filter == ::Const.Items.ItemFilter.Armor) return "armor";
		if (_filter == ::Const.Items.ItemFilter.Misc) return "misc";
		if (_filter == ::Const.Items.ItemFilter.Usable) return "usable";
		return "all";
	},
	function currentStashFilter()
	{
		if (this.m.Screen == null) return ::Const.Items.ItemFilter.All;
		return this.m.Screen.m.InventoryFilter;
	},
	function buildStashRows()
	{
		local bro = this.current();
		local rows = [];
		if (bro == null) return rows;
		local stash = ::World.Assets.getStash();
		if (stash == null) return rows;
		local filter = this.currentStashFilter();
		rows.push(this.row("stash:commands", "world.character.stash.commands", "",
			this.stashFilterName(filter), "", [], { source = "commands" }));

		foreach( index, item in stash.getItems() )
		{
			if (item == null || item == -1) continue;
			if (filter != ::Const.Items.ItemFilter.All
				&& (item.getItemType() & filter) == 0) continue;
			rows.push(this.row("stash:" + item.getInstanceID(), "world.character.stash.item",
				item.getName(), this.itemAmount(item), "",
				[this.itemDetail(bro, item, "stash")], {
					source = "stash",
					item = item,
					itemId = item.getInstanceID(),
					sourceIndex = index,
					slotIndex = null
				}));
		}
		return rows;
	},
	function buildPerkRows()
	{
		local bro = this.current();
		local rows = [];
		if (bro == null || !::isKindOf(bro, "player")) return rows;
		local spent = bro.getPerkPointsSpent();
		local points = bro.getPerkPoints();
		foreach( rowIndex, perkRow in ::Const.Perks.Perks )
		{
			foreach( perk in perkRow )
			{
				local state = "locked";
				if (bro.hasPerk(perk.ID)) state = "acquired";
				else if (spent >= perk.Unlocks) state = points > 0 ? "available" : "no_points";
				rows.push(this.row("perk:" + perk.ID, "world.character.perk",
					perk.Name, state, "" + (rowIndex + 1), [this.perkDetail(bro, perk)]));
			}
		}
		return rows;
	},
	function buildFormationRows()
	{
		local selected = this.current();
		local rows = [];
		local formation = ::World.Assets.getFormation();
		if (formation == null) return rows;
		local active = 0;
		local reserves = 0;
		for (local i = 0; i < formation.len(); i += 1)
		{
			if (formation[i] == null) continue;
			if (i <= 17) active += 1;
			else reserves += 1;
		}
		rows.push(this.row("formation:summary", "world.character.formation.summary",
			"", "" + active,
			::World.Assets.getBrothersMaxInCombat() + "|" + reserves,
			[], { source = "formation_summary" }));
		for (local i = 0; i < formation.len(); i += 1)
		{
			local line = this.formationLine(i);
			local position = this.formationPosition(i);
			local bro = formation[i];
			local isSelected = bro != null && selected != null && bro.getID() == selected.getID();
			rows.push(this.row("formation:" + i, "world.character.formation.slot",
				bro != null ? bro.getName() : "", line,
				position + "|" + (isSelected ? "1" : "0"),
				bro != null ? [this.rosterDetail(bro)] : [],
				{
					source = "formation",
					slot = i,
					line = line,
					position = position,
					entityID = bro != null ? bro.getID() : null
				}));
		}
		return rows;
	},
	// Build the ordered list of sheet entries for the shown brother. Each entry is a
	// tagged line the companion localizes; the framing words ("Resolve", "Head
	// armor"...) stay on that side, this only supplies the numbers and the already
	// localized game names. Attributes come first (what the user asked to read one
	// by one), then injuries, traits, perks and worn equipment as list entries.
	// Tactical mode appends the individual backpack slots so an item can be equipped
	// through CharacterScreen's native AP-charging endpoint.
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

		local function entry(_cat, _texto, _valor, _detalle, _details = null)
		{
			return {
				key = _cat,
				cat = _cat,
				texto = _texto,
				valor = _valor,
				detalle = _detalle,
				details = _details != null ? _details : []
			};
		}

		items.push(entry("combat.sheet.identity", bro.getName(), "" + bro.getLevel(), ""));

		if (isPlayer)
		{
			local bg = bro.getBackground();
			local bgDetails = bg != null ? [this.statusDetail(bro, bg)] : [];
			items.push(entry("combat.sheet.background", bg != null ? bg.getName() : "",
				"", "", bgDetails));
			items.push(entry("combat.sheet.xp", "", "" + bro.getXP(),
				"" + bro.getXPForNextLevel(),
				[this.uiElementDetail(bro, "character-screen.left-panel-header-module.Experience")]));
			// Long-term company mood has no dedicated standalone tooltip. The native
			// roster tooltip is its real visual source and includes the current mood.
			items.push(entry("combat.sheet.mood", "", "" + bro.getMoodState(), "",
				[this.rosterDetail(bro)]));
		}

		items.push(entry("combat.sheet.hp", "", "" + bro.getHitpoints(),
			"" + bro.getHitpointsMax(), [this.uiElementDetail(bro, "character-stats.Hitpoints")]));
		items.push(entry("combat.sheet.fatigue", "", "" + bro.getFatigue(),
			"" + bro.getFatigueMax(), [this.uiElementDetail(bro, "character-stats.Fatigue")]));
		items.push(entry("combat.sheet.resolve", "", "" + p.getBravery(), "",
			[this.uiElementDetail(bro, "character-stats.Bravery")]));
		items.push(entry("combat.sheet.initiative", "", "" + p.getInitiative(), "",
			[this.uiElementDetail(bro, "character-stats.Initiative")]));
		items.push(entry("combat.sheet.mskill", "", "" + p.getMeleeSkill(), "",
			[this.uiElementDetail(bro, "character-stats.MeleeSkill")]));
		items.push(entry("combat.sheet.rskill", "", "" + p.getRangedSkill(), "",
			[this.uiElementDetail(bro, "character-stats.RangeSkill")]));
		items.push(entry("combat.sheet.mdef", "", "" + p.getMeleeDefense(), "",
			[this.uiElementDetail(bro, "character-stats.MeleeDefense")]));
		items.push(entry("combat.sheet.rdef", "", "" + p.getRangedDefense(), "",
			[this.uiElementDetail(bro, "character-stats.RangeDefense")]));
		items.push(entry("combat.sheet.armor.head", "",
			"" + bro.getArmor(::Const.BodyPart.Head), "" + bro.getArmorMax(::Const.BodyPart.Head),
			[this.uiElementDetail(bro, "character-stats.ArmorHead")]));
		items.push(entry("combat.sheet.armor.body", "",
			"" + bro.getArmor(::Const.BodyPart.Body), "" + bro.getArmorMax(::Const.BodyPart.Body),
			[this.uiElementDetail(bro, "character-stats.ArmorBody")]));

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
		if (!this.m.WorldMode)
		{
			foreach( bagRow in this.buildBagRows() )
			{
				items.push(bagRow);
			}
		}

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
		local details = [];
		foreach( s in skills )
		{
			if (s == null) continue;
			if (n > 0) text += "\n";
			text += s.getName();
			details.push(this.statusDetail(_bro, s));
			n += 1;
		}
		return { key = _cat, cat = _cat, texto = text, valor = "" + n, detalle = "", details = details };
	},
	// Active skills for the sheet: each line is "name\tap\tfatigue" (no slot number,
	// since a non-active brother's hotkeys are not live, and no usability flag).
	function skillsEntry(_bro)
	{
		local list = _bro.getSkills().queryActives();
		local text = "";
		local n = 0;
		local details = [];
		foreach( s in list )
		{
			if (s == null) continue;
			if (n > 0) text += "\n";
			text += s.getName() + "\t" + s.getActionPointCost() + "\t" + s.getFatigueCost();
			details.push(this.skillDetail(_bro, s));
			n += 1;
		}
		return {
			key = "combat.sheet.skills",
			cat = "combat.sheet.skills",
			texto = text,
			valor = "" + n,
			detalle = "",
			details = details
		};
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
		local details = [];
		foreach( sl in slots )
		{
			local it = inv.getItemAtSlot(sl);
			if (it == null) continue;
			if (n > 0) text += "\n";
			text += it.getName();
			details.push(this.itemDetail(_bro, it));
			n += 1;
		}
		return {
			key = "combat.sheet.equipment",
			cat = "combat.sheet.equipment",
			texto = text,
			valor = "" + n,
			detalle = "",
			details = details
		};
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

// World pre-combat dialog. Vanilla renders the scout report and its buttons to a
// texture, and its AllowFormationPicking flag is not consumed by the JS at all.
// Flatten the visible report into a keyboard list and turn that dormant flag into
// an explicit "review formation" action. The character screen is layered over the
// still-live dialog without adding a MenuStack entry (defensive encounters make
// their existing entry non-cancellable); closing it therefore returns here instead
// of accidentally dismissing the encounter. Engage/retreat still call the exact
// backend methods used by the visible buttons.
::UnseenBanner.WorldCombatDialogNav <- {
	m = {
		Screen = null,
		Items = null,
		ItemIndex = 0,
		AllowDisengage = false,
		AllowFormation = false,
		InFormation = false,
		ClosingFormation = false,
		WorldState = null,
		Active = false
	},
	Keys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end",
		[39] = "activate",
		[41] = "cancel"
	},
	function isActive()
	{
		return this.m.Active;
	},
	function isEditingFormation()
	{
		return this.m.Active && this.m.InFormation;
	},
	function initialCharacterSection()
	{
		return this.isEditingFormation() ? "formation" : null;
	},
	function handles(_code)
	{
		return this.m.Active && _code in this.Keys;
	},
	function reset()
	{
		this.m.Screen = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.AllowDisengage = false;
		this.m.AllowFormation = false;
		this.m.InFormation = false;
		this.m.ClosingFormation = false;
		this.m.WorldState = null;
		this.m.Active = false;
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
	function prime(_screen, _entities, _allowDisengage, _allowFormation, _text,
		_disengageText)
	{
		this.reset();
		this.m.Screen = _screen;
		this.m.AllowDisengage = _allowDisengage;
		this.m.AllowFormation = _allowFormation;

		local visibleCount = _entities != null
			? (_entities.len() < 7 ? _entities.len() : 7)
			: 0;
		local kind = _allowDisengage ? "prepare" : "attacked";
		local items = [
			this.item("world.combat.dialog.screen", "", kind,
				visibleCount + "|" + (_allowFormation ? "1" : "0")
				+ "|" + (_allowDisengage ? "1" : "0"))
		];

		if (visibleCount == 0)
		{
			items.push(this.item("world.combat.dialog.unknown", _text));
		}
		else
		{
			for (local i = 0; i < visibleCount; i += 1)
			{
				items.push(this.item("world.combat.dialog.enemy",
					_entities[i].Name, "" + (i + 1), "" + visibleCount));
			}
		}

		if (_allowFormation)
		{
			items.push(this.item("world.combat.dialog.action.formation",
				"", "", "", "formation"));
		}
		items.push(this.item(_allowDisengage
				? "world.combat.dialog.action.engage"
				: "world.combat.dialog.action.defend",
			"", "", "", "engage"));
		if (_allowDisengage)
		{
			items.push(this.item("world.combat.dialog.action.disengage",
				_disengageText, "", "", "disengage"));
		}
		this.m.Items = items;
	},
	function open()
	{
		if (this.m.Screen == null || this.m.Items == null
			|| this.m.Items.len() == 0) return;
		::UnseenBanner.WorldStatus.reset();
		::UnseenBanner.WorldSurvey.reset();
		::UnseenBanner.WorldMove.reset();
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem();
	},
	function close()
	{
		this.reset();
	},
	function move(_direction)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		if (_direction == "up") this.m.ItemIndex -= 1;
		else if (_direction == "down") this.m.ItemIndex += 1;
		else if (_direction == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len())
			this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local item = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", item.texto, item.cat,
			item.valor, item.detalle);
	},
	function onKey(_code, _state)
	{
		if (!this.m.Active || !(_code in this.Keys)) return;
		local action = this.Keys[_code];
		if (action == "up" || action == "down"
			|| action == "home" || action == "end")
		{
			this.move(action);
			return;
		}
		if (action == "cancel")
		{
			if (!this.m.AllowDisengage)
			{
				::UnseenBanner.sendMessage("interrupt", "",
					"world.combat.dialog.error.cannot_disengage");
				return;
			}
			this.activate("disengage", _state);
			return;
		}

		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local selected = this.m.Items[this.m.ItemIndex].action;
		if (selected == null) this.announceItem();
		else this.activate(selected, _state);
	},
	function activate(_action, _state)
	{
		if (_action == "formation")
		{
			this.openFormation(_state);
			return;
		}

		local screen = this.m.Screen;
		if (screen == null) return;
		this.reset();
		if (_action == "engage") screen.onEngageButtonPressed();
		else if (_action == "disengage") screen.onCancelButtonPressed();
	},
	function openFormation(_state)
	{
		if (!this.m.Active || !this.m.AllowFormation || this.m.InFormation
			|| _state == null || _state.m.CharacterScreen == null
			|| _state.m.CharacterScreen.isVisible()
			|| _state.m.CharacterScreen.isAnimating()) return;

		this.m.InFormation = true;
		this.m.ClosingFormation = false;
		this.m.WorldState = _state;
		::World.Assets.updateFormation();
		if (this.m.Screen != null && this.m.Screen.m.JSHandle != null)
		{
			this.m.Screen.m.JSHandle.asyncCall(
				"setAccessibilityFormationOverlay", true);
		}
		_state.m.CharacterScreen.show();
	},
	// CharacterScreen's native close listener and C/I/Escape all funnel through the
	// hooked world_state.character_screen_onClosePressed below. Do not pop MenuStack:
	// its top entry belongs to the encounter dialog, not this temporary overlay.
	function closeFormation(_state)
	{
		if (!this.isEditingFormation() || this.m.ClosingFormation) return;
		local state = _state != null ? _state : this.m.WorldState;
		if (state == null || state.m.CharacterScreen == null) return;
		this.m.ClosingFormation = true;
		state.m.CharacterScreen.hide();
		::World.Assets.refillAmmo();
		state.updateTopbarAssets();
	},
	// Called only once Coherent reports the character screen fully hidden, so the
	// return cue cannot be cut off by its final formation-row announcement.
	function onFormationClosed()
	{
		if (!this.m.Active || !this.m.InFormation) return;
		if (this.m.Screen != null && this.m.Screen.m.JSHandle != null)
		{
			this.m.Screen.m.JSHandle.asyncCall(
				"setAccessibilityFormationOverlay", false);
		}
		this.m.InFormation = false;
		this.m.ClosingFormation = false;
		this.m.WorldState = null;
		::UnseenBanner.sendMessage("interrupt", "",
			"world.combat.dialog.formation.returned");
	}
};

// Battle confirmation dialog (the generic Yes/No popup). Pressing R brings up the
// "End Round" prompt, and quitting a battle brings up its own; vanilla draws them as
// a modal texture whose Yes/No buttons only the mouse can reach. While the popup is
// up the state parks a MenuStack backstep and swallows the keyboard, and Escape does
// not dismiss it either — so a blind player who opens one is trapped with no way out.
// We flatten the popup into a tiny navigable list: the message first, then the
// confirm and (for a real choice) cancel buttons. Up/Down reads one entry, Enter
// activates the focused button, and Escape cancels outright. Title and body are the
// game's own words, handed straight to dialog_screen.show, so nothing is scraped from
// the DOM; only the fixed button labels and the framing live in L10n. Buttons fire
// through the screen's own onOkPressed / onCancelPressed — exactly what a click calls.
::UnseenBanner.DialogNav = {
	m = {
		Items = null,
		ItemIndex = 0,
		Active = false,
		Title = "",
		Text = "",
		IsMonologue = false,
		Context = ""
	},
	// enter activates the focused button; escape cancels (native does nothing with it
	// while the dialog is up). Up/Down walk the list. Codes are MSU KeyMapSQ, not ASCII.
	Keys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end",
		[39] = "activate",
		[41] = "cancel"
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		// P is an additional Back key only for the P/Retinue confirmation.
		return _code in this.Keys || (this.m.Context == "world.retinue" && _code == 26);
	},
	function isContext(_context)
	{
		return this.m.Context == _context;
	},
	function reset()
	{
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
		this.m.Title = "";
		this.m.Text = "";
		this.m.IsMonologue = false;
		this.m.Context = "";
	},
	function item(_cat, _texto = "", _valor = "", _action = null, _detalle = "")
	{
		return { cat = _cat, texto = _texto, valor = _valor, action = _action, detalle = _detalle };
	},
	// Captured from dialog_screen.show before the modal animates in; open() then builds
	// the list once onScreenShown confirms the DOM is fully up (the deterministic point,
	// same pattern as the event and combat-result screens).
	function prime(_title, _text, _isMonologue, _context = "tactical")
	{
		this.m.Title = _title == null ? "" : _title;
		this.m.Text = _text == null ? "" : _text;
		this.m.IsMonologue = _isMonologue;
		this.m.Context = _context;
	},
	function open()
	{
		local items = [];
		// The message row carries the game's own title and body verbatim (cleaned on the
		// companion side); the framing and the navigation hint stay in L10n.
		local retinueItem = this.m.Context == "world.retinue"
			? ::UnseenBanner.WorldRetinue.getDialogItem()
			: null;
		if (retinueItem != null)
		{
			items.push(this.item(retinueItem.cat, retinueItem.texto, retinueItem.valor, null, retinueItem.detalle));
		}
		else
		{
			items.push(this.item("combat.dialog.screen", this.m.Text, this.m.Title));
		}
		if (this.m.IsMonologue)
		{
			// An info popup: a single "Ok", no cancel button or callback.
			items.push(this.item("combat.dialog.button.confirm.mono", "", "", "ok"));
		}
		else
		{
			items.push(this.item("combat.dialog.button.confirm", "", "", "ok"));
			items.push(this.item("combat.dialog.button.cancel", "", "", "cancel"));
		}
		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem();
	},
	function close()
	{
		this.reset();
	},
	function onKey(_code)
	{
		if (_code == 26)
		{
			this.cancel();
			return;
		}
		local what = this.Keys[_code];
		if (what == "up" || what == "down" || what == "home" || what == "end") this.move(what);
		else if (what == "activate") this.activate();
		else if (what == "cancel") this.cancel();
	},
	function move(_direction)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		if (_direction == "up") this.m.ItemIndex -= 1;
		else if (_direction == "down") this.m.ItemIndex += 1;
		else if (_direction == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	function activate()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local action = this.m.Items[this.m.ItemIndex].action;
		// The message row has no action, so Enter on it just re-reads it. Buttons go
		// through the screen's own handlers, which hide the dialog and fire the callback.
		if (action == "ok") ::DialogScreen.onOkPressed();
		else if (action == "cancel") ::DialogScreen.onCancelPressed();
		else this.announceItem();
	},
	// Escape from any row dismisses the whole dialog, the same as choosing No. A
	// monologue has no cancel path, so Escape confirms it — its only way out.
	function cancel()
	{
		if (this.m.IsMonologue) ::DialogScreen.onOkPressed();
		else ::DialogScreen.onCancelPressed();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
	}
};

// Tactical choice dialog. This is a separate screen from the generic dialog_screen:
// it presents the player's retreat confirmation and the mid-battle "The Enemy
// Retreats" decision. Both are mouse-only in vanilla and park a MenuStack backstep,
// so flatten the live title/body/button labels into a keyboard list. Enter invokes
// the focused native callback; Escape chooses the secondary action (or the sole
// primary action when no secondary callback exists).
::UnseenBanner.TacticalDialogNav = {
	m = {
		Screen = null,
		Items = null,
		ItemIndex = 0,
		Title = "",
		Subtitle = "",
		Text = "",
		YesLabel = "",
		NoLabel = "",
		HasNo = false,
		Active = false
	},
	Keys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end",
		[39] = "activate",
		[41] = "cancel"
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		return this.m.Active && _code in this.Keys;
	},
	function reset()
	{
		this.m.Screen = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Title = "";
		this.m.Subtitle = "";
		this.m.Text = "";
		this.m.YesLabel = "";
		this.m.NoLabel = "";
		this.m.HasNo = false;
		this.m.Active = false;
	},
	function item(_cat, _texto = "", _valor = "", _action = null)
	{
		return { cat = _cat, texto = _texto, valor = _valor, action = _action };
	},
	function prime(_screen, _title, _subtitle, _text, _yesLabel, _noLabel, _hasNo)
	{
		this.reset();
		this.m.Screen = _screen;
		this.m.Title = _title == null ? "" : _title;
		this.m.Subtitle = _subtitle == null ? "" : _subtitle;
		this.m.Text = _text == null ? "" : _text;
		this.m.YesLabel = _yesLabel == null ? "" : _yesLabel;
		this.m.NoLabel = _noLabel == null ? "" : _noLabel;
		this.m.HasNo = _hasNo;
	},
	function open()
	{
		if (this.m.Screen == null) return;
		local heading = this.m.Title;
		if (this.m.Subtitle != "")
		{
			heading += (heading == "" ? "" : ". ") + this.m.Subtitle;
		}
		this.m.Items = [
			this.item("combat.dialog.screen", this.m.Text, heading),
			this.item("combat.tactical.dialog.button", this.m.YesLabel, "", "yes")
		];
		if (this.m.HasNo)
		{
			this.m.Items.push(
				this.item("combat.tactical.dialog.button", this.m.NoLabel, "", "no"));
		}
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem();
	},
	function close()
	{
		this.reset();
	},
	function onKey(_code)
	{
		local what = this.Keys[_code];
		if (what == "up" || what == "down" || what == "home" || what == "end")
			this.move(what);
		else if (what == "activate")
			this.activate();
		else if (what == "cancel")
			this.cancel();
	},
	function move(_direction)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		if (_direction == "up") this.m.ItemIndex -= 1;
		else if (_direction == "down") this.m.ItemIndex += 1;
		else if (_direction == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;
		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len())
			this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	function activate()
	{
		if (this.m.Screen == null || this.m.Items == null || this.m.Items.len() == 0)
			return;
		local action = this.m.Items[this.m.ItemIndex].action;
		if (action == "yes") this.m.Screen.onYesPressed();
		else if (action == "no") this.m.Screen.onNoPressed();
		else this.announceItem();
	},
	function cancel()
	{
		if (this.m.Screen == null) return;
		if (this.m.HasNo) this.m.Screen.onNoPressed();
		else this.m.Screen.onYesPressed();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor);
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
		::UnseenBanner.TooltipNav.connect();
		::UnseenBanner.CharacterEdit.connect();
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

// The encounter dialog owns the final scout report and the native engage/retreat
// callbacks. Prime from show(), where those live values arrive, but announce only
// after its animation reports onScreenShown. Keeping the screen object lets the
// semantic action rows invoke exactly the same endpoints as its mouse buttons.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/world_combat_dialog", function(q) {
	q.show = @(__original) function( _entities, _allyBanners, _enemyBanners,
		_allowDisengage, _allowFormationPicking, _text, _image,
		_disengageText = "Cancel" )
	{
		::UnseenBanner.WorldCombatDialogNav.prime(this, _entities,
			_allowDisengage, _allowFormationPicking, _text, _disengageText);
		__original(_entities, _allyBanners, _enemyBanners, _allowDisengage,
			_allowFormationPicking, _text, _image, _disengageText);
	}

	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldCombatDialogNav.open();
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldCombatDialogNav.close();
	}
});

// The active-contract panel is the single UI funnel for acceptance, state changes
// (including post-combat "return to town" objectives) and save loading. Observe
// only after vanilla has successfully rendered the same getUIBulletpoints data.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/modules/world_contract_screen/world_active_contract_panel_module", function(q) {
	q.updateContract = @(__original) function( _contract = null )
	{
		__original(_contract);
		::UnseenBanner.ContractObjectives.observe(_contract);
	}

	q.clearContract = @(__original) function()
	{
		__original();
		::UnseenBanner.ContractObjectives.reset();
	}
});

// Obituary (phase 5.2). onScreenShown is the first deterministic point at which
// the native O screen is fully visible; build and announce the semantic list
// there. The same hook also covers opening it from the topbar button.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/world_obituary_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldObituary.open(this);
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldObituary.close();
	}
});

// Factions & Relations (phase 5.2). The same screen class handles both the R
// shortcut and the topbar button; build only once its native slide-in completes.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/world_relations_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldRelations.open(this);
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldRelations.close();
	}
});

// Retinue (phase 5.2). The screen-level shown event covers the first P opening.
// Returning from the hire submodule does not re-show the screen itself, so the
// main/hire module lifecycle hooks below rebuild at those transitions too.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/world_campfire_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldRetinue.openMain(this);
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldRetinue.onScreenHidden();
	}
});

::UnseenBanner.Mod.hook("scripts/ui/screens/world/modules/world_campfire_screen/campfire_main_dialog_module", function(q) {
	q.onModuleShown = @(__original) function()
	{
		__original();
		if (this.m.Parent != null && this.m.Parent.isVisible())
		{
			::UnseenBanner.WorldRetinue.openMain(this.m.Parent);
		}
	}

	q.onUpgradeInventorySpace = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldRetinue.onCartUpgraded();
	}
});

::UnseenBanner.Mod.hook("scripts/ui/screens/world/modules/world_campfire_screen/campfire_hire_dialog_module", function(q) {
	q.onModuleShown = @(__original) function()
	{
		__original();
		if (this.m.Parent != null && this.m.Parent.isVisible())
		{
			::UnseenBanner.WorldRetinue.openHire(this.m.Parent, this);
		}
	}
});

// Town screen (phase 4.5 + market phase 2.3b). onScreenShown builds the flattened
// building/contract list. showShopDialog and showHireDialog are the shared funnels
// used by their respective buildings, so they open the accessible cursor only
// after vanilla has installed the active module. showMainDialog closes whichever
// cursor owns the sub-dialog when Escape pops back to town.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/world_town_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldShop.close();
		::UnseenBanner.WorldHire.close();
		::UnseenBanner.WorldTown.open(this.getTown());
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldShop.close();
		::UnseenBanner.WorldHire.close();
		::UnseenBanner.WorldTown.close();
	}

	q.showShopDialog = @(__original) function()
	{
		__original();
		if (this.isVisible() && this.m.ShopDialogModule != null
			&& this.m.ShopDialogModule.getShop() != null)
		{
			::UnseenBanner.WorldShop.open(this, this.m.ShopDialogModule);
		}
	}

	q.showHireDialog = @(__original) function()
	{
		__original();
		if (this.isVisible() && this.m.HireDialogModule != null)
		{
			::UnseenBanner.WorldHire.open(this, this.m.HireDialogModule);
		}
	}

	q.showMainDialog = @(__original) function()
	{
		local leavingShop = ::UnseenBanner.WorldShop.isCurrent(this);
		local leavingHire = ::UnseenBanner.WorldHire.isCurrent(this);
		__original();
		if (leavingShop) ::UnseenBanner.WorldShop.close();
		if (leavingHire) ::UnseenBanner.WorldHire.close();
		if (leavingShop || leavingHire)
		{
			if (::UnseenBanner.WorldTown.isActive())
				::UnseenBanner.WorldTown.announceItem();
		}
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

// TacticalDialogScreen is distinct from the shared DialogScreen and carries its
// own live button labels. Capture them at show(), announce only after the opening
// animation completes, and clear the cursor when either native callback hides it.
::UnseenBanner.Mod.hook("scripts/ui/screens/tactical/tactical_dialog_screen", function(q) {
	q.show = @(__original) function( _title, _subTitle, _text, _yesButton,
		_noButton, _yesCallback, _noCallback = null )
	{
		::UnseenBanner.TacticalDialogNav.prime(this, _title, _subTitle, _text,
			_yesButton, _noButton, _noCallback != null);
		__original(_title, _subTitle, _text, _yesButton, _noButton,
			_yesCallback, _noCallback);
	}

	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.TacticalDialogNav.open();
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.TacticalDialogNav.close();
	}
});

// Confirmation dialog (dialog_screen, the shared Yes/No modal). show() is where the
// title/body arrive, so DialogNav is primed there; onScreenShown is the deterministic
// point the modal is fully up, so the list is built and announced there (same pattern
// as the event and combat-result screens); onScreenHidden clears it. It serves
// tactical dialogs and the Retinue's cart/hiring confirmations; other world-map
// users remain untouched. Their keys are driven by their respective state hooks.
::UnseenBanner.Mod.hook("scripts/ui/screens/dialog_screen", function(q) {
	q.show = @(__original) function( _title, _text, _doneCallback, _okCallback = null, _cancelCallback = null, _isMonologue = false )
	{
		__original(_title, _text, _doneCallback, _okCallback, _cancelCallback, _isMonologue);
		if (::Tactical.isActive())
		{
			::UnseenBanner.DialogNav.prime(_title, _text, _isMonologue);
		}
		else if (::UnseenBanner.WorldRetinue.isDialogPending())
		{
			::UnseenBanner.DialogNav.prime(_title, _text, _isMonologue, "world.retinue");
		}
	}

	q.onScreenShown = @(__original) function()
	{
		__original();
		if (::Tactical.isActive() || ::UnseenBanner.DialogNav.isContext("world.retinue"))
		{
			::UnseenBanner.DialogNav.open();
		}
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		local wasRetinue = ::UnseenBanner.DialogNav.isContext("world.retinue");
		::UnseenBanner.DialogNav.close();
		if (wasRetinue)
		{
			::UnseenBanner.WorldRetinue.onDialogClosed();
		}
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
		::UnseenBanner.WorldStatus.reset();
		::UnseenBanner.ContractObjectives.reset();
		::UnseenBanner.WorldSurvey.reset();
		::UnseenBanner.WorldMove.reset();
		::UnseenBanner.WorldTown.reset();
		::UnseenBanner.WorldObituary.close();
		::UnseenBanner.WorldRelations.close();
		::UnseenBanner.WorldRetinue.reset();
		::UnseenBanner.WorldCombatDialogNav.reset();
		::UnseenBanner.SheetNav.reset();
		__original();
	}

	q.loading_screen_onScreenShown = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.WorldStatus.reset();
		::UnseenBanner.ContractObjectives.reset();
		::UnseenBanner.WorldSurvey.reset();
		::UnseenBanner.WorldMove.reset();
		::UnseenBanner.WorldTown.reset();
		::UnseenBanner.WorldObituary.close();
		::UnseenBanner.WorldRelations.close();
		::UnseenBanner.WorldRetinue.reset();
		::UnseenBanner.WorldCombatDialogNav.reset();
		::UnseenBanner.SheetNav.reset();
		__original();
	}

	q.onFinish = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.WorldStatus.reset();
		::UnseenBanner.ContractObjectives.reset();
		::UnseenBanner.WorldSurvey.reset();
		::UnseenBanner.WorldMove.reset();
		::UnseenBanner.WorldTown.reset();
		::UnseenBanner.WorldObituary.close();
		::UnseenBanner.WorldRelations.close();
		::UnseenBanner.WorldRetinue.reset();
		::UnseenBanner.WorldCombatDialogNav.reset();
		::UnseenBanner.SheetNav.reset();
		__original();
	}

	// A CharacterScreen opened from the encounter dialog is a temporary overlay,
	// not a new MenuStack level. Its native close button and C/I/Escape all reach
	// this same funnel, so return to the still-visible dialog without popping the
	// encounter's own backstep.
	q.character_screen_onClosePressed = @(__original) function()
	{
		if (::UnseenBanner.WorldCombatDialogNav.isEditingFormation())
		{
			::UnseenBanner.WorldCombatDialogNav.closeFormation(this);
			return;
		}
		__original();
	}

	// Arrival polling for directional movement (phase 4.0). onUpdate runs every frame;
	// WorldMove.tick short-circuits immediately unless a step is in flight, so the
	// common idle case costs one boolean check.
	q.onUpdate = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldMove.tick();
	}

	// Announce pause/unpause (phase 4.0 companion request). setPause is the one funnel
	// every manual pause change flows through — the Space key, the topbar pause button,
	// auto-pause-after-city — so hooking it here catches them all in one place. Its own
	// guard means it only really flips on a genuine change (setAutoPause echoes the
	// current value, so menus/events do not trip it). Two changes are kept silent: our
	// own unpause when starting to move (SelfUnpause), which would otherwise speak on
	// every step, and pause changes during a loading screen (save load, etc.).
	q.setPause = @(__original) function( _f )
	{
		local was = this.m.IsGamePaused;
		__original(_f);

		if (this.m.IsGamePaused == was) return;

		if (::UnseenBanner.WorldMove.m.SelfUnpause)
		{
			::UnseenBanner.WorldMove.m.SelfUnpause = false;
			return;
		}

		if (this.isInLoadingScreen()) return;

		::UnseenBanner.sendMessage("interrupt", "", this.m.IsGamePaused ? "world.pause.on" : "world.pause.off");
	}

	q.onKeyInput = @(__original) function( _key )
	{
		// Ground truth for "a menu or popup is up" is the MenuStack's backsteps, not
		// MenuNav's module flags. Saving from the in-game pause menu returns to this
		// same world_state with no onInit and no loading screen (our other reset
		// points), and the pause menu's onModuleHidden is not guaranteed to fire, so
		// MenuNav.ActiveModule can stay set after the menu is gone — which then makes
		// the map-readout guard below (isActive) keep swallowing B and G. When the
		// stack has no backsteps the map is genuinely free, so clear any stale menu
		// state here. During real pause-menu navigation hasBacksteps() is true, so
		// MenuNav keeps working there untouched.
		if (this.m.MenuStack != null && !this.m.MenuStack.hasBacksteps()
			&& ::UnseenBanner.MenuNav.isActive())
		{
			::UnseenBanner.MenuNav.reset();
		}

		// Events and menu modules take priority over the map readouts. They can open
		// without a key handled here, so clear stale lists as soon as either is up.
		if (::UnseenBanner.EventNav.isActive() || ::UnseenBanner.MenuNav.isActive())
		{
			::UnseenBanner.WorldStatus.reset();
			::UnseenBanner.WorldSurvey.reset();
		}

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

		local code = _key.getKey();

		// World character screen (phase 2.2). This is the same CharacterScreen
		// class and SheetNav used in tactical mode, but its brother order comes
		// from World.Assets.getFormation(). Navigate on keydown with controlled
		// repeat and consume keyup as well, so A/D never pan the hidden map. The one
		// exception is Enter on identity and formation rows: open/arm on keyup, after
		// the triggering press has ended, or that same press can confirm the new state.
		// Escape is likewise consumed through keyup only while a formation move is
		// armed, preventing its release from leaking through and closing the screen.
		// C, I and ordinary Escape retain the world's native close path.
		if (this.isInCharacterScreen()
			&& ::UnseenBanner.SheetNav.isActive()
			&& !this.m.CharacterScreen.isAnimating()
			&& ::UnseenBanner.SheetNav.handles(code))
		{
			local handleOnRelease = ::UnseenBanner.SheetNav.isReleaseHandledKey(code);
			if (_key.getState() == 1 && !handleOnRelease)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.SheetNav.onKey(code, this.m.CharacterScreen);
				}
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(code);
				if (handleOnRelease)
				{
					::UnseenBanner.SheetNav.onReleaseHandledKey(code,
						this.m.CharacterScreen);
				}
			}
			return true;
		}

		// World encounter report and actions. CharacterScreen takes priority while
		// its formation overlay is up; after it closes, Up/Down/Home/End review the
		// scout report, Enter invokes the selected native action and Escape uses the
		// visible retreat button only when the encounter actually provides one.
		if (!this.isInCharacterScreen()
			&& this.m.CombatDialog != null
			&& this.m.CombatDialog.isVisible()
			&& ::UnseenBanner.WorldCombatDialogNav.handles(code))
		{
			if (_key.getState() == 0 && !this.m.CombatDialog.isAnimating())
			{
				::UnseenBanner.WorldCombatDialogNav.onKey(code, this);
			}
			return true;
		}

		// Retinue confirmation (cart upgrade or follower hire). The campfire screen
		// is temporarily hidden while dialog_screen is visible, so this must run
		// before checking the P screen itself or the plain-map guards. Use the same
		// keydown cadence as the Retinue lists; P and Escape both cancel here.
		if (::UnseenBanner.DialogNav.isActive()
			&& ::UnseenBanner.DialogNav.isContext("world.retinue")
			&& ::UnseenBanner.DialogNav.handles(code))
		{
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.DialogNav.onKey(code);
				}
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Retinue (phase 5.2): main and hire lists use immediate keydown navigation
		// with controlled repeat. P and Escape are absent from WorldRetinue.Keys, so
		// vanilla retains its native hire -> main -> map back path.
		if (this.m.CampfireScreen != null
			&& this.m.CampfireScreen.isVisible()
			&& ::UnseenBanner.WorldRetinue.isActive()
			&& ::UnseenBanner.WorldRetinue.handles(code))
		{
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldRetinue.onKey(code);
				}
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Obituary (phase 5.2): navigate the read-only list on keydown so every tap
		// responds immediately. Consume keyup too, using it only to clear KeyGate;
		// this prevents vanilla camera/list input from seeing half of the keystroke.
		// Held keys repeat at KeyGate's controlled cadence. O and Escape fall through
		// untouched, so vanilla closes the screen and pops its menu-stack entry.
		if (this.m.ObituaryScreen != null
			&& this.m.ObituaryScreen.isVisible()
			&& ::UnseenBanner.WorldObituary.isActive()
			&& ::UnseenBanner.WorldObituary.handles(code))
		{
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldObituary.onKey(code);
				}
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Factions & Relations (phase 5.2): identical keydown semantics to the
		// obituary. R and Escape are not captured, so the native state owns closing.
		if (this.m.RelationsScreen != null
			&& this.m.RelationsScreen.isVisible()
			&& ::UnseenBanner.WorldRelations.isActive()
			&& ::UnseenBanner.WorldRelations.handles(code))
		{
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldRelations.onKey(code);
				}
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Recruitment (phase 4.5): like the shop, the town frame remains technically
		// visible behind this module. Candidate navigation and its action/detail
		// sub-lists therefore take priority over the town list. At candidate level
		// Escape remains native and returns through MenuStack.
		if (this.m.WorldTownScreen.isVisible()
			&& !::UnseenBanner.EventNav.isActive()
			&& ::UnseenBanner.WorldHire.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldHire.handles(code))
		{
			if (_key.getState() == 0 && !this.m.WorldTownScreen.isAnimating())
			{
				::UnseenBanner.WorldHire.onKey(code);
			}
			return true;
		}

		// Market (phase 2.3b): the town screen remains technically visible behind its
		// shop module, so give the market cursor priority over the town list. Consume
		// both key states; act on release once the native slide animation is finished.
		// Escape is captured only inside an action/confirmation sub-list. At the normal
		// item level it falls through to MenuStack and returns to the town frame.
		if (this.m.WorldTownScreen.isVisible()
			&& !::UnseenBanner.EventNav.isActive()
			&& ::UnseenBanner.WorldShop.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldShop.handles(code))
		{
			if (_key.getState() == 0 && !this.m.WorldTownScreen.isAnimating())
			{
				::UnseenBanner.WorldShop.onKey(code);
			}
			return true;
		}

		// Town screen (phase 4.5): while the settlement screen is up (and no event is
		// layered over it), our list drives it — Up/Down/Home/End walk buildings and
		// contracts, Enter activates. Act on release, consume the key. Escape is left
		// alone so the native menu-stack pop still leaves the town.
		if (this.m.WorldTownScreen.isVisible()
			&& !::UnseenBanner.EventNav.isActive()
			&& !::UnseenBanner.WorldShop.isCurrent(this.m.WorldTownScreen)
			&& !::UnseenBanner.WorldHire.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldTown.isActive()
			&& ::UnseenBanner.WorldTown.handles(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.WorldTown.onKey(code, this);
			}
			return true;
		}

		// Map readouts, only on the plain map: G toggles the company status list (4.4),
		// B toggles the "what's in view" survey list (4.3); Up/Down move through the
		// open one, all on release. Consume both key states so vanilla camera movement
		// never competes with list navigation. The two lists are mutually exclusive —
		// opening or acting on one closes the other — so Up/Down always has a single
		// owner. Any unrelated map action closes both before passing through, so arrows
		// cannot remain captured after the player resumes normal play. "Map free" also
		// requires the character, town and Retinue screens to be down, so map keys
		// never fire inside any of those modal surfaces.
		local mapFree = !::UnseenBanner.EventNav.isActive() && !::UnseenBanner.MenuNav.isActive()
			&& !::UnseenBanner.WorldCombatDialogNav.isActive()
			&& !this.isInCharacterScreen()
			&& !this.m.WorldTownScreen.isVisible()
			&& (this.m.CampfireScreen == null || !this.m.CampfireScreen.isVisible());

		if (mapFree && ::UnseenBanner.WorldStatus.handles(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.WorldSurvey.reset();
				::UnseenBanner.WorldStatus.onKey(code);
			}

			return true;
		}

		if (mapFree && ::UnseenBanner.WorldSurvey.handles(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.WorldStatus.reset();
				::UnseenBanner.WorldSurvey.onKey(code, this);
			}

			return true;
		}

		// Directional movement (phase 4.0). Q/W/E/A/S/D step the party one hex; act on
		// press (Shift latches a march), clear the heading on release. Consume both key
		// states so the vanilla camera pan on these keys never fires. Starting to move
		// closes any open readout list — the player is driving the world now, not the list.
		if (mapFree && ::UnseenBanner.WorldMove.handlesDir(code))
		{
			if (_key.getState() == 1)
			{
				::UnseenBanner.WorldStatus.reset();
				::UnseenBanner.WorldSurvey.reset();
				::UnseenBanner.WorldMove.onDirKey(code, (_key.getModifier() & 1) != 0);
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.WorldMove.onRelease(code);
			}
			return true;
		}

		// Brake keys (Space and the other pause toggles): stop our march immediately on
		// press, then fall through so the engine still toggles pause on its own (it acts
		// on release). Not consumed — the native pause behavior is left intact.
		if (mapFree && ::UnseenBanner.WorldMove.handlesBrake(code) && _key.getState() == 1)
		{
			::UnseenBanner.WorldMove.onBrake();
		}

		// Enter (phase 4.5): engage a hostile party at contact range, or enter/interact
		// with the settlement or location under the party. This includes hostile camps
		// and event locations, not only isEnterable towns. Only consumed when there is
		// a valid target, so with nothing there the key falls through to its native
		// zoom-reset. Acts on release (the map delivers it, and native Enter uses press).
		if (mapFree && code == ::UnseenBanner.WorldEnter.EnterKey && _key.getState() == 0)
		{
			if (::UnseenBanner.WorldEnter.tryEnter(this)) return true;
		}

		if (::UnseenBanner.WorldStatus.isActive()) ::UnseenBanner.WorldStatus.reset();
		if (::UnseenBanner.WorldSurvey.isActive()) ::UnseenBanner.WorldSurvey.reset();

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
		::UnseenBanner.DialogNav.reset();
		::UnseenBanner.TacticalDialogNav.reset();
		::UnseenBanner.KeyGate.reset();
		// A battle starting clears the party's world path, so drop any in-flight world
		// march here — otherwise Pending would be left stale and fire a spurious
		// "Stopped" (or resume the march) on returning to the map.
		::UnseenBanner.WorldMove.reset();
	}

	q.onFinish = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.CombatResult.reset();
		::UnseenBanner.DialogNav.reset();
		::UnseenBanner.TacticalDialogNav.reset();
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

		// Tactical choice dialog (player retreat and enemy-retreat decision). This
		// screen is independent from DialogScreen, hides the tactical UI and leaves
		// a MenuStack backstep, so intercept it before every ordinary combat cursor.
		// Releases reach this outer hook while vanilla considers the modal active.
		if (this.m.TacticalDialogScreen != null
			&& this.m.TacticalDialogScreen.isVisible()
			&& !this.m.TacticalDialogScreen.isAnimating()
			&& ::UnseenBanner.TacticalDialogNav.handles(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.TacticalDialogNav.onKey(code);
			}
			return true;
		}

		// Confirmation dialog (the End Round popup R opens, and quit-battle prompts).
		// While it is up the state parks a MenuStack backstep and native onKeyInput
		// returns false for every key, so this must run before the tile cursor and
		// readouts to keep the popup reachable. Act on release (state 0), which is
		// delivered here even mid-battle — it is the very event R itself arrives on —
		// and consume it so nothing leaks through. Up/Down/Enter/Escape drive the list.
		if (::UnseenBanner.DialogNav.isActive() && ::UnseenBanner.DialogNav.handles(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.DialogNav.onKey(code);
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
			&& !this.m.CharacterScreen.isAnimating()
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
					::UnseenBanner.SheetNav.onKey(code, this.m.CharacterScreen);
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
							::UnseenBanner.Readout.onKey(code, active, this.Tactical.Entities, (_key.getModifier() & 1) != 0);
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

// Character sheet (the shared C/I screen). The screen's Visible flag flips only
// in onScreenShown — the asynchronous callback Coherent fires once the show
// animation is done — so hooking a state's showCharacterScreen and checking
// isVisible() right after show() never triggers (it is still false there; this
// exact bug ate the tactical sheet readout once). onScreenShown/onScreenHidden
// are the deterministic points, the same pattern as the event and combat-result
// screens. Tactical and world reuse the same navigation; only their native roster
// sources differ.
::UnseenBanner.Mod.hook("scripts/ui/screens/character/character_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();

		if (::Tactical.isActive())
		{
			// In battle the screen opens on the active brother; in battle
			// preparation there is none and SheetNav falls back to the first of
			// the roster — the same man the screen shows.
			::UnseenBanner.SheetNav.open(::Tactical.TurnSequenceBar.getActiveEntity(), null, this);
		}
		else
		{
			// strategic_onQueryBrothersList feeds this same 27-slot formation to
			// the native JS. SheetNav filters its null slots but retains formation
			// order, so every next/previous operation remains in lockstep. A
			// pre-combat review opens directly on Formation instead of briefly
			// announcing the ordinary character-sheet first.
			::UnseenBanner.SheetNav.open(null, ::World.Assets.getFormation(), this,
				::UnseenBanner.WorldCombatDialogNav.initialCharacterSection());
		}
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.SheetNav.close();
		::UnseenBanner.WorldCombatDialogNav.onFormationClosed();
	}
});

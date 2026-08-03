// The Unseen Banner — accessibility mod for blind players.
// Preload: registers the mod with Modern Hooks and wires the smoke test
// for phase 0.2 (trivial Squirrel hook + trivial injected JS).

::UnseenBanner <- {
	ID = "mod_unseen_banner",
	Name = "The Unseen Banner",
	Version = "0.9.0",
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
::Hooks.registerJS("ui/mods/mod_unseen_banner/game_finish_nav.js");
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

// Vanilla joins several paragraphs of prose into one field with <br> breaks — the
// harbour's destination blurb is a settlement description and a ship offer glued
// together that way. Speaking the whole thing in one utterance is the dump the
// "lists, not dumps" convention forbids, so it is cut here, in one place, into the
// paragraphs a sub-list can walk. Runs of breaks collapse and blank pieces are
// dropped, so "a<br><br>b" is two rows and never three. Whitespace inside a piece
// is left alone: the companion's cleaner already normalizes it.
::UnseenBanner.splitParagraphs <- function(_text)
{
	local result = [];
	if (_text == null) return result;
	local rest = "" + _text;

	while (true)
	{
		local at = rest.find("<br");
		local piece = at == null ? rest : rest.slice(0, at);
		local hasContent = false;
		for (local i = 0; i < piece.len(); i += 1)
		{
			local ch = piece.slice(i, i + 1);
			if (ch != " " && ch != "\t" && ch != "\n" && ch != "\r")
			{
				hasContent = true;
				break;
			}
		}
		if (hasContent) result.push(piece);

		if (at == null) break;
		// Step past the tag itself, whichever spelling it uses: <br>, <br/>, <br />.
		local close = rest.find(">", at);
		if (close == null) break;
		rest = rest.slice(close + 1);
	}

	return result;
}

::UnseenBanner.sendMessage <- function(_canal, _texto, _categoria = null, _valor = null, _detalle = null, _hermano = null, _detalles = null, _contexto = null, _acciones = null, _comparacion = null, _cadaver = null, _talento = null)
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
	if (_cadaver != null) json += ",\"cadaver\":\"" + ::UnseenBanner.jsonEscape(_cadaver) + "\"";
	// Talent stars (0-3) of an attribute row. Its own field rather than a token
	// packed into detalle, because the two rows that carry a maximum (health,
	// fatigue) already spend detalle on it, and because the companion appends the
	// stars uniformly for every row that reports them.
	if (_talento != null) json += ",\"talento\":\"" + ::UnseenBanner.jsonEscape(_talento) + "\"";
	json += "}";
	::logInfo("UB_MSG:" + json);
}

::logInfo("UnseenBanner: preload executed (Squirrel layer alive).");

::UnseenBanner.Mod.queue(">mod_msu", function() {
	::logInfo("UnseenBanner: queued function executed (Modern Hooks queue alive).");
	// MSU is guaranteed loaded here (the > dependency), so its vanilla keybinds
	// exist and can be rebound. See disarmVanillaWaitTurnEnd for why End must go.
	::UnseenBanner.disarmVanillaWaitTurnEnd();
});

// MSU reimplements the vanilla tactical hotkeys as its own remappable keybinds
// (msu/vanilla_mod/vanilla_keybinds.nut) and dispatches them from its OWN
// tactical_state.onKeyInput wrapper. MSU's hooks register during its queued
// function — after this preload's hooks — so its wrapper sits OUTSIDE ours and
// sees every key first. Consuming End in our hook therefore cannot stop MSU's
// "tactical_waitTurn" (bound to "end/space", no guard for our lists) from
// passing the active brother's turn before we ever run: exactly the bug where
// End meant "last row of the open list" to the player and "wait turn" to MSU.
// The fix goes through the keybind's own MSU setting — the same funnel its Mod
// Settings UI uses — so the dispatch index is rebuilt, the settings screen
// shows the truth, and the value persists. Space stays as the deliberate
// wait-turn key; End belongs to list navigation everywhere in this mod.
::UnseenBanner.disarmVanillaWaitTurnEnd <- function()
{
	// Defensive: a future MSU could rename the mod ID or the keybind. Losing
	// the rebind must degrade to the old behavior, never break loading (the
	// TacticalBlockedKeys fallthrough still blocks vanilla's own End path).
	try
	{
		local setting = ::getModSetting("vanilla", "tactical_waitTurn");
		if (setting.getValue() != "space") setting.set("space");
	}
	catch (error)
	{
		::logError("UnseenBanner: could not unbind End from MSU wait-turn: " + error);
	}
}

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
		ActiveModule = null,
		// Whether a popup dialog is up inside the active module (the Retire
		// confirmation, the save-name prompt, the delete confirmation). Reported by
		// menu_nav.js, because these popups fire no module lifecycle event of their
		// own. It is the one condition under which Escape stops being vanilla's.
		PopupOpen = false
	},
	// The menu modules this cursor drives across every surface that hosts them: the
	// main menu (main_menu_state) and the world/tactical pause menus. OptionsMenuModule
	// itself is shared by all three. Every one inherits ui_module, so the ui_module
	// hook below already reports them here by ID — activeness is just "one of these is
	// fully shown", regardless of which state hosts it.
	RecognizedModules = {
		MainMenuModule = true,
		NewCampaignModule = true,
		ScenarioMenuModule = true,
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
				&& _code in ::UnseenBanner.OptionsKeyCodes)
			|| (this.m.PopupOpen && _code == this.CancelKey);
	},
	// Escape belongs to vanilla everywhere in these menus — it pops the menu stack,
	// which is the whole back-navigation path — with one exception: while a popup is
	// up it cancels the popup instead, through the dialog's own Cancel button. Vanilla
	// cannot do this itself; its Escape-cancels-the-popup handler is a keyup bound on
	// `document` (popup_dialog.js), and the engine never delivers keyboard to this DOM,
	// so it has never fired for anybody.
	//
	// This only takes effect in the MAIN menu. In the world and tactical pause menus
	// MSU binds escape to its own "toggleMenuScreen" keybind, and MSU's onKeyInput
	// wrapper sits OUTSIDE ours (it registers in a queued function, after this
	// preload's hooks), so it consumes the key before we ever run — the same trap that
	// made consuming End useless against its wait-turn keybind. There Escape closes
	// the whole pause menu, and menu_nav.js destroys the abandoned dialog from
	// onModuleHidden instead. That is where the real hazard lived anyway: the Retire
	// dialog hangs off the module container, which hide() only display-toggles and the
	// button rebuild does not empty, so a popup left behind would come back visible
	// with its Ok still wired to onRetireButtonPressed.
	CancelKey = 41, // escape
	ActionKey = 39, // enter
	// Enter must never act on the press. Several menu rows open a text field — the
	// company name in New Campaign, the name prompt when saving — and once an input
	// holds DOM focus the engine routes the keyboard to the DOM, including the REST
	// of the very press that opened it. That press's ~40 ms auto-repeat arrives at
	// the field as a plain code 13, which every handler there reads as "commit and
	// leave the field": it opened and closed inside a single tap, and the player
	// never got to type a letter. KeyGate cannot debounce that repeat, because it is
	// delivered to the DOM and never passes through our Squirrel hook at all.
	//
	// So Enter waits for the release, once the press that triggered it is over —
	// the same rule SheetNav applies to the rows that open a new state. The movement
	// keys keep acting on the press, and that is where the reader latency was.
	// Escape joins Enter on the release for the same reason, from the other side: it
	// closes the popup, after which handlesKey stops claiming it — so a press-driven
	// Escape would see its own release fall through to vanilla and pop the menu the
	// popup was sitting on.
	function isReleaseHandledKey(_code)
	{
		return _code == this.ActionKey || _code == this.CancelKey;
	},
	function getKeyName(_code)
	{
		if (_code == this.CancelKey) return "escape";
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
		this.m.PopupOpen = false;
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onStateExited", null);
		}
	},
	// Reported by menu_nav.js as it takes over / hands back a popup dialog. Receives a
	// single table, because SQ.call transports one args value.
	function onPopupState(_data)
	{
		this.m.PopupOpen = _data != null && "abierto" in _data && _data.abierto == true;
		::logInfo("UnseenBanner: menu popup "
			+ (this.m.PopupOpen ? "opened" : "closed") + ".");
	},
	function onModuleShown(_id)
	{
		if (_id in this.RecognizedModules)
		{
			this.m.ActiveModule = _id;
			this.m.PopupOpen = false;
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
			this.m.PopupOpen = false;
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

// End-of-campaign screen: the defeat card after the last brother falls, and the
// retirement card after a won campaign. Vanilla leaves it reachable by mouse only
// — one Quit button, and a MenuStack entry whose backstep returns false, so not
// even Escape moves — which made a lost campaign end on a silent, inescapable
// screen. game_finish_nav.js reads it and adds the Up/Down/Enter cursor; keys are
// stolen from world_state.onKeyInput, which is where the screen lives.
//
// Won versus lost is not in the DOM in any form worth parsing, so it is captured
// from showGameFinishScreen's own argument (hook below) and handed to the JS side
// when the screen finishes animating in.
::UnseenBanner.GameFinishNav <- {
	m = {
		JSHandle = null,
		Active = false,
		GameWon = false
	},
	function connect()
	{
		this.m.JSHandle = ::UI.connect("UnseenBannerGameFinishNav", this);
	},
	function isActive()
	{
		return this.m.Active;
	},
	function reset()
	{
		this.m.Active = false;
		this.m.GameWon = false;
	},
	function setOutcome( _gameWon )
	{
		this.m.GameWon = _gameWon;
	},
	function sendKey(_name)
	{
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onKeyForwarded", _name);
		}
	},
	function onScreenShown()
	{
		this.m.Active = true;
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onFinishShown", this.m.GameWon ? "victory" : "defeat");
		}
	},
	function onScreenHidden()
	{
		this.m.Active = false;
		if (this.m.JSHandle != null)
		{
			this.m.JSHandle.asyncCall("onFinishHidden", null);
		}
	},
	// Receives a single table from JS (SQ.call only carries one args value).
	// Interrupt channel: the screen is modal and terminal, so nothing queued
	// behind it is worth hearing over the player's own navigation.
	function onFinishAnnouncement(_data)
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
// not push: F2 opens/closes the list and Up/Down read one fact at a time. Every
// fact is a Squirrel API (World.Assets / World.getTime / World.Contracts / the
// player roster), so nothing is scraped from the DOM; the companion owns the
// framing words.
//
// Key: F2 (code 72). g (17) used to own this readout, but it collided with the
// map explorer's own G (send the company to the cursor tile): with the explorer
// on, this list became unreachable. F2 is unbound on the world map in vanilla —
// only 42/75/79 are claimed among the higher codes (menu, quicksave, quickload)
// — and it is free of that ambiguity regardless of explorer state. Eventually
// remappable through MSU keybinds (roadmap fase 5).
::UnseenBanner.WorldStatus <- {
	m = {
		Sections = null,
		SectionIndex = 0,
		Items = null,
		ItemIndex = 0,
		Active = false,
		// Non-empty from the moment Enter requests an ambition or contract cancellation
		// until the native confirmation closes. The dialog hook uses the value as its
		// context, the same handshake the Retinue uses for its confirmations.
		DialogContext = ""
	},
	ToggleKey = 72, // f2
	ActionKey = 39, // enter
	MoveKeys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end"
	},
	SectionKeys = {
		[46] = "prev", // Page Up
		[47] = "next"  // Page Down
	},
	function isActive()
	{
		return this.m.Active;
	},
	function isDialogPending()
	{
		return this.m.DialogContext != "";
	},
	function getDialogContext()
	{
		return this.m.DialogContext;
	},
	function onDialogClosed()
	{
		this.m.DialogContext = "";
	},
	function handles(_code)
	{
		if (_code == this.ToggleKey) return true;
		if (!this.m.Active) return false;
		// Enter is only ours while the list is open; on the plain map it belongs to
		// WorldEnter (enter a settlement) and, failing that, to vanilla's zoom reset.
		return _code == this.ActionKey || _code in this.MoveKeys
			|| _code in this.SectionKeys;
	},
	function reset()
	{
		this.m.Sections = null;
		this.m.SectionIndex = 0;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
		this.m.DialogContext = "";
	},
	function item(_cat, _texto = "", _valor = "", _detalle = "", _action = "")
	{
		return { cat = _cat, texto = _texto, valor = _valor, detalle = _detalle,
			action = _action };
	},
	function section(_id, _items)
	{
		return { id = _id, items = _items, index = 0 };
	},
	function currentSection()
	{
		if (this.m.Sections == null || this.m.Sections.len() == 0) return null;
		if (this.m.SectionIndex < 0 || this.m.SectionIndex >= this.m.Sections.len())
			return null;
		return this.m.Sections[this.m.SectionIndex];
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
		if (_announce) this.announceItem();
	},
	function moveSection(_code)
	{
		local index = this.m.SectionIndex
			+ (this.SectionKeys[_code] == "next" ? 1 : -1);
		// Clamp so the first and last categories are audible boundaries.
		if (index < 0) index = 0;
		if (index >= this.m.Sections.len()) index = this.m.Sections.len() - 1;
		this.activateSection(index);
	},
	// Which of the topbar's four time buttons is lit, named. The test is copied from
	// world_state.updateTopBarButtonState, exact float comparison included, so the
	// spoken state and the highlighted button can never drift apart. Camping and
	// escorting pin the multiplier to values that match none of the three settings
	// (CampMult 3.0, EscortMult 3.75); they get their own states instead of being
	// rounded into a lie.
	function speedState()
	{
		if (::World.State.isPaused()) return "paused";
		if (::World.Assets.isCamping()) return "camp";
		local mult = ::World.getSpeedMult();
		if (mult == ::Const.World.SpeedSettings.NormalMult) return "normal";
		if (mult == ::Const.World.SpeedSettings.FastMult) return "fast";
		if (mult == ::Const.World.SpeedSettings.VeryFastMult) return "veryfast";
		return "locked";
	},
	// Feedback for a speed change, spoken from the setter hooks below after vanilla
	// has acted. Always read back rather than echo the request: when a clamp refuses
	// the change (camping, escorting) this reports what really happened instead of a
	// lie. Terser than the readout row on purpose — it repeats on every key tap.
	function announceSpeed(_state)
	{
		// Mirror the setters' own guard: with a menu up they are a silent no-op, and
		// announcing one would invent a change that never happened. Loading screens
		// get the same silence the setPause hook gives them.
		if (_state.m.MenuStack.hasBacksteps() || _state.isInLoadingScreen()) return;
		::UnseenBanner.sendMessage("interrupt", "", "world.speed." + this.speedState());
	},
	function open()
	{
		local assets = ::World.Assets;
		local money = assets.getMoney();
		local dailyMoney = assets.getDailyMoneyCost();
		// The crowns tooltip uses this exact floored division to estimate how many
		// full payrolls the current purse covers. A zero cost is kept separate so
		// the companion can say that nobody is drawing wages without dividing.
		local moneyDays = dailyMoney > 0 ? (money / dailyMoney).tointeger() : -1;
		local food = assets.getFood();
		local dailyFood = assets.getDailyFoodCost();
		// Days of food left at the current rate; -1 signals "no upkeep" (an empty
		// roster) so it gets a meaningful row without dividing by zero.
		local foodDays = dailyFood > 0 ? (food / dailyFood).tointeger() : -1;
		local brothers = ::World.getPlayerRoster().getSize();
		local brothersMax = assets.getBrothersMax();
		local repair = assets.getRepairRequired();
		local healing = assets.getHealingRequired();

		local time = ::World.getTime();
		local day = time.Days;
		local timeCat = time.IsDaytime ? "world.status.time.day" : "world.status.time.night";
		// The topbar clock paints exactly this table (the topbar datasource module
		// does `Const.Strings.World.TimeOfDay[currentTime.TimeOfDay]`), so speaking it
		// is reading what is on screen, not rebuilding the hour from raw seconds. The
		// bounds check keeps a future eighth-of-day from throwing and aborting the
		// whole list — the failure mode contract.getTitle() already taught us.
		local timeOfDay = time.TimeOfDay;
		local timeName = timeOfDay >= 0 && timeOfDay < ::Const.Strings.World.TimeOfDay.len()
			? ::Const.Strings.World.TimeOfDay[timeOfDay] : "";

		// The topbar banner, otherwise unreadable: getUIText() is the very string it
		// paints, progress counter included ("Defeat packs of roving beasts (3/5)").
		// Every ambition rebuilds it from live world state, so it gets the same
		// treatment as game-written text elsewhere — a throw in here would abort the
		// list half-built and leave G mute.
		local ambition = "";
		// Vanilla only lets an ambition be abandoned through the topbar banner, a
		// mouse-only click, and only for the ones that allow it; the row below turns
		// that same guarded path into an Enter when the game itself would allow it.
		local ambitionCancelable = false;
		if ("Ambitions" in ::World && ::World.Ambitions != null
			&& ::World.Ambitions.hasActiveAmbition())
		{
			try
			{
				ambition = ::World.Ambitions.getActiveAmbition().getUIText();
				ambitionCancelable = ::World.Ambitions.getActiveAmbition().isCancelable();
			}
			catch (error)
			{
				::logError("UnseenBanner: could not read the active ambition: " + error);
			}
		}

		// Brothers holding an unspent perk point or a pending level-up. isLeveled() is
		// the exact predicate the roster paints the level-up star from (data_helper
		// feeds it as `leveledUp`), guests already excluded, so this count and the
		// stars on screen cannot disagree. They are named one per row rather than
		// crammed into a sentence — with eight of them a single utterance is a dump.
		//
		// That one flag covers two independent debts, though: the attribute increases
		// the level granted (m.LevelUps) and the perk point (m.PerkPoints). Spending
		// one does not clear the other, so each man says which he still owes. Saying
		// only "waiting to level up" left the count stuck at one with an empty perk
		// tree and no way to tell what was missing.
		local leveled = [];
		foreach( bro in ::World.getPlayerRoster().getAll() )
		{
			if (bro == null || !bro.isLeveled()) continue;
			local levelUps = bro.getLevelUps();
			local points = bro.getPerkPoints();
			leveled.push({
				name = bro.getName(),
				what = levelUps > 0 ? (points > 0 ? "both" : "attributes") : "perk",
				detail = levelUps + "|" + points
			});
		}

		// Contract titles carry BBCode/colour markup, so they ride in `texto`, the
		// field the companion runs through clean() before speaking.
		local contract = ::World.Contracts.getActiveContract();
		local title = contract != null ? contract.getTitle() : "";

		local general = [];
		general.push(this.item("world.status.screen"));
		general.push(this.item(timeCat, timeName, "" + day));
		// No speed row: pausing and the 1/2/3 keys already announce the speed the
		// moment it changes (see the setPause and setNormal/Fast/VeryFastTime hooks),
		// so a row repeating it here is one more thing to walk past.
		general.push(this.item(brothers == 1 ? "world.status.brothers.one" : "world.status.brothers", "", "" + brothers, "" + brothersMax));
		// Pending level ups are listed only when there are any. "Nobody is waiting"
		// is not news: the answer to "who can level up" is a list, and an empty list
		// is best said by not being there.
		if (leveled.len() != 0)
		{
			general.push(this.item(leveled.len() == 1 ? "world.status.levelup.one" : "world.status.levelup", "", "" + leveled.len()));
			foreach( entry in leveled )
				general.push(this.item("world.status.levelup.brother", entry.name,
					entry.what, entry.detail));
		}
		general.push(this.item("world.status.money", "", "" + money,
			dailyMoney + "|" + moneyDays));
		general.push(this.item("world.status.food", "", "" + food));
		if (foodDays < 0) general.push(this.item("world.status.food.none"));
		else general.push(this.item(foodDays == 1 ? "world.status.food.day" : "world.status.food.days", "", "" + foodDays));
		// The three consumables the topbar shows next to crowns and food. Vanilla's own
		// UI data names armor parts "Supplies" (data_helper.convertAssetsInformationToUIData),
		// so the spoken name follows the screen rather than the internal getter.
		general.push(this.item("world.status.supplies", "", "" + assets.getArmorParts(),
			repair.Hours + "|" + repair.ArmorParts));
		general.push(this.item("world.status.ammo", "", "" + assets.getAmmo()));
		general.push(this.item("world.status.medicine", "", "" + assets.getMedicine(),
			healing.DaysMin + "|" + healing.DaysMax + "|"
				+ healing.MedicineMin + "|" + healing.MedicineMax));
		local ambitionCat = ambition == ""
			? "world.status.ambition.none"
			: (ambitionCancelable ? "world.status.ambition.cancelable" : "world.status.ambition");
		general.push(this.item(ambitionCat, ambition, "", "",
			ambitionCancelable ? "ambition.cancel" : ""));
		general.push(this.item(contract != null ? "world.status.contract.cancelable" : "world.status.contract.none",
			title, "", "", contract != null ? "contract.cancel" : ""));
		if (contract != null)
		{
			local objectives = ::UnseenBanner.ContractObjectives.getTexts(contract);
			if (objectives.len() == 0)
				general.push(this.item("world.status.objectives.none"));
			else
				foreach( objective in objectives )
					general.push(this.item("world.status.objective", objective));
		}

		// The second category is one row per brother who is missing hitpoints or has
		// a temporary injury. Hitpoint recovery uses getDaysWounded(), the exact rounded
		// value vanilla paints as Light Wounds. Each injury uses getHealingTime(), the
		// same remaining min/max range its native tooltip displays.
		local woundedRows = [];
		foreach( bro in ::World.getPlayerRoster().getAll() )
		{
			if (bro == null) continue;
			local injuries = bro.getSkills().query(::Const.SkillType.TemporaryInjury);
			if (bro.getSkills().hasSkill("injury.sickness"))
			{
				local sickness = bro.getSkills().getSkillByID("injury.sickness");
				if (sickness != null && injuries.find(sickness) == null) injuries.push(sickness);
			}

			local lightDays = bro.getDaysWounded();
			if (lightDays <= 0 && injuries.len() == 0) continue;

			local healingState = assets.getMedicine() <= 0 ? "medicine"
				: (bro.getSkills().hasSkill("trait.oath_of_sacrifice") ? "oath" : "ok");
			local injuryData = "";
			foreach( injury in injuries )
			{
				if (injury == null) continue;
				local healing = injury.getHealingTime();
				if (injuryData != "") injuryData += "\n";
				injuryData += injury.getName() + "\t" + healing.Min + "\t"
					+ healing.Max + "\t" + healingState;
			}
			local detail = bro.getHitpoints() + "|" + bro.getHitpointsMax()
				+ "|" + lightDays + "|" + injuryData;
			woundedRows.push(this.item("world.status.wounded.brother",
				bro.getName(), "", detail));
		}

		local wounded = [];
		wounded.push(this.item(woundedRows.len() == 1
			? "world.status.wounded.screen.one" : "world.status.wounded.screen",
			"", "" + woundedRows.len()));
		if (woundedRows.len() == 0)
			wounded.push(this.item("world.status.wounded.none"));
		else
			foreach( row in woundedRows ) wounded.push(row);

		this.m.Sections = [
			this.section("general", general),
			this.section("wounded", wounded)
		];
		this.m.Active = true;
		this.activateSection(0, true, false);
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

		if (!this.m.Active) return;
		if (_code in this.SectionKeys)
		{
			this.moveSection(_code);
			return;
		}

		if (_code == this.ActionKey)
		{
			this.activate();
			return;
		}

		if (!(_code in this.MoveKeys)) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.ItemIndex -= 1;
		else if (dir == "down") this.m.ItemIndex += 1;
		else if (dir == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	// Enter on an actionable row always calls the same native endpoint as its mouse
	// control. Both cancellation paths raise the shared confirmation dialog, which
	// DialogNav narrates and operates; no reputation, relation or payment rule is
	// reproduced here.
	function activate()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		if (it.action == "ambition.cancel") this.cancelAmbition();
		else if (it.action == "contract.cancel") this.cancelContract();
		else this.announceItem(); // no action on this row: re-read it
	},
	function cancelAmbition()
	{

		local module = ("TopbarAmbitionModule" in ::World) ? ::World.TopbarAmbitionModule : null;
		if (module == null || ::World.Ambitions == null
			|| !::World.Ambitions.hasActiveAmbition()
			|| !::World.Ambitions.getActiveAmbition().isCancelable())
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.status.ambition.uncancelable");
			return;
		}

		// The confirmation takes over the screen, and the row behind it would be
		// describing an ambition that may be gone by the time it comes back. Close the
		// list rather than leave a stale row under the cursor; F2 rebuilds it fresh.
		this.reset();
		this.m.DialogContext = "world.ambition";
		module.onRequestCancel();
	},
	function cancelContract()
	{
		local contract = ::World.Contracts.getActiveContract();
		local screen = ::World.State.getWorldScreen();
		local module = screen != null ? screen.getActiveContractPanelModule() : null;
		if (contract == null || module == null)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.status.contract.none");
			return;
		}

		// onShowContractDetails is the misleadingly named click endpoint of the visible
		// contract panel. It opens vanilla's Cancel Contract warning; accepting it calls
		// ContractManager.removeContract, which owns every consequence of abandonment.
		this.reset();
		this.m.DialogContext = "world.contract";
		module.onShowContractDetails();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
	}
};

// Passage of time. The clock is the only thing on the world map that moves on its
// own, and it moves in silence: night falls, most buildings shut and the recruit
// board empties with nothing to mark it. G already reports the hour on demand
// (WorldStatus); this announces the change itself.
//
// Funnel: world_state.updateDayTime, the single call that refreshes the visible
// clock — it is what feeds Const.Strings.World.TimeOfDay to the topbar datasource.
// It runs from onUpdate on every frame the map is live, so the common path here is
// two comparisons and a return; only a real change ever speaks.
//
// Channel: the FIFO queue, never interrupt. Dusk arrives while the player is halfway
// down a survey list or a contract briefing, and cutting that off to say "Evening"
// is exactly the bug that made F&H1 unusable.
::UnseenBanner.WorldClock <- {
	m = {
		LastDay = -1,
		LastTimeName = null
	},
	function reset()
	{
		this.m.LastDay = -1;
		this.m.LastTimeName = null;
	},
	// The spoken name decides what counts as a change, not the enum index: the
	// strings table holds "Dawn" at both ends (index 0, and 7 for EarlyMorning), so
	// tracking the index would announce "Dawn" a second time across the rollover.
	function timeName(_time)
	{
		local names = ::Const.Strings.World.TimeOfDay;
		local i = _time.TimeOfDay;
		return i >= 0 && i < names.len() ? names[i] : "";
	},
	function update()
	{
		local time = ::World.getTime();
		local day = time.Days;
		local name = this.timeName(time);

		// First look after entering the map or loading a save: seed and stay quiet, or
		// every load would open by reading out a clock nobody asked for.
		if (this.m.LastTimeName == null)
		{
			this.m.LastDay = day;
			this.m.LastTimeName = name;
			return;
		}

		local dayChanged = day != this.m.LastDay;
		local timeChanged = name != this.m.LastTimeName;
		if (!dayChanged && !timeChanged) return;

		this.m.LastDay = day;
		this.m.LastTimeName = name;

		// A new day always brings a new time of day with it, so the two travel as one
		// message instead of two queued utterances treading on each other.
		if (dayChanged)
		{
			::UnseenBanner.sendMessage("queue", name, "world.clock.day", "" + day);
			return;
		}

		// Camping runs the clock at speed, and every day crosses seven of these. The
		// day rollover above still lands — it is the one a camping player waits for —
		// but the hours in between would be a message every few seconds of real time.
		if (::World.Assets.isCamping()) return;

		::UnseenBanner.sendMessage("queue", name, "world.clock.time");
	}
};

// An attached location: the farms, mines, workshops and harbours the map builds around
// every settlement. attached_location.nut's create() hardwires them non-attackable and
// its isEnterable() returns false unconditionally — and none of the 30-odd concrete
// scripts overrides either — so nothing of this kind can ever be entered or fought. For
// a sighted player they are scenery. They still register in EntityManager's location
// list, which is why they need naming in one place: the survey gives them their own
// orientation-only category and WorldEnter refuses to travel to them.
::UnseenBanner.isLandmark <- function(_entity)
{
	// isLocationType lives on location.nut only, so a party would throw on it; the
	// isLocation() guard short-circuits before that can happen.
	return _entity != null && _entity.isLocation()
		&& _entity.isLocationType(::Const.World.LocationType.AttachedLocation);
};

// World-map perception readout (phase 4.3). Static places and moving parties are two
// separate tools: B opens known settlements by default and Page Up/Down cycle through
// settlements, locations and landmarks; Shift+B opens only the parties currently in
// sight. Up/Down reads one entry at a time in either window. Fog of war is honoured:
// parties use the same hidden/visibility test as mouse interaction, while settlements
// and locations use the game's per-entity discovered flag.
//
// Key: b (code 12), free on the world map in vanilla (the map claims c/f/i/o/p/r/t and
// G is the explorer's send-to-cursor action). Mutually exclusive with WorldStatus so
// Up/Down never has two owners. Enter acts on the focused row through the same
// AutoAttack / AutoEnterLocation funnels as a mouse click.
::UnseenBanner.WorldSurvey <- {
	m = {
		Items = null,
		ItemIndex = 0,
		Active = false,
		Mode = null, // "places" (B) or "parties" (Shift+B)
		Section = "settlements", // places mode: one of Sections below
		ToggleHeld = false,
		ToggleShift = false,
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
	// The static-place window's categories, cycled by Page Up/Down. With three of them
	// the direction matters, so each key carries its own step instead of toggling.
	Sections = ["settlements", "locations", "landmarks"],
	SectionKeys = {
		[46] = -1, // Page Up
		[47] = 1   // Page Down
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
	function isToggleHeld()
	{
		return this.m.ToggleHeld;
	},
	function handles(_code)
	{
		return _code == this.ToggleKey
			|| (this.m.Active && (_code == this.InspectKey
				|| _code == this.InteractKey || _code in this.MoveKeys
				|| (this.m.Mode == "places" && _code in this.SectionKeys)));
	},
	function handlesOnPress(_code)
	{
		return this.m.Active && (_code in this.MoveKeys
			|| (this.m.Mode == "places" && _code in this.SectionKeys));
	},
	function reset()
	{
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
		this.m.Mode = null;
		this.m.Section = "settlements";
		this.m.ToggleHeld = false;
		this.m.ToggleShift = false;
		this.m.Detail = null;
		this.m.DetailIndex = 0;
	},
	// Capture Shift on B press and act on B release. The engine reports modifiers on
	// each key event independently, so remembering the press prevents releasing Shift
	// first from turning an intended Shift+B into plain B.
	function captureToggle(_shift)
	{
		if (this.m.ToggleHeld) return;
		this.m.ToggleHeld = true;
		this.m.ToggleShift = _shift;
	},
	function consumeToggleRelease()
	{
		if (!this.m.ToggleHeld) return null;
		local shift = this.m.ToggleShift;
		this.m.ToggleHeld = false;
		this.m.ToggleShift = false;
		return shift;
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
	// Roads and rivers (phase 4.8). They are the world map's two travel-speed modifiers —
	// Const.World.MovementSettings.RoadMult (1.5) and RiverMult (0.75), both applied to the
	// company's speed in party.nut — and neither of them changes the tile's terrain type,
	// so nothing the mod already said could give them away: not the terrain word, and not
	// the terrain-change cue of a march.
	//
	// They are read exactly like a trail of footprints, and for the same reason: a road is
	// only worth knowing about if you know which way it runs. The engine answers presence
	// only, so the heading is reconstructed from the neighbouring tiles carrying the same
	// feature, the way trailDirs does it for prints.
	function tileHasPath(_tile, _river)
	{
		// HasRoad exposes the generated road network even while a tile is still under
		// fog. Gate every road lookup here so the cursor cannot reveal either a road on
		// unexplored ground or its continuation through an unexplored neighbour.
		if (!_river && !_tile.IsDiscovered) return false;
		return _river ? _tile.HasRiver : _tile.HasRoad;
	},
	// The hex directions in which _tile's road (or river) continues, comma-separated. A
	// tile that carries none itself still answers, and then the directions are where one
	// starts — which is how a road is found at all while sweeping the map.
	function pathDirs(_tile, _river)
	{
		local dirs = "";
		for( local d = 0; d < 6; d += 1 )
		{
			if (!_tile.hasNextTile(d)) continue;
			if (!this.tileHasPath(_tile.getNextTile(d), _river)) continue;
			if (dirs != "") dirs += ",";
			dirs += d;
		}
		return dirs;
	},
	// "kind:state:dirs" entries joined by ";", packed for one utterance the way footprints
	// are: kind is road or river, state is "on" for a feature the tile itself carries (dirs
	// = where it continues, empty = it ends here) or "near" for one only a neighbour has
	// (dirs = which neighbours). The near half is asked for by the readouts the player
	// requests — X and the V list — and not by the steps of a cursor sweep, where every
	// hex beside a road would repeat it.
	function pathSegment(_tile, _includeNear)
	{
		local out = "";
		for( local i = 0; i < 2; i += 1 )
		{
			local river = i == 1;
			local dirs = this.pathDirs(_tile, river);
			local state = this.tileHasPath(_tile, river) ? "on" : (_includeNear && dirs != "" ? "near" : "");
			if (state == "") continue;
			if (out != "") out += ";";
			out += (river ? "river:" : "road:") + state + ":" + dirs;
		}
		return out;
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
	function collectParties(_player)
	{
		// Visible parties: everything the mouse click would let you interact with —
		// in sight (not hidden by fog), with non-zero visibility. Kind splits into
		// ally / enemy (attackable and not allied) / neutral (a caravan, say).
		local parties = [];
		foreach( e in ::World.getAllEntitiesAtPos(_player.getPos(), this.ScanRadius) )
		{
			if (e == null || !e.isParty() || e.getID() == _player.getID()) continue;
			if (e.isHiddenToPlayer() || e.getVisibilityMult() <= 0.0) continue;
			if (e.getTile() == null) continue;
			parties.push({ e = e, d = _player.getTile().getDistanceTo(e.getTile()) });
		}
		this.sortByDistance(parties);
		return parties;
	},

	function collectSettlements(_playerTile)
	{
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
			settlements.push({ e = s, d = _playerTile.getDistanceTo(s.getTile()) });
		}
		this.sortByDistance(settlements);
		return settlements;
	},

	function collectLocations(_playerTile)
	{
		// Known, active locations (camps, ruins, legendary sites); undiscovered or
		// inactive ones are left out for the same fog-of-war parity (roadmap 4.2).
		// EntityManager's list also holds every settlement's attached farms, mines and
		// workshops, which swamped this category — 69 entries on day 3, the handful of
		// real camps buried among scenery, and the nearest rows always unusable. They
		// move to their own landmark category below.
		local locations = [];
		foreach( l in ::World.EntityManager.getLocations() )
		{
			if (l == null || !l.isAlive() || !l.isActive() || l.getTile() == null) continue;
			if (::UnseenBanner.isLandmark(l)) continue;
			if (!l.isDiscovered()) continue;
			locations.push({ e = l, d = _playerTile.getDistanceTo(l.getTile()) });
		}
		this.sortByDistance(locations);
		return locations;
	},
	// Attached locations mark themselves discovered during onInit, before the player has
	// seen any of them. Their owning settlement carries the persistent discovery state a
	// sighted player actually earns by exploring that part of the map.
	function isLandmarkDiscovered(_landmark)
	{
		if (_landmark == null || !::UnseenBanner.isLandmark(_landmark)) return false;
		local settlement = _landmark.getSettlement();
		return settlement != null && !settlement.isNull() && settlement.isDiscovered();
	},

	function collectLandmarks(_playerTile)
	{
		// Attached locations whose owning settlement is known. Unlike collectLocations
		// this keeps the inactive ones: a burned-down farm still stands on the map
		// (getName() turns it into "Ruins") and remains a valid destination.
		local landmarks = [];
		foreach( l in ::World.EntityManager.getLocations() )
		{
			if (l == null || !l.isAlive() || l.getTile() == null) continue;
			if (!::UnseenBanner.isLandmark(l)) continue;
			if (!this.isLandmarkDiscovered(l)) continue;
			landmarks.push({ e = l, d = _playerTile.getDistanceTo(l.getTile()) });
		}
		this.sortByDistance(landmarks);
		return landmarks;
	},

	// Step through Sections, wrapping both ways: Page Down past the last category
	// returns to the first, Page Up from the first reaches the last. Squirrel's % keeps
	// the sign of the dividend, hence the double modulo for the -1 step.
	function nextSection(_step)
	{
		local at = 0;
		foreach( i, s in this.Sections )
		{
			if (s == this.m.Section)
			{
				at = i;
				break;
			}
		}
		local n = this.Sections.len();
		return this.Sections[((at + _step) % n + n) % n];
	},

	function openPlaces(_section = "settlements")
	{
		local player = ::World.State.getPlayer();
		local playerTile = player.getTile();
		local records;
		local kind;
		if (_section == "locations")
		{
			records = this.collectLocations(playerTile);
			kind = "location";
		}
		else if (_section == "landmarks")
		{
			records = this.collectLandmarks(playerTile);
			kind = "landmark";
		}
		else
		{
			records = this.collectSettlements(playerTile);
			kind = "settlement";
		}

		local items = [];
		items.push(this.item("world.survey.places.screen", "", _section,
			"" + records.len()));
		foreach( r in records )
		{
			// The owning faction is drawn on the map: setOwner hangs the owner's
			// small banner on the settlement's own location_banner sprite, and it
			// stays up for as long as the place does. This list only ever holds
			// discovered places, which are exactly the ones showing that banner, so
			// naming the faction here is the banner in words and nothing more.
			// Locations and landmarks carry no such banner and get no faction.
			// No `in` guard on getOwner: Squirrel's `in` does not follow an instance's
			// class delegate, so it answers false for a method that resolves fine. The
			// kind is the guard — collectSettlements only ever yields settlements.
			local faction = "";
			if (kind == "settlement")
			{
				local owner = r.e.getOwner();
				if (owner != null) faction = owner.getName();
			}
			items.push(this.item("world.survey.item", r.e.getName(), kind,
				this.posDetail(playerTile, r.e.getTile()) + "|" + faction, r.e));
		}

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.m.Mode = "places";
		this.m.Section = _section;
		this.m.Detail = null;
		this.m.DetailIndex = 0;
		this.announceItem();
	},
	function openParties()
	{
		local player = ::World.State.getPlayer();
		local playerTile = player.getTile();
		local parties = this.collectParties(player);
		if (parties.len() == 0)
		{
			this.reset();
			::UnseenBanner.sendMessage("interrupt", "", "world.survey.parties.empty");
			return;
		}

		local items = [];
		items.push(this.item("world.survey.parties.screen", "", "",
			"" + parties.len()));
		foreach( r in parties )
		{
			local e = r.e;
			local kind = e.isAlliedWithPlayer()
				? "ally"
				: (e.isAttackable() ? "enemy" : "neutral");
			items.push(this.item("world.survey.item", e.getName(), kind,
				this.posDetail(playerTile, e.getTile()), e));
		}

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.m.Mode = "parties";
		this.m.Detail = null;
		this.m.DetailIndex = 0;
		this.announceItem();
	},
	function toggle(_parties)
	{
		local mode = _parties ? "parties" : "places";
		if (this.m.Active && this.m.Mode == mode)
		{
			this.close(true);
			return;
		}

		this.reset();
		if (_parties) this.openParties();
		else this.openPlaces("settlements");
	},
	function close(_announce = false)
	{
		this.reset();
		if (_announce) ::UnseenBanner.sendMessage("interrupt", "", "world.survey.closed");
	},
	function onKey(_code, _state = null)
	{
		if (!this.m.Active) return;

		// Page Up/Down cycle the static-place window through its categories, Page Down
		// forwards and Page Up backwards. Switching also exits an entity detail so the
		// new category header is always the first announcement.
		if (this.m.Mode == "places" && _code in this.SectionKeys)
		{
			this.openPlaces(this.nextSection(this.SectionKeys[_code]));
			return;
		}

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

// Ambient discovery pings (user request, jul 2026): settlements, locations,
// attached locations (landmarks) and enemy parties newly entering the player's
// sight while travelling, spoken without opening the B/Shift+B survey (4.3).
// Reuses the exact 4.2 fog-of-war tests those lists already use — isDiscovered()
// + !isHiddenToPlayer() for statics, the mouse-click visibility test for parties
// — so nothing here reveals more than a sighted player would already see.
//
// Decisions (user, jul 2026): only enemy parties are announced (allies/neutrals
// stay silent, matching the vanilla "enemy discovered" sound, which never plays
// for them either — world_entity.onDiscovered). An enemy re-announces every time
// it re-enters sight, since a sighted player watches it reappear too; a
// settlement/location/landmark only ever announces once (a city does not
// "reappear"). Several sightings landing in the same scan (fast travel, arriving
// near a cluster) collapse into one short count instead of reading every row —
// the detail is one B/Shift+B press away (see the "lists, not dumps" convention).
//
// Polled from world_state.onUpdate (below) at a throttled real-time interval,
// not every frame — the full entity scan is not free — and skipped entirely
// while the game is paused, since nothing can newly enter sight without the
// party moving.
::UnseenBanner.WorldDiscovery <- {
	m = {
		LastScanTime = 0.0,
		Seeded = false,      // false until the first post-load scan has baselined
		SeenStatic = {},     // "s<id>"/"l<id>" -> true, once sighted, forever
		VisibleEnemies = {}  // party id -> true, enemies in sight as of last scan
	},
	ScanInterval = 0.4, // seconds of real time between scans
	// Threat proximity bands, in hex tiles, outermost first (phase 4.7). A hostile party
	// crossing one of these inwards is announced; the innermost is the one that means
	// contact is a step away. Everything here belongs in config once 5.1 lands.
	Bands = [6, 4, 2],
	// Tiles a party must put between itself and a band before it counts as having left it.
	// Without this a party pacing the threshold alternates in and out, alerting every scan.
	BandHysteresis = 1,
	function reset()
	{
		this.m.LastScanTime = 0.0;
		this.m.Seeded = false;
		this.m.SeenStatic = {};
		this.m.VisibleEnemies = {};
	},
	function isSettlementSighted(_s)
	{
		return _s != null && _s.isAlive() && _s.getTile() != null
			&& _s.isDiscovered() && !_s.isHiddenToPlayer();
	},
	function isLocationSighted(_l, _isLandmark)
	{
		if (_l == null || !_l.isAlive() || _l.getTile() == null) return false;
		// Same active-only gate WorldSurvey.collectLocations uses: a landmark keeps
		// showing once burned down (it still stands and orients), a plain location does
		// not.
		if (!_isLandmark && !_l.isActive()) return false;
		return _l.isDiscovered() && !_l.isHiddenToPlayer();
	},
	function isEnemySighted(_e, _player)
	{
		return _e != null && _e.isParty() && _e.getID() != _player.getID()
			&& _e.getTile() != null && !_e.isHiddenToPlayer() && _e.getVisibilityMult() > 0.0
			&& !_e.isAlliedWithPlayer() && _e.isAttackable();
	},
	// Baseline what is already discovered/visible on entering the map (or loading a
	// save), so the very first scan reports nothing — matching the B survey, which
	// never dumps the whole map either. Everything after this call is a genuine new
	// sighting.
	function seed(_player)
	{
		local seen = {};
		foreach( s in ::World.EntityManager.getSettlements() )
			if (this.isSettlementSighted(s)) seen["s" + s.getID()] <- true;
		foreach( l in ::World.EntityManager.getLocations() )
			if (this.isLocationSighted(l, ::UnseenBanner.isLandmark(l)))
				seen["l" + l.getID()] <- true;
		this.m.SeenStatic = seen;

		local playerTile = _player.getTile();
		local enemies = {};
		foreach( e in ::World.getAllEntitiesAtPos(_player.getPos(),
			::UnseenBanner.WorldSurvey.ScanRadius) )
			if (this.isEnemySighted(e, _player))
				enemies["" + e.getID()] <- this.bandOf(playerTile.getDistanceTo(e.getTile()));
		this.m.VisibleEnemies = enemies;
	},
	// Which proximity band a distance falls in: 0 beyond the outermost, then 1 upwards as
	// the gap closes. Crossing one inwards is what earns an alert (phase 4.7) — the sighting
	// cue only ever fires once, and between it and the fight the map used to go silent no
	// matter how directly the party came at the company.
	function bandOf(_dist)
	{
		for( local i = this.Bands.len() - 1; i >= 0; i -= 1 )
			if (_dist <= this.Bands[i]) return i + 1;
		return 0;
	},
	function collectNewStatics(_playerTile, _out)
	{
		foreach( s in ::World.EntityManager.getSettlements() )
		{
			if (!this.isSettlementSighted(s)) continue;
			local id = "s" + s.getID();
			if (id in this.m.SeenStatic) continue;
			this.m.SeenStatic[id] <- true;
			_out.push({ kind = "settlement", name = s.getName(), tile = s.getTile() });
		}
		foreach( l in ::World.EntityManager.getLocations() )
		{
			local isLandmark = ::UnseenBanner.isLandmark(l);
			if (!this.isLocationSighted(l, isLandmark)) continue;
			local id = "l" + l.getID();
			if (id in this.m.SeenStatic) continue;
			this.m.SeenStatic[id] <- true;
			_out.push({ kind = isLandmark ? "landmark" : "location", name = l.getName(),
				tile = l.getTile() });
		}
	},
	// Enemies only (user decision). Re-diffed against the previous scan every time, so
	// a party that leaves sight and comes back announces again — unlike statics, which
	// only ever announce once.
	//
	// The stored value is the party's proximity band, not a bare "seen" flag: a sighting
	// is one moment, and what kills a company is the twenty that follow it, with the party
	// walking straight at you and the mod saying nothing. Each band crossed inwards is
	// pushed to _closing; the band is measured, not the intent, so it also fires when the
	// company is the one closing the gap — which is why the wording says the gap is
	// closing rather than claiming the party is charging.
	function collectNewEnemies(_player, _playerTile, _out, _closing)
	{
		local current = {};
		foreach( e in ::World.getAllEntitiesAtPos(_player.getPos(),
			::UnseenBanner.WorldSurvey.ScanRadius) )
		{
			if (!this.isEnemySighted(e, _player)) continue;
			local id = "" + e.getID();
			local tile = e.getTile();
			local dist = _playerTile.getDistanceTo(tile);
			local band = this.bandOf(dist);

			if (!(id in this.m.VisibleEnemies))
			{
				// First sight: the sighting cue already carries the distance, so no band
				// alert on top of it. Its band is recorded so the next one is measured
				// from here.
				current[id] <- band;
				_out.push({ kind = "enemy", name = e.getName(), tile = tile });
				continue;
			}

			local was = this.m.VisibleEnemies[id];
			if (band > was)
			{
				// Deliberately keeps the OLD band for now: only the alert actually spoken
				// advances it (see announceClosing), so a second party closing in the same
				// scan is said on the next one instead of being lost or piled up.
				current[id] <- was;
				_closing.push({ id = id, name = e.getName(), tile = tile, band = band,
					dist = dist });
				continue;
			}

			if (band < was && dist > this.Bands[was - 1] + this.BandHysteresis) was = band;
			current[id] <- was;
		}
		this.m.VisibleEnemies = current;
	},
	// One alert per scan, the most urgent: the innermost band, and the nearest of those.
	// Only this one commits its new band, so nothing said is forgotten and nothing unsaid
	// is dropped. Queue channel, like every other game event — an interrupt here would cut
	// off whatever list the player is reading, which is the F&H1 bug this project was
	// built to avoid repeating.
	function announceClosing(_playerTile, _closing)
	{
		if (_closing.len() == 0) return;

		local best = _closing[0];
		foreach( c in _closing )
			if (c.band > best.band || (c.band == best.band && c.dist < best.dist)) best = c;

		this.m.VisibleEnemies[best.id] = best.band;
		// Semantics cross the bridge, never the band number: which band is the innermost
		// is a fact of this table alone, and config will move it (5.1). The companion is
		// told "contact" or "closing" and needs to know nothing about the thresholds.
		::UnseenBanner.sendMessage("queue", best.name, "world.threat.closing",
			best.band >= this.Bands.len() ? "contact" : "closing",
			::UnseenBanner.WorldSurvey.posDetail(_playerTile, best.tile));
	},
	// A single sighting is read in full (name, kind, distance and bearing — the same
	// posDetail packing the B survey and the tactical tile readout share); several at
	// once collapse into one short count instead of a queued pile of full rows.
	function announce(_playerTile, _sightings)
	{
		if (_sightings.len() == 1)
		{
			local s = _sightings[0];
			::UnseenBanner.sendMessage("queue", s.name, "world.discovery.single", s.kind,
				::UnseenBanner.WorldSurvey.posDetail(_playerTile, s.tile));
			return;
		}

		local places = 0;
		local enemies = 0;
		foreach( s in _sightings )
		{
			if (s.kind == "enemy") enemies += 1;
			else places += 1;
		}
		::UnseenBanner.sendMessage("queue", "", "world.discovery.summary",
			places + "|" + enemies);
	},
	// _now is the caller's this.Time.getRealTimeF(): Time is only reachable through a
	// hooked instance's own delegate, never as a bare global (see the this-root
	// fallback lesson), so the value travels in rather than being fetched here.
	function tick(_now)
	{
		if (::World.State.isPaused()) return;
		if (_now - this.m.LastScanTime < this.ScanInterval) return;
		this.m.LastScanTime = _now;

		local player = ::World.State.getPlayer();
		if (player == null) return;
		local playerTile = player.getTile();
		if (playerTile == null) return;

		if (!this.m.Seeded)
		{
			this.seed(player);
			this.m.Seeded = true;
			return;
		}

		local sightings = [];
		local closing = [];
		this.collectNewStatics(playerTile, sightings);
		this.collectNewEnemies(player, playerTile, sightings, closing);

		if (sightings.len() > 0) this.announce(playerTile, sightings);
		this.announceClosing(playerTile, closing);
	}
};

// Upkeep: food and wages (phase 4.9). Both were on-demand only, through F2, and the
// company can starve or go unpaid without a single word — a sighted player watches the
// topbar turn against him and the mood icons drop.
//
// The funnel is asset_manager.update, which settles the day once, past hour 8: it pays
// each brother and worsens the mood of anyone it could not pay ("Did not get paid") or
// feed ("Did go hungry"). Everything here hangs off that one moment rather than watching
// the purse continuously, and that is the whole design: money moves constantly, so a
// running watch would cross its thresholds three times while buying one suit of armour
// and turn into an alarm nobody listens to. Once a day, when it actually matters.
//
// Two halves (user decision, jul 2026):
//   - what just happened, counted the same way vanilla counts it, because the mood hit
//     is the real damage and it was invisible;
//   - what is coming, repeated every day the company stays in trouble — which is when
//     the reminder is wanted, not only on the day it first crosses a line.
::UnseenBanner.WorldUpkeep <- {
	// Days of food left worth a warning. Thresholds, not crossings: at or under the
	// widest one it speaks every day, since a company down to its last rations wants
	// telling each morning. To config with the rest (5.1).
	FoodWarnDays = 3,
	// True on the one frame vanilla is about to settle the day: the same three tests
	// its own branch makes, read before the original runs and moves LastDayPaid.
	function isSettling(_assets)
	{
		return _assets.m.IsConsumingAssets
			&& ::World.getTime().Days > _assets.m.LastDayPaid
			&& ::World.getTime().Hours > 8;
	},
	// Who is about to go unpaid or hungry, replicating vanilla's own arithmetic rather
	// than inspecting moods afterwards: the same tick also runs skills and other mood
	// sources, so a before/after comparison would credit us with changes we did not
	// cause. Money is walked down brother by brother exactly as the payday loop does
	// (and, as there, it is allowed to go negative).
	function measure(_assets)
	{
		local roster = ::World.getPlayerRoster().getAll();
		local money = _assets.getMoney();
		local food = _assets.getFood();
		local unpaid = 0;
		local hungry = 0;

		foreach( bro in roster )
		{
			local cost = bro.getDailyCost();
			if (cost > 0 && money < cost) unpaid += 1;
			money -= cost;
			// Food is not decremented here; vanilla consumes it hourly elsewhere and
			// compares the whole larder against each man's ration, so this is usually
			// all or nothing.
			if (_assets.m.IsUsingProvisions && food < bro.getDailyFood()) hungry += 1;
		}

		return { unpaid = unpaid, hungry = hungry };
	},
	// Spoken after the original has settled, so the warning half reads the purse and the
	// larder as they now stand. Queue channel: this lands while the player may be deep in
	// a survey list, and an interrupt would cut it off.
	function announce(_assets, _report)
	{
		if (_report.unpaid > 0 || _report.hungry > 0)
		{
			::UnseenBanner.sendMessage("queue", "", "world.upkeep.result",
				_report.hungry + "|" + _report.unpaid);
		}

		// Days of food left, by the same division F2 speaks. It ignores the terrain
		// multiplier vanilla applies when actually eating, so it is an estimate — but it
		// is the estimate the player already has, and two readouts that disagree would be
		// worse than one that rounds.
		local dailyFood = _assets.getDailyFoodCost();
		local foodPart = "";
		if (_assets.m.IsUsingProvisions && dailyFood > 0)
		{
			local days = (_assets.getFood() / dailyFood).tointeger();
			if (days <= this.FoodWarnDays) foodPart = "" + days;
		}

		// Wages: whether tomorrow's payroll is covered by what is left after today's.
		local needed = _assets.getDailyMoneyCost();
		local purse = _assets.getMoney();
		local wagePart = needed > 0 && purse < needed ? needed + "|" + purse : "";

		if (foodPart != "" || wagePart != "")
		{
			::UnseenBanner.sendMessage("queue", "", "world.upkeep.warning", foodPart,
				wagePart);
		}
	}
};

// Camping is a world-map state, not a modal screen. Vanilla T and the topbar
// button both funnel through world_state.onCamp(), but their only feedback is
// visual: the party turns into a camp and the shared PAUSED label becomes
// ENCAMPED. Announce every genuine state change from that funnel. Shift+T is an
// on-demand explanation that never changes the state; DetailsHeld consumes its
// eventual T release even if Shift itself is released first, so the release
// cannot leak into vanilla and accidentally make or break camp.
::UnseenBanner.WorldCamp <- {
	Key = 30, // t
	m = {
		DetailsHeld = false
	},
	function reset()
	{
		this.m.DetailsHeld = false;
	},
	function handles(_code)
	{
		return _code == this.Key;
	},
	function onDetailsPress(_state)
	{
		if (this.m.DetailsHeld) return;
		this.m.DetailsHeld = true;
		this.announceDetails(_state);
	},
	function consumeDetailsRelease()
	{
		if (!this.m.DetailsHeld) return false;
		this.m.DetailsHeld = false;
		return true;
	},
	function announceDetails(_state)
	{
		local category;
		if (_state.World.Assets.isCamping())
			category = "world.camp.info.on";
		else if (!_state.isCampingAllowed())
			category = "world.camp.info.unavailable";
		else
			category = "world.camp.info.off";
		::UnseenBanner.sendMessage("interrupt", "", category);
	},
	function announceUnavailable()
	{
		::UnseenBanner.sendMessage("interrupt", "", "world.camp.unavailable");
	},
	function announceChanged(_isCamping)
	{
		::UnseenBanner.sendMessage("interrupt", "",
			_isCamping ? "world.camp.on" : "world.camp.off");
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
		// A straight-line march is in flight instead of a path: the map explorer's G uses
		// one for a very close or still unexplored target, exactly as a map click does. It
		// needs its own flag because there is no path to watch — see tick().
		PendingDirect = false,
		Blocked = false,   // the current heading hit a wall; hold intent but stop trying
		LastTileID = -1,   // global player-tile observer, including native/autowalk paths
		LastTerrain = -1,  // last terrain type observed, so only changes are spoken
		// Road and river are watched beside the terrain type and for the same reason, but
		// they are their own transitions: neither changes Type, so stepping onto a road
		// would otherwise pass in the same silence the terrain cue was built to break.
		LastRoad = false,
		LastRiver = false,
		DestinationID = null, // entity the party is travelling to, sampled each frame
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
		return this.m.Heading != -1 || this.m.Pending || this.m.PendingDirect;
	},
	// Clears only our own bookkeeping; does NOT touch the party (which may not exist
	// yet at state init). Used on entering/leaving the world state.
	function reset()
	{
		this.m.Heading = -1;
		this.m.HeadingKey = -1;
		this.m.Continuous = false;
		this.m.Pending = false;
		this.m.PendingDirect = false;
		this.m.Blocked = false;
		this.m.LastTileID = -1;
		this.m.LastTerrain = -1;
		this.m.LastRoad = false;
		this.m.LastRiver = false;
		this.m.DestinationID = null;
		this.m.SelfUnpause = false;
	},
	function clearHeading()
	{
		this.m.Heading = -1;
		this.m.HeadingKey = -1;
		this.m.Continuous = false;
		this.m.Blocked = false;
	},
	function primeTerrain(_player)
	{
		if (_player == null || _player.getTile() == null) return;
		local tile = _player.getTile();
		this.m.LastTileID = tile.ID;
		this.m.LastTerrain = tile.Type;
		this.m.LastRoad = ::UnseenBanner.WorldSurvey.tileHasPath(tile, false);
		this.m.LastRiver = tile.HasRiver;
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

		// A native map click breaks camp before assigning its path. Our keyboard
		// navigator bypasses onMouseInput, so mirror that transition explicitly;
		// world_state.onCamp remains the single state-change and speech funnel.
		if (::World.Assets.isCamping()) ::World.State.onCamp();
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
	// is already known blocked. A fresh world state primes the global terrain observer
	// here if its first update has not done so yet.
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
			this.primeTerrain(player);
		}
		this.m.Blocked = !this.issueStep(this.m.Heading);
	},
	// A direction key was released. A plain hold stops chaining once the current step
	// lands; a Shift-latched march ignores the release and walks on until braked. Only
	// the key that owns the current heading clears it, so releasing an older key does
	// not cancel a newer heading. If nothing is in flight (idle, or stuck at a wall
	// already announced), just go quiet — the completion cue only fires for a step that
	// was actually travelling (handled in onArrived). Terrain observation remains
	// primed while idle so a later native/autowalk order starts from the right baseline.
	function onRelease(_code)
	{
		if (_code == this.m.HeadingKey && !this.m.Continuous)
		{
			this.m.Heading = -1;
			this.m.HeadingKey = -1;
			this.m.Blocked = false;
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
		this.m.PendingDirect = false;
		this.primeTerrain(player);
		return true;
	},
	// Sampled from world_state.onUpdate BEFORE its original runs, which is the one
	// moment the current travel destination is still readable: an arrival is what
	// consumes AutoEnterLocation, and the original clears it on the very frame the
	// party steps onto the tile. Holding the id from the start of the frame lets the
	// tile observer below recognise the destination it has just reached and stay quiet.
	function observeDestination(_state)
	{
		local pending = _state != null ? _state.m.AutoEnterLocation : null;
		this.m.DestinationID = (pending != null && !pending.isNull())
			? pending.getID()
			: null;
	},
	// The static place standing on _tile, or null. A sighted player watches the farm or
	// the camp slide under the banner; without this the map between two explicit B
	// surveys is featureless. Every location marks its tile IsOccupied when it spawns
	// (location.nut's onInit) and nothing else on the world map sets that flag, so it
	// is a free prefilter — an ordinary step costs one boolean and never looks an
	// entity up.
	function findPlace(_player, _tile)
	{
		if (_tile == null || !_tile.IsOccupied) return null;

		// The same lookup the mouse hover and Enter use; "AndOneLocation" already caps
		// the result at a single location, so the first match is the only one. The
		// player party is in the list too and fails isLocation().
		foreach( e in ::World.getAllEntitiesAndOneLocationAtPos(_player.getPos(), 1.0) )
		{
			if (e == null || !e.isAlive() || !e.isLocation()) continue;
			if (e.getTile() == null || !e.getTile().isSameTileAs(_tile)) continue;
			if (!e.isDiscovered()) continue;
			if (::UnseenBanner.isLandmark(e)
				&& !::UnseenBanner.WorldSurvey.isLandmarkDiscovered(e)) continue;
			// Reaching what we were travelling to: the entry flow either opens a screen
			// that announces itself or reports the arrival, so naming it here as well
			// would say it twice in a row.
			if (this.m.DestinationID != null && e.getID() == this.m.DestinationID) return null;
			return e;
		}
		return null;
	},
	// Pack a found place into the two trailing message fields, so terrain and place
	// always travel as ONE utterance. Sending them as two messages does not work at any
	// setting: two interrupts in a frame cut the first off mid-word, and a queued second
	// is discarded outright by the next interrupt — the "Stopped" cue that ends a tapped
	// step lands a few frames later and would erase it. The character sheet solved the
	// same race the same way (see combat.sheet.brother).
	function placeName(_place)
	{
		return _place != null ? _place.getName() : "";
	},
	function placeKind(_place)
	{
		return _place != null && ::UnseenBanner.isLandmark(_place) ? "landmark" : "";
	},
	// Road/river transitions for the tile just entered, as the cursor's own
	// "kind:state:dirs" entries with an added "off" state. Updates the watched flags, so it
	// is called exactly once per tile change. The neighbour pass only runs on the frame a
	// transition actually happens, which is a handful of times in a day's march.
	function pathChange(_tile)
	{
		local out = "";
		for( local i = 0; i < 2; i += 1 )
		{
			local river = i == 1;
			local now = ::UnseenBanner.WorldSurvey.tileHasPath(_tile, river);
			if (now == (river ? this.m.LastRiver : this.m.LastRoad)) continue;
			if (river) this.m.LastRiver = now;
			else this.m.LastRoad = now;

			if (out != "") out += ";";
			out += (river ? "river:" : "road:")
				+ (now ? "on:" + ::UnseenBanner.WorldSurvey.pathDirs(_tile, river) : "off:");
		}
		return out;
	},
	// Polled from world_state.onUpdate every frame. Terrain observation is global, not
	// conditional on Pending: paths started with B+Enter, mouse clicks, contracts or
	// native pursuit all move the same player party and must announce transitions too.
	// The second half still handles completion/chaining only for our directional steps.
	function tick()
	{
		local player = ::World.State.getPlayer();
		if (player == null)
		{
			this.m.Pending = false;
			return;
		}

		local tile = player.getTile();
		if (tile != null)
		{
			if (this.m.LastTileID == -1)
			{
				this.primeTerrain(player);
			}
			else if (tile.ID != this.m.LastTileID)
			{
				this.m.LastTileID = tile.ID;
				// Terrain is still only spoken when it actually changes; a place is
				// spoken on every tile it occupies. Either alone is worth a message,
				// and when both land on the same step they go out together.
				local terrain = "";
				if (tile.Type != this.m.LastTerrain)
				{
					this.m.LastTerrain = tile.Type;
					terrain = "" + tile.Type;
				}
				// Crossing onto or off a road or a river, in the same shape the cursor
				// packs them. Stepping ON carries the directions it runs, because that is
				// the moment they are worth having and the alternative is stopping to press
				// X; stepping OFF is one word, since where the road went no longer matters.
				local paths = this.pathChange(tile);
				local place = this.findPlace(player, tile);
				if (terrain != "" || paths != "" || place != null)
				{
					::UnseenBanner.sendMessage("interrupt", this.placeName(place),
						"world.move.step", terrain, this.placeKind(place) + "|" + paths);
				}
			}
		}

		// A straight-line march has no path to watch: the engine drives it from the party's
		// Destination and clears that field itself the moment it arrives or gives up
		// (party.onUpdate), which is therefore the completion signal. Without this, G onto a
		// close or unexplored tile would end in the same silence that made a finished order
		// indistinguishable from one that never started.
		if (this.m.PendingDirect)
		{
			if (player.hasPath() || player.m.Destination != null) return;
			this.m.PendingDirect = false;
			this.announceStopped(player);
			this.primeTerrain(player);
			return;
		}

		if (!this.m.Pending) return;
		if (player.hasPath()) return; // still walking to the step tile

		this.m.Pending = false;
		this.onArrived(player);
	},
	function onArrived(_player)
	{
		if (this.m.Heading != -1)
		{
			// Still walking: the global tile observer above has already announced any
			// terrain transition, so only issue the next directional step here.
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
			this.primeTerrain(_player);
		}
	},
	// Ending an order on top of a place names it here too. This cue interrupts, and it
	// lands a few frames after the tile observer's own message, so it must repeat what
	// that one said or the player loses it: it already re-states the terrain for exactly
	// that reason.
	function announceStopped(_player)
	{
		local tile = _player.getTile();
		local place = this.findPlace(_player, tile);
		::UnseenBanner.sendMessage("interrupt", this.placeName(place),
			"world.move.stopped", "" + tile.Type, this.placeKind(place));
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
		// stopCurrentOrder resets movement bookkeeping first, so prime the terrain
		// observer at the origin before the native route advances.
		::UnseenBanner.WorldMove.primeTerrain(_state.m.Player);
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
		if (::UnseenBanner.isLandmark(_entity)) return this.tryApproachLandmark(_state, _entity);
		return this.tryEnterLocation(_state, _entity);
	},
	// Landmarks are scenery: they cannot be entered, but they are useful navigation
	// targets. Track this as an ordinary movement order rather than AutoEnterLocation,
	// which would call enterLocation on arrival and mark the scenery visited for no gain.
	function tryApproachLandmark(_state, _landmark)
	{
		local player = _state.m.Player;
		if (player == null
			|| !::UnseenBanner.WorldSurvey.isLandmarkDiscovered(_landmark))
		{
			this.announceUnavailable("world.interact.gone");
			return false;
		}
		if (this.isEscorting(_state))
		{
			this.announceUnavailable("world.interact.escorting");
			return false;
		}

		local sameTile = _landmark.getTile().isSameTileAs(player.getTile());
		local inRange = player.getDistanceTo(_landmark)
			<= ::Const.World.CombatSettings.CombatPlayerDistance;
		if (sameTile && inRange)
		{
			this.stopCurrentOrder(_state);
			::UnseenBanner.sendMessage("interrupt", _landmark.getName(),
				"world.interact.already_there");
			return true;
		}

		this.stopCurrentOrder(_state);
		if (!this.routeTo(_state, _landmark))
		{
			this.announceUnavailable("world.interact.no_route", _landmark.getName());
			return false;
		}

		// routeTo chooses either the engine's short direct march or a navigator path.
		// WorldMove needs the matching completion flag because no AutoEnterLocation will
		// remain armed to own and announce this journey's arrival.
		if (player.m.Destination != null)
			::UnseenBanner.WorldMove.m.PendingDirect = true;
		else
			::UnseenBanner.WorldMove.m.Pending = true;
		this.ensureTravelRunning(_state);
		::UnseenBanner.sendMessage("interrupt", _landmark.getName(),
			"world.interact.approaching");
		return true;
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

// Map explorer (phase 4.6). The B and Shift+B surveys answer "what is near me, nearest
// first"; this answers "what is THERE" — a keyboard cursor over the world map, the same
// instrument the tile cursor is on a battlefield. M toggles the mode: while it is on, the
// Q/W/E/A/S/D cluster walks the cursor over the hexes instead of walking the company, and
// each step reports its tile in one utterance (terrain, the place standing on it, the
// parties in sight on it, and each trail of footprints crossing it with the directions it
// runs). V opens that same tile as a navigable list, one row per fact, and Enter acts on a
// place or party through the very funnels the B survey uses; V works with the mode off too,
// on the company's own tile, as an on-the-spot "what am I standing on". X recentres the
// cursor on the company, Shift+X reports its bearing, and G sends the company to it. With
// the mode off X answers that same "what am I standing on" in one utterance instead of a
// list: terrain, then the trails.
//
// Every one of those readouts carries the trail headings. Following a trail is the reason to
// ask about footprints at all, and opening a list to learn which way it went is too slow to
// do between marching steps — the whole point of keys you can just tap.
//
// Keys: m (23) is free on the plain map — vanilla reaches it only from the developer-mode
// handler. x (34) is vanilla's camera lock (a sighted-only toggle) and g (17) is the
// explorer's own travel key, so both are consumed here while the mode is on; with it off
// only x stays claimed, for the readout above.
//
// Footprints are the one fact vanilla gates behind a follower: the prints are drawn on the
// map for everyone, but only a hired Lookout turns them into words, and only then names the
// exact party type (tooltip_events.strategic_queryTileTooltipData). Since a sighted player
// without him still reads the sprite — and there are only four sprite sets, men, greenskins,
// beasts and undead — the readout keeps exactly that asymmetry: the family always, the exact
// type only with the Lookout. That way this hands a blind player what the screen already
// shows, and hiring the Lookout still buys something.
::UnseenBanner.WorldCursor <- {
	m = {
		Active = false,
		// The hex the cursor stands on. Null while the mode is off; re-anchored on the
		// company every time the mode is switched on, so it always starts from a known
		// reference instead of wherever it was left before a battle or a load.
		Tile = null,
		Items = null,
		ItemIndex = 0,
		ListActive = false,
		// Codes whose press has already been acted on, cleared by their own release. The
		// engine auto-repeats a held key as a stream of fresh presses, so a toggle (M, V)
		// held for longer than a moment would open and immediately close again — the bug
		// the tactical cursor's own InspectKeyHeld latch exists for. Directional and list
		// keys are deliberately excluded: holding those to sweep the map must repeat.
		Held = {}
	},
	ToggleKey = 23,    // m -> mode on/off
	RecenterKey = 34,  // x -> cursor back to the company; Shift+x reports its bearing
	InspectKey = 32,   // v -> the cursor tile as a navigable list
	TravelKey = 17,    // g -> send the company to the cursor tile
	InteractKey = 39,  // enter -> act on the focused place or party in that list
	// Same cluster and same hex directions as the tactical tile cursor and the company's
	// own steps (Const.Direction: N=0, NE=1, SE=2, S=3, SW=4, NW=5), so the muscle memory
	// carries over from the battlefield to the map.
	DirKeys = {
		[33] = 0,   // w  -> N
		[15] = 1,   // e  -> NE
		[14] = 2,   // d  -> SE
		[29] = 3,   // s  -> S
		[11] = 4,   // a  -> SW
		[27] = 5    // q  -> NW
	},
	MoveKeys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end"
	},
	// World units around the cursor tile's centre scanned for parties. Correctness comes
	// from the tile comparison in collectParties, not from this radius: it only has to be
	// generous enough to reach every party standing on the tile (a party's position drifts
	// inside its own tile as it walks), and whatever it over-collects the filter drops.
	// Twice the engine's contact radius (Const.World.CombatSettings.CombatPlayerDistance).
	ScanRadius = 200.0,
	function isActive()
	{
		return this.m.Active;
	},
	function isListActive()
	{
		return this.m.ListActive;
	},
	// The mode key is always ours. With the mode on the cursor owns the letter cluster, X
	// and G; with it off V and X, which both read the company's own tile — V as a list, X
	// as one utterance. The list keys are claimed solely while the list is up, so plain-map
	// Enter keeps entering whatever the company is standing on.
	function handles(_code)
	{
		if (_code == this.ToggleKey) return true;
		if (this.m.Active)
		{
			if ((_code in this.DirKeys) || _code == this.RecenterKey
				|| _code == this.InspectKey || _code == this.TravelKey) return true;
		}
		else if (_code == this.InspectKey || _code == this.RecenterKey)
		{
			return true;
		}
		return this.m.ListActive
			&& ((_code in this.MoveKeys) || _code == this.InteractKey);
	},
	// Directional and list keys repeat while held (KeyGate's cadence); everything else
	// acts once per physical press, however long it is held, via the Held latch that
	// its own release clears. X cannot use that latch: it is the one explorer key with
	// a native binding on this screen (camera lock), which MSU's outer onKeyInput
	// wrapper re-dispatches on release and consumes — so X's release never reaches
	// this hook, the latch jammed after the first press, and every later X died
	// silently (verified in log.html: one recentered cue in a whole session). X goes
	// through KeyGate instead: a held X re-recentres every 0.2 s, which is harmless,
	// unlike M or V where a repeat would toggle the mode or the list right back.
	function repeats(_code)
	{
		return (_code in this.DirKeys) || (_code in this.MoveKeys)
			|| _code == this.RecenterKey;
	},
	function shouldFire(_code, _now)
	{
		if (this.repeats(_code)) return ::UnseenBanner.KeyGate.shouldFire(_code, _now);
		if (_code in this.m.Held) return false;
		this.m.Held[_code] <- true;
		return true;
	},
	function release(_code)
	{
		if (this.repeats(_code)) ::UnseenBanner.KeyGate.release(_code);
		else if (_code in this.m.Held) delete this.m.Held[_code];
	},
	function reset()
	{
		this.m.Active = false;
		this.m.Tile = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.ListActive = false;
		this.m.Held = {};
	},
	// A battle starts without the world state ever finishing, so a key still physically
	// held when combat opens would never see its release here and would stay latched —
	// dead for the rest of the campaign. The mode itself deliberately survives a battle;
	// only the press bookkeeping is dropped.
	function clearHeld()
	{
		this.m.Held = {};
	},
	function item(_cat, _texto = "", _valor = "", _detalle = "", _entity = null)
	{
		return { cat = _cat, texto = _texto, valor = _valor, detalle = _detalle, entity = _entity };
	},
	function ensureAnchored()
	{
		local player = ::World.State.getPlayer();
		if (player == null) return false;
		if (this.m.Tile == null) this.m.Tile = player.getTile();
		return this.m.Tile != null;
	},
	function onKey(_code, _shift, _state)
	{
		if (_code == this.ToggleKey)
		{
			this.toggle();
			return;
		}

		if (this.m.ListActive && (_code in this.MoveKeys))
		{
			this.moveList(_code);
			return;
		}

		if (this.m.ListActive && _code == this.InteractKey)
		{
			this.activate(_state);
			return;
		}

		if (_code == this.InspectKey)
		{
			if (this.m.ListActive) this.closeList(true);
			else this.openList();
			return;
		}

		// X with the mode off has no cursor to recentre: it reads the hex the company is
		// already on. Shift is ignored here for the same reason — a bearing to itself.
		if (!this.m.Active && _code == this.RecenterKey)
		{
			this.announceHere();
			return;
		}

		// Everything below belongs to the mode itself and cannot be reached with it off.
		if (!this.m.Active) return;

		if (_code == this.RecenterKey)
		{
			if (_shift) this.announceBearing();
			else this.recenter();
			return;
		}

		if (_code == this.TravelKey)
		{
			this.travel(_state);
			return;
		}

		if (_code in this.DirKeys) this.step(this.DirKeys[_code]);
	},
	function toggle()
	{
		if (this.m.Active)
		{
			this.closeList(false);
			this.m.Active = false;
			this.m.Tile = null;
			::UnseenBanner.sendMessage("interrupt", "", "world.cursor.off");
			return;
		}

		this.closeList(false);
		this.m.Tile = null;
		if (!this.ensureAnchored())
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.cursor.unavailable");
			return;
		}

		this.m.Active = true;
		// The mode cue names where the cursor starts rather than reading the tile out: a
		// second interrupt in the same frame would cut this one off mid-sentence.
		::UnseenBanner.sendMessage("interrupt", "", "world.cursor.on");
	},
	function step(_dir)
	{
		if (!this.ensureAnchored()) return;
		if (!this.m.Tile.hasNextTile(_dir))
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.cursor.edge");
			return;
		}

		// The list described the tile we are leaving, so it goes with it.
		this.closeList(false);
		this.m.Tile = this.m.Tile.getNextTile(_dir);
		this.announceTile("world.cursor.tile");
	},
	function recenter()
	{
		local player = ::World.State.getPlayer();
		if (player == null || player.getTile() == null) return;
		this.closeList(false);
		this.m.Tile = player.getTile();
		this.announceTile("world.cursor.recentered", true);
	},
	// Shift+X: how far the cursor has wandered and in which direction, without reading the
	// tile again. Deliberately absent from every cursor step — a bearing on each hex of a
	// sweep is noise, and this is the one keystroke that answers "where am I looking?".
	function announceBearing()
	{
		local player = ::World.State.getPlayer();
		if (player == null || player.getTile() == null || !this.ensureAnchored()) return;
		local playerTile = player.getTile();
		if (playerTile.isSameTileAs(this.m.Tile))
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.cursor.bearing.here");
			return;
		}

		::UnseenBanner.sendMessage("interrupt", "", "world.cursor.bearing", "",
			::UnseenBanner.WorldSurvey.posDetail(playerTile, this.m.Tile));
	},
	// X with the mode off: terrain under the company, then the footprints crossing it and
	// where each trail runs — the same detail X gives with the mode on, so the key means one
	// thing whichever mode the player is in. Following a trail is the whole reason to ask,
	// and the heading is what makes it followable; the V list stays for the rest of the tile
	// (place, parties) one row at a time.
	//
	// Reads the player's tile directly rather than through the cursor: with the mode off
	// there is no cursor, and anchoring one here would leave a stale tile behind.
	function announceHere()
	{
		local player = ::World.State.getPlayer();
		local tile = player != null ? player.getTile() : null;
		// Silent on a company with no tile, exactly as recenter() and announceBearing()
		// are: it means the world is mid-load, not that the player pressed a dead key.
		if (tile == null) return;

		::UnseenBanner.sendMessage("interrupt", "", "world.cursor.here", "" + tile.Type,
			this.trackSegment(tile) + "|" + this.lookoutFlag()
				+ "|" + ::UnseenBanner.WorldSurvey.pathSegment(tile, true));
	},
	// G: walk the company to the cursor tile, mirroring what a click on that hex does in
	// world_state.onMouseInput — a straight-line march for anything very close or still
	// unexplored (the game deliberately refuses to route through ground the player has not
	// seen), a navigator route otherwise. Arrival is handed to WorldMove, which already owns
	// the "Stopped" cue and the terrain commentary on the way.
	function travel(_state)
	{
		local state = _state != null ? _state : ::World.State;
		local player = state.m.Player;
		if (player == null || !this.ensureAnchored()) return;

		local from = player.getTile();
		if (from == null) return;
		if (from.isSameTileAs(this.m.Tile))
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.cursor.travel.here");
			return;
		}

		// A tile's world position is its Pos property — the API vanilla itself uses
		// (uncoverFogOfWar, setPos, the trail builder's _from.Pos). tileToWorld exists
		// too but vanilla only ever feeds it navigator waypoints; handed tile.Coords it
		// returned a silently wrong vector, which is how every position query in this
		// module came back empty while the list-based place lookup kept working.
		local dest = this.m.Tile.Pos;
		local dx = dest.X - player.getPos().X;
		local dy = dest.Y - player.getPos().Y;
		local direct = ::Const.World.MovementSettings.PlayerDirectMoveRadius;
		local isDirect = (dx * dx + dy * dy <= direct * direct) || !this.m.Tile.IsDiscovered;

		local path = null;
		if (!isDirect)
		{
			local nav = ::World.getNavigator();
			local settings = nav.createSettings();
			settings.ActionPointCosts = ::Const.World.TerrainTypeNavCost;
			settings.RoadMult = 1.0 / ::Const.World.MovementSettings.RoadMult;
			path = nav.findPath(from, this.m.Tile, settings, 0);
			if (path.isEmpty())
			{
				::UnseenBanner.sendMessage("interrupt", "", "world.cursor.travel.no_route");
				return;
			}
		}

		// Drop whatever the company was doing first: a pending pursuit or town entry would
		// otherwise keep steering it. This also clears WorldMove's bookkeeping, so the
		// arrival flags below have to be set after it, not before.
		::UnseenBanner.WorldEnter.stopCurrentOrder(state);
		// A map click breaks camp before assigning its path; keyboard travel bypasses that
		// mouse funnel, so mirror the transition through onCamp, the one speech funnel.
		if (::World.Assets.isCamping()) state.onCamp();

		if (isDirect)
		{
			player.setPath(null);
			player.setDestination(dest);
			// No path to watch in this case, so arrival is detected from the destination
			// the engine clears on its own (party.onUpdate) — see WorldMove.tick.
			::UnseenBanner.WorldMove.m.PendingDirect = true;
		}
		else
		{
			player.setDestination(null);
			player.setPath(path);
			::UnseenBanner.WorldMove.m.Pending = true;
		}

		::UnseenBanner.WorldMove.primeTerrain(player);
		if (state.isPaused())
		{
			::UnseenBanner.WorldMove.m.SelfUnpause = true;
			state.setPause(false);
		}

		local place = this.findPlace(this.m.Tile);
		::UnseenBanner.sendMessage("interrupt", place != null ? place.e.getName() : "",
			"world.cursor.travel", "" + this.m.Tile.Type,
			(place != null ? place.kind : "") + "|"
				+ ::UnseenBanner.WorldSurvey.posDetail(from, this.m.Tile) + "|"
				+ (this.m.Tile.IsDiscovered ? "0" : "1"));
	},
	// The settlement or location standing on _tile as { e, kind }, or null. The
	// EntityManager lists are walked rather than the position query the company's step
	// observer uses (getAllEntitiesAndOneLocationAtPos): that one caps locations at a single
	// result per call, so with a radius wide enough to cover a whole tile the location it
	// returns can be the one on a NEIGHBOURING tile — which the tile filter then discards,
	// reporting bare ground where a farm stands. Which list a place came from also settles
	// its kind without guessing at an entity API. Discovery is honoured exactly as in the B
	// survey, and inactive landmarks are kept for the same reason it keeps them: a burned
	// farm still stands there and still orients.
	function findPlace(_tile)
	{
		foreach( s in ::World.EntityManager.getSettlements() )
		{
			if (s == null || !s.isAlive() || s.getTile() == null) continue;
			if (!s.isDiscovered() || !s.getTile().isSameTileAs(_tile)) continue;
			return { e = s, kind = "settlement" };
		}

		foreach( l in ::World.EntityManager.getLocations() )
		{
			if (l == null || !l.isAlive() || l.getTile() == null) continue;
			if (!l.getTile().isSameTileAs(_tile)) continue;
			if (::UnseenBanner.isLandmark(l))
			{
				if (::UnseenBanner.WorldSurvey.isLandmarkDiscovered(l))
					return { e = l, kind = "landmark" };
				continue;
			}
			if (!l.isDiscovered()) continue;
			if (l.isActive()) return { e = l, kind = "location" };
		}
		return null;
	},
	function collectParties(_tile, _player)
	{
		local out = [];
		foreach( e in ::World.getAllEntitiesAtPos(_tile.Pos, this.ScanRadius) )
		{
			if (e == null || !e.isParty() || !e.isAlive()) continue;
			if (_player != null && e.getID() == _player.getID()) continue;
			// Same sight test as the B survey and as mouse interaction: discovered before
			// is not enough, it has to be visible right now.
			if (e.isHiddenToPlayer() || e.getVisibilityMult() <= 0.0) continue;
			if (e.getTile() == null || !e.getTile().isSameTileAs(_tile)) continue;
			out.push(e);
		}
		return out;
	},
	function partyKind(_party)
	{
		if (_party.isAlliedWithPlayer()) return "ally";
		return _party.isAttackable() ? "enemy" : "neutral";
	},
	// Which party types left prints on _tile, as Const.World.FootprintsType indices. Index 0
	// is the "None" type, skipped exactly as vanilla's Lookout tooltip skips it: only a party
	// that set a type is worth naming, and the player's own company leaves no prints at all
	// (player_party.nut switches them off), so nothing of ours is ever reported back.
	function readFootprints(_tile)
	{
		local found = [];
		local flags = ::World.getAllFootprintsAtPos(_tile.Pos,
			::Const.World.FootprintsType.COUNT);
		if (flags == null) return found;
		for( local i = 1; i < flags.len(); i += 1 )
		{
			if (flags[i]) found.push(i);
		}
		return found;
	},
	// The six neighbours' footprint flags, read once per list so a trail's heading costs one
	// pass instead of one per type found.
	function neighbourFootprints(_tile)
	{
		local out = [];
		for( local d = 0; d < 6; d += 1 )
		{
			out.push(_tile.hasNextTile(d)
				? ::World.getAllFootprintsAtPos(_tile.getNextTile(d).Pos,
					::Const.World.FootprintsType.COUNT)
				: null);
		}
		return out;
	},
	// Where a trail of _type continues, as hex directions. This is the one thing the engine
	// will not answer: a footprint picks its sprite from the direction its party was walking,
	// but getAllFootprintsAtPos reports presence only, so the heading is reconstructed from
	// the neighbouring tiles. A trail crossing a tile normally shows two of them — where it
	// came from and where it went — which is what makes following one possible at all.
	function trailDirs(_neighbours, _type)
	{
		local dirs = "";
		foreach( d, flags in _neighbours )
		{
			if (flags == null || _type >= flags.len() || !flags[_type]) continue;
			if (dirs != "") dirs += ",";
			dirs += d;
		}
		return dirs;
	},
	function lookoutFlag()
	{
		// The Lookout sets this on World.Assets and vanilla reads the raw field for the
		// same purpose; there is no getter to prefer.
		return ::World.Assets.m.IsShowingExtendedFootprints ? "1" : "0";
	},
	// The footprints crossing a tile, packed for a single utterance: "index:dirs" entries
	// separated by ";", the index being a Const.World.FootprintsType and dirs being
	// trailDirs' own comma-separated hex directions. The colon and its (possibly empty)
	// direction list are always emitted, so a trail that continues nowhere reads as exactly
	// that instead of being confused with a readout that never computed the headings.
	//
	// Every cursor readout carries the headings — the tile list, X in either explorer mode,
	// and each cursor step. Following a trail is the reason to ask about footprints at all,
	// and the heading is the half that makes it followable; the six-neighbour pass it costs
	// is paid on a keystroke, which is nowhere near often enough to matter.
	function trackSegment(_tile)
	{
		local tracks = this.readFootprints(_tile);
		if (tracks.len() == 0) return "";

		local neighbours = this.neighbourFootprints(_tile);
		local out = "";
		foreach( t in tracks )
		{
			if (out != "") out += ";";
			out += t + ":" + this.trailDirs(neighbours, t);
		}
		return out;
	},
	// One utterance per cursor step, never several: two interrupts in the same frame cut
	// each other off (the lesson behind world.move.step packing terrain and place together),
	// and a sweep across the map would leave only the last clause audible. Everything the
	// tile holds is therefore packed into the two trailing fields and worded by the
	// companion. Party and place names are game text and carry no pipes; the count and kind
	// precede the name so a comma inside one is harmless.
	function announceTile(_cat, _includeNear = false)
	{
		if (this.m.Tile == null) return;
		local tile = this.m.Tile;
		local player = ::World.State.getPlayer();
		local playerTile = player != null ? player.getTile() : null;

		local place = this.findPlace(tile);
		local parties = this.collectParties(tile, player);
		local partiesSeg = parties.len() > 0
			? parties.len() + "," + this.partyKind(parties[0]) + "," + parties[0].getName()
			: "";

		local tracksSeg = this.trackSegment(tile);

		local detail = (tile.IsDiscovered ? "0" : "1")
			+ "|" + (place != null ? place.kind : "")
			+ "|" + (playerTile != null && playerTile.isSameTileAs(tile) ? "1" : "0")
			+ "|" + partiesSeg
			+ "|" + tracksSeg
			+ "|" + this.lookoutFlag()
			// Roads and rivers ride last in the packing but are spoken right after the
			// terrain: they are a property of the ground, like height on the tactical
			// cursor. Only a readout the player asked for (X, recentring) reports one on a
			// neighbouring tile; a sweep step reports the hex it landed on and no more.
			+ "|" + ::UnseenBanner.WorldSurvey.pathSegment(tile, _includeNear);

		::UnseenBanner.sendMessage("interrupt", place != null ? place.e.getName() : "",
			_cat, "" + tile.Type, detail);
	},
	// V: the same tile as a navigable list, so the facts a step packs into one utterance can
	// be taken one at a time, and so a place or party on the hex can be acted on with Enter.
	// Place and party rows reuse the B survey's own row category, which already words them
	// and already offers Enter, so both windows speak the same language.
	function openList()
	{
		// With the mode off this is a readout of the company's own tile, wherever the
		// cursor may have been left before.
		if (!this.m.Active) this.m.Tile = null;
		if (!this.ensureAnchored()) return;

		local tile = this.m.Tile;
		local player = ::World.State.getPlayer();
		local playerTile = player != null ? player.getTile() : null;
		local pos = playerTile != null
			? ::UnseenBanner.WorldSurvey.posDetail(playerTile, tile)
			: "0|-1";

		local rows = [];
		rows.push(this.item("world.cursor.list.terrain", "", "" + tile.Type,
			tile.IsDiscovered ? "0" : "1"));

		// Road and river follow the terrain, being a property of the same ground, and each
		// takes its own row: this is the surface where one fact at a time is the point, so
		// it is also the one place that spells out what the feature does to travel speed.
		for( local i = 0; i < 2; i += 1 )
		{
			local river = i == 1;
			local dirs = ::UnseenBanner.WorldSurvey.pathDirs(tile, river);
			local state = ::UnseenBanner.WorldSurvey.tileHasPath(tile, river)
				? "on" : (dirs != "" ? "near" : "");
			if (state == "") continue;
			rows.push(this.item("world.cursor.list.path", "",
				(river ? "river:" : "road:") + state + ":" + dirs));
		}

		if (playerTile != null && playerTile.isSameTileAs(tile))
		{
			rows.push(this.item("world.cursor.list.self"));
		}

		local place = this.findPlace(tile);
		if (place != null)
		{
			rows.push(this.item("world.survey.item", place.e.getName(), place.kind, pos,
				place.e));
		}

		foreach( p in this.collectParties(tile, player) )
		{
			rows.push(this.item("world.survey.item", p.getName(), this.partyKind(p), pos, p));
		}

		local tracks = this.readFootprints(tile);
		if (tracks.len() > 0)
		{
			local lookout = this.lookoutFlag();
			local neighbours = this.neighbourFootprints(tile);
			foreach( t in tracks )
			{
				rows.push(this.item("world.cursor.list.tracks", "", "" + t,
					this.trailDirs(neighbours, t) + "|" + lookout));
			}
		}

		local items = [this.item("world.cursor.list.screen", "", "" + rows.len(), pos)];
		foreach( r in rows ) items.push(r);

		this.m.Items = items;
		this.m.ItemIndex = 0;
		this.m.ListActive = true;
		this.announceItem();
	},
	function closeList(_announce = false)
	{
		if (!this.m.ListActive)
		{
			this.m.Items = null;
			this.m.ItemIndex = 0;
			return;
		}

		this.m.ListActive = false;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		if (_announce) ::UnseenBanner.sendMessage("interrupt", "", "world.cursor.list.closed");
	},
	function moveList(_code)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local idx = this.m.ItemIndex;
		local dir = this.MoveKeys[_code];
		if (dir == "up") idx -= 1;
		else if (dir == "down") idx += 1;
		else if (dir == "home") idx = 0;
		else idx = this.m.Items.len() - 1;

		if (idx < 0) idx = 0;
		if (idx >= this.m.Items.len()) idx = this.m.Items.len() - 1;
		this.m.ItemIndex = idx;
		this.announceItem();
	},
	// Enter on a place or party row: the same AutoAttack / AutoEnterLocation funnels the B
	// survey and a mouse click use. A successful order closes the list so map input is free
	// again; a stale row keeps it open after its explanatory cue.
	function activate(_state)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		if (it.entity == null)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.interact.none");
			return;
		}

		local state = _state != null ? _state : ::World.State;
		if (::UnseenBanner.WorldEnter.tryInteract(state, it.entity)) this.closeList(false);
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle);
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
		Active = false,
		// One-shot: swallow the next "back in town" re-read. Sailing from the harbour
		// walks back through showMainDialog while the screen still points at the port
		// town, and WorldTravel speaks the arrival itself — so that intermediate row
		// would either talk over the arrival or contradict it, depending on whether
		// vanilla's menu-stack pop lands before or after the destination is set.
		SuppressAnnounce = false
	},
	Keys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end",
		[39] = "activate", // enter
		[32] = "inspect"   // v
	},
	// Buildings without a trade stash that nonetheless have an accessible cursor.
	// Anything not listed here (and not a shop) is still reported as unreachable
	// rather than opening a dialog the player could not navigate.
	EnterableBuildings = {
		["building.crowd"] = true,
		["building.tavern"] = true,
		["building.temple"] = true,
		["building.arena"] = true,
		["building.taxidermist"] = true,
		["building.port"] = true,
		["building.training_hall"] = true
	},
	// The southern cities of the Blazing Deserts DLC re-skin several buildings by
	// subclassing them, and three of those subclasses give themselves their own ID:
	// building.taxidermist_oriental, .armorsmith_oriental and .weaponsmith_oriental
	// (crowd, marketplace, port and temple inherit theirs unchanged). The two smiths are
	// shops, caught by the stash test before any ID is looked at, but the taxidermist has
	// no stash — so keying the tables on the exact ID answered "not accessible yet" in
	// every desert city for a building that has been accessible since 0.9, and its
	// subclass changes nothing but the ID and two sprites.
	//
	// Normalising here rather than adding one more row to the tables: the suffix is the
	// DLC's re-skin convention, so this also covers any variant we have not met.
	function baseID( _building )
	{
		local id = _building.getID();
		local cut = id.len() - 9; // "_oriental"
		return cut > 0 && id.slice(cut) == "_oriental" ? id.slice(0, cut) : id;
	},
	// Buildings deliberately left undescribed. The barber only swaps sprite brushes
	// (body, face, hair, beard, tattoo and hair colour) — no cost, no effect on play,
	// and nothing nameable behind it but brush filenames like "hair_black_02". A
	// cursor there would be real work for zero information, so it says so plainly
	// instead of the "not accessible yet" that reads as an unkept promise.
	CosmeticBuildings = {
		["building.barber"] = true
	},
	// The arena is the one building whose native onClicked can refuse silently:
	// it returns without opening anything at night, during its one-day cooldown,
	// while an unrelated contract is active, or when the stash cannot hold the
	// prize slots it reserves. A mouse user sees the closed sign; this returns the
	// reason so the same information is spoken instead of nothing happening.
	function arenaBlockReason( _building )
	{
		if (!::World.getTime().IsDaytime) return "night";
		if (_building.isClosed()) return "cooldown";

		local active = ::World.Contracts.getActiveContract();
		local isArena = active != null
			&& (active.getType() == "contract.arena" || active.getType() == "contract.arena_tournament");
		if (active != null && !isArena) return "contract";
		if (isArena) return null;

		// No arena contract yet: vanilla creates one here, and only if the stash has
		// room for the slots the tournament (5) or the ordinary bout (3) reserves.
		local faction = ::World.FactionManager.getFactionOfType(::Const.Faction.Arena);
		if (faction != null && faction.getContracts().len() != 0) return null;

		local town = ::World.State.getCurrentTown();
		local free = ::World.Assets.getStash().getNumberOfEmptySlots();
		local needed = (town != null && town.hasSituation("situation.arena_tournament") && free >= 5) ? 5 : 3;
		return free >= needed ? null : "stash";
	},
	// The harbour has the same silent-refusal shape as the arena: port_building's own
	// onClicked returns without opening anything while an escort-caravan contract is
	// running (the caravan is the thing you are escorting overland — sailing off would
	// abandon it). A mouse user watches the dialog simply not appear; this turns that
	// into words. Every other harbour condition is not a refusal: an empty destination
	// list still opens the dialog, and WorldTravel announces the emptiness itself.
	function portBlockReason()
	{
		local active = ::World.Contracts.getActiveContract();
		if (active != null && active.getType() == "contract.escort_caravan") return "caravan";
		return null;
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
	function suppressNextAnnounce()
	{
		this.m.SuppressAnnounce = true;
	},
	function consumeSuppressedAnnounce()
	{
		if (!this.m.SuppressAnnounce) return false;
		this.m.SuppressAnnounce = false;
		return true;
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
	function open(_town, _announce = true)
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

		// Situations: the icons vanilla draws in the top-left corner of this very
		// screen, unconditionally and with a tooltip each — cheap food from a good
		// harvest, a siege, ambushed trade routes, a tournament. Several of them change
		// how the town should be used, and they were the one thing on the screen with
		// no voice at all. Mirror getUIInformation exactly: de-duplicate by ID, and do
		// NOT apply the validity filter the MAP tooltip uses, because this screen does
		// not apply it either.
		//
		// They come before the buildings, where the eye finds them, and V reads the
		// description straight off the situation object.
		local situations = [];
		local seenSituations = {};
		foreach( s in town.getSituations() )
		{
			if (s == null) continue;
			local id = s.getID();
			if (id in seenSituations) continue;
			seenSituations[id] <- true;
			situations.push(s);
		}

		local items = [];
		items.push(this.item("world.town.screen", town.getName(), "" + situations.len()));
		foreach( s in situations )
		{
			items.push(this.item("world.town.situation", s.getName(), "", "situation", {
				situation = s
			}));
		}

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
		if (_announce) this.announceItem();
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
		if (what == "inspect")
		{
			this.inspect();
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
			else if (::UnseenBanner.WorldTown.baseID(building) in ::UnseenBanner.WorldTown.CosmeticBuildings)
			{
				::UnseenBanner.sendMessage("interrupt", it.texto, "world.town.building.cosmetic");
			}
			else if (::UnseenBanner.WorldTown.baseID(building) == "building.arena")
			{
				local reason = ::UnseenBanner.WorldTown.arenaBlockReason(building);
				if (reason != null)
				{
					::UnseenBanner.sendMessage("interrupt", it.texto, "world.town.arena.closed", reason);
					return;
				}
				// Opens the arena contract's own event screen; EventNav takes over.
				_state.m.WorldTownScreen.onSlotClicked(it.payload.slot);
			}
			else if (::UnseenBanner.WorldTown.baseID(building) == "building.port")
			{
				local reason = ::UnseenBanner.WorldTown.portBlockReason();
				if (reason != null)
				{
					::UnseenBanner.sendMessage("interrupt", it.texto, "world.town.port.closed", reason);
					return;
				}
				_state.m.WorldTownScreen.onSlotClicked(it.payload.slot);
			}
			else if (::UnseenBanner.WorldTown.baseID(building) in ::UnseenBanner.WorldTown.EnterableBuildings)
			{
				// Buildings with no trade stash but an accessible dialog of their
				// own: the crowd (recruit roster), the tavern and the temple. Enter
				// through the exact same slot callback as a mouse click; the
				// matching show*Dialog hook below installs the accessible cursor.
				_state.m.WorldTownScreen.onSlotClicked(it.payload.slot);
			}
			else
			{
				::UnseenBanner.sendMessage("interrupt", it.texto, "world.town.building.locked");
			}
		}
		else
		{
			this.announceItem(); // header and situation rows: re-read
		}
	},
	// V reads a situation's own description — one paragraph of game prose, so it is
	// spoken as a single utterance rather than turned into a sub-list. Every other row
	// answers with itself instead of with silence, which reads as a hang.
	function inspect()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		local situation = (it.action == "situation" && it.payload != null)
			? it.payload.situation
			: null;
		if (situation == null)
		{
			this.announceItem();
			return;
		}
		::UnseenBanner.sendMessage("interrupt", situation.getDescription(),
			"world.town.situation.details", situation.getName());
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
	// What a haggler needs before deciding, without opening a tooltip for every row: the
	// price this town is asking or offering, and the item's own worth to measure it
	// against. Both are the numbers vanilla itself prints — getValue() is what the tooltip
	// words as "Worth" — so this is reading the same sheet faster, not a valuation of ours.
	//
	// The price actually paid exists for exactly two families, and only in the player's own
	// stash: provisions and trading goods record it on the way in (m.BoughtAtPrice, set in
	// onAddedToStash for stashID "player"). Those are the two the game means you to trade
	// on, and for them the profit is otherwise unknowable. Weapons and armour keep no such
	// record anywhere, so nothing is invented for them. isKindOf gates the field access:
	// reading .m.BoughtAtPrice off an item that has no such member would throw and take the
	// whole row with it.
	function boughtPrice(_source, _item)
	{
		if (_source != "sell") return "";
		if (!::isKindOf(_item, "food_item") && !::isKindOf(_item, "trading_good_item"))
			return "";
		return _item.m.BoughtAtPrice > 0 ? "" + _item.m.BoughtAtPrice : "";
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
			"" + (_source == "buy" ? _item.getBuyPrice() : _item.getSellPrice())
				+ "|" + _item.getValue()
				+ "|" + this.boughtPrice(_source, _item),
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

// Tavern. Vanilla lays out two panels — buy the patrons a round for news, buy
// your own men a round for morale — each with a Pay button and a result area, plus
// a Leave button. Both actions are pure Squirrel endpoints on tavern_building, so
// this stays in Squirrel like the shop and recruitment cursors rather than driving
// the DOM.
//
// Up/Down/Home/End walk the two actions, Enter performs the focused one, V re-reads
// the text it last produced (a rumor can be several sentences and the interrupt
// channel drops it the moment anything else speaks). Escape at action level is left
// to the native menu stack, which returns to the town frame.
//
// The rumor and the drinking report are game-written prose: they cross the bridge
// verbatim, BBCode and all, for the central cleaner to handle. Only the row labels
// and prices are mod speech and live in L10n.
::UnseenBanner.WorldTavern <- {
	m = {
		Screen = null,
		Module = null,
		Tavern = null,
		Items = null,
		ItemIndex = 0,
		Active = false
	},
	InspectKey = 32, // v
	ActionKey = 39, // enter
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
			|| _code in this.MoveKeys;
	},
	function reset()
	{
		this.m.Screen = null;
		this.m.Module = null;
		this.m.Tavern = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Active = false;
	},
	function close()
	{
		this.reset();
	},
	// The building is handed to the module by tavern_building.onClicked right before
	// the dialog opens, so read it from there rather than re-deriving it from the
	// settlement: a town can only have one tavern, but the module's copy is the one
	// its own endpoints will charge against.
	function open(_screen, _module)
	{
		this.reset();
		if (_screen == null || _module == null) return;

		this.m.Screen = _screen;
		this.m.Module = _module;
		this.m.Tavern = _module.m.Tavern;
		if (this.m.Tavern == null) return;

		// queryData() is exactly what vanilla calls when the dialog opens, and it is
		// safe to reach for here: the free-of-charge rumor it returns is cached in
		// the building's LastRumor, so asking twice in one visit yields the same
		// string rather than burning a new one.
		local data = this.m.Module.queryData();
		local freeRumor = (data != null && "Rumor" in data && data.Rumor != null)
			? data.Rumor : "";

		this.m.Items = [
			{
				execute = "rumor",
				label = "rumor",
				price = this.m.Tavern.getRumorPrice(),
				result = freeRumor
			},
			{
				execute = "drink",
				label = "drink",
				price = this.m.Tavern.getDrinkPrice(),
				result = ""
			}
		];
		this.m.ItemIndex = 0;
		this.m.Active = true;
		this.announceItem(true);
	},
	function currentRow()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return null;
		if (this.m.ItemIndex < 0 || this.m.ItemIndex >= this.m.Items.len()) return null;
		return this.m.Items[this.m.ItemIndex];
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
		if (this.m.ItemIndex >= this.m.Items.len())
			this.m.ItemIndex = this.m.Items.len() - 1;
		this.announceItem();
	},
	// Keep vanilla's own panel in step after an accessible purchase, so the crowns
	// on screen and the button availability match what was actually spent.
	function refreshNative()
	{
		if (this.m.Module == null || this.m.Screen == null) return;
		local data = this.m.Module.queryData();
		this.m.Screen.updateAssets();
		if (data != null && this.m.Module.m.JSHandle != null)
			this.m.Module.m.JSHandle.asyncCall("loadFromData", data);
	},
	// Flatten the drinking report into one spoken block. Vanilla renders an intro
	// line plus a table of per-brother outcomes; the icons carry no text, so only
	// the written rows are worth speaking.
	function joinDrinkResult(_result)
	{
		if (_result == null) return "";
		local text = ("Intro" in _result && _result.Intro != null) ? _result.Intro : "";
		if (!("Result" in _result) || _result.Result == null) return text;
		foreach( row in _result.Result )
		{
			if (row == null) continue;
			if (!("Text" in row) || row.Text == null || row.Text == "") continue;
			if (text != "") text += "\n";
			text += row.Text;
		}
		return text;
	},
	function execute()
	{
		local row = this.currentRow();
		if (row == null || this.m.Module == null) return;

		// Both endpoints refuse and charge nothing when the crowns are short, and
		// report that by returning null. Checking their answer rather than the purse
		// keeps the affordability rule in the game's hands, prices multipliers and
		// all.
		if (row.execute == "rumor")
		{
			local data = this.m.Module.onQueryRumor();
			local rumor = (data != null && "Rumor" in data && data.Rumor != null)
				? data.Rumor : null;
			if (rumor == null)
			{
				::UnseenBanner.sendMessage("interrupt", "", "world.tavern.error", "money");
				return;
			}
			row.result = rumor;
			this.refreshNative();
			::UnseenBanner.sendMessage("interrupt", rumor, "world.tavern.result.rumor",
				"" + row.price, "" + ::World.Assets.getMoney());
			return;
		}

		local data = this.m.Module.onDrink();
		local drink = (data != null && "Drink" in data) ? data.Drink : null;
		if (drink == null)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.tavern.error", "money");
			return;
		}
		row.result = this.joinDrinkResult(drink);
		this.refreshNative();
		::UnseenBanner.sendMessage("interrupt", row.result, "world.tavern.result.drink",
			"" + row.price, "" + ::World.Assets.getMoney());
	},
	// V re-reads whatever the focused action last produced. The free rumor the
	// tavern offers on arrival counts, so a player can hear it without paying.
	function inspect()
	{
		local row = this.currentRow();
		if (row == null) return;
		if (row.result == null || row.result == "")
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.tavern.nothing." + row.label);
			return;
		}
		::UnseenBanner.sendMessage("interrupt", row.result, "world.tavern.reread");
	},
	function announceItem(_opened = false)
	{
		local row = this.currentRow();
		if (row == null) return;
		local detail = "" + row.price + "|" + (this.m.ItemIndex + 1)
			+ "|" + this.m.Items.len() + "|" + (_opened ? "1" : "0")
			+ "|" + (row.result != null && row.result != "" ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", "" + ::World.Assets.getMoney(),
			"world.tavern.action", row.label, detail);
	},
	function onKey(_code)
	{
		if (!this.m.Active) return;
		if (_code == this.ActionKey) this.execute();
		else if (_code == this.InspectKey) this.inspect();
		else if (_code in this.MoveKeys) this.move(_code);
	}
};

// Temple. Vanilla lists every brother carrying an untreated, treatable injury and,
// for the selected one, a row per injury with a price button. The module exposes
// both the roster query and the treatment endpoint, so this cursor mirrors the
// recruitment one: Up/Down over the wounded, Enter opens that man's injuries as an
// action sub-list, Enter again pays for the treatment, V or Escape backs out.
//
// One thing vanilla does NOT do in Squirrel: onTreatInjury deducts the price with
// no affordability check at all — the only guard is the JS disabling the button
// when the crowns are short. Reaching the endpoint directly therefore has to
// enforce that rule here, or an accessible treatment would push the company into
// negative crowns where a mouse never could.
::UnseenBanner.WorldTemple <- {
	m = {
		Screen = null,
		Module = null,
		Items = null,
		ItemIndex = 0,
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
			|| (_code == this.EscapeKey && this.m.ActionMode)
			|| _code in this.MoveKeys;
	},
	function reset()
	{
		this.m.Screen = null;
		this.m.Module = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.ActionMode = false;
		this.m.Actions = null;
		this.m.ActionIndex = 0;
		this.m.Active = false;
	},
	function close()
	{
		this.reset();
	},
	function open(_screen, _module)
	{
		this.reset();
		if (_screen == null || _module == null) return;
		this.m.Screen = _screen;
		this.m.Module = _module;
		this.m.Active = true;
		this.buildItems();
		this.announceItem(true);
	},
	// Rebuilt from queryRosterInformation, the same call that feeds the visible
	// list, so a man whose last injury was just treated drops out exactly as he does
	// on screen. _preferredID keeps the cursor on the brother being worked on across
	// that rebuild; _fallbackIndex catches the case where he has left the list.
	function buildItems(_preferredID = null, _fallbackIndex = 0)
	{
		local rows = [];
		if (this.m.Module != null)
		{
			local data = this.m.Module.queryRosterInformation();
			if (data != null && "Roster" in data && data.Roster != null)
			{
				foreach( entry in data.Roster )
				{
					if (entry == null) continue;
					local injuries = [];
					local total = 0;
					foreach( injury in entry.Injuries )
					{
						if (injury == null) continue;
						injuries.push({
							id = injury.id,
							name = injury.name,
							price = injury.price
						});
						total += injury.price;
					}
					if (injuries.len() == 0) continue;
					rows.push({
						entityID = entry.ID,
						name = entry.Name,
						injuries = injuries,
						total = total
					});
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
	function currentRow()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return null;
		if (this.m.ItemIndex < 0 || this.m.ItemIndex >= this.m.Items.len()) return null;
		return this.m.Items[this.m.ItemIndex];
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
		this.announceItem();
	},
	function openActions()
	{
		local row = this.currentRow();
		if (row == null)
		{
			this.announceItem();
			return;
		}
		this.m.Actions = row.injuries;
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
	function refreshNative()
	{
		if (this.m.Module == null || this.m.Screen == null) return;
		local data = this.m.Module.queryRosterInformation();
		this.m.Screen.updateAssets();
		// The whole table, not data.Roster: the temple's loadFromData reads
		// _data.Roster itself (unlike the recruit module, which takes the bare list).
		if (data != null && this.m.Module.m.JSHandle != null)
			this.m.Module.m.JSHandle.asyncCall("loadFromData", data);
	},
	function executeAction()
	{
		if (!this.m.ActionMode || this.m.Actions == null
			|| this.m.Actions.len() == 0) return;
		local row = this.currentRow();
		if (row == null) return;
		local injury = this.m.Actions[this.m.ActionIndex];

		// The guard vanilla only ever applied in the UI layer (see the note above).
		if (injury.price > ::World.Assets.getMoney())
		{
			::UnseenBanner.sendMessage("interrupt", injury.name, "world.temple.error", "money");
			return;
		}

		local fallback = this.m.ItemIndex;
		this.m.Module.onTreatInjury([row.entityID, injury.id]);
		this.leaveActions(false);
		this.refreshNative();
		this.buildItems(row.entityID, fallback);
		::UnseenBanner.sendMessage("interrupt", injury.name, "world.temple.result",
			row.name, "" + injury.price + "|" + ::World.Assets.getMoney());
	},
	function announceAction(_opened = false)
	{
		if (this.m.Actions == null || this.m.Actions.len() == 0) return;
		local row = this.currentRow();
		local injury = this.m.Actions[this.m.ActionIndex];
		local detail = "" + injury.price + "|" + (this.m.ActionIndex + 1)
			+ "|" + this.m.Actions.len() + "|" + (_opened ? "1" : "0")
			+ "|" + (injury.price > ::World.Assets.getMoney() ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", injury.name, "world.temple.injury",
			row != null ? row.name : "", detail);
	},
	function announceItem(_opened = false)
	{
		local money = "" + ::World.Assets.getMoney();
		if (this.m.Items == null || this.m.Items.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.temple.empty", money,
				_opened ? "1" : "0");
			return;
		}
		local row = this.currentRow();
		if (row == null) return;
		local detail = "" + row.injuries.len() + "|" + row.total + "|"
			+ (this.m.ItemIndex + 1) + "|" + this.m.Items.len() + "|"
			+ (_opened ? "1" : "0") + "|" + money;
		::UnseenBanner.sendMessage("interrupt", row.name, "world.temple.patient",
			"", detail);
	},
	function onKey(_code)
	{
		if (!this.m.Active) return;

		if (this.m.ActionMode)
		{
			if (_code == this.ActionKey) this.executeAction();
			else if (_code == this.InspectKey || _code == this.EscapeKey)
				this.leaveActions(true);
			else if (_code in this.MoveKeys) this.moveAction(_code);
			return;
		}

		if (_code == this.ActionKey) this.openActions();
		else if (_code in this.MoveKeys) this.move(_code);
	}
};

// Taxidermist (the crafting building of the Beasts & Exploration DLC). Vanilla
// shows a mouse-only list of qualified blueprints; the ingredients are icons whose
// only text lives in a hover tooltip, so a blind player could neither tell what a
// trophy recipe needs nor why a greyed-out entry is greyed out.
//
// This cursor flattens the same queryBlueprints() the screen is painted from:
// Up/Down over the blueprints, V opens description and ingredients as a sub-list
// (one fact per row, never one long utterance), Enter opens an explicit craft
// action and a second Enter calls the module's own onCraft. Escape is captured only
// inside those sub-lists; at blueprint level it belongs to the native menu stack.
//
// Same trap as the temple: onCraft charges the crowns with no affordability check
// of its own — the only guard vanilla has is the JS disabling the button when the
// purse is short or an ingredient is missing (see its updateDetailsPanel). Reaching
// the endpoint directly therefore has to enforce both rules here.
::UnseenBanner.WorldTaxidermist <- {
	m = {
		Screen = null,
		Module = null,
		Items = null,
		ItemIndex = 0,
		DetailMode = false,
		Details = null,
		DetailIndex = 0,
		ActionMode = false,
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
		this.m.Details = null;
		this.m.DetailIndex = 0;
		this.m.ActionMode = false;
		this.m.ActionIndex = 0;
		this.m.Active = false;
	},
	function close()
	{
		this.reset();
	},
	function open(_screen, _module)
	{
		this.reset();
		if (_screen == null || _module == null) return;
		this.m.Screen = _screen;
		this.m.Module = _module;
		this.m.Active = true;
		this.buildItems();
		this.announceItem(true);
	},
	// Ingredient names for one blueprint. getUIData's Ingredients array is one entry
	// per required unit ({InstanceID, IsMissing}) and carries no name — the screen
	// paints icons — so the names come from the blueprint's own components, the item
	// instances the recipe was built from, already localized by the game. The missing
	// flags stay the game's: they are counted off the very array the icons are
	// greyed out from, never recomputed against the stash here.
	function ingredientsOf(_blueprintID, _uiIngredients)
	{
		local rows = [];
		if (!("Crafting" in ::World) || ::World.Crafting == null) return rows;
		local blueprint = ::World.Crafting.getBlueprint(_blueprintID);
		if (blueprint == null) return rows;

		foreach( index, component in blueprint.m.PreviewComponents )
		{
			if (component == null || component.Instance == null) continue;
			local missing = 0;
			if (_uiIngredients != null)
			{
				foreach( entry in _uiIngredients )
				{
					if (entry != null && entry.InstanceID == index && entry.IsMissing)
						missing += 1;
				}
			}
			rows.push({
				name = component.Instance.getName(),
				num = component.Num,
				missing = missing
			});
		}
		return rows;
	},
	// Rebuilt from queryBlueprints(), the same call that fills the visible list, so a
	// recipe that stops qualifying after a craft drops out exactly as it does on
	// screen. _preferredID holds the cursor on the recipe just worked on across the
	// rebuild; _fallbackIndex catches the case where it is gone.
	function buildItems(_preferredID = null, _fallbackIndex = 0)
	{
		local rows = [];
		if (this.m.Module != null)
		{
			local data = this.m.Module.queryBlueprints();
			if (data != null && "Blueprints" in data && data.Blueprints != null)
			{
				foreach( entry in data.Blueprints )
				{
					if (entry == null) continue;
					rows.push({
						id = entry.ID,
						name = entry.Name,
						description = entry.Description,
						cost = entry.Cost,
						craftable = entry.IsCraftable,
						ingredients = this.ingredientsOf(entry.ID,
							("Ingredients" in entry) ? entry.Ingredients : null)
					});
				}
			}
		}

		this.m.Items = rows;
		this.m.ItemIndex = _fallbackIndex;
		if (_preferredID != null)
		{
			for (local i = 0; i < rows.len(); i += 1)
			{
				if (rows[i].id == _preferredID)
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
	function currentRow()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return null;
		if (this.m.ItemIndex < 0 || this.m.ItemIndex >= this.m.Items.len()) return null;
		return this.m.Items[this.m.ItemIndex];
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
		this.announceItem();
	},
	function openDetails()
	{
		local row = this.currentRow();
		if (row == null)
		{
			this.announceItem();
			return;
		}

		local details = [];
		if (row.description != null && row.description != "")
			details.push({ kind = "description", texto = row.description, valor = "" });
		foreach( ingredient in row.ingredients )
			details.push({
				kind = "ingredient",
				texto = ingredient.name,
				valor = "" + ingredient.num + "|" + ingredient.missing
			});

		if (details.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", row.name, "world.craft.details.none");
			return;
		}

		this.m.Details = details;
		this.m.DetailIndex = 0;
		this.m.DetailMode = true;
		this.announceDetail(true);
	},
	function leaveDetails(_announceParent = false)
	{
		this.m.DetailMode = false;
		this.m.Details = null;
		this.m.DetailIndex = 0;
		if (_announceParent) this.announceItem();
	},
	function moveDetail(_code)
	{
		if (this.m.Details == null || this.m.Details.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.DetailIndex -= 1;
		else if (dir == "down") this.m.DetailIndex += 1;
		else if (dir == "home") this.m.DetailIndex = 0;
		else this.m.DetailIndex = this.m.Details.len() - 1;
		if (this.m.DetailIndex < 0) this.m.DetailIndex = 0;
		if (this.m.DetailIndex >= this.m.Details.len())
			this.m.DetailIndex = this.m.Details.len() - 1;
		this.announceDetail();
	},
	function openActions()
	{
		local row = this.currentRow();
		if (row == null)
		{
			this.announceItem();
			return;
		}
		this.m.ActionMode = true;
		this.m.ActionIndex = 0;
		this.announceAction(true);
	},
	function leaveActions(_announceParent = false)
	{
		this.m.ActionMode = false;
		this.m.ActionIndex = 0;
		if (_announceParent) this.announceItem();
	},
	// Keep vanilla's own panel in step after an accessible craft, so the crowns and
	// the recipe list on screen match what was really spent and made.
	function refreshNative()
	{
		if (this.m.Module == null || this.m.Screen == null) return;
		local data = this.m.Module.queryBlueprints();
		this.m.Screen.updateAssets();
		if (data != null && this.m.Module.m.JSHandle != null)
			this.m.Module.m.JSHandle.asyncCall("loadFromData", data);
	},
	function blockReason(_row)
	{
		if (_row == null) return "";
		if (!_row.craftable) return "ingredients";
		if (_row.cost > ::World.Assets.getMoney()) return "money";
		return "";
	},
	function executeAction()
	{
		local row = this.currentRow();
		if (row == null || this.m.Module == null) return;

		// The two guards vanilla only ever applied in the UI layer (see the note
		// above the module).
		local reason = this.blockReason(row);
		if (reason != "")
		{
			::UnseenBanner.sendMessage("interrupt", row.name, "world.craft.error", reason);
			return;
		}

		local fallback = this.m.ItemIndex;
		local cost = row.cost;
		local id = row.id;
		local name = row.name;
		this.m.Module.onCraft(id);
		this.leaveActions(false);
		this.refreshNative();
		this.buildItems(id, fallback);
		::UnseenBanner.sendMessage("interrupt", name, "world.craft.result",
			"" + cost, "" + ::World.Assets.getMoney());
	},
	function announceDetail(_opened = false)
	{
		if (this.m.Details == null || this.m.Details.len() == 0) return;
		local detail = this.m.Details[this.m.DetailIndex];
		local position = "" + (this.m.DetailIndex + 1) + "|" + this.m.Details.len()
			+ "|" + (_opened ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", detail.texto,
			"world.craft.detail." + detail.kind, detail.valor, position);
	},
	function announceAction(_opened = false)
	{
		local row = this.currentRow();
		if (row == null) return;
		local detail = "" + (_opened ? "1" : "0") + "|" + this.blockReason(row)
			+ "|" + ::World.Assets.getMoney();
		::UnseenBanner.sendMessage("interrupt", row.name, "world.craft.action",
			"" + row.cost, detail);
	},
	function announceItem(_opened = false)
	{
		local money = "" + ::World.Assets.getMoney();
		if (this.m.Items == null || this.m.Items.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.craft.empty", money,
				_opened ? "1" : "0");
			return;
		}
		local row = this.currentRow();
		if (row == null) return;
		// craftable + affordable are sent apart so the companion can name the reason
		// a recipe cannot be made right now, which is the whole point of the greyed
		// out entry a blind player cannot see.
		local detail = (row.craftable ? "1" : "0")
			+ "|" + (row.cost <= ::World.Assets.getMoney() ? "1" : "0")
			+ "|" + (this.m.ItemIndex + 1) + "|" + this.m.Items.len()
			+ "|" + (_opened ? "1" : "0") + "|" + money
			+ "|" + row.ingredients.len();
		::UnseenBanner.sendMessage("interrupt", row.name, "world.craft.blueprint",
			"" + row.cost, detail);
	},
	function onKey(_code)
	{
		if (!this.m.Active) return;

		if (this.m.ActionMode)
		{
			if (_code == this.ActionKey) this.executeAction();
			else if (_code == this.InspectKey || _code == this.EscapeKey)
				this.leaveActions(true);
			// Crafting offers a single action, so Up/Down have nowhere to go; re-read
			// it rather than answer a keystroke with silence, which reads as a hang.
			else if (_code in this.MoveKeys) this.announceAction();
			return;
		}

		if (this.m.DetailMode)
		{
			if (_code == this.InspectKey || _code == this.EscapeKey)
				this.leaveDetails(true);
			else if (_code in this.MoveKeys) this.moveDetail(_code);
			return;
		}

		if (_code == this.ActionKey) this.openActions();
		else if (_code == this.InspectKey) this.openDetails();
		else if (_code in this.MoveKeys) this.move(_code);
	}
};

// Harbour (the port building). Booking passage by ship is the map's only fast
// travel: it turns a march of dozens of days into one payment, and vanilla hid it
// behind a mouse-only list of destinations whose cost and description live in a
// side panel. That made it, in practice, unavailable to a blind player — the one
// building on this list whose absence changed how a whole campaign has to be
// played.
//
// The destinations are not computed here: port_building.getUITravelRoster() has
// already filtered them (other harbours only, allied with the player AND with this
// settlement's owner, never this town itself) and priced each one, and
// port_building.onClicked hands that table to the module before the dialog opens.
// So this reads queryTravelInformation(), the module's own accessor, and Enter
// calls its onTravel — the very endpoint the Travel button uses. Unlike the temple
// and the taxidermist, onTravel does check the purse itself and answers with
// Const.UI.Error.NotEnoughMoney, so the refusal is spoken from its result rather
// than second-guessed here. The affordability of each row is still announced up
// front, so nobody has to press Enter to find out.
//
// Sailing is not reversible and lands the company in another settlement, so Enter
// asks once: it opens a one-row confirmation the way the taxidermist's craft action
// does, and only a second Enter pays.
::UnseenBanner.WorldTravel <- {
	m = {
		Screen = null,
		Module = null,
		Items = null,
		ItemIndex = 0,
		Details = null,
		DetailIndex = 0,
		DetailMode = false,
		ConfirmMode = false,
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
			|| (_code == this.EscapeKey && (this.m.DetailMode || this.m.ConfirmMode))
			|| _code in this.MoveKeys;
	},
	function reset()
	{
		this.m.Screen = null;
		this.m.Module = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Details = null;
		this.m.DetailIndex = 0;
		this.m.DetailMode = false;
		this.m.ConfirmMode = false;
		this.m.Active = false;
		::UnseenBanner.TooltipNav.hide();
	},
	function close()
	{
		this.reset();
	},
	function open(_screen, _module)
	{
		this.reset();
		if (_screen == null || _module == null) return;
		this.m.Screen = _screen;
		this.m.Module = _module;
		this.m.Active = true;
		this.buildItems();
		this.announceItem(true);
	},
	function buildItems()
	{
		local rows = [];
		if (this.m.Module != null)
		{
			local info = this.m.Module.queryTravelInformation();
			// setData is what port_building.onClicked filled in; if the dialog was
			// somehow raised without it, Data is null and the list is simply empty.
			local data = (info != null && info.Data != null) ? info.Data : null;
			local player = ::World.State.getPlayer();
			local fromTile = player != null ? player.getTile() : null;
			if (data != null && data.Roster != null)
			{
				foreach( entry in data.Roster )
				{
					if (entry == null) continue;
					// The roster carries no faction and no position — only a banner
					// image and a name — so resolve the settlement itself, the same way
					// onTravel does with this very ID.
					local dest = ::World.getEntityByID(entry.ID);
					local owner = dest != null ? dest.getOwner() : null;
					// Bearing and distance are what the map gives a sighted player, and
					// they also make the fare legible: it is distance x company size x
					// 0.5, rounded to tens. But ONLY for a settlement he has actually
					// seen — the roster is filtered by alliance, not by discovery, so an
					// allied harbour still under fog can be listed, and the map does not
					// show him that one either.
					local seen = dest != null && dest.isDiscovered();
					local tile = dest != null ? dest.getTile() : null;
					rows.push({
						entryID = entry.EntryID,
						name = entry.Name,
						cost = entry.Cost,
						faction = owner != null ? owner.getName() : "",
						seen = seen,
						// Same "dist|dir" encoding the B survey and the tactical cursor
						// use, so the companion's ComposePosition is reused verbatim.
						pos = (seen && tile != null && fromTile != null)
							? ::UnseenBanner.WorldSurvey.posDetail(fromTile, tile)
							: "0|-1",
						// One blob of prose in vanilla: the settlement's own description
						// and the ship offer, joined by <br><br>. Split on that seam so V
						// answers with a two-row list instead of one long utterance.
						description = ("BackgroundText" in entry) ? entry.BackgroundText : ""
					});
				}
			}
		}

		this.m.Items = rows;
		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (rows.len() > 0 && this.m.ItemIndex >= rows.len())
			this.m.ItemIndex = rows.len() - 1;
	},
	function currentRow()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return null;
		if (this.m.ItemIndex < 0 || this.m.ItemIndex >= this.m.Items.len()) return null;
		return this.m.Items[this.m.ItemIndex];
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
		this.announceItem();
	},
	function openDetails()
	{
		local row = this.currentRow();
		if (row == null)
		{
			this.announceItem();
			return;
		}

		local details = ::UnseenBanner.splitParagraphs(row.description);
		if (details.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", row.name, "world.travel.details.none");
			return;
		}

		this.m.Details = details;
		this.m.DetailIndex = 0;
		this.m.DetailMode = true;
		this.announceDetail(true);
	},
	function leaveDetails(_announceParent = false)
	{
		this.m.DetailMode = false;
		this.m.Details = null;
		this.m.DetailIndex = 0;
		if (_announceParent) this.announceItem();
	},
	function moveDetail(_code)
	{
		if (this.m.Details == null || this.m.Details.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.DetailIndex -= 1;
		else if (dir == "down") this.m.DetailIndex += 1;
		else if (dir == "home") this.m.DetailIndex = 0;
		else this.m.DetailIndex = this.m.Details.len() - 1;
		if (this.m.DetailIndex < 0) this.m.DetailIndex = 0;
		if (this.m.DetailIndex >= this.m.Details.len())
			this.m.DetailIndex = this.m.Details.len() - 1;
		this.announceDetail();
	},
	function announceDetail(_opened = false)
	{
		if (this.m.Details == null || this.m.Details.len() == 0) return;
		local row = this.currentRow();
		local detail = "" + (this.m.DetailIndex + 1) + "|" + this.m.Details.len()
			+ "|" + (_opened ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", this.m.Details[this.m.DetailIndex],
			"world.travel.detail", row != null ? row.name : "", detail);
	},
	function openConfirm()
	{
		local row = this.currentRow();
		if (row == null)
		{
			this.announceItem();
			return;
		}
		this.m.ConfirmMode = true;
		this.announceConfirm(true);
	},
	function leaveConfirm(_announceParent = false)
	{
		this.m.ConfirmMode = false;
		if (_announceParent) this.announceItem();
	},
	function announceConfirm(_opened = false)
	{
		local row = this.currentRow();
		if (row == null) return;
		local money = ::World.Assets.getMoney();
		local detail = "" + money + "|" + (_opened ? "1" : "0")
			+ "|" + (row.cost > money ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", row.name, "world.travel.confirm",
			"" + row.cost, detail);
	},
	function executeTravel()
	{
		local row = this.currentRow();
		if (row == null) return;
		local screen = this.m.Screen;
		local cost = row.cost;
		local name = row.name;

		// onTravel walks back through showMainDialog on success (fastTravelTo pops the
		// harbour's own menu-stack backstep), and that funnel re-reads the settlement
		// list. Arm the one-shot before calling in, since vanilla's pop is refused
		// outright while the screen animates and may therefore land on either side of
		// this call — or not at all.
		::UnseenBanner.WorldTown.suppressNextAnnounce();
		local result = this.m.Module.onTravel(row.entryID);
		local code = (result != null && "Result" in result) ? result.Result : 0;
		if (code != 0)
		{
			// onTravel refuses without charging, so the cursor stays where it was and
			// the player can pick a nearer harbour.
			local reason = code == ::Const.UI.Error.NotEnoughMoney ? "money" : "gone";
			::UnseenBanner.WorldTown.consumeSuppressedAnnounce();
			this.leaveConfirm(false);
			::UnseenBanner.sendMessage("interrupt", name, "world.travel.error", reason,
				"" + cost + "|" + ::World.Assets.getMoney());
			return;
		}

		// fastTravelTo has already closed this dialog through onLeaveButtonPressed (our
		// showMainDialog hook shut this cursor down with it) and then re-pointed the
		// screen at the destination, so the settlement list underneath is stale. Rebuild
		// it against the new town before speaking, or the first Up/Down would walk the
		// buildings of the port left behind.
		this.reset();
		if (screen != null && screen.isVisible())
		{
			::UnseenBanner.WorldTown.open(screen.getTown(), false);
		}
		::UnseenBanner.sendMessage("interrupt", name, "world.travel.arrived",
			"" + cost, "" + ::World.Assets.getMoney());
	},
	function announceItem(_opened = false)
	{
		local money = ::World.Assets.getMoney();
		if (this.m.Items == null || this.m.Items.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.travel.empty", "" + money,
				_opened ? "1" : "0");
			return;
		}
		local row = this.currentRow();
		if (row == null) return;
		local detail = "" + row.cost + "|" + (this.m.ItemIndex + 1) + "|"
			+ this.m.Items.len() + "|" + (_opened ? "1" : "0") + "|" + money
			+ "|" + (row.cost > money ? "1" : "0")
			+ "|" + (row.seen ? "1" : "0") + "|" + row.pos;
		::UnseenBanner.sendMessage("interrupt", row.name, "world.travel.destination",
			row.faction, detail);
	},
	function onKey(_code)
	{
		if (!this.m.Active) return;

		if (this.m.ConfirmMode)
		{
			if (_code == this.ActionKey) this.executeTravel();
			else if (_code == this.InspectKey || _code == this.EscapeKey)
				this.leaveConfirm(true);
			// One action only, so Up/Down have nowhere to go: re-read it rather than
			// answer a keystroke with silence, which reads as a hang.
			else if (_code in this.MoveKeys) this.announceConfirm();
			return;
		}

		if (this.m.DetailMode)
		{
			if (_code == this.InspectKey || _code == this.EscapeKey)
				this.leaveDetails(true);
			else if (_code in this.MoveKeys) this.moveDetail(_code);
			return;
		}

		if (_code == this.ActionKey) this.openConfirm();
		else if (_code == this.InspectKey) this.openDetails();
		else if (_code in this.MoveKeys) this.move(_code);
	}
};

// Training hall. Vanilla offers three paid experience boosts per man, in a
// mouse-only roster whose prices scale with level and whose only explanation of
// what each one does is a hover tooltip. Those tooltips are the same ui-element
// entries the rest of this mod already reads, so V hands over the real wording
// instead of a description written here.
//
// Two traps this cursor has to cover, both because the endpoint is reached
// directly instead of through the button:
//
//  1. onTrain charges the crowns with NO affordability check of its own — the only
//     guard vanilla has is the JS disabling the button (its createTrainingControlDIV
//     compares price against the purse). So the purse is checked here.
//  2. queryRosterInformation silently drops the men who cannot train at all (level
//     11 or more, already carrying effects.trained, and the Manhunters origin's
//     slaves from level 7). A sighted player sees a short list and infers why; a
//     blind one would just find brothers missing. So the full roster is listed and
//     the ones who cannot train say so, with the reason.
::UnseenBanner.WorldTraining <- {
	m = {
		Screen = null,
		Module = null,
		Items = null,
		ItemIndex = 0,
		Actions = null,
		ActionIndex = 0,
		ActionMode = false,
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
			|| (_code == this.EscapeKey && this.m.ActionMode)
			|| _code in this.MoveKeys;
	},
	function reset()
	{
		this.m.Screen = null;
		this.m.Module = null;
		this.m.Items = null;
		this.m.ItemIndex = 0;
		this.m.Actions = null;
		this.m.ActionIndex = 0;
		this.m.ActionMode = false;
		this.m.Active = false;
		::UnseenBanner.TooltipNav.hide();
	},
	function close()
	{
		this.reset();
	},
	function open(_screen, _module)
	{
		this.reset();
		if (_screen == null || _module == null) return;
		this.m.Screen = _screen;
		this.m.Module = _module;
		this.m.Active = true;
		this.buildItems();
		this.announceItem(true);
	},
	// Why a man cannot train, mirroring the three tests queryRosterInformation
	// applies before it drops him. Kept in the same order so the spoken reason is
	// the one that actually excluded him.
	function blockReason(_bro)
	{
		if (_bro.getLevel() >= 11) return "maxlevel";
		if (_bro.getLevel() >= 7 && ::World.Assets.getOrigin().getID() == "scenario.manhunters"
			&& _bro.getBackground().getID() == "background.slave") return "slave";
		if (_bro.getSkills().hasSkill("effects.trained")) return "trained";
		return null;
	},
	// The trainable men and their prices come from the module; the men who cannot
	// train come from the roster, so nobody vanishes without a spoken reason.
	// _preferredID keeps the cursor on the man being worked on across a rebuild.
	function buildItems(_preferredID = null, _fallbackIndex = 0)
	{
		local offers = {};
		if (this.m.Module != null)
		{
			local data = this.m.Module.queryRosterInformation();
			if (data != null && data.Roster != null)
			{
				foreach( entry in data.Roster )
				{
					if (entry == null) continue;
					local options = [];
					foreach( option in entry.Training )
					{
						if (option == null) continue;
						options.push({
							id = option.id,
							name = option.name,
							price = option.price,
							tooltip = option.tooltip
						});
					}
					offers[entry.ID] <- options;
				}
			}
		}

		local rows = [];
		local roster = ::World.getPlayerRoster().getAll();
		if (roster != null)
		{
			foreach( bro in roster )
			{
				if (bro == null) continue;
				local id = bro.getID();
				rows.push({
					entityID = id,
					name = bro.getName(),
					level = bro.getLevel(),
					options = (id in offers) ? offers[id] : [],
					reason = (id in offers) ? null : this.blockReason(bro)
				});
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
	function currentRow()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return null;
		if (this.m.ItemIndex < 0 || this.m.ItemIndex >= this.m.Items.len()) return null;
		return this.m.Items[this.m.ItemIndex];
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
		this.announceItem();
	},
	function openActions()
	{
		local row = this.currentRow();
		if (row == null)
		{
			this.announceItem();
			return;
		}
		if (row.options.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", row.name, "world.training.blocked",
				row.reason != null ? row.reason : "none");
			return;
		}
		this.m.Actions = row.options;
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
	function currentAction()
	{
		if (this.m.Actions == null || this.m.Actions.len() == 0) return null;
		if (this.m.ActionIndex < 0 || this.m.ActionIndex >= this.m.Actions.len()) return null;
		return this.m.Actions[this.m.ActionIndex];
	},
	// V on a training option opens vanilla's own tooltip for it, so the "+50%
	// experience for the next battle" wording is the game's and needs no copy here.
	function showActionDetail()
	{
		local option = this.currentAction();
		if (option == null || option.tooltip == "")
		{
			this.announceAction();
			return;
		}
		::UnseenBanner.TooltipNav.show({
			contentType = "ui-element",
			elementId = option.tooltip
		}, 1, 1, "world.training");
	},
	function refreshNative()
	{
		if (this.m.Module == null || this.m.Screen == null) return;
		local data = this.m.Module.queryRosterInformation();
		this.m.Screen.updateAssets();
		// The whole table: the training module's own loadFromData reads _data.Roster
		// (and the two titles) itself, like the temple's and unlike the recruit one.
		if (data != null && this.m.Module.m.JSHandle != null)
			this.m.Module.m.JSHandle.asyncCall("loadFromData", data);
	},
	function executeAction()
	{
		local row = this.currentRow();
		local option = this.currentAction();
		if (row == null || option == null) return;

		// The guard vanilla only ever applied in the UI layer (see the note above).
		if (option.price > ::World.Assets.getMoney())
		{
			::UnseenBanner.sendMessage("interrupt", option.name, "world.training.error",
				"money", "" + option.price + "|" + ::World.Assets.getMoney());
			return;
		}

		local fallback = this.m.ItemIndex;
		this.m.Module.onTrain([row.entityID, option.id]);
		this.leaveActions(false);
		this.refreshNative();
		this.buildItems(row.entityID, fallback);
		::UnseenBanner.sendMessage("interrupt", option.name, "world.training.result",
			row.name, "" + option.price + "|" + ::World.Assets.getMoney());
	},
	function announceAction(_opened = false)
	{
		local option = this.currentAction();
		if (option == null) return;
		local row = this.currentRow();
		local money = ::World.Assets.getMoney();
		local detail = "" + option.price + "|" + (this.m.ActionIndex + 1)
			+ "|" + this.m.Actions.len() + "|" + (_opened ? "1" : "0")
			+ "|" + (option.price > money ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", option.name, "world.training.option",
			row != null ? row.name : "", detail);
	},
	function announceItem(_opened = false)
	{
		local money = "" + ::World.Assets.getMoney();
		if (this.m.Items == null || this.m.Items.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.training.empty", money,
				_opened ? "1" : "0");
			return;
		}
		local row = this.currentRow();
		if (row == null) return;
		local detail = "" + row.level + "|" + row.options.len() + "|"
			+ (this.m.ItemIndex + 1) + "|" + this.m.Items.len() + "|"
			+ (_opened ? "1" : "0") + "|" + money + "|"
			+ (row.reason != null ? row.reason : "");
		::UnseenBanner.sendMessage("interrupt", row.name, "world.training.man",
			"", detail);
	},
	function onKey(_code)
	{
		if (!this.m.Active) return;

		if (this.m.ActionMode)
		{
			if (_code == this.ActionKey) this.executeAction();
			else if (_code == this.InspectKey) this.showActionDetail();
			else if (_code == this.EscapeKey) this.leaveActions(true);
			else if (_code in this.MoveKeys) this.moveAction(_code);
			return;
		}

		if (_code == this.ActionKey) this.openActions();
		// V belongs to the lesson sub-list. handles() claims it at roster level too, so
		// it cannot leak into the town screen underneath; answer with the focused man
		// rather than with silence, which a blind player reads as a hang.
		else if (_code == this.InspectKey) this.announceItem();
		else if (_code in this.MoveKeys) this.move(_code);
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
		InspectItems = null,
		InspectIndex = 0,
		InspectMenuActive = false,
		// A row can carry more than one native tooltip (the equipment row, one per
		// worn piece). DetailMode nests V's list one level into that row's own
		// details; V again backs out to the row, same convention as SheetNav.
		DetailMode = false,
		DetailIndex = 0,
		// Engine code of the key that closed the inspect list on its press, so its
		// own release can be swallowed instead of leaking into vanilla (-1 = none).
		PendingRelease = -1,
		// True from the press of V until its release. V is a toggle (it opens the
		// list, and Shift+V closes it again), and the engine auto-repeats a held key
		// as a stream of fresh presses, so without this one physical Shift+V that
		// the player holds for more than KeyGate's 0.2 s opens the list and closes
		// it right back — leaving him on the battlefield still believing he is in
		// the list, where End is vanilla's "wait turn" instead of "last row".
		InspectKeyHeld = false,
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
	InspectMoveKeys = {
		[44] = "end",
		[45] = "home",
		[49] = "up",
		[51] = "down"
	},
	InspectCancelKey = 41, // Escape
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
	function handlesInspectMenu(_code, _shift)
	{
		if (this.m.InspectMenuActive)
		{
			return (_code in this.InspectKeys)
				|| (_code in this.InspectMoveKeys)
				|| _code == this.InspectCancelKey;
		}
		return _shift && (_code in this.InspectKeys);
	},
	function isInspectMenuActive()
	{
		return this.m.InspectMenuActive;
	},
	// The inspect list closes on the key PRESS (KeyGate cadence), so by the time the
	// matching release arrives the list is already down and the "consume every key"
	// branch that shielded it is gone. Vanilla then acts on that release: Escape's
	// opened the tactical pause menu right after our list closed. Remember the
	// closing key and swallow exactly its release, nothing else.
	function armReleaseSwallow(_code)
	{
		this.m.PendingRelease = _code;
	},
	function consumeReleaseSwallow(_code)
	{
		if (this.m.PendingRelease != _code) return false;
		this.m.PendingRelease = -1;
		return true;
	},
	// Called for every key release reaching the tactical hook, whatever else that
	// release does, so the held-V latch can never stay stuck on a path we forgot.
	function clearInspectKeyHeld(_code)
	{
		if (_code in this.InspectKeys) this.m.InspectKeyHeld = false;
	},
	function reset()
	{
		this.m.PendingRelease = -1;
		this.m.InspectKeyHeld = false;
		this.closeInspectMenu(false);
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
			this.closeInspectMenu(false);
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
		this.closeInspectMenu(false);

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
	// Three facts the tile readout used to leave to the eye, packed for the companion
	// as "elev|zoc|kind|ap|fatigue|complete". They ride in their own protocol field
	// instead of being tacked onto `detail`, whose last two slots are the optional
	// target preview: appended there they would sit at a different index depending on
	// whether a skill is armed. Every one of them is spoken AFTER everything the
	// readout already said, so sweeping hexes stays as fast to hear as before and the
	// new clauses are what a player interrupts through, never what he waits for.
	function extras(_active, _tile)
	{
		if (_active == null || _tile == null) return null;
		local activeTile = _active.getTile();

		// Height relative to the active man, not the absolute level: high ground is
		// worth hit chance and ranged reach in this game, and "one level higher" is
		// the form that answers the question. Equal height stays silent (companion
		// side), which is the common case on most maps.
		local elev = activeTile != null ? (_tile.Level - activeTile.Level) : 0;

		// Enemies exerting zone of control over the tile — the same count the AI
		// consults before disengaging (ai_disengage reads it off the destination
		// tile). Standing here means each of them gets a free attack the moment this
		// man walks away, which is exactly the trap a blind player cannot see coming.
		local zoc = _tile.getZoneOfControlCountOtherThan(_active.getAlliedFactions());

		return "" + elev + "|" + zoc + "|" + this.moveCost(_active, _tile);
	},
	// What walking to the cursor tile would cost, mirroring the mouse hover's own
	// preview (tactical_state.computeEntityPath): identical navigator settings and
	// the same find -> build -> cost order, so the numbers are the ones vanilla
	// paints on the turn bar. Two deliberate differences: m.CurrentActionState is
	// left untouched (the cursor must never cancel an armed skill or a queued
	// action), and the visualisation is cleared again immediately — nothing on
	// screen may change just because a blind player swept a hex.
	//
	// Returns "" whenever there is nothing useful to say: the man's own tile, an
	// occupied or undiscovered tile, or a skill already armed, where the target
	// preview answers the question instead and a movement clause would be noise.
	function moveCost(_active, _tile)
	{
		if (this.m.CurrentSkill != null) return "";

		local from = _active.getTile();
		if (from == null || from.ID == _tile.ID) return "";
		if (!_tile.IsEmpty || !_tile.IsDiscovered) return "";
		// Rooted is announced by G itself when the move is attempted; repeating it on
		// every hex of a sweep would be the verbosity this readout is trying to avoid.
		if (_active.getCurrentProperties().IsRooted) return "";

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

		if (!nav.findPath(from, _tile, settings, 0))
		{
			nav.clearVisualisation();
			return "none";
		}

		nav.buildVisualisation(_active, settings, _active.getActionPoints(),
			_active.getFatigueMax() - _active.getFatigue());
		// Vanilla drops the zone-of-control surcharge before pricing the path: the
		// extra cost steers the route, it is not part of what the move charges.
		settings.ZoneOfControlCost = 0;
		local costs = nav.getCostForPath(_active, settings, _active.getActionPoints(),
			_active.getFatigueMax() - _active.getFatigue());
		nav.clearVisualisation();

		if (costs == null) return "";
		local tiles = ("Tiles" in costs) ? costs.Tiles : 0;
		if (tiles == 0) return "far";

		local ap = ("ActionPoints" in costs) ? costs.ActionPoints : 0;
		local fatigue = ("Fatigue" in costs) ? costs.Fatigue : 0;
		// IsComplete is false when the man would run out of action points partway and
		// stop short of the tile — the difference between "you can be there" and "you
		// can start walking there", which the numbers alone do not convey.
		local complete = (!("IsComplete" in costs) || costs.IsComplete) ? "1" : "0";
		return "cost|" + ap + "|" + fatigue + "|" + complete;
	},
	function getCorpseName(_tile)
	{
		if (_tile == null || !_tile.IsCorpseSpawned
			|| !_tile.Properties.has("Corpse"))
		{
			return "";
		}

		local corpse = _tile.Properties.get("Corpse");
		return corpse != null && ("CorpseName" in corpse) && corpse.CorpseName != null
			? corpse.CorpseName
			: "";
	},
	function announce(_active)
	{
		local tile = this.m.CursorTile;
		local name = "";
		local kind = "empty";
		local hp = "";
		local hpMax = "";
		local corpseName = this.getCorpseName(tile);

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
		// the health clause for an actor. A corpse is independent of the current
		// occupant: actors can stand over one, and skills such as Gruesome Feast
		// target that corpse rather than the living actor on the same hex.
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

		// NB: the extras ride in `comparacion`, not in `contexto`. `contexto` is not a
		// free field: every message passes through ComposeCharacterContext, which
		// turns whatever is in it into "Entry N of M" — a tile readout sent there came
		// out with a bogus position glued to its tail. `comparacion` and `cadaver` are
		// the two fields with no such global post-processing.
		::UnseenBanner.sendMessage("interrupt", name, "tile.readout", "" + tile.Type,
			detail, null, null, null, null, this.extras(_active, tile),
			corpseName != "" ? corpseName : null);
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
		local corpseName = this.getCorpseName(tile);

		if (tile == null || tile.IsEmpty)
		{
			if (corpseName != "")
				::UnseenBanner.sendMessage("interrupt", corpseName, "combat.inspect.corpse");
			else
				::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.empty");
			return;
		}

		local e = tile.getEntity();
		if (e == null)
		{
			if (corpseName != "")
				::UnseenBanner.sendMessage("interrupt", corpseName, "combat.inspect.corpse");
			else
				::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.empty");
			return;
		}

		if (!::isKindOf(e, "actor"))
		{
			// Cover or decoration — worth naming (it affects line of sight and
			// defence) but there are no combat stats to read.
			if (corpseName != "")
				::UnseenBanner.sendMessage("interrupt", e.getName(),
					"combat.inspect.object_corpse", corpseName);
			else
				::UnseenBanner.sendMessage("interrupt", e.getName(), "combat.inspect.object");
			return;
		}

		if (!e.isAlive() || e.isDying() || !e.isPlacedOnMap())
		{
			if (corpseName != "")
				::UnseenBanner.sendMessage("interrupt", corpseName, "combat.inspect.corpse");
			else
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
		else if (e.isPlayerControlled() || e.isAlliedWithPlayer()) kind = "ally";

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
		local equipment = this.equipmentItem(e).texto;

		local detail = kind + "|" + e.getLevel()
			+ "|" + timing
			+ "|" + e.getHitpoints() + "|" + e.getHitpointsMax()
			+ "|" + e.getArmor(::Const.BodyPart.Head) + "|" + e.getArmorMax(::Const.BodyPart.Head)
			+ "|" + e.getArmor(::Const.BodyPart.Body) + "|" + e.getArmorMax(::Const.BodyPart.Body)
			+ "|" + equipment
			+ "|" + e.getMoraleState()
			+ "|" + effects;

		::UnseenBanner.sendMessage("interrupt", name, "combat.inspect", "ok", detail,
			null, null, null, null, null, corpseName != "" ? corpseName : null);
	},
	// _details is an array of native tooltip descriptors (0, 1 or many): 0 means
	// "no tooltip" (V says so), 1 shows directly, more than 1 nests into a list
	// V walks with Up/Down, same convention as SheetNav's rows.
	function inspectItem(_cat, _texto = "", _valor = "", _detalle = "", _details = null)
	{
		return {
			cat = _cat,
			texto = _texto,
			valor = _valor,
			detalle = _detalle,
			details = _details != null ? _details : []
		};
	},
	function statusDetail(_actor, _skill)
	{
		return {
			contentType = "status-effect",
			entityId = _actor.getID(),
			statusEffectId = _skill.getID()
		};
	},
	function itemDetail(_actor, _item)
	{
		return {
			contentType = "ui-item",
			entityId = _actor.getID(),
			itemId = _item.getInstanceID(),
			itemOwner = "entity"
		};
	},
	// Worn equipment (mainhand, offhand, head, body, accessory), same slot order
	// and same "combat.sheet.equipment" wording as SheetNav's character sheet, so
	// the phrasing a player already knows for a brother ("Equipment: sword, ...")
	// is exactly what they hear for any unit under the cursor — ally or enemy. A
	// non-combatant actor (a beast with no item container) reads as no equipment
	// rather than throwing and aborting the rest of the menu.
	function equipmentItem(_actor)
	{
		local inv = _actor.getItems();
		if (inv == null) return this.inspectItem("combat.sheet.equipment", "", "0");

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
			details.push(this.itemDetail(_actor, it));
			n += 1;
		}
		return this.inspectItem("combat.sheet.equipment", text, "" + n, "",
			n > 0 ? details : null);
	},
	function timing(_actor)
	{
		local active = ::Tactical.TurnSequenceBar.getActiveEntity();
		if (active != null && active.getID() == _actor.getID()) return "now";
		if (_actor.isTurnDone()) return "done";

		local turns = ::Tactical.TurnSequenceBar.getTurnsUntilActive(_actor.getID());
		return turns != null && turns > 0 ? "" + turns : "none";
	},
	// Shift+V turns the unit tooltip readout into a navigable semantic menu. Each
	// status effect is its own row and carries the exact native status-effect
	// descriptor used by the visible UI, so plain V can render and read its tooltip.
	function openInspectMenu(_active)
	{
		this.ensureAnchored(_active);
		local tile = this.m.CursorTile;
		local corpseName = this.getCorpseName(tile);

		if (tile == null || tile.IsEmpty)
		{
			if (corpseName != "")
				::UnseenBanner.sendMessage("interrupt", corpseName, "combat.inspect.corpse");
			else
				::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.empty");
			return;
		}

		local actor = tile.getEntity();
		if (actor == null)
		{
			if (corpseName != "")
				::UnseenBanner.sendMessage("interrupt", corpseName, "combat.inspect.corpse");
			else
				::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.empty");
			return;
		}
		if (!::isKindOf(actor, "actor"))
		{
			if (corpseName != "")
				::UnseenBanner.sendMessage("interrupt", actor.getName(),
					"combat.inspect.object_corpse", corpseName);
			else
				::UnseenBanner.sendMessage("interrupt", actor.getName(),
					"combat.inspect.object");
			return;
		}
		if (!actor.isAlive() || actor.isDying() || !actor.isPlacedOnMap())
		{
			if (corpseName != "")
				::UnseenBanner.sendMessage("interrupt", corpseName, "combat.inspect.corpse");
			else
				::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.empty");
			return;
		}
		if (!actor.isDiscovered())
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.hidden");
			return;
		}
		if (actor.isHiddenToPlayer())
		{
			::UnseenBanner.sendMessage("interrupt", actor.getName(), "combat.inspect",
				"sight", "");
			return;
		}

		local kind = "enemy";
		if (_active != null && actor.getID() == _active.getID()) kind = "self";
		else if (actor.isPlayerControlled() || actor.isAlliedWithPlayer()) kind = "ally";

		local items = [];
		items.push(this.inspectItem("combat.inspect.menu.screen", actor.getName()));
		items.push(this.inspectItem("combat.inspect.header." + kind,
			actor.getName(), "" + actor.getLevel()));

		local when = this.timing(actor);
		if (when == "now")
			items.push(this.inspectItem("combat.inspect.timing.now"));
		else if (when == "done")
			items.push(this.inspectItem("combat.inspect.timing.done"));
		else if (when != "none")
			items.push(this.inspectItem(when == "1"
				? "combat.inspect.timing.turns.one"
				: "combat.inspect.timing.turns", when));

		items.push(this.inspectItem("combat.inspect.menu.health",
			"", "" + actor.getHitpoints(), "" + actor.getHitpointsMax()));
		items.push(this.inspectItem("combat.inspect.menu.armor.head",
			"", "" + actor.getArmor(::Const.BodyPart.Head),
			"" + actor.getArmorMax(::Const.BodyPart.Head)));
		items.push(this.inspectItem("combat.inspect.menu.armor.body",
			"", "" + actor.getArmor(::Const.BodyPart.Body),
			"" + actor.getArmorMax(::Const.BodyPart.Body)));
		items.push(this.equipmentItem(actor));
		items.push(this.inspectItem("combat.inspect.menu.fatigue",
			"", "" + actor.getFatigue(), "" + actor.getFatigueMax()));

		local statuses = actor.getSkills().query(
			::Const.SkillType.StatusEffect | ::Const.SkillType.TemporaryInjury,
			false, true);
		local moraleDetails = null;
		foreach( status in statuses )
		{
			if (status != null && status.getID() == "special.morale.check")
			{
				moraleDetails = [this.statusDetail(actor, status)];
				break;
			}
		}
		items.push(this.inspectItem("combat.inspect.menu.morale", "",
			"" + actor.getMoraleState(), "", moraleDetails));

		local effectCount = 0;
		foreach( status in statuses )
		{
			if (status == null || status.getID() == "special.morale.check") continue;
			items.push(this.inspectItem("combat.inspect.menu.effect", status.getName(),
				"", "", [this.statusDetail(actor, status)]));
			effectCount += 1;
		}
		if (effectCount == 0)
			items.push(this.inspectItem("combat.inspect.menu.effects.none"));
		if (corpseName != "")
			items.push(this.inspectItem("combat.inspect.corpse", corpseName));

		this.m.InspectItems = items;
		this.m.InspectIndex = 0;
		this.m.InspectMenuActive = true;
		::UnseenBanner.TooltipNav.hide();
		this.announceInspectItem();
	},
	function closeInspectMenu(_announce = false)
	{
		local wasActive = this.m.InspectMenuActive;
		this.m.InspectItems = null;
		this.m.InspectIndex = 0;
		this.m.InspectMenuActive = false;
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
		::UnseenBanner.TooltipNav.hide();
		if (_announce && wasActive)
			::UnseenBanner.sendMessage("interrupt", "", "combat.inspect.menu.closed");
	},
	function onInspectMenuKey(_code, _shift, _active)
	{
		// V acts once per physical press, never on the engine's auto-repeat of a
		// key still held down: it is a toggle, so a repeat would undo what the very
		// same keystroke just did. The move keys below are deliberately left
		// repeatable — holding End to run to the end of the list is wanted.
		if (_code in this.InspectKeys)
		{
			if (this.m.InspectKeyHeld) return;
			this.m.InspectKeyHeld = true;
		}

		if (!this.m.InspectMenuActive)
		{
			if (_shift && (_code in this.InspectKeys)) this.openInspectMenu(_active);
			return;
		}

		if (_code == this.InspectCancelKey
			|| (_shift && (_code in this.InspectKeys)))
		{
			// Escape/Shift+V backs out one level at a time: out of a row's nested
			// detail list first, only closing the whole menu on the next press.
			if (this.m.DetailMode)
			{
				this.leaveDetails();
				::UnseenBanner.TooltipNav.hide();
				this.announceInspectItem();
			}
			else
			{
				this.closeInspectMenu(true);
			}
			this.armReleaseSwallow(_code);
			return;
		}

		if (_code in this.InspectKeys)
		{
			this.toggleDetails();
			return;
		}
		if (!(_code in this.InspectMoveKeys)
			|| this.m.InspectItems == null || this.m.InspectItems.len() == 0)
		{
			return;
		}

		if (this.m.DetailMode)
		{
			this.moveDetail(_code);
			return;
		}

		local move = this.InspectMoveKeys[_code];
		if (move == "up") this.m.InspectIndex -= 1;
		else if (move == "down") this.m.InspectIndex += 1;
		else if (move == "home") this.m.InspectIndex = 0;
		else this.m.InspectIndex = this.m.InspectItems.len() - 1;

		if (this.m.InspectIndex < 0) this.m.InspectIndex = 0;
		if (this.m.InspectIndex >= this.m.InspectItems.len())
			this.m.InspectIndex = this.m.InspectItems.len() - 1;
		::UnseenBanner.TooltipNav.hide();
		this.announceInspectItem();
	},
	function announceInspectItem()
	{
		if (!this.m.InspectMenuActive || this.m.InspectItems == null
			|| this.m.InspectItems.len() == 0)
		{
			return;
		}

		local item = this.m.InspectItems[this.m.InspectIndex];
		::UnseenBanner.sendMessage("interrupt", item.texto, item.cat,
			item.valor, item.detalle, null, "" + item.details.len());
	},
	// V on a row with several native tooltips (currently only the equipment row)
	// enters a nested list; V again backs out and re-announces the parent row. A
	// single tooltip is shown/read directly without changing modes, same as
	// SheetNav's character sheet.
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
			this.announceInspectItem();
			return;
		}
		if (this.m.InspectItems == null || this.m.InspectItems.len() == 0) return;
		local details = this.m.InspectItems[this.m.InspectIndex].details;
		if (details.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "tooltip.unavailable");
			return;
		}
		this.m.DetailIndex = 0;
		if (details.len() > 1) this.m.DetailMode = true;
		this.showInspectDetail();
	},
	function moveDetail(_code)
	{
		local details = this.m.InspectItems[this.m.InspectIndex].details;
		if (details.len() == 0) return;
		local dir = this.InspectMoveKeys[_code];
		if (dir == "up") this.m.DetailIndex -= 1;
		else if (dir == "down") this.m.DetailIndex += 1;
		else if (dir == "home") this.m.DetailIndex = 0;
		else this.m.DetailIndex = details.len() - 1;
		if (this.m.DetailIndex < 0) this.m.DetailIndex = 0;
		if (this.m.DetailIndex >= details.len()) this.m.DetailIndex = details.len() - 1;
		this.showInspectDetail();
	},
	function showInspectDetail()
	{
		if (!this.m.InspectMenuActive || this.m.InspectItems == null
			|| this.m.InspectItems.len() == 0)
		{
			return;
		}

		local details = this.m.InspectItems[this.m.InspectIndex].details;
		if (details.len() == 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "tooltip.unavailable");
			return;
		}
		::UnseenBanner.TooltipNav.show(details[this.m.DetailIndex],
			this.m.DetailIndex + 1, details.len(), "combat.inspect.menu.effect");
	}
};

// Combat log (phase 3.1). The tactical event log is the funnel every combat
// line already flows through as fully rendered, localized text ("X uses Y and
// hits Z", deaths, morale, round starts...). We forward each line on the queue
// channel — the FIFO lesson from F&H1: combat lines must all be spoken, in
// order, nothing dropped. The category lets the companion shorten the standard
// Chance/Rolled suffix without reconstructing the rest of the rendered line.
// No JS: the text is already in Squirrel, so this reads it at the source instead
// of re-scraping the DOM. BBCode color tags are stripped by TextCleaner there.
::UnseenBanner.CombatLog = {
	function onLine(_text)
	{
		if (_text == null) return;
		// Skip the blank spacer lines the log uses between blocks; they carry
		// no words and would only add dead air to the speech queue.
		if (typeof _text != "string" || this.strip(_text) == "") return;
		::UnseenBanner.sendMessage("queue", _text, "combat.log");
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
	// t = active man's live action resources, tab = turn order, b = visible enemies, k = active
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
		// T is the terse live-resource answer: action points and fatigue only.
		// Identity, health, armour, equipment, morale and effects belong to V's
		// unit inspection, so repeating them here only makes every combat check slower.
		local detail = _active.getActionPoints() + "/" + _active.getActionPointsMax()
			+ "|" + _active.getFatigue() + "/" + _active.getFatigueMax();
		::UnseenBanner.sendMessage("interrupt", "", "combat.status", "", detail);
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
		// The attribute-increase list, held apart from the ordinary sections the same
		// way the dismissal confirmation is, and for the same reason: vanilla puts it
		// in a modal popup and it ends in something that cannot be undone. Picks are
		// one flag per attribute in Const.Attributes order, mirroring the popup's
		// mLevelUpIncreaseValues — nothing reaches the game until the three are
		// confirmed. The target is captured by ID and name so nothing depends on a
		// live actor reference that a roster change could invalidate.
		LevelUpMode = false,
		LevelUpItems = null,
		LevelUpIndex = 0,
		LevelUpPicks = null,
		LevelUpTargetID = null,
		LevelUpTargetName = "",
		FormationMoveMode = false,
		FormationSourceID = null,
		FormationSourceSlot = -1,
		FormationSourceName = "",
		// Dismissal confirmation: the brother Delete was pressed on, plus the
		// options list. Held apart from ActionMode on purpose — this is the one
		// operation on this screen that permanently removes a man from the roster,
		// and it should not share a code path with equipping a helmet.
		DismissMode = false,
		DismissItems = null,
		DismissIndex = 0,
		// The man the confirmation is about, captured by ID and name the way the
		// native popup does, so nothing depends on a live actor reference that the
		// dismissal itself is about to invalidate.
		DismissTargetID = null,
		DismissTargetName = "",
		DismissFree = "0",
		Screen = null,
		WorldMode = false,
		Active = false
	},
	// Vanilla's own rule for a level-up: three of the eight attributes, each raised
	// once (Constants.Game.MAX_STATS_INCREASE_COUNT in globals.js, which is what
	// enables the popup's OK button). Not tunable — changing it would desync this
	// list from what the game considers one spent level.
	MaxStatsIncrease = 3,
	InspectKey = 32, // v -> open/close the focused entry's native tooltip details
	ActionKey = 39, // Enter -> rename, open/confirm an action or place a brother
	CancelKey = 41, // Escape -> cancel an armed formation move
	DismissKey = 54, // delete -> dismiss the shown brother (identity row, world map)
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
				&& (this.m.ActionMode || this.m.DismissMode || this.isTacticalBagRow()
					|| (this.m.WorldMode && (this.isInventorySection()
						|| this.isIdentityRow() || this.isFormationSection()
						|| this.isPerksSection())) || this.m.LevelUpMode))
			|| (_code == this.CancelKey
				&& (this.m.FormationMoveMode || this.m.DismissMode
					|| this.m.LevelUpMode))
			// Delete is answered on every identity row in world mode, including the
			// rows where dismissing is not allowed: vanilla simply hides its button
			// there, and a key that does nothing at all is indistinguishable from a
			// broken mod when there is no button to see. The one exception is the
			// native name editor: while it is up Delete belongs to the text field
			// the player is typing in, not to us.
			|| (_code == this.DismissKey
				&& !::UnseenBanner.CharacterEdit.isActive()
				&& (this.m.DismissMode || (this.m.WorldMode && this.isIdentityRow())))
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
				&& (this.isIdentityRow() || this.isFormationSection()
					|| this.m.LevelUpMode))
			|| (_code == this.CancelKey
				&& (this.m.FormationMoveMode || this.m.DismissMode
					|| this.m.LevelUpMode));
	},
	function onReleaseHandledKey(_code, _screen)
	{
		// Inside the dismissal confirmation and the attribute list the identity row is
		// still the focused row, but Enter there means "carry out the chosen option",
		// never "open the rename editor" — so the editor guards below must not
		// intercept it.
		if (_code == this.ActionKey && this.isIdentityRow()
			&& !this.m.DismissMode && !this.m.LevelUpMode)
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
		this.resetLevelUp();
		this.resetFormationMove();
		this.resetDismiss();
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
		// The dismissal confirmation owns the keyboard while it is up: it is modal
		// by intent, because the action behind it cannot be undone.
		if (this.m.DismissMode)
		{
			// The engine repeats a held key as a stream of fresh presses, and the
			// press that opened this list is still down. Swallow those repeats.
			if (_code == this.DismissKey) return;

			if (_code == this.CancelKey || _code == this.InspectKey)
			{
				this.cancelDismiss(true);
				return;
			}
			if (_code == this.ActionKey)
			{
				this.executeDismiss(_screen);
				return;
			}
			if (_code in this.MoveKeys)
			{
				this.moveDismiss(_code);
				return;
			}

			// Changing brother or section abandons the confirmation and then runs
			// its ordinary course, the same way the action sub-list behaves. The
			// man it named is no longer the man in front of the player.
			this.cancelDismiss(false);
		}

		// The attribute list owns the keyboard while it is up, like the dismissal
		// confirmation. V is the one difference between them: here it stays "read what
		// this attribute does", the native tooltip that is the whole basis for
		// choosing, and Escape alone cancels.
		if (this.m.LevelUpMode)
		{
			if (_code == this.CancelKey)
			{
				this.cancelLevelUp(true);
				return;
			}
			if (_code == this.InspectKey)
			{
				this.showLevelUpDetail();
				return;
			}
			if (_code == this.ActionKey)
			{
				this.activateLevelUp(_screen);
				return;
			}
			if (_code in this.MoveKeys)
			{
				this.moveLevelUp(_code);
				return;
			}
			// Delete belongs to the identity row underneath, which is still the focused
			// row but is not what the player is on. Dropping straight from choosing an
			// increase into a dismissal confirmation would be its own accident.
			if (_code == this.DismissKey) return;

			// Changing brother or section abandons the choices and then runs its
			// ordinary course. Nothing was spent, so there is nothing to undo.
			this.cancelLevelUp(false);
		}

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

		if (_code == this.DismissKey)
		{
			this.openDismiss();
			return;
		}

		if (_code == this.ActionKey)
		{
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
	function isPerksSection()
	{
		local section = this.currentSection();
		return this.m.WorldMode && section != null && section.id == "perks";
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
		// Sheet rows are built by a different helper and carry no payload field at
		// all, so this cannot read the slot without testing for it — the identity row
		// below is one of them.
		local payload = _row != null && ("payload" in _row) ? _row.payload : null;
		local actions = [];

		// The identity row is the screen's header, and vanilla hangs two things off
		// it: renaming, on the name, and the level-up popup, on the level label right
		// beside it. Both live behind this one Enter. The level-up entry appears only
		// while the man actually has increases to spend, exactly like the star vanilla
		// draws there — and it leads, because the row's own hint has just said one is
		// waiting, and that is what the player pressed Enter for.
		if (this.m.WorldMode && _row != null && _row.cat == "combat.sheet.identity")
		{
			local bro = this.current();
			if (this.levelUpPending(bro) > 0)
			{
				actions.push(this.action("levelup_open", "levelup_open", "levelup_open",
					"", { source = "identity" }));
			}
			actions.push(this.action("rename", "rename", "rename",
				bro != null ? bro.getName() : "", { source = "identity" }));
			return actions;
		}

		// A perk is offered only when it can actually be taken. Every other state
		// (already acquired, tier still locked, no points left) is reported by the
		// row itself, so there is nothing to put in a menu.
		if (payload != null && payload.source == "perk")
		{
			if (payload.state == "available")
			{
				actions.push(this.action("unlock_perk", "unlock_perk", "unlock_perk",
					payload.perkName, payload));
			}
			return actions;
		}

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
			? (this.isInventorySection() || this.isPerksSection()
				|| this.isIdentityRow())
			: this.isTacticalBagRow();
		if (!canOpen || this.m.Items == null || this.m.Items.len() == 0) return;

		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		local row = this.m.Items[this.m.ItemIndex];
		local actions = this.buildActions(row);
		if (actions.len() == 0)
		{
			// Say why Enter did nothing in the vocabulary of what is under the
			// cursor: for a perk that is its own state, and the points summary is
			// a readout, not something that can be acted on at all.
			// Sheet rows are built by a different helper and carry no payload field
			// at all, so this must test for the field before reading it.
			local source = ("payload" in row) && row.payload != null
				? row.payload.source : "";
			if (source == "perk")
			{
				::UnseenBanner.sendMessage("interrupt", row.texto,
					"world.character.perk.actions.none", row.valor);
			}
			else if (source == "perk_summary")
			{
				::UnseenBanner.sendMessage("interrupt", "",
					"world.character.perks.summary.no_action");
			}
			else
			{
				::UnseenBanner.sendMessage("interrupt", row.texto,
					"world.inventory.actions.none");
			}
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

		// The two entries of the identity menu open something rather than changing
		// state, so they leave the menu and hand over instead of running through the
		// mutate-reload-announce tail below.
		if (action.execute == "rename")
		{
			this.leaveActions(false);
			this.leaveDetails();
			::UnseenBanner.TooltipNav.hide();
			::UnseenBanner.CharacterEdit.open(bro);
			return;
		}

		if (action.execute == "levelup_open")
		{
			this.leaveActions(false);
			this.openLevelUp();
			return;
		}

		switch(action.execute)
		{
		// The screen's own endpoint, not entity.unlockPerk directly: it is the
		// funnel that validates the entity, spends the point and rolls back on
		// failure, exactly as clicking the perk in the tree would.
		case "unlock_perk":
			result = _screen.onUnlockPerk([bro.getID(), payload.perkID]);
			success = this.mutationSucceeded(result);
			break;

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

		// Deliberately NOT onDropBagItemIntoInventory, the endpoint that matches this
		// direction by name: it hands our null target index straight to
		// stash_container.insert(), whose isValidSlot(null) is false in Squirrel
		// (null compares below 0), so it stores nothing and returns null — and the
		// caller only puts the item back in the bag when insert() hands it a displaced
		// one. The bag slot had already been emptied, so the item was destroyed, and
		// the call still returned valid UI data, which we read as success. Vanilla
		// never trips this: a mouse drag always names the stash slot it dropped on.
		//
		// onDropPaperdollItem is the null-tolerant sibling. Its helper checks for stash
		// room first, moves an item whose current slot is Bag with stash.add(), and
		// restores it to the bag if that fails; it finds the item by instance ID across
		// every slot type, the bag included, so a bag item resolves fine despite the
		// paperdoll name. The three other inventory endpoints we call all guard their
		// null index like this one; this was the only one that did not.
		case "bag_to_stash":
			result = _screen.onDropPaperdollItem([
				bro.getID(), payload.itemId, null
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
			if (payload != null && payload.source == "perk")
			{
				// Read back the points that are left, from live state after the
				// rebuild: how many remain is the next thing the player needs to
				// decide whether to keep spending.
				::UnseenBanner.sendMessage("interrupt", action.name,
					"world.character.perk.result." + action.result,
					bro != null ? "" + bro.getPerkPoints() : "");
			}
			else
			{
				::UnseenBanner.sendMessage("interrupt", action.name,
					"world.inventory.result." + action.result);
			}
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
	// --- Spending a level-up (Enter on the identity row) ------------------------
	//
	// Vanilla's level-up is a mouse-only popup behind the portrait's level label:
	// eight "+" buttons, three of which can be pressed, then OK. Nothing in it is
	// reachable from the keyboard, so m.LevelUps only ever grew and every attribute
	// increase the company earned was silently lost — while the F2 status kept
	// counting the man as waiting to level up, because isLeveled() is true for
	// either of the two debts a level grants. This is that popup as a list, opened
	// where vanilla puts its star: on the identity row, beside the name and level.
	//
	// It is modal, like the dismissal confirmation, because it ends in the same kind
	// of act: setAttributeLevelUpValues cannot be undone by anything short of
	// loading a save.

	// The eight attributes a level-up can raise, in the order
	// general_onCommitStatsIncreaseValues unpacks the array it is handed — which is
	// also Const.Attributes order, so one index serves as the commit slot and as the
	// talent (star) lookup. The native dialog draws icons and has no names to read,
	// so the names live in L10n and only the id travels. Each entry reuses the same
	// character-stats tooltip the sheet already reads for that attribute.
	function levelUpAttributes()
	{
		return [
			{ id = "hitpoints", value = "hitpoints", max = "hitpointsMax",
				increase = "hitpointsIncrease", tooltip = "character-stats.Hitpoints" },
			{ id = "bravery", value = "bravery", max = "braveryMax",
				increase = "braveryIncrease", tooltip = "character-stats.Bravery" },
			{ id = "fatigue", value = "fatigue", max = "fatigueMax",
				increase = "fatigueIncrease", tooltip = "character-stats.Fatigue" },
			{ id = "initiative", value = "initiative", max = "initiativeMax",
				increase = "initiativeIncrease", tooltip = "character-stats.Initiative" },
			{ id = "mskill", value = "meleeSkill", max = "meleeSkillMax",
				increase = "meleeSkillIncrease", tooltip = "character-stats.MeleeSkill" },
			{ id = "rskill", value = "rangeSkill", max = "rangeSkillMax",
				increase = "rangeSkillIncrease", tooltip = "character-stats.RangeSkill" },
			{ id = "mdef", value = "meleeDefense", max = "meleeDefenseMax",
				increase = "meleeDefenseIncrease", tooltip = "character-stats.MeleeDefense" },
			{ id = "rdef", value = "rangeDefense", max = "rangeDefenseMax",
				increase = "rangeDefenseIncrease", tooltip = "character-stats.RangeDefense" }
		];
	},
	// Whether this man has attribute increases waiting, and how many. Two exclusions,
	// both vanilla's: the popup is never offered in battle (its star checks
	// isTacticalMode), and guests level up but never get their increases offered —
	// isLeveled(), and with it the star, exclude them. Announcing a level-up where
	// Enter would refuse is worse than staying quiet.
	function levelUpPending(_bro = null)
	{
		if (!this.m.WorldMode) return 0;
		local bro = _bro != null ? _bro : this.current();
		if (bro == null || !::isKindOf(bro, "player") || bro.isGuest()) return 0;
		return bro.getLevelUps();
	},
	function resetLevelUp()
	{
		this.m.LevelUpMode = false;
		this.m.LevelUpItems = null;
		this.m.LevelUpIndex = 0;
		this.m.LevelUpPicks = null;
		this.m.LevelUpTargetID = null;
		this.m.LevelUpTargetName = "";
	},
	// Resolved from the captured ID rather than kept as a reference, so a roster
	// change under the open list cannot leave it pointing at a stale actor.
	function levelUpTarget()
	{
		if (this.m.LevelUpTargetID == null || this.m.Brothers == null) return null;
		foreach( bro in this.m.Brothers )
		{
			if (bro != null && bro.getID() == this.m.LevelUpTargetID) return bro;
		}
		return null;
	},
	function levelUpPicked()
	{
		if (this.m.LevelUpPicks == null) return 0;
		local n = 0;
		foreach( picked in this.m.LevelUpPicks )
		{
			if (picked) n += 1;
		}
		return n;
	},
	function currentLevelUpItem()
	{
		if (this.m.LevelUpItems == null || this.m.LevelUpItems.len() == 0) return null;
		if (this.m.LevelUpIndex < 0 || this.m.LevelUpIndex >= this.m.LevelUpItems.len())
			return null;
		return this.m.LevelUpItems[this.m.LevelUpIndex];
	},
	// Eight attributes and, last, the entry that applies them. The offer is read once
	// here: getAttributeLevelUpValues returns a pre-rolled set that stays fixed until
	// a commit consumes it, and holding it means what is committed is exactly what was
	// spoken, with no chance of the two drifting apart.
	function buildLevelUpItems(_bro)
	{
		local items = [];
		if (_bro == null)
		{
			this.m.LevelUpItems = items;
			return;
		}

		local offer = _bro.getAttributeLevelUpValues();
		local talents = _bro.getTalents();
		foreach( index, attribute in this.levelUpAttributes() )
		{
			items.push({
				kind = "attribute",
				index = index,
				id = attribute.id,
				increase = offer[attribute.increase],
				facts = "" + offer[attribute.value] + "|" + offer[attribute.max]
					+ "|" + offer[attribute.increase] + "|" + talents[index],
				tooltip = this.uiElementDetail(_bro, attribute.tooltip)
			});
		}
		items.push({
			kind = "confirm",
			index = -1,
			id = "",
			increase = 0,
			facts = "",
			tooltip = null
		});
		this.m.LevelUpItems = items;
	},
	function openLevelUp()
	{
		local bro = this.current();
		if (this.levelUpPending(bro) <= 0)
		{
			::UnseenBanner.sendMessage("interrupt", "", "world.character.levelup.unavailable");
			return;
		}

		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();
		this.m.LevelUpMode = true;
		this.m.LevelUpTargetID = bro.getID();
		this.m.LevelUpTargetName = bro.getName();
		this.m.LevelUpPicks = [false, false, false, false, false, false, false, false];
		this.m.LevelUpIndex = 0;
		this.buildLevelUpItems(bro);
		this.announceLevelUp(true);
	},
	function cancelLevelUp(_announce)
	{
		local name = this.m.LevelUpTargetName;
		this.resetLevelUp();
		::UnseenBanner.TooltipNav.hide();
		// A silent cancel is one the player caused by moving on: changing brother or
		// section speaks for itself right after this, and a second message would cut
		// the first one off.
		if (_announce)
		{
			::UnseenBanner.sendMessage("interrupt", name,
				"world.character.levelup.cancelled");
		}
	},
	function moveLevelUp(_code)
	{
		if (this.m.LevelUpItems == null || this.m.LevelUpItems.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.LevelUpIndex -= 1;
		else if (dir == "down") this.m.LevelUpIndex += 1;
		else if (dir == "home") this.m.LevelUpIndex = 0;
		else this.m.LevelUpIndex = this.m.LevelUpItems.len() - 1;

		if (this.m.LevelUpIndex < 0) this.m.LevelUpIndex = 0;
		if (this.m.LevelUpIndex >= this.m.LevelUpItems.len())
			this.m.LevelUpIndex = this.m.LevelUpItems.len() - 1;
		::UnseenBanner.TooltipNav.hide();
		this.announceLevelUp();
	},
	// The already-chosen attributes packed as "id:increase" pairs. It is what the
	// confirm entry reads out before applying anything, and what the outcome repeats
	// afterwards — by then the entity has changed and cannot be asked again.
	function levelUpPickedPack()
	{
		local packed = "";
		if (this.m.LevelUpItems == null) return packed;
		foreach( item in this.m.LevelUpItems )
		{
			if (item.kind != "attribute" || !this.m.LevelUpPicks[item.index]) continue;
			if (packed != "") packed += ",";
			packed += item.id + ":" + item.increase;
		}
		return packed;
	},
	function announceLevelUp(_opened = false)
	{
		local item = this.currentLevelUpItem();
		if (item == null) return;
		local position = (this.m.LevelUpIndex + 1) + "|" + this.m.LevelUpItems.len()
			+ "|" + (_opened ? "1" : "0");

		if (item.kind == "confirm")
		{
			::UnseenBanner.sendMessage("interrupt", this.m.LevelUpTargetName,
				"world.character.levelup.confirm", this.levelUpPickedPack(),
				this.levelUpPicked() + "|" + this.MaxStatsIncrease + "|" + position);
			return;
		}

		::UnseenBanner.sendMessage("interrupt", this.m.LevelUpTargetName,
			"world.character.levelup.attribute", item.id,
			item.facts + "|" + (this.m.LevelUpPicks[item.index] ? "1" : "0")
				+ "|" + position,
			null, "1");
	},
	// V keeps its ordinary meaning here rather than becoming a second cancel: each
	// attribute has exactly one native tooltip, and what it says is the whole reason
	// to prefer one increase over another.
	function showLevelUpDetail()
	{
		local item = this.currentLevelUpItem();
		if (item == null || item.tooltip == null)
		{
			::UnseenBanner.sendMessage("interrupt", "", "tooltip.unavailable");
			return;
		}
		::UnseenBanner.TooltipNav.show(item.tooltip, 1, 1, "world.character.levelup");
	},
	function activateLevelUp(_screen)
	{
		local item = this.currentLevelUpItem();
		if (item == null) return;
		if (item.kind == "confirm")
		{
			this.commitLevelUp(_screen);
			return;
		}

		local picked = this.m.LevelUpPicks[item.index];
		// The cap is the game's own (Constants.Game.MAX_STATS_INCREASE_COUNT): three
		// attributes per level, each raised once. Refusing has to name the way out,
		// because with three taken every further Enter would otherwise be silence.
		if (!picked && this.levelUpPicked() >= this.MaxStatsIncrease)
		{
			::UnseenBanner.sendMessage("interrupt", item.id,
				"world.character.levelup.full", "" + this.MaxStatsIncrease);
			return;
		}

		this.m.LevelUpPicks[item.index] = !picked;
		::UnseenBanner.TooltipNav.hide();
		::UnseenBanner.sendMessage("interrupt", item.id,
			"world.character.levelup.result." + (picked ? "undo" : "pick"),
			"" + this.levelUpPicked(), "" + this.MaxStatsIncrease);
	},
	// The screen's own endpoint, not entity.setAttributeLevelUpValues directly: it is
	// the funnel that resolves the entity and refuses one the player does not control,
	// exactly as the popup's OK button does. Nothing else decrements m.LevelUps.
	function commitLevelUp(_screen)
	{
		local bro = this.levelUpTarget();
		if (bro == null || _screen == null)
		{
			this.cancelLevelUp(false);
			::UnseenBanner.sendMessage("interrupt", "", "world.inventory.error", "0");
			return;
		}

		// setAttributeLevelUpValues decrements m.LevelUps whatever array it is handed,
		// so a partial set would burn the level and apply almost nothing. This is the
		// lock on it; the confirm entry itself already says how many are missing.
		if (this.levelUpPicked() < this.MaxStatsIncrease)
		{
			::UnseenBanner.sendMessage("interrupt", "",
				"world.character.levelup.confirm.blocked",
				"" + this.levelUpPicked(), "" + this.MaxStatsIncrease);
			return;
		}

		local values = [0, 0, 0, 0, 0, 0, 0, 0];
		foreach( item in this.m.LevelUpItems )
		{
			if (item.kind != "attribute" || !this.m.LevelUpPicks[item.index]) continue;
			values[item.index] = item.increase;
		}
		local applied = this.levelUpPickedPack();

		local saved = this.captureSectionPositions();
		local oldSection = this.m.SectionIndex;
		local result = _screen.onCommitStatsIncreaseValues([bro.getID(), values]);
		if (!this.mutationSucceeded(result))
		{
			// Nothing was spent, so the list stays open with the choices intact.
			::UnseenBanner.sendMessage("interrupt", "", "world.inventory.error",
				this.mutationErrorCode(result));
			return;
		}

		local left = bro.getLevelUps();
		this.resetLevelUp();
		_screen.loadData();
		this.buildWorldSections(saved);
		this.activateSection(oldSection, false, false);
		// A brother can be several levels behind, so the outcome ends with whether
		// there is another set waiting — the identity row will offer it again.
		::UnseenBanner.sendMessage("interrupt", applied,
			"world.character.levelup.confirmed", "" + left);
	},
	// --- Dismissing a brother (Delete on the identity row) ----------------------
	//
	// Vanilla puts this behind a small portrait button that opens a popup with an
	// OK/Cancel pair and a "pay compensation" checkbox — all mouse-only, so a blind
	// player could hire and equip a company but never let anyone go, and kept paying
	// wages for men they could not use. The button is shown only when the roster
	// holds more than one man, the screen is not the tactical one and the man is not
	// the player character (character_screen_left_panel_header_module.js, "update
	// dismiss button"). Those three rules are mirrored here rather than reinvented.
	function dismissBlockReason()
	{
		if (!this.m.WorldMode) return "tactical";
		local bro = this.current();
		if (bro == null) return "none";
		if (bro.getFlags().get("IsPlayerCharacter")) return "player";
		if (::World.getPlayerRoster().getSize() <= 1) return "last";
		return null;
	},
	function canDismiss()
	{
		return this.isIdentityRow() && this.dismissBlockReason() == null;
	},
	// What vanilla's checkbox offers: 10 crowns per day served, at least one day's
	// worth. Paying it skips every mood penalty and news entry the dismissal would
	// otherwise cause (character_screen.onDismissCharacter), which is exactly why it
	// is offered as its own option instead of being decided for the player.
	function dismissCost(_bro)
	{
		return 10 * ::Math.max(1, _bro.getDaysWithCompany());
	},
	function resetDismiss()
	{
		this.m.DismissMode = false;
		this.m.DismissItems = null;
		this.m.DismissIndex = 0;
		this.m.DismissTargetID = null;
		this.m.DismissTargetName = "";
		this.m.DismissFree = "0";
	},
	function openDismiss()
	{
		local reason = this.dismissBlockReason();
		local bro = this.current();
		if (reason != null || bro == null)
		{
			::UnseenBanner.sendMessage("interrupt", bro != null ? bro.getName() : "",
				"world.character.dismiss.blocked", reason != null ? reason : "none");
			return;
		}

		this.leaveActions(false);
		this.leaveDetails();
		::UnseenBanner.TooltipNav.hide();

		this.m.DismissTargetID = bro.getID();
		this.m.DismissTargetName = bro.getName();
		// Vanilla words it as freeing a man and paying reparations when he draws no
		// daily wage (the indebted of the Manhunters origin), and as dismissing and
		// compensating otherwise. Same distinction, same words.
		this.m.DismissFree = bro.getDailyCost() == 0 ? "1" : "0";
		this.m.DismissItems = [
			{ action = "cancel", cost = 0 },
			{ action = "plain", cost = 0 },
			{ action = "paid", cost = this.dismissCost(bro) }
		];
		// Cancel first, and focused: the same safe default the market uses before
		// selling something irreplaceable. A mistaken Enter here must cost nothing.
		this.m.DismissIndex = 0;
		this.m.DismissMode = true;
		this.announceDismiss(true);
	},
	function moveDismiss(_code)
	{
		if (!this.m.DismissMode || this.m.DismissItems == null) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.DismissIndex -= 1;
		else if (dir == "down") this.m.DismissIndex += 1;
		else if (dir == "home") this.m.DismissIndex = 0;
		else this.m.DismissIndex = this.m.DismissItems.len() - 1;

		if (this.m.DismissIndex < 0) this.m.DismissIndex = 0;
		if (this.m.DismissIndex >= this.m.DismissItems.len())
			this.m.DismissIndex = this.m.DismissItems.len() - 1;
		this.announceDismiss();
	},
	function announceDismiss(_opened = false)
	{
		if (!this.m.DismissMode || this.m.DismissItems == null) return;
		local it = this.m.DismissItems[this.m.DismissIndex];
		local detail = (this.m.DismissIndex + 1) + "|" + this.m.DismissItems.len()
			+ "|" + (_opened ? "1" : "0") + "|" + this.m.DismissFree
			+ "|" + ::World.Assets.getMoney();
		::UnseenBanner.sendMessage("interrupt", this.m.DismissTargetName,
			"world.character.dismiss.option." + it.action, "" + it.cost, detail);
	},
	function cancelDismiss(_announce)
	{
		if (!this.m.DismissMode) return;
		local name = this.m.DismissTargetName;
		this.resetDismiss();
		if (_announce)
		{
			::UnseenBanner.sendMessage("interrupt", name,
				"world.character.dismiss.cancelled");
		}
	},
	function executeDismiss(_screen)
	{
		if (!this.m.DismissMode || this.m.DismissItems == null || _screen == null) return;

		local it = this.m.DismissItems[this.m.DismissIndex];
		if (it.action == "cancel")
		{
			this.cancelDismiss(true);
			return;
		}

		local name = this.m.DismissTargetName;
		local id = this.m.DismissTargetID;
		local paid = it.action == "paid";
		local cost = it.cost;
		local before = ::World.getPlayerRoster().getSize();
		this.resetDismiss();

		// The screen's own endpoint — the one the popup's OK button calls. It moves
		// the man's equipment to the stash, charges the compensation, applies the
		// mood changes or the news entry, removes him from the roster and refreshes
		// both the visible screen and the topbar. Nothing is duplicated here.
		_screen.onDismissCharacter([id, paid]);

		// Judge success by the roster actually shrinking rather than by a return
		// value: the endpoint has none, and it silently does nothing if the ID no
		// longer resolves. Announcing a dismissal that did not happen would be
		// worse than the missing feature.
		local after = ::World.getPlayerRoster().getSize();
		if (after >= before)
		{
			::UnseenBanner.sendMessage("interrupt", name, "world.character.dismiss.failed");
			return;
		}

		this.reopenAfterDismiss();
		::UnseenBanner.sendMessage("interrupt", name,
			paid ? "world.character.dismiss.done.paid" : "world.character.dismiss.done",
			"" + cost, after + "|" + ::World.Assets.getMoney());
	},
	// The endpoint's loadData() reselects the FIRST brother in the visible screen:
	// no world brother carries the isSelected flag (data_helper.addFlagsToUIData
	// marks only the tactical active entity), so its JS falls back to the first
	// non-null entry. Land this cursor on that same man, or the spoken sheet and the
	// drawn one would describe two different people. Silent on purpose — the result
	// message that follows is what the player needs to hear.
	function reopenAfterDismiss()
	{
		local list = [];
		local raw = ::World.Assets.getFormation();
		if (raw != null)
		{
			foreach( b in raw )
			{
				if (b != null) list.push(b);
			}
		}
		this.m.Brothers = list;
		this.m.BroIndex = 0;
		this.m.DetailMode = false;
		this.m.DetailIndex = 0;
		this.resetFormationMove();
		this.buildWorldSections();
		this.activateSection(this.m.SectionIndex, false, false);
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
		// Hints that belong to the identity row travel with it, and only while they
		// are true: a pending level-up is where vanilla puts its star, next to the
		// name and the level, and Delete is where it puts the dismiss button.
		// Advertising a key that will refuse is worse than not advertising it at all.
		else if (category == "combat.sheet.identity")
		{
			detail = "";
			if (this.levelUpPending() > 0) detail = "levelup";
			if (this.canDismiss()) detail += (detail != "" ? "|" : "") + "dismiss";
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
		if ((this.m.WorldMode && this.isInventorySection()) || this.isTacticalBagRow()
			|| this.isIdentityRow())
			actionCount = this.buildActions(it).len();
		local context = null;
		local section = this.currentSection();
		if (this.m.WorldMode && section != null)
		{
			context = section.id + "|" + (this.m.ItemIndex + 1) + "|" + this.m.Items.len()
				+ "|" + (_includeSection ? "1" : "0");
		}
		// The talent star rides along only on the eight attribute rows; a formation
		// target has borrowed this row's category and must not carry it.
		local talent = ("talent" in it) && category == it.cat && it.talent != ""
			? it.talent
			: null;
		::UnseenBanner.sendMessage("interrupt", text, category, value, detail,
			name, "" + detailCount, context, "" + actionCount, null, null, talent);
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
	// The eight attributes a level-up can raise, in the order
	// general_onCommitStatsIncreaseValues unpacks the array it is handed — which is
	// also Const.Attributes order, so one index serves as the commit slot and as the
	// talent (star) lookup. The native dialog draws icons and has no names to read,
	// so the names live in L10n and only the id travels. Each row reuses the same
	// character-stats tooltip the sheet already reads for that attribute.
	function levelUpAttributes()
	{
		return [
			{ id = "hitpoints", value = "hitpoints", max = "hitpointsMax",
				increase = "hitpointsIncrease", tooltip = "character-stats.Hitpoints" },
			{ id = "bravery", value = "bravery", max = "braveryMax",
				increase = "braveryIncrease", tooltip = "character-stats.Bravery" },
			{ id = "fatigue", value = "fatigue", max = "fatigueMax",
				increase = "fatigueIncrease", tooltip = "character-stats.Fatigue" },
			{ id = "initiative", value = "initiative", max = "initiativeMax",
				increase = "initiativeIncrease", tooltip = "character-stats.Initiative" },
			{ id = "mskill", value = "meleeSkill", max = "meleeSkillMax",
				increase = "meleeSkillIncrease", tooltip = "character-stats.MeleeSkill" },
			{ id = "rskill", value = "rangeSkill", max = "rangeSkillMax",
				increase = "rangeSkillIncrease", tooltip = "character-stats.RangeSkill" },
			{ id = "mdef", value = "meleeDefense", max = "meleeDefenseMax",
				increase = "meleeDefenseIncrease", tooltip = "character-stats.MeleeDefense" },
			{ id = "rdef", value = "rangeDefense", max = "rangeDefenseMax",
				increase = "rangeDefenseIncrease", tooltip = "character-stats.RangeDefense" }
		];
	},
	function buildPerkRows()
	{
		local bro = this.current();
		local rows = [];
		if (bro == null || !::isKindOf(bro, "player")) return rows;
		local spent = bro.getPerkPointsSpent();
		local points = bro.getPerkPoints();
		// Unspent perk points lead the section: they decide whether walking the
		// tree is worth anything at all, and the native screen only shows them as
		// a number floating next to the trees, where nothing can reach it.
		rows.push(this.row("perk:summary", "world.character.perks.summary",
			"", "" + points, "" + spent, [], { source = "perk_summary" }));
		foreach( rowIndex, perkRow in ::Const.Perks.Perks )
		{
			foreach( perk in perkRow )
			{
				local state = "locked";
				if (bro.hasPerk(perk.ID)) state = "acquired";
				else if (spent >= perk.Unlocks) state = points > 0 ? "available" : "no_points";
				rows.push(this.row("perk:" + perk.ID, "world.character.perk",
					perk.Name, state, "" + (rowIndex + 1), [this.perkDetail(bro, perk)],
					{
						source = "perk",
						perkID = perk.ID,
						perkName = perk.Name,
						state = state
					}));
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

		// _talent is the star count vanilla draws next to the eight attributes that
		// grow on level up. Empty on every other row, which is what keeps the
		// companion silent instead of saying "no stars" on two thirds of the sheet.
		local function entry(_cat, _texto, _valor, _detalle, _details = null, _talent = "")
		{
			return {
				key = _cat,
				cat = _cat,
				texto = _texto,
				valor = _valor,
				detalle = _detalle,
				details = _details != null ? _details : [],
				talent = _talent
			};
		}

		// The stars are indexed by ::Const.Attributes, and only those eight rows have
		// one: data_helper hardwires the armour talents to 0 and gives action points
		// and morale none at all, so the sheet must not invent stars for them either.
		local talents = isPlayer ? bro.getTalents() : null;
		local function star(_attribute)
		{
			return talents != null ? "" + talents[_attribute] : "";
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
			"" + bro.getHitpointsMax(), [this.uiElementDetail(bro, "character-stats.Hitpoints")],
			star(::Const.Attributes.Hitpoints)));
		items.push(entry("combat.sheet.fatigue", "", "" + bro.getFatigue(),
			"" + bro.getFatigueMax(), [this.uiElementDetail(bro, "character-stats.Fatigue")],
			star(::Const.Attributes.Fatigue)));
		items.push(entry("combat.sheet.resolve", "", "" + p.getBravery(), "",
			[this.uiElementDetail(bro, "character-stats.Bravery")],
			star(::Const.Attributes.Bravery)));
		items.push(entry("combat.sheet.initiative", "", "" + p.getInitiative(), "",
			[this.uiElementDetail(bro, "character-stats.Initiative")],
			star(::Const.Attributes.Initiative)));
		items.push(entry("combat.sheet.mskill", "", "" + p.getMeleeSkill(), "",
			[this.uiElementDetail(bro, "character-stats.MeleeSkill")],
			star(::Const.Attributes.MeleeSkill)));
		items.push(entry("combat.sheet.rskill", "", "" + p.getRangedSkill(), "",
			[this.uiElementDetail(bro, "character-stats.RangeSkill")],
			star(::Const.Attributes.RangedSkill)));
		items.push(entry("combat.sheet.mdef", "", "" + p.getMeleeDefense(), "",
			[this.uiElementDetail(bro, "character-stats.MeleeDefense")],
			star(::Const.Attributes.MeleeDefense)));
		items.push(entry("combat.sheet.rdef", "", "" + p.getRangedDefense(), "",
			[this.uiElementDetail(bro, "character-stats.RangeDefense")],
			star(::Const.Attributes.RangedDefense)));

		// The four weapon-dependent rows vanilla shows straight after ranged defense,
		// in its own order. They are as visible to a sighted player as the skills
		// above — no hover involved — so they belong on the list, not behind V.
		//
		// The numbers are data_helper.addStatsToUIData's, arithmetic included: the
		// melee damage multiplier applies ONLY when a melee weapon is held (vanilla
		// never applies it to a bow), and the two percentages come off the properties
		// rather than from any weapon field, so perks and effects are already in them.
		local dm = bro.isArmedWithMeleeWeapon() ? p.MeleeDamageMult : 1.0;
		local dmgMin = ::Math.floor(p.getDamageRegularMin() * dm);
		local dmgMax = ::Math.floor(p.getDamageRegularMax() * dm);
		// Unarmed leaves DamageRegularMin/Max at 0, and vanilla duly paints "0 - 0".
		// Spoken, that reads like a broken readout, so say what it means instead.
		if (dmgMax <= 0)
		{
			items.push(entry("combat.sheet.damage.none", "", "", "",
				[this.uiElementDetail(bro, "character-stats.RegularDamage")]));
		}
		else
		{
			items.push(entry("combat.sheet.damage", "", "" + dmgMin, "" + dmgMax,
				[this.uiElementDetail(bro, "character-stats.RegularDamage")]));
		}
		items.push(entry("combat.sheet.armordamage", "",
			"" + ::Math.floor(p.getDamageArmorMult() * 100), "",
			[this.uiElementDetail(bro, "character-stats.CrushingDamage")]));
		// getHitchance returns a float by construction (it ends in "* 1.0"), and a
		// float reaches the reader as "25.000000". This is the head-hit chance, not
		// the chance to hit a target at all — that one depends on the target and is
		// reported by the skill readouts in battle.
		items.push(entry("combat.sheet.headhit", "",
			"" + p.getHitchance(::Const.BodyPart.Head).tointeger(), "",
			[this.uiElementDetail(bro, "character-stats.ChanceToHitHead")]));
		items.push(entry("combat.sheet.vision", "", "" + p.getVision(), "",
			[this.uiElementDetail(bro, "character-stats.SightDistance")]));

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
// Up/Down/Home/End reads one entry at a time and Enter activates the focused
// button — or, on a loot row, takes exactly that item into the stash so a player
// with limited stash space can pick loot piece by piece. V reads the focused
// item's full native tooltip (damage, durability, effects). The old L/R
// shortcuts remain available for loot-all and repeating the current row.
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
		[45] = "home",
		[44] = "end",
		[39] = "activate", // enter -> activate the focused button or loot the focused item
		[32] = "inspect",  // v -> read the focused loot item's native tooltip
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
	function item(_cat, _texto = "", _valor = "", _detalle = "", _action = null, _payload = null)
	{
		return {
			cat = _cat,
			texto = _texto,
			valor = _valor,
			detalle = _detalle,
			action = _action,
			payload = _payload
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
		if (what == "up" || what == "down" || what == "home" || what == "end") this.move(what);
		else if (what == "activate") this.activate(screen);
		else if (what == "inspect") this.inspect();
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
			// The heading carries the free-slot count: the stash limit is the whole
			// reason a player picks items one by one instead of pressing loot-all.
			local heading = lootCount == 1 ? "combat.result.loot.heading.one" : "combat.result.loot.heading";
			result.push(this.item(heading, "", "" + lootCount, "" + ::Stash.getNumberOfEmptySlots()));

			// One row per item with everything a take-or-leave decision needs:
			// name+amount, the game's own category text ("Sword, One-Handed Weapon"),
			// condition (only for items that degrade), value and list position.
			// Enter loots exactly this item; V reads its full native tooltip.
			local index = 0;
			foreach( item in items )
			{
				if (item == null) continue;
				index += 1;
				local amount = item.isAmountShown() ? "" + item.getAmountString() : "";
				local detail = index + "|" + lootCount
					+ "|" + (item.getConditionMax() > 1 ? item.getCondition() : "")
					+ "|" + (item.getConditionMax() > 1 ? item.getConditionMax() : "")
					+ "|" + item.getValue()
					+ "|" + amount;
				result.push(this.item("combat.result.loot.item", item.getName(),
					item.getCategories(), detail, "loot", { itemId = item.getInstanceID() }));
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
		else if (_direction == "down") this.m.ItemIndex += 1;
		else if (_direction == "home") this.m.ItemIndex = 0;
		else this.m.ItemIndex = this.m.Items.len() - 1;

		if (this.m.ItemIndex < 0) this.m.ItemIndex = 0;
		if (this.m.ItemIndex >= this.m.Items.len()) this.m.ItemIndex = this.m.Items.len() - 1;
		::UnseenBanner.TooltipNav.hide();
		this.announceItem();
	},
	function announceItem()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		::UnseenBanner.sendMessage("interrupt", it.texto, it.cat, it.valor, it.detalle,
			null, it.action == "loot" ? "1" : null);
	},
	function inspect()
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local it = this.m.Items[this.m.ItemIndex];
		if (it.action != "loot" || it.payload == null)
		{
			::UnseenBanner.TooltipNav.onTooltipUnavailable();
			return;
		}
		// Same owner id vanilla binds on this screen's slots, so the tooltip query
		// resolves through the exact hover path a sighted player gets.
		::UnseenBanner.TooltipNav.show({
			contentType = "ui-item",
			entityId = null,
			itemId = it.payload.itemId,
			itemOwner = "tactical-combat-result-screen.found-loot"
		}, 1, 1, "combat.result.loot.item");
	},
	function activate(_screen)
	{
		if (this.m.Items == null || this.m.Items.len() == 0) return;
		local action = this.m.Items[this.m.ItemIndex].action;
		if (action == "lootall") this.lootAll(_screen);
		else if (action == "loot") this.lootItem(_screen);
		else if (action == "continue") _screen.onLeaveButtonPressed();
		else this.announceItem();
	},
	// Take exactly the focused item, mirroring vanilla's right-click pickup path
	// (onSwapItem found-loot -> stash): Stash.add already fires onAddedToStash.
	// The loot container is resizable, so removal shifts indexes; the row is
	// resolved by instance id and the whole list rebuilt afterwards.
	function lootItem(_screen)
	{
		local it = this.m.Items[this.m.ItemIndex];
		// Defeat (and any other outcome the game marks as loot-less) shows the pile
		// but forbids taking from it; vanilla enforces this by hiding the button.
		if (!this.m.CanLoot)
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.result.loot.locked");
			return;
		}
		if (!::Stash.hasEmptySlot())
		{
			::UnseenBanner.sendMessage("interrupt", "", "combat.result.loot.stash_full");
			return;
		}

		local found = ::Tactical.CombatResultLoot.getItemByInstanceID(it.payload.itemId);
		if (found == null)
		{
			// Stale row (already taken through another path): resync and re-read.
			this.rebuildKeepingPosition(_screen);
			this.announceItem();
			return;
		}

		local removed = ::Tactical.CombatResultLoot.removeByIndex(found.index);
		if (removed == null) return;
		::Stash.add(removed);
		removed.playInventorySound(::Const.Items.InventoryEventType.PlacedInBag);
		this.rebuildKeepingPosition(_screen);
		::UnseenBanner.sendMessage("interrupt", removed.getName(), "combat.result.loot.taken.one",
			"" + ::Stash.getNumberOfEmptySlots());
	},
	function rebuildKeepingPosition(_screen)
	{
		local index = this.m.ItemIndex;
		_screen.loadItemLists();
		this.buildItems(_screen);
		this.m.ItemIndex = index >= this.m.Items.len() ? this.m.Items.len() - 1 : index;
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
			// A monologue has no No button and Escape confirms it, so it gets its own
			// header rather than being told to cancel with a key that does the opposite.
			items.push(this.item(this.m.IsMonologue
				? "combat.dialog.screen.mono" : "combat.dialog.screen",
				this.m.Text, this.m.Title));
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
// Contextual key help (F1). The mod owns some thirty keys spread over a dozen
// surfaces, and until now they lived only in the README — unreachable from inside
// the game, which is precisely where a player forgets one. F1 opens the keys that
// are live on the surface he is standing on, as a navigable list (Up/Down/Home/End,
// one key per row) rather than a single utterance: the "lists, not dumps" rule that
// every other multi-fact readout in this mod follows.
//
// The rows are pure L10n keys — Squirrel owns the order, the companion owns every
// spoken word — so a translation covers the help without touching the mod.
::UnseenBanner.KeyHelp <- {
	m = {
		Rows = null,
		RowIndex = 0,
		Active = false,
		Context = "",
		// Engine code of the key that closed the list on its press, so its own
		// release can be swallowed instead of leaking into vanilla — Escape's
		// release opens the pause menu, the same trap the tactical inspect list hit.
		PendingRelease = -1
	},
	ToggleKey = 71, // f1 (no vanilla binding in either state)
	CancelKey = 41, // escape
	MoveKeys = {
		[49] = "up",
		[51] = "down",
		[45] = "home",
		[44] = "end"
	},
	// Surface -> ordered row keys. A surface missing from here falls back to the
	// plain map or plain combat list, so a screen the mod has not described yet
	// still answers F1 with something true rather than with silence.
	Contexts = {
		["combat"] = ["cursor", "recenter", "enemies", "allies", "inspect",
			"inspectlist", "act", "status", "turnorder", "threats", "adjacent",
			"skills", "hotkeys", "sheet", "endround", "wait"],
		["combat.sheet"] = ["move", "details", "equip", "switch", "close"],
		["combat.inspect"] = ["move", "details", "close"],
		["combat.result"] = ["move", "activate", "details", "lootall", "repeat"],
		["world"] = ["move", "march", "brake", "enter", "places", "parties",
			"status", "explorer", "camp", "campdetails", "sheet", "obituary",
			"relations", "retinue", "menu"],
		["world.explorer"] = ["move", "recenter", "list", "travel", "leave"],
		["world.survey"] = ["move", "details", "activate", "pages", "close"],
		["world.status"] = ["move", "sections", "ambition", "contract", "close"],
		["world.sheet"] = ["sections", "move", "details", "actions", "switch", "close"],
		["world.town"] = ["move", "activate", "situations", "leave"],
		["world.market"] = ["pages", "move", "actions", "details", "compare", "back"],
		["world.recruit"] = ["move", "details", "actions", "back"],
		["world.tavern"] = ["move", "buy", "reread", "back"],
		["world.temple"] = ["move", "injuries", "pay", "back"],
		["world.craft"] = ["move", "details", "craft", "back"],
		["world.travel"] = ["move", "details", "sail", "back"],
		["world.training"] = ["move", "lessons", "pay", "details", "back"],
		["world.retinue"] = ["move", "activate", "back"],
		["world.list"] = ["move", "close"],
		["world.event"] = ["move", "activate", "hotkeys"],
		["world.encounter"] = ["move", "activate", "retreat"],
		["menu"] = ["move", "activate", "adjust", "back"],
		["dialog"] = ["move", "activate", "cancel"]
	},
	function isActive()
	{
		return this.m.Active;
	},
	function handles(_code)
	{
		if (_code == this.ToggleKey) return true;
		if (this.m.PendingRelease == _code) return true;
		if (!this.m.Active) return false;
		return (_code in this.MoveKeys) || _code == this.CancelKey;
	},
	function consumeReleaseSwallow(_code)
	{
		if (this.m.PendingRelease != _code) return false;
		this.m.PendingRelease = -1;
		return true;
	},
	function reset()
	{
		this.m.Rows = null;
		this.m.RowIndex = 0;
		this.m.Active = false;
		this.m.Context = "";
	},
	function open(_context)
	{
		local context = _context;
		if (!(context in this.Contexts))
		{
			// Fall back to the broadest list of the surface the player is on.
			context = context.find("world") == 0 ? "world" : "combat";
		}

		this.m.Context = context;
		this.m.Rows = this.Contexts[context];
		this.m.RowIndex = 0;
		this.m.Active = true;
		this.announceRow(true);
	},
	// _armRelease carries the key whose release must not reach vanilla, for the two
	// paths that close the list on a key PRESS (F1 again, Escape).
	function close(_announce = false, _armRelease = -1)
	{
		local was = this.m.Active;
		this.reset();
		if (_armRelease >= 0) this.m.PendingRelease = _armRelease;
		if (was && _announce) ::UnseenBanner.sendMessage("interrupt", "", "help.closed");
	},
	function move(_code)
	{
		if (this.m.Rows == null || this.m.Rows.len() == 0) return;
		local dir = this.MoveKeys[_code];
		if (dir == "up") this.m.RowIndex -= 1;
		else if (dir == "down") this.m.RowIndex += 1;
		else if (dir == "home") this.m.RowIndex = 0;
		else this.m.RowIndex = this.m.Rows.len() - 1;
		if (this.m.RowIndex < 0) this.m.RowIndex = 0;
		if (this.m.RowIndex >= this.m.Rows.len()) this.m.RowIndex = this.m.Rows.len() - 1;
		this.announceRow();
	},
	function onKey(_code, _context)
	{
		if (_code == this.ToggleKey)
		{
			if (this.m.Active) this.close(true, _code);
			else this.open(_context);
			return;
		}

		if (!this.m.Active) return;
		if (_code == this.CancelKey)
		{
			this.close(true, _code);
			return;
		}
		if (_code in this.MoveKeys) this.move(_code);
	},
	function announceRow(_opened = false)
	{
		if (this.m.Rows == null || this.m.Rows.len() == 0) return;
		local detail = this.m.Context + "|" + (this.m.RowIndex + 1)
			+ "|" + this.m.Rows.len() + "|" + (_opened ? "1" : "0");
		::UnseenBanner.sendMessage("interrupt", "", "help.row",
			this.m.Rows[this.m.RowIndex], detail);
	}
};

// Which key list F1 answers with, on each of the two states that route keyboard.
// Read in the same priority order the key dispatchers themselves use, so the help
// always describes the surface that would actually receive the next keystroke.
::UnseenBanner.tacticalHelpContext <- function(_state)
{
	if (_state.m.TacticalCombatResultScreen != null
		&& _state.m.TacticalCombatResultScreen.isVisible()) return "combat.result";
	if ((_state.m.TacticalDialogScreen != null && _state.m.TacticalDialogScreen.isVisible())
		|| ::UnseenBanner.DialogNav.isActive()) return "dialog";
	if (::UnseenBanner.MenuNav.isActive()) return "menu";
	if (_state.isInCharacterScreen()) return "combat.sheet";
	if (::UnseenBanner.TileCursor.isInspectMenuActive()) return "combat.inspect";
	return "combat";
}

::UnseenBanner.worldHelpContext <- function(_state)
{
	if (::UnseenBanner.EventNav.isActive()) return "world.event";
	if (::UnseenBanner.MenuNav.isActive()) return "menu";
	if (::UnseenBanner.DialogNav.isActive()) return "dialog";
	if (_state.isInCharacterScreen()) return "world.sheet";
	if (_state.m.CombatDialog != null && _state.m.CombatDialog.isVisible())
		return "world.encounter";
	if (_state.m.CampfireScreen != null && _state.m.CampfireScreen.isVisible())
		return "world.retinue";
	if ((_state.m.ObituaryScreen != null && _state.m.ObituaryScreen.isVisible())
		|| (_state.m.RelationsScreen != null && _state.m.RelationsScreen.isVisible()))
		return "world.list";
	if (_state.m.WorldTownScreen != null && _state.m.WorldTownScreen.isVisible())
	{
		local screen = _state.m.WorldTownScreen;
		if (::UnseenBanner.WorldShop.isCurrent(screen)) return "world.market";
		if (::UnseenBanner.WorldHire.isCurrent(screen)) return "world.recruit";
		if (::UnseenBanner.WorldTavern.isCurrent(screen)) return "world.tavern";
		if (::UnseenBanner.WorldTemple.isCurrent(screen)) return "world.temple";
		if (::UnseenBanner.WorldTaxidermist.isCurrent(screen)) return "world.craft";
		if (::UnseenBanner.WorldTravel.isCurrent(screen)) return "world.travel";
		if (::UnseenBanner.WorldTraining.isCurrent(screen)) return "world.training";
		return "world.town";
	}
	if (::UnseenBanner.WorldCursor.isActive()) return "world.explorer";
	if (::UnseenBanner.WorldSurvey.isActive()) return "world.survey";
	if (::UnseenBanner.WorldStatus.isActive()) return "world.status";
	return "world";
}

::UnseenBanner.KeyGate <- {
	m = {
		Last = {},
		// Codes acted on during their PRESS whose RELEASE must not act again. See
		// armSwallow below.
		Swallow = {}
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
	// A cursor that acts on the press changes the surface underneath the very key
	// that is still held down: Enter opens a building, Escape closes a sub-list,
	// Enter on a contract raises the event screen. The matching release then lands
	// on a DIFFERENT owner — a release-driven cursor, or vanilla's own handler —
	// and fires a second, unasked-for action from one physical tap (Escape's
	// release left the building; Enter's release picked the first event option).
	// So every press-driven branch arms the swallow, and the state hook consumes it
	// before any dispatch: one tap, one action, wherever the release lands.
	function armSwallow(_code)
	{
		this.m.Swallow[_code] <- true;
	},
	function consumeSwallow(_code)
	{
		if (!(_code in this.m.Swallow)) return false;
		delete this.m.Swallow[_code];
		this.release(_code);
		return true;
	},
	function reset()
	{
		this.m.Last = {};
		this.m.Swallow = {};
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

// Bare modifiers. The engine delivers them as ordinary key events of their own,
// so a Shift+key combination reaches a state's onKeyInput as four events, the
// last of them the Shift release — after the combination has already done its
// work. Anything that closes/resets on an unrecognized key must skip these, or a
// Shift-armed action tears down what it just opened (Shift+B's party explorer
// vanished on the Shift release, before Up/Down could reach it).
::UnseenBanner.ModifierKeys <- {
	[95] = true, // ctrl
	[96] = true, // shift
	[97] = true  // alt
};

// Keys that must never reach vanilla's tactical handler, whatever state the mod
// is in. End is the whole reason this table exists: vanilla binds it to "wait
// turn" (tactical_state, case 44, alongside Space), while every list the mod
// offers binds it to "jump to the last row". A sighted player sees which one is
// in front of him; a blind one does not, so a single stale cursor turned a
// navigation keystroke into a spent turn with no way back. Space is left alone
// and remains the way to wait a turn deliberately.
::UnseenBanner.TacticalBlockedKeys <- {
	[44] = true // end
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
		::UnseenBanner.GameFinishNav.connect();
		::UnseenBanner.TooltipNav.connect();
		::UnseenBanner.CharacterEdit.connect();
		::logInfo("UnseenBanner: root_state.onInit hook fired (class hooking alive).");
		onInit();
	}
});

// Module lifecycle is the deterministic point at which the animated DOM is
// ready. Hooking the common base avoids polling and keeps the announcement
// aligned with the screen the player can actually interact with.
// Daily upkeep (4.9). update() runs every frame, so the guard is three field reads and
// a return on all but one frame a day; only when vanilla's own payday branch is about to
// fire is anything measured. Measure before, announce after: the counts need the purse as
// it was, the warning needs it as it ends up.
::UnseenBanner.Mod.hook("scripts/states/world/asset_manager", function(q) {
	q.update = @(__original) function( _worldState )
	{
		local report = ::UnseenBanner.WorldUpkeep.isSettling(this)
			? ::UnseenBanner.WorldUpkeep.measure(this) : null;
		__original(_worldState);
		if (report != null) ::UnseenBanner.WorldUpkeep.announce(this, report);
	}
});

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
		// Contextual key help (F1). The main menu is the first surface a new player
		// meets, so it answers F1 too — with the menu key list, the same one the
		// in-game pause menu and Options get. Acts on the press, consumes both states.
		local helpCode = _key.getKey();
		if (::UnseenBanner.KeyHelp.handles(helpCode))
		{
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.KeyGate.shouldFire(helpCode, this.Time.getRealTimeF()))
				{
					::UnseenBanner.KeyHelp.onKey(helpCode, "menu");
				}
			}
			else
			{
				::UnseenBanner.KeyGate.release(helpCode);
				::UnseenBanner.KeyHelp.consumeReleaseSwallow(helpCode);
			}
			return true;
		}

		if (::UnseenBanner.KeyHelp.isActive() && !(helpCode in ::UnseenBanner.ModifierKeys))
		{
			::UnseenBanner.KeyHelp.close(false);
		}

		// A key already acted on during its press: eat its release before anything
		// else can read it as a fresh keystroke (Enter's release would otherwise
		// activate whatever the submenu it just opened has focused).
		if (_key.getState() == 0 && ::UnseenBanner.KeyGate.consumeSwallow(_key.getKey()))
		{
			return true;
		}

		// Only steal keys while a menu handled by menu_nav.js is fully shown.
		// All other submenus keep their native keyboard behavior.
		//
		// Move on the PRESS: waiting for the release means the screen reader only
		// starts speaking once the player lifts the key, which reads as lag on every
		// single move. KeyGate debounces the ~40 ms auto-repeat that comes with the
		// press, and both states are consumed so vanilla never sees half a keystroke.
		// Enter is the exception (see MenuNav.isReleaseHandledKey): it opens text
		// fields, so it has to wait for the press to be over.
		if (::UnseenBanner.MenuNav.handlesKey(_key.getKey())
			&& ::UnseenBanner.MenuNav.isActive()
			&& this.isKeyInputPermitted())
		{
			local code = _key.getKey();
			local onRelease = ::UnseenBanner.MenuNav.isReleaseHandledKey(code);
			if (_key.getState() == 1 && !onRelease)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(code));
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(code);
				if (onRelease)
				{
					::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(code));
				}
			}
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

// Same contract as the event screen: onScreenShown is fired by the JS side once
// the fade-in completes, which is after loadFromData has put the ending text and
// the score in the DOM, so reading it there is safe.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/world_game_finish_screen", function(q) {
	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.GameFinishNav.onScreenShown();
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.GameFinishNav.onScreenHidden();
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
		::UnseenBanner.WorldTavern.close();
		::UnseenBanner.WorldTemple.close();
		::UnseenBanner.WorldTaxidermist.close();
		::UnseenBanner.WorldTravel.close();
		::UnseenBanner.WorldTraining.close();
		::UnseenBanner.WorldTown.open(this.getTown());
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldShop.close();
		::UnseenBanner.WorldHire.close();
		::UnseenBanner.WorldTavern.close();
		::UnseenBanner.WorldTemple.close();
		::UnseenBanner.WorldTaxidermist.close();
		::UnseenBanner.WorldTravel.close();
		::UnseenBanner.WorldTraining.close();
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

	// tavern_building.onClicked hands the building to the module immediately before
	// calling this, so the module's Tavern is already set by the time we open.
	q.showTavernDialog = @(__original) function()
	{
		__original();
		if (this.isVisible() && this.m.TavernDialogModule != null)
		{
			::UnseenBanner.WorldTavern.open(this, this.m.TavernDialogModule);
		}
	}

	q.showTempleDialog = @(__original) function()
	{
		__original();
		if (this.isVisible() && this.m.TempleDialogModule != null)
		{
			::UnseenBanner.WorldTemple.open(this, this.m.TempleDialogModule);
		}
	}

	// The crafting building of the Beasts & Exploration DLC. Its module is set as
	// LastActiveModule right before this call, so the accessible cursor opens once
	// vanilla has installed it, exactly like the tavern and the temple.
	q.showTaxidermistDialog = @(__original) function()
	{
		__original();
		if (this.isVisible() && this.m.TaxidermistDialogModule != null)
		{
			::UnseenBanner.WorldTaxidermist.open(this, this.m.TaxidermistDialogModule);
		}
	}

	// The harbour's destination list. port_building.onClicked has already called
	// setData with the roster it built, so queryTravelInformation is populated by the
	// time we open — same ordering guarantee the tavern relies on.
	q.showTravelDialog = @(__original) function()
	{
		__original();
		if (this.isVisible() && this.m.TravelDialogModule != null)
		{
			::UnseenBanner.WorldTravel.open(this, this.m.TravelDialogModule);
		}
	}

	q.showTrainingDialog = @(__original) function()
	{
		__original();
		if (this.isVisible() && this.m.TrainingDialogModule != null)
		{
			::UnseenBanner.WorldTraining.open(this, this.m.TrainingDialogModule);
		}
	}

	q.showMainDialog = @(__original) function()
	{
		local leavingShop = ::UnseenBanner.WorldShop.isCurrent(this);
		local leavingHire = ::UnseenBanner.WorldHire.isCurrent(this);
		local leavingTavern = ::UnseenBanner.WorldTavern.isCurrent(this);
		local leavingTemple = ::UnseenBanner.WorldTemple.isCurrent(this);
		local leavingCraft = ::UnseenBanner.WorldTaxidermist.isCurrent(this);
		local leavingTravel = ::UnseenBanner.WorldTravel.isCurrent(this);
		local leavingTraining = ::UnseenBanner.WorldTraining.isCurrent(this);
		__original();
		if (leavingShop) ::UnseenBanner.WorldShop.close();
		if (leavingHire) ::UnseenBanner.WorldHire.close();
		if (leavingTavern) ::UnseenBanner.WorldTavern.close();
		if (leavingTemple) ::UnseenBanner.WorldTemple.close();
		if (leavingCraft) ::UnseenBanner.WorldTaxidermist.close();
		if (leavingTravel) ::UnseenBanner.WorldTravel.close();
		if (leavingTraining) ::UnseenBanner.WorldTraining.close();
		if (leavingShop || leavingHire || leavingTavern || leavingTemple || leavingCraft
			|| leavingTravel || leavingTraining)
		{
			// Not after a successful sailing: fastTravelTo routes through this same
			// funnel while the screen still points at the harbour town, and WorldTravel
			// rebuilds the list against the destination and speaks the arrival itself.
			// Consume unconditionally, so a one-shot armed for a sailing that then took
			// another path cannot sit there and swallow a later, legitimate re-read.
			local suppressed = ::UnseenBanner.WorldTown.consumeSuppressedAnnounce();
			if (::UnseenBanner.WorldTown.isActive() && !suppressed)
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
		else if (::UnseenBanner.WorldStatus.isDialogPending())
		{
			::UnseenBanner.DialogNav.prime(_title, _text, _isMonologue,
				::UnseenBanner.WorldStatus.getDialogContext());
		}
		else
		{
			// Everything else this modal is used for. It used to be the silent case, and
			// silence here is the worst kind: the dialog pauses the map, takes the
			// keyboard and waits, so a popup nobody announced reads as a frozen game. The
			// one that arrives unasked is "Old Campaign Loaded", raised on loading a save
			// made before a DLC was switched on (world_state), but the branch also catches
			// anything a future DLC or another mod puts through the same screen.
			//
			// Nothing is context-specific below the wording: DialogNav already builds its
			// rows from the live title, body and monologue flag and acts through
			// DialogScreen's own onOkPressed/onCancelPressed, so a generic context is
			// navigable with no further work.
			::UnseenBanner.DialogNav.prime(_title, _text, _isMonologue, "world.dialog");
		}
	}

	q.onScreenShown = @(__original) function()
	{
		__original();
		::UnseenBanner.DialogNav.open();
	}

	q.onScreenHidden = @(__original) function()
	{
		__original();
		local wasRetinue = ::UnseenBanner.DialogNav.isContext("world.retinue");
		local wasStatus = ::UnseenBanner.DialogNav.isContext("world.ambition")
			|| ::UnseenBanner.DialogNav.isContext("world.contract");
		::UnseenBanner.DialogNav.close();
		if (wasRetinue)
		{
			::UnseenBanner.WorldRetinue.onDialogClosed();
		}
		if (wasStatus)
		{
			::UnseenBanner.WorldStatus.onDialogClosed();
		}
	}
});

// The native contract panel owns cancellation and all its consequences. Announce
// success only after that callback has actually removed the active contract; this
// also covers a mouse activation without duplicating any contract logic in the mod.
::UnseenBanner.Mod.hook("scripts/ui/screens/world/modules/world_contract_screen/world_active_contract_panel_module", function(q) {
	q.onContractCancelled = @(__original) function()
	{
		local contract = ::World.Contracts.getActiveContract();
		local title = "";
		if (contract != null)
		{
			try { title = contract.getTitle(); }
			catch (error) { title = contract.getName(); }
		}
		__original();
		::UnseenBanner.sendMessage("queue", title,
			title == "" ? "world.status.contract.cancelled" : "world.status.contract.cancelled.named");
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
		::UnseenBanner.WorldClock.reset();
		::UnseenBanner.ContractObjectives.reset();
		::UnseenBanner.WorldSurvey.reset();
		::UnseenBanner.WorldDiscovery.reset();
		::UnseenBanner.WorldCamp.reset();
		::UnseenBanner.WorldMove.reset();
		::UnseenBanner.WorldCursor.reset();
		::UnseenBanner.WorldTown.reset();
		::UnseenBanner.WorldTavern.close();
		::UnseenBanner.WorldTemple.close();
		::UnseenBanner.WorldObituary.close();
		::UnseenBanner.WorldRelations.close();
		::UnseenBanner.WorldRetinue.reset();
		::UnseenBanner.WorldCombatDialogNav.reset();
		::UnseenBanner.GameFinishNav.reset();
		::UnseenBanner.SheetNav.reset();
		__original();
	}

	q.loading_screen_onScreenShown = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.WorldStatus.reset();
		::UnseenBanner.WorldClock.reset();
		::UnseenBanner.ContractObjectives.reset();
		::UnseenBanner.WorldSurvey.reset();
		::UnseenBanner.WorldDiscovery.reset();
		::UnseenBanner.WorldCamp.reset();
		::UnseenBanner.WorldMove.reset();
		::UnseenBanner.WorldCursor.reset();
		::UnseenBanner.WorldTown.reset();
		::UnseenBanner.WorldTavern.close();
		::UnseenBanner.WorldTemple.close();
		::UnseenBanner.WorldObituary.close();
		::UnseenBanner.WorldRelations.close();
		::UnseenBanner.WorldRetinue.reset();
		::UnseenBanner.WorldCombatDialogNav.reset();
		::UnseenBanner.GameFinishNav.reset();
		::UnseenBanner.SheetNav.reset();
		__original();
	}

	q.onFinish = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.WorldStatus.reset();
		::UnseenBanner.WorldClock.reset();
		::UnseenBanner.ContractObjectives.reset();
		::UnseenBanner.WorldSurvey.reset();
		::UnseenBanner.WorldDiscovery.reset();
		::UnseenBanner.WorldCamp.reset();
		::UnseenBanner.WorldMove.reset();
		::UnseenBanner.WorldCursor.reset();
		::UnseenBanner.WorldTown.reset();
		::UnseenBanner.WorldTavern.close();
		::UnseenBanner.WorldTemple.close();
		::UnseenBanner.WorldObituary.close();
		::UnseenBanner.WorldRelations.close();
		::UnseenBanner.WorldRetinue.reset();
		::UnseenBanner.WorldCombatDialogNav.reset();
		::UnseenBanner.GameFinishNav.reset();
		::UnseenBanner.SheetNav.reset();
		__original();
	}

	// Arrival at a location. Entering opens the town screen, an event or the encounter
	// dialog, and each of those announces itself on arrival — but when none of them
	// opens, vanilla merely marks the place visited and leaves the map exactly as it
	// was. A sighted player sees the party stop; for a blind one that silence is
	// indistinguishable from a travel order that never finished, which is what made
	// walking to a non-interactable location feel like nothing had happened at all.
	//
	// All three of those screens push a MenuStack backstep synchronously from inside
	// enterLocation, so an empty stack once it returns is the reliable "nothing opened"
	// test — no polling and no guessing at which screen was due. Only a successful entry
	// is announced: a refused one returns false with AutoEnterLocation still armed, so
	// world_state.onUpdate retries it every frame and the cue would repeat endlessly.
	q.enterLocation = @(__original) function( _location )
	{
		local entered = __original(_location);
		if (entered && _location != null && !this.m.MenuStack.hasBacksteps())
		{
			::UnseenBanner.sendMessage("interrupt", _location.getName(),
				"world.interact.arrived.empty");
		}
		return entered;
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
	// common idle case costs one boolean check. The destination is sampled around the
	// original rather than inside tick, because entering a location is exactly what the
	// original does with it — see observeDestination.
	q.onUpdate = @(__original) function()
	{
		::UnseenBanner.WorldMove.observeDestination(this);
		__original();
		::UnseenBanner.WorldMove.tick();
		::UnseenBanner.WorldDiscovery.tick(this.Time.getRealTimeF());
	}

	// Both T and the clickable topbar button reach this funnel; native movement
	// also uses it to leave camp. Compare around the original so only a real
	// transition is announced, never a rejected or redundant request.
	q.onCamp = @(__original) function()
	{
		local wasCamping = this.World.Assets.isCamping();
		__original();
		local isCamping = this.World.Assets.isCamping();
		if (isCamping != wasCamping)
			::UnseenBanner.WorldCamp.announceChanged(isCamping);
	}

	// The single call that refreshes the visible clock, reached from onUpdate on every
	// frame the map is live. WorldClock returns immediately unless the hour or the day
	// actually moved, so the cost here is two comparisons per frame.
	q.updateDayTime = @(__original) function()
	{
		__original();
		::UnseenBanner.WorldClock.update();
	}

	// Game speed. Hooking the 1/2/3 keys was tried first and never fired: MSU
	// re-registers vanilla's speed keys in its own keybind system
	// (vanilla_keybinds.nut, world_speedNormal/Fast/VeryFast), and its outer
	// onKeyInput wrapper returns without calling the wrapped chain once its dispatch
	// handles a key — an inner hook simply never sees them. The lesson that already
	// held for setPause holds here: hook the action, not the key. Every route
	// converges on these three setters — vanilla's own key cases, the topbar's
	// clickable buttons and MSU's re-dispatch — and the game itself also calls
	// setNormalTime when an event fires or a location is entered, a real, otherwise
	// silent speed change a sighted player sees on the button highlight. Those two
	// automatic calls land right before an event or town announcement, so on the
	// interrupt channel the readout that follows overwrites them in a beat.
	q.setNormalTime = @(__original) function( _force = false )
	{
		__original(_force);
		::UnseenBanner.WorldStatus.announceSpeed(this);
	}

	q.setFastTime = @(__original) function( _force = false )
	{
		__original(_force);
		::UnseenBanner.WorldStatus.announceSpeed(this);
	}

	q.setVeryFastTime = @(__original) function( _force = false )
	{
		__original(_force);
		::UnseenBanner.WorldStatus.announceSpeed(this);
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

	// The one place that knows whether the campaign was won or lost. It is called
	// from onUpdate (last brother down), from the ironman quit-to-menu path and
	// from retirement; capture the outcome before the original shows the screen,
	// so it is already there when onScreenShown fires.
	q.showGameFinishScreen = @(__original) function( _gameWon )
	{
		::UnseenBanner.GameFinishNav.setOutcome(_gameWon);
		__original(_gameWon);
	}

	q.onKeyInput = @(__original) function( _key )
	{
		// A key already acted on during its press: eat its release before any cursor
		// or vanilla handler below can read it as a fresh keystroke. This runs first
		// because the press that armed it usually changed the surface, so the release
		// lands on a different owner than the one that handled the press — it is what
		// keeps a press-driven Enter from also picking the first option of the event
		// screen it just opened, and a press-driven Escape from closing a sub-list and
		// then leaving the building underneath it.
		if (_key.getState() == 0 && ::UnseenBanner.KeyGate.consumeSwallow(_key.getKey()))
		{
			return true;
		}

		// The end-of-campaign screen is terminal and fully modal: it pushes a
		// MenuStack entry that refuses to be popped, so Escape does nothing and Quit
		// is the only action left. Handle its cursor first and let every other key
		// fall straight through to vanilla, skipping all the map readouts below —
		// none of them should speak over a campaign that is already over, and the
		// map they describe is hidden anyway.
		if (::UnseenBanner.GameFinishNav.isActive())
		{
			::UnseenBanner.WorldStatus.reset();
			::UnseenBanner.WorldSurvey.reset();

			if (_key.getState() == 0 && _key.getKey() in ::UnseenBanner.KeyCodes)
			{
				::UnseenBanner.GameFinishNav.sendKey(::UnseenBanner.KeyCodes[_key.getKey()]);
				return true;
			}

			return __original(_key);
		}

		// Contextual key help (F1), before every other cursor for the same reason as
		// in combat: it has to be reachable from any map surface, and while it is open
		// its rows own Up/Down. The map's own readouts stay untouched underneath.
		if (::UnseenBanner.KeyHelp.handles(_key.getKey()))
		{
			local helpCode = _key.getKey();
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.KeyGate.shouldFire(helpCode, this.Time.getRealTimeF()))
				{
					::UnseenBanner.KeyHelp.onKey(helpCode,
						::UnseenBanner.worldHelpContext(this));
				}
			}
			else
			{
				::UnseenBanner.KeyGate.release(helpCode);
				::UnseenBanner.KeyHelp.consumeReleaseSwallow(helpCode);
			}
			return true;
		}

		if (::UnseenBanner.KeyHelp.isActive()
			&& !(_key.getKey() in ::UnseenBanner.ModifierKeys))
		{
			::UnseenBanner.KeyHelp.close(false);
		}

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
		// as the main menu, and on the same press cadence. They are shown inside
		// world_state, so keys are stolen here while one is fully up; Escape (41) is
		// left to the native handler, which pops the menu stack (submenu -> pause menu
		// -> resume). The event screen and a menu are never up at once.
		if (::UnseenBanner.MenuNav.handlesKey(_key.getKey())
			&& !::UnseenBanner.EventNav.isActive()
			&& ::UnseenBanner.MenuNav.isActive())
		{
			local menuCode = _key.getKey();
			local menuOnRelease = ::UnseenBanner.MenuNav.isReleaseHandledKey(menuCode);
			if (_key.getState() == 1 && !menuOnRelease)
			{
				if (::UnseenBanner.KeyGate.shouldFire(menuCode, this.Time.getRealTimeF()))
				{
					::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(menuCode));
				}
				::UnseenBanner.KeyGate.armSwallow(menuCode);
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(menuCode);
				if (menuOnRelease)
				{
					::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(menuCode));
				}
			}
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
			&& ::UnseenBanner.SheetNav.handles(code))
		{
			// isAnimating() must only gate the ACTION, not this whole block: while
			// the show/hide transition plays, Home/End/etc. still have to be
			// swallowed here, or they fall through to __original and, mid-combat,
			// End is vanilla's own "wait turn" binding — pressing it to jump the
			// sheet's list to its last row passed the active brother's turn instead.
			if (!this.m.CharacterScreen.isAnimating())
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

		// World confirmations we raised ourselves: the Retinue's cart/hire popups and
		// the "abandon this ambition" one that Enter opens from the F2 list. The
		// campfire screen is temporarily hidden while dialog_screen is visible, so
		// this must run before checking the P screen itself or the plain-map guards.
		// Use the same keydown cadence as the lists that open them; P and Escape both
		// cancel here.
		// Any context, not just the two that open one on purpose: while this modal is up
		// it owns the screen, the map underneath is paused and nothing else should be
		// reading these keys. Dropping the context test also means a dialog raised by a
		// DLC or another mod is navigable without naming it here — the same reason the
		// tactical side has always routed it by isActive() alone.
		if (::UnseenBanner.DialogNav.isActive()
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

		// The settlement screen and every building dialog inside it act on the PRESS.
		// Waiting for the release put the whole town under a "press, lift, then hear
		// it" cadence, which is dead time on every row of a long building or item
		// list. KeyGate debounces the auto-repeat that comes with the press, both
		// states are still consumed so vanilla never sees half a keystroke, and the
		// press arms the release swallow because these keys change the surface under
		// themselves (Enter opens a building, Escape closes a sub-list).
		local townPressed = _key.getState() == 1;
		local townFree = this.m.WorldTownScreen.isVisible()
			&& !::UnseenBanner.EventNav.isActive();

		// Recruitment (phase 4.5): like the shop, the town frame remains technically
		// visible behind this module. Candidate navigation and its action/detail
		// sub-lists therefore take priority over the town list. At candidate level
		// Escape remains native and returns through MenuStack.
		if (townFree
			&& ::UnseenBanner.WorldHire.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldHire.handles(code))
		{
			if (townPressed && !this.m.WorldTownScreen.isAnimating())
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldHire.onKey(code);
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (!townPressed)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Market (phase 2.3b): the town screen remains technically visible behind its
		// shop module, so give the market cursor priority over the town list. Escape is
		// captured only inside an action/confirmation sub-list. At the normal item level
		// it falls through to MenuStack and returns to the town frame.
		if (townFree
			&& ::UnseenBanner.WorldShop.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldShop.handles(code))
		{
			if (townPressed && !this.m.WorldTownScreen.isAnimating())
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldShop.onKey(code);
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (!townPressed)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Tavern: two paid actions and their results, same priority rule as the shop
		// and the recruit list. Escape is never captured here — at action level it
		// belongs to the native menu stack, which walks back to the town frame.
		if (townFree
			&& ::UnseenBanner.WorldTavern.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldTavern.handles(code))
		{
			if (townPressed && !this.m.WorldTownScreen.isAnimating())
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldTavern.onKey(code);
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (!townPressed)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Temple: wounded brothers and their treatable injuries. Escape is captured
		// only inside the injury sub-list; at patient level it falls through and
		// leaves the temple natively.
		if (townFree
			&& ::UnseenBanner.WorldTemple.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldTemple.handles(code))
		{
			if (townPressed && !this.m.WorldTownScreen.isAnimating())
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldTemple.onKey(code);
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (!townPressed)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Harbour: destination list, its V description sub-list and the sail
		// confirmation. Same priority rule as the other building dialogs.
		if (townFree
			&& ::UnseenBanner.WorldTravel.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldTravel.handles(code))
		{
			if (townPressed && !this.m.WorldTownScreen.isAnimating())
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldTravel.onKey(code);
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (!townPressed)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Training hall: the company roster and each man's three paid lessons. Escape
		// is captured only inside the lesson sub-list; at roster level it leaves the
		// building natively.
		if (townFree
			&& ::UnseenBanner.WorldTraining.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldTraining.handles(code))
		{
			if (townPressed && !this.m.WorldTownScreen.isAnimating())
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldTraining.onKey(code);
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (!townPressed)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Taxidermist: blueprint list, its V detail sub-list and its craft action.
		// Same priority rule as the other building dialogs — the town frame stays
		// technically visible behind the module. Escape is captured only inside a
		// sub-list; at blueprint level it leaves the building natively.
		if (townFree
			&& ::UnseenBanner.WorldTaxidermist.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldTaxidermist.handles(code))
		{
			if (townPressed && !this.m.WorldTownScreen.isAnimating())
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldTaxidermist.onKey(code);
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (!townPressed)
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Town screen (phase 4.5): while the settlement screen is up (and no event is
		// layered over it), our list drives it — Up/Down/Home/End walk buildings and
		// contracts, Enter activates. Escape is left alone so the native menu-stack pop
		// still leaves the town.
		if (townFree
			&& !::UnseenBanner.WorldShop.isCurrent(this.m.WorldTownScreen)
			&& !::UnseenBanner.WorldHire.isCurrent(this.m.WorldTownScreen)
			&& !::UnseenBanner.WorldTavern.isCurrent(this.m.WorldTownScreen)
			&& !::UnseenBanner.WorldTemple.isCurrent(this.m.WorldTownScreen)
			&& !::UnseenBanner.WorldTaxidermist.isCurrent(this.m.WorldTownScreen)
			&& !::UnseenBanner.WorldTravel.isCurrent(this.m.WorldTownScreen)
			&& !::UnseenBanner.WorldTraining.isCurrent(this.m.WorldTownScreen)
			&& ::UnseenBanner.WorldTown.isActive()
			&& ::UnseenBanner.WorldTown.handles(code))
		{
			if (townPressed)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldTown.onKey(code, this);
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else
			{
				::UnseenBanner.KeyGate.release(code);
			}
			return true;
		}

		// Map readouts, only on the plain map: G toggles company status; B opens
		// settlements/locations and Shift+B opens visible parties. Up/Down move through
		// the open list. The readouts are mutually exclusive, so navigation always has a
		// single owner. "Map free" also requires character, town and Retinue screens to
		// be down, so these keys never fire inside modal surfaces.
		local mapFree = !::UnseenBanner.EventNav.isActive() && !::UnseenBanner.MenuNav.isActive()
			&& !::UnseenBanner.WorldCombatDialogNav.isActive()
			&& !::UnseenBanner.DialogNav.isActive()
			&& !this.isInCharacterScreen()
			&& !this.m.WorldTownScreen.isVisible()
			&& (this.m.CampfireScreen == null || !this.m.CampfireScreen.isVisible());

		// T keeps its native make/break-camp behavior. Shift+T is a read-only
		// explanation; consume both states so vanilla never sees its release.
		// Vanilla filters a disallowed T before onCamp(), so report that rejected
		// keyboard request here instead of relying on the state-change hook.
		if (mapFree && ::UnseenBanner.WorldCamp.handles(code))
		{
			local shift = (_key.getModifier() & 1) != 0;
			if (_key.getState() == 1 && shift)
			{
				::UnseenBanner.WorldStatus.reset();
				::UnseenBanner.WorldSurvey.reset();
				::UnseenBanner.WorldCamp.onDetailsPress(this);
				return true;
			}
			else if (_key.getState() == 0
				&& ::UnseenBanner.WorldCamp.consumeDetailsRelease())
			{
				return true;
			}
			else if (_key.getState() == 0 && shift)
			{
				::UnseenBanner.WorldStatus.reset();
				::UnseenBanner.WorldSurvey.reset();
				::UnseenBanner.WorldCamp.announceDetails(this);
				return true;
			}
			else if (_key.getState() == 0 && !this.isCampingAllowed())
			{
				::UnseenBanner.WorldStatus.reset();
				::UnseenBanner.WorldSurvey.reset();
				::UnseenBanner.WorldCamp.announceUnavailable();
				return true;
			}
		}

		// Map explorer (phase 4.6). M toggles the mode; while it is on the cursor owns
		// Q/W/E/A/S/D, X and G, and while its tile list is up it owns Up/Down/Home/End and
		// Enter. Every one of those keys is acted on at PRESS and consumed in both states:
		// three of them carry a native binding on this screen (the letters pan the camera on
		// press, X toggles the camera lock on release, Enter recentres it), and G is our own
		// send-company-to-cursor action, so letting either state through would fire two
		// actions at once. G no longer collides with the company readout (moved to F2).
		// Only the keys the cursor SHARES with the other two readouts (V and the list keys)
		// yield while one of those windows is open, so Up/Down and V never have two owners.
		// The mode's own keys never yield: M has to be able to leave the mode from anywhere,
		// and if the letter cluster deferred to an open survey it would silently walk the
		// company instead of the cursor — the exact opposite of what turning the mode on
		// announces. Those keys close the other windows on their way through, the same
		// mutual exclusion the two readouts already apply to each other.
		local cursorShared = code == ::UnseenBanner.WorldCursor.InspectKey
			|| code == ::UnseenBanner.WorldCursor.InteractKey
			|| (code in ::UnseenBanner.WorldCursor.MoveKeys);
		if (mapFree && ::UnseenBanner.WorldCursor.handles(code)
			&& (!cursorShared
				|| (!::UnseenBanner.WorldSurvey.isActive()
					&& !::UnseenBanner.WorldStatus.isActive())))
		{
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.WorldCursor.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldStatus.reset();
					::UnseenBanner.WorldSurvey.reset();
					::UnseenBanner.WorldCursor.onKey(code,
						(_key.getModifier() & 1) != 0, this);
				}
			}
			else
			{
				::UnseenBanner.WorldCursor.release(code);
			}
			return true;
		}

		if (mapFree && ::UnseenBanner.WorldStatus.handles(code))
		{
			if (_key.getState() == 0)
			{
				::UnseenBanner.WorldSurvey.reset();
				::UnseenBanner.WorldCursor.closeList();
				::UnseenBanner.WorldStatus.onKey(code);
			}

			return true;
		}

		// Remember Shift on B press, then toggle the requested explorer on release.
		// This survives the common release order B-after-Shift without opening the
		// wrong window. Both states are consumed so vanilla never sees half a B press.
		if (code == ::UnseenBanner.WorldSurvey.ToggleKey
			&& (mapFree || ::UnseenBanner.WorldSurvey.isToggleHeld()))
		{
			if (_key.getState() == 1 && mapFree)
			{
				::UnseenBanner.WorldSurvey.captureToggle(
					(_key.getModifier() & 1) != 0);
			}
			else if (_key.getState() == 0)
			{
				local parties = ::UnseenBanner.WorldSurvey.consumeToggleRelease();
				if (parties != null && mapFree)
				{
					::UnseenBanner.WorldStatus.reset();
					::UnseenBanner.WorldCursor.closeList();
					::UnseenBanner.WorldSurvey.toggle(parties);
				}
			}
			return true;
		}

		if (mapFree && ::UnseenBanner.WorldSurvey.handles(code))
		{
			local onPress = ::UnseenBanner.WorldSurvey.handlesOnPress(code);
			if (_key.getState() == 1 && onPress)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.WorldStatus.reset();
					::UnseenBanner.WorldSurvey.onKey(code, this);
				}
			}
			else if (_key.getState() == 0)
			{
				if (onPress)
				{
					::UnseenBanner.KeyGate.release(code);
				}
				else
				{
					// V and Enter remain release-driven: both can change modal/action
					// state, so their press must never immediately leak into that state.
					::UnseenBanner.WorldStatus.reset();
					::UnseenBanner.WorldSurvey.onKey(code, this);
				}
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
				// Only reachable with the explorer off (its cursor owns these keys while it
				// is on), and then the open tile list describes a tile the company is about
				// to leave behind.
				::UnseenBanner.WorldCursor.closeList();
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

		// Any other key closes an open readout — the player moved on to something
		// else. A bare modifier is not "something else": it is half of the very
		// combination that opened the list (Shift+B), and its release lands after the
		// list is up, so acting on it would close the explorer the player just asked
		// for and leave Up/Down with no owner.
		if (!(code in ::UnseenBanner.ModifierKeys))
		{
			if (::UnseenBanner.WorldStatus.isActive()) ::UnseenBanner.WorldStatus.reset();
			if (::UnseenBanner.WorldSurvey.isActive()) ::UnseenBanner.WorldSurvey.reset();
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
		// Belt and braces: MSU restores persisted settings when its UI connects,
		// after our queue-time rebind, and a user reset of MSU settings would
		// also bring "end/space" back. Re-asserting at every battle start is a
		// cheap no-op when the value is already "space".
		::UnseenBanner.disarmVanillaWaitTurnEnd();
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.TileCursor.reset();
		::UnseenBanner.SheetNav.reset();
		::UnseenBanner.CombatResult.reset();
		::UnseenBanner.DialogNav.reset();
		::UnseenBanner.TacticalDialogNav.reset();
		::UnseenBanner.KeyHelp.close(false);
		::UnseenBanner.KeyGate.reset();
		// A battle starting clears the party's world path, so drop any in-flight world
		// march here — otherwise Pending would be left stale and fire a spurious
		// "Stopped" (or resume the march) on returning to the map.
		::UnseenBanner.WorldMove.reset();
		::UnseenBanner.WorldCursor.clearHeld();
	}

	q.onFinish = @(__original) function()
	{
		::UnseenBanner.MenuNav.reset();
		::UnseenBanner.TileCursor.reset();
		::UnseenBanner.CombatResult.reset();
		::UnseenBanner.DialogNav.reset();
		::UnseenBanner.TacticalDialogNav.reset();
		::UnseenBanner.KeyHelp.close(false);
		__original();
	}

	q.onKeyInput = @(__original) function( _key )
	{
		local code = _key.getKey();
		local shift = (_key.getModifier() & 1) != 0;

		// Starting a practice scenario goes straight from MainMenuState to this
		// TacticalState. The scenario module can survive that hand-off as MenuNav's
		// active module because the whole main-menu screen is hidden without the
		// module completing its own onModuleHidden callback. Up/Down/Enter were then
		// claimed here as menu keys and forwarded to a hidden ScenarioMenuModule;
		// Home/End still reached the tactical lists because MenuNav does not own them.
		//
		// The tactical pause menu is the only legitimate menu owner in this state.
		// Drop any other residual ownership before dispatch, then keep processing this
		// very key so the first Up/Down reaches the character or inspect list.
		if (::UnseenBanner.MenuNav.isActive()
			&& (this.m.TacticalMenuScreen == null
				|| !this.m.TacticalMenuScreen.isVisible()))
		{
			::UnseenBanner.MenuNav.reset();
		}

		// Before any dispatch, and whatever the key ends up doing: a release ends
		// the physical press of V, so the auto-repeat latch is cleared here for
		// every path through this hook, including the ones that return early.
		if (_key.getState() == 0) ::UnseenBanner.TileCursor.clearInspectKeyHeld(code);

		// Contextual key help (F1). First of all, so it can be reached from every
		// battle surface — including the ones that consume every key, like the
		// Shift+V list — and so its own Up/Down own the list while it is open.
		if (::UnseenBanner.KeyHelp.handles(code))
		{
			if (_key.getState() == 1)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.KeyHelp.onKey(code,
						::UnseenBanner.tacticalHelpContext(this));
				}
			}
			else
			{
				::UnseenBanner.KeyGate.release(code);
				::UnseenBanner.KeyHelp.consumeReleaseSwallow(code);
			}
			return true;
		}

		// Any other key means the player has moved on: drop the help before it can
		// own Up/Down over a surface he is no longer reading. A bare modifier is not
		// "another key" — it is half of a combination still being pressed.
		if (::UnseenBanner.KeyHelp.isActive() && !(code in ::UnseenBanner.ModifierKeys))
		{
			::UnseenBanner.KeyHelp.close(false);
		}

		// A key already acted on during its press (the pause menu below, or a world
		// surface whose action dropped us into this state): eat its release before any
		// cursor here can read it as a fresh keystroke.
		if (_key.getState() == 0 && ::UnseenBanner.KeyGate.consumeSwallow(code))
		{
			return true;
		}

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
			&& ::UnseenBanner.TacticalDialogNav.handles(code))
		{
			// Same isAnimating() placement bug as the character sheet below: gating
			// the whole block let its keys leak to __original during the dialog's
			// own show/hide transition.
			if (_key.getState() == 0 && !this.m.TacticalDialogScreen.isAnimating())
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

		// The tactical pause menu uses the same modules as the other menu surfaces,
		// and the same press cadence. Consume both key states while one is up so
		// native camera bindings cannot leak through; KeyGate debounces the press
		// auto-repeat and arms the swallow for the release.
		if (::UnseenBanner.MenuNav.isActive() && ::UnseenBanner.MenuNav.handlesKey(code))
		{
			local menuOnRelease = ::UnseenBanner.MenuNav.isReleaseHandledKey(code);
			if (_key.getState() == 1 && !menuOnRelease)
			{
				if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
				{
					::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(code));
				}
				::UnseenBanner.KeyGate.armSwallow(code);
			}
			else if (_key.getState() == 0)
			{
				::UnseenBanner.KeyGate.release(code);
				if (menuOnRelease)
				{
					::UnseenBanner.MenuNav.sendKey(::UnseenBanner.MenuNav.getKeyName(code));
				}
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
			// isAnimating() must only gate the ACTION below, not this whole block:
			// during the show/hide transition the key still has to be swallowed
			// here or it falls through to __original, and mid-combat End is
			// vanilla's own "wait turn" binding — jumping this list to its last
			// row with End while the sheet was still opening passed the active
			// brother's turn instead of moving the cursor.
			if (!this.m.CharacterScreen.isAnimating())
			{
				// Act on the press (state 1), gated against auto-repeat: the screen
				// pauses the game and swallows the release of the brother-switch
				// keys, so a release-driven handler would never fire (see KeyGate).
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
			}
			return true;
		}

		// Shift+V's unit list is a real modal cursor once opened. Its rows and
		// status descriptors are already captured, so navigation must not depend on
		// TurnSequenceBar still reporting an active player or on transient
		// MenuStack/input-lock flags. Those checks silently discarded the list on
		// the very next key in live play. Native result/dialog/character screens
		// retain priority because their handlers run above this block.
		if (::UnseenBanner.TileCursor.isInspectMenuActive())
		{
			if (::UnseenBanner.TileCursor.handlesInspectMenu(code, shift))
			{
				if (_key.getState() == 1)
				{
					if (::UnseenBanner.KeyGate.shouldFire(code, this.Time.getRealTimeF()))
						::UnseenBanner.TileCursor.onInspectMenuKey(code, shift, null);
				}
				else if (_key.getState() == 0)
				{
					::UnseenBanner.KeyGate.release(code);
				}
			}

			// Consume every key while the list is open. Unrelated bindings must
			// never pan the camera, arm a skill or silently destroy the menu state;
			// Shift+V and Escape are its explicit exits.
			return true;
		}

		// The list is already closed here, but the key that closed it (on its press)
		// still owes a release. Swallow that one so it cannot reach vanilla: Escape's
		// release opens the pause menu, right on top of the battlefield we returned to.
		if (_key.getState() == 0
			&& ::UnseenBanner.TileCursor.consumeReleaseSwallow(code))
		{
			::UnseenBanner.KeyGate.release(code);
			return true;
		}

		local isCursorKey = ::UnseenBanner.TileCursor.handles(code);
		local isInspectMenuKey = ::UnseenBanner.TileCursor.handlesInspectMenu(code, shift);
		local isInspectKey = ::UnseenBanner.TileCursor.handlesInspect(code);
		local isActKey = ::UnseenBanner.Combat.handles(code);
		local isReadoutKey = ::UnseenBanner.Readout.handles(code);
		if ((isCursorKey || isInspectMenuKey || isInspectKey || isActKey || isReadoutKey)
			&& !this.isInLoadingScreen()
			&& !this.isBattleEnded()
			&& !this.isInCharacterScreen()
			&& !this.isInputLocked()
			&& !this.m.MenuStack.hasBacksteps())
		{
			local active = this.Tactical.TurnSequenceBar.getActiveEntity();
			if (active != null && active.isPlayerControlled())
			{
				::UnseenBanner.TileCursor.ensureAnchored(active);

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
							::UnseenBanner.TileCursor.onKey(code, active,
								this.Tactical.Entities, shift, this);
						else if (isInspectMenuKey)
							::UnseenBanner.TileCursor.onInspectMenuKey(code, shift, active);
						else if (isInspectKey)
							::UnseenBanner.TileCursor.inspect(active);
						else if (isActKey)
							::UnseenBanner.Combat.onKey(code, active, this, ::UnseenBanner.TileCursor.getTile(active));
						else
							::UnseenBanner.Readout.onKey(code, active,
								this.Tactical.Entities, shift);
					}
				}
				else if (_key.getState() == 0)
				{
					::UnseenBanner.KeyGate.release(code);
				}
				return true;
			}
		}

		// Last line of defence. Reaching here means no cursor of ours claimed the
		// key, which is exactly the situation the player cannot perceive: he
		// pressed End meaning "last row" of a list that, for whatever reason, is
		// no longer under him, and vanilla reads it as "wait turn" and spends the
		// turn irreversibly. The mod uses End for list navigation everywhere, so
		// the safe trade is to deny it here; Space keeps vanilla's own wait-turn
		// binding, so nothing the player needs is actually lost.
		if (code in ::UnseenBanner.TacticalBlockedKeys) return true;

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
		// The Shift+V list is a snapshot of live combat state. Drop it as soon as
		// initiative advances so armor, fatigue, morale and effects cannot go stale.
		// Say so: a list that dies in silence leaves the player navigating a cursor
		// that is no longer there, and his next Home/End is no longer list
		// navigation but vanilla's "wait turn" — the turn is gone before he can
		// hear that anything changed. Announced only when one was really open.
		::UnseenBanner.TileCursor.closeInspectMenu(true);

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

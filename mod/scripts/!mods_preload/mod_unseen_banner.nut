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
	EventNav = null
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

// The Unseen Banner — keyboard cursor over button-based menus (main menu,
// world map menu, tactical pause menu: all built by MainMenuModule and share
// the same .main-menu-module/.button markup, so one implementation covers
// all three screens).
// ES3 only: Chromium 48, no let/const, arrows, template literals.
//
// The engine does not forward raw keyboard events to this DOM (document
// keydown never fires in-game), so keys arrive from Squirrel instead: our
// onKeyInput hook calls onKeyForwarded() below via asyncCall. The cursor
// moves among the currently visible, enabled buttons and reports the focused
// button's already-rendered label back to Squirrel (never reconstructed from
// localization keys, per CLAUDE.md). "enter" activates the focused button
// exactly like a real click.

var UnseenBannerMenuNav = function ()
{
	this.mSQHandle = null;
	this.mIndex = -1;
};

UnseenBannerMenuNav.prototype.onConnection = function (_handle)
{
	this.mSQHandle = _handle;
};

UnseenBannerMenuNav.prototype.onDisconnection = function ()
{
	this.mSQHandle = null;
};

UnseenBannerMenuNav.prototype.getButtons = function ()
{
	// createTextButton() emits class "button" when created without a size but
	// "button-<n>" when sized (the menu uses size 4), so match both. Verified
	// live via DevTools: this finds all 8 main-menu buttons, including the
	// "Mod Options" one added by MSU — reading the rendered DOM picks up
	// other mods' buttons for free.
	return $('.main-menu-module.display-block div[class*="button"]').not('[disabled]').filter(':visible');
};

UnseenBannerMenuNav.prototype.readLabel = function (_button)
{
	var label = $(_button).find('.label:first');
	return label.length > 0 ? label.text() : '';
};

// Called from Squirrel (main_menu_state.onKeyInput hook) with "up", "down"
// or "enter".
UnseenBannerMenuNav.prototype.onKeyForwarded = function (_name)
{
	var buttons = this.getButtons();
	if (buttons.length === 0)
	{
		this.mIndex = -1;
		return;
	}

	if (this.mIndex < 0 || this.mIndex >= buttons.length)
	{
		this.mIndex = 0;
	}

	var activated = false;

	if (_name === 'down')
	{
		this.mIndex = (this.mIndex + 1) % buttons.length;
	}
	else if (_name === 'up')
	{
		this.mIndex = (this.mIndex - 1 + buttons.length) % buttons.length;
	}
	else if (_name === 'enter')
	{
		activated = true;
	}
	else
	{
		return;
	}

	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	var current = buttons.eq(this.mIndex);
	current.addClass('unseen-banner-focus');

	if (activated)
	{
		current.trigger('click');
	}
	else
	{
		SQ.call(this.mSQHandle, 'onMenuFocusChanged', this.readLabel(current));
	}
};

registerScreen('UnseenBannerMenuNav', new UnseenBannerMenuNav());

// The Unseen Banner — reads the world event screen aloud and lets the player
// walk its option buttons by keyboard. ES3 only: Chromium 48, no let/const,
// arrows or template literals.
//
// world_event_screen.js renders a title, a body and one or more option
// buttons, but has no keyboard cursor of its own: the engine only reaches the
// buttons through world_state's number-key shortcuts. This screen reads the
// rendered DOM when the event appears (title + body on the interrupt channel,
// one utterance) and adds an Up/Down/Enter cursor over the same buttons. Enter
// clicks the focused button, firing the exact click handler the game installed
// on it, so activation goes through the game's own path (World.Events).
//
// Keys arrive from Squirrel (world_state.onKeyInput hook): the engine does not
// forward raw keyboard to this DOM. All game-owned text is read from the
// rendered DOM; only semantic categories cross the bridge for L10n.

var UnseenBannerEventNav = function ()
{
	this.mSQHandle = null;
	this.mIndex = -1;
};

UnseenBannerEventNav.prototype.onConnection = function (_handle)
{
	this.mSQHandle = _handle;
};

UnseenBannerEventNav.prototype.onDisconnection = function ()
{
	this.mSQHandle = null;
};

UnseenBannerEventNav.prototype.sendAnnouncement = function (_category, _text, _value, _detail)
{
	// One args value only (see menu_nav.js): pack everything in a single
	// object, which Squirrel receives as a table.
	if (this.mSQHandle !== null)
	{
		SQ.call(this.mSQHandle, 'onEventAnnouncement', {
			categoria: _category || '',
			texto: _text || '',
			valor: _value || '',
			detalle: _detail || ''
		});
	}
};

UnseenBannerEventNav.prototype.getScreen = function ()
{
	return $('.world-event-screen:first');
};

UnseenBannerEventNav.prototype.getTitle = function ()
{
	return this.getScreen().find('.ui-control.dialog:first .header:first .title:first').text();
};

UnseenBannerEventNav.prototype.getBody = function ()
{
	var parts = [];
	// .description holds the narrative paragraphs and any list intro; .title
	// and .text hold list headings and list items. .find() returns them in
	// document order regardless of the order they appear in the selector, so
	// a mixed event reads top to bottom.
	//
	// .html(), not .text(): the content is XBBCODE output with real <br>/<p>/
	// <span> tags for paragraph breaks and styling, which .text() would
	// collapse into one run-on line. TextCleaner on the companion side turns
	// the tags into line breaks before speech.
	this.getScreen().find('.world-event-content .description, .world-event-content .title, .world-event-content .text').each(function ()
	{
		var html = $(this).html();
		if (html && html.length > 0)
		{
			parts.push(html);
		}
	});
	// The log.html bridge frames each message up to its first </div>. XBBCODE
	// description output holds only <p>/<span>/<br>, but strip any stray div
	// tag defensively so a leaked one can never truncate the payload in flight.
	return parts.join('\n').replace(/<\/?div[^>]*>/g, ' ');
};

UnseenBannerEventNav.prototype.getButtons = function ()
{
	var buttons = [];
	this.getScreen().find('.world-event-buttons .l-button > .ui-control').each(function ()
	{
		var button = $(this);
		if (button.is(':visible') && button.attr('disabled') !== 'disabled')
		{
			buttons.push(button);
		}
	});
	return buttons;
};

UnseenBannerEventNav.prototype.readButtonLabel = function (_button)
{
	var label = _button.find('.label:first');
	return label.length > 0 ? label.text() : _button.text();
};

UnseenBannerEventNav.prototype.focusButton = function (_index, _buttons)
{
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	if (_index >= 0 && _index < _buttons.length)
	{
		_buttons[_index].addClass('unseen-banner-focus');
	}
};

UnseenBannerEventNav.prototype.announceButton = function (_index, _buttons)
{
	if (_index < 0 || _index >= _buttons.length)
	{
		return;
	}
	this.sendAnnouncement('event.option', this.readButtonLabel(_buttons[_index]),
		'' + (_index + 1), '' + _buttons.length);
};

UnseenBannerEventNav.prototype.onEventShown = function ()
{
	this.mIndex = -1;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	// Title in texto, body in valor: L10n's "event.screen" reads "{0}. {1}",
	// one utterance so the interrupt channel does not cut the body off.
	this.sendAnnouncement('event.screen', this.getTitle(), this.getBody(), '');
};

UnseenBannerEventNav.prototype.onEventHidden = function ()
{
	this.mIndex = -1;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
};

// Called from world_state.onKeyInput with "up", "down" or "enter".
UnseenBannerEventNav.prototype.onKeyForwarded = function (_name)
{
	var buttons = this.getButtons();
	if (buttons.length === 0)
	{
		return;
	}

	if (_name === 'enter')
	{
		// A first Enter with nothing focused focuses the first option instead
		// of activating it: the player hears what they are about to pick, and
		// an event that just appeared cannot be dismissed by a stray Enter.
		if (this.mIndex < 0 || this.mIndex >= buttons.length)
		{
			this.mIndex = 0;
			this.focusButton(this.mIndex, buttons);
			this.announceButton(this.mIndex, buttons);
			return;
		}
		buttons[this.mIndex].trigger('click');
		return;
	}

	if (_name !== 'up' && _name !== 'down')
	{
		return;
	}

	if (this.mIndex < 0 || this.mIndex >= buttons.length)
	{
		this.mIndex = (_name === 'down') ? 0 : buttons.length - 1;
	}
	else if (_name === 'down')
	{
		this.mIndex = (this.mIndex + 1) % buttons.length;
	}
	else
	{
		this.mIndex = (this.mIndex - 1 + buttons.length) % buttons.length;
	}

	this.focusButton(this.mIndex, buttons);
	this.announceButton(this.mIndex, buttons);
};

registerScreen('UnseenBannerEventNav', new UnseenBannerEventNav());

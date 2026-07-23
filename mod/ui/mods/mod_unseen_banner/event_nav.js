// The Unseen Banner — reads the world event screen aloud and lets the player
// walk its narrative body and option buttons by keyboard. ES3 only: Chromium
// 48, no let/const, arrows or template literals.
//
// world_event_screen.js renders a title, a body and one or more option
// buttons, but has no keyboard cursor of its own: the engine only reaches the
// buttons through world_state's number-key shortcuts. This screen reads the
// rendered DOM whenever the event page appears (title + body on the interrupt
// channel, one utterance) and adds an Up/Down/Enter cursor over a combined
// list whose first entry is the narrative body and whose remaining entries are
// the option buttons. Enter clicks the focused button, firing the exact click
// handler the game installed on it, so activation goes through the game's own
// path (World.Events / World.Contracts).
//
// Multi-step events (negotiations, contracts) advance IN PLACE: picking an
// option calls World.*.processInput, which re-runs WorldEventScreen.show with
// the next page's data. But show() only fires notifyBackendOnShown (our
// Squirrel onScreenShown hook) on the FIRST appearance — it early-outs the
// animation, and the notify inside it, when the screen is already visible. So
// the second page onward would render silently. show() DOES call loadEvent on
// every page, so we wrap loadEvent to drive the announcement uniformly for the
// first page and every page after it. The body is also navigable, so the
// player can re-read it on demand even after it has scrolled past in speech.
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

// The navigable list: a leading text entry for the narrative body (when the
// page has one), then one entry per visible, enabled option button. Rebuilt
// from the live DOM on every keystroke so it always reflects the current page.
UnseenBannerEventNav.prototype.getEntries = function ()
{
	var entries = [];

	var body = this.getBody();
	if (body && body.length > 0)
	{
		entries.push({ type: 'text', text: body });
	}

	this.getScreen().find('.world-event-buttons .l-button > .ui-control').each(function ()
	{
		var button = $(this);
		if (button.is(':visible') && button.attr('disabled') !== 'disabled')
		{
			entries.push({ type: 'option', button: button });
		}
	});

	return entries;
};

UnseenBannerEventNav.prototype.readButtonLabel = function (_button)
{
	var label = _button.find('.label:first');
	return label.length > 0 ? label.text() : _button.text();
};

UnseenBannerEventNav.prototype.focusEntry = function (_index, _entries)
{
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	// Only option buttons get the visual highlight; the body text entry has no
	// single control to mark, and the highlight is a sighted-debugging aid only.
	if (_index >= 0 && _index < _entries.length && _entries[_index].type === 'option')
	{
		_entries[_index].button.addClass('unseen-banner-focus');
	}
};

UnseenBannerEventNav.prototype.announceEntry = function (_index, _entries)
{
	if (_index < 0 || _index >= _entries.length)
	{
		return;
	}

	var entry = _entries[_index];
	if (entry.type === 'text')
	{
		// Re-read the narrative body verbatim (L10n "event.body" is just "{0}").
		this.sendAnnouncement('event.body', entry.text, '', '');
		return;
	}

	// Option: announce label plus its position AMONG THE OPTIONS (not among all
	// entries), so the count matches what the player expects to choose from.
	var optionCount = 0;
	var ordinal = 0;
	var i;
	for (i = 0; i < _entries.length; ++i)
	{
		if (_entries[i].type === 'option')
		{
			optionCount++;
			if (i === _index)
			{
				ordinal = optionCount;
			}
		}
	}
	this.sendAnnouncement('event.option', this.readButtonLabel(entry.button),
		'' + ordinal, '' + optionCount);
};

// Announce the current page (title + body, one utterance) and reset the cursor.
// Driven from the loadEvent wrapper so it fires on the first page and on every
// page a chosen option advances to.
UnseenBannerEventNav.prototype.onEventRendered = function ()
{
	this.mIndex = -1;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	// Title in texto, body in valor: L10n's "event.screen" reads "{0}. {1}",
	// one utterance so the interrupt channel does not cut the body off.
	this.sendAnnouncement('event.screen', this.getTitle(), this.getBody(), '');
};

// Called from Squirrel's world_state hook on the FIRST appearance only. The
// loadEvent wrapper (below) already announced this page, so here we only reset
// the cursor — unless the wrapper failed to install, in which case this is the
// fallback that keeps the first page from going unread.
UnseenBannerEventNav.prototype.onEventShown = function ()
{
	this.mIndex = -1;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	if (!UnseenBannerEventNav.loadEventWrapped)
	{
		this.sendAnnouncement('event.screen', this.getTitle(), this.getBody(), '');
	}
};

UnseenBannerEventNav.prototype.onEventHidden = function ()
{
	this.mIndex = -1;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
};

// Called from world_state.onKeyInput with "up", "down" or "enter".
UnseenBannerEventNav.prototype.onKeyForwarded = function (_name)
{
	var entries = this.getEntries();
	if (entries.length === 0)
	{
		return;
	}

	if (_name === 'enter')
	{
		// A first Enter with nothing focused jumps to the first OPTION (skipping
		// the narrative body) instead of activating anything: the player hears
		// what they are about to pick, and an event that just appeared cannot be
		// dismissed by a stray Enter.
		if (this.mIndex < 0 || this.mIndex >= entries.length)
		{
			var firstOption = -1;
			var i;
			for (i = 0; i < entries.length; ++i)
			{
				if (entries[i].type === 'option')
				{
					firstOption = i;
					break;
				}
			}
			if (firstOption < 0)
			{
				return;
			}
			this.mIndex = firstOption;
			this.focusEntry(this.mIndex, entries);
			this.announceEntry(this.mIndex, entries);
			return;
		}
		// Enter on the body text entry is inert — it is not an actionable choice.
		if (entries[this.mIndex].type === 'option')
		{
			entries[this.mIndex].button.trigger('click');
		}
		return;
	}

	if (_name !== 'up' && _name !== 'down')
	{
		return;
	}

	if (this.mIndex < 0 || this.mIndex >= entries.length)
	{
		this.mIndex = (_name === 'down') ? 0 : entries.length - 1;
	}
	else if (_name === 'down')
	{
		this.mIndex = (this.mIndex + 1) % entries.length;
	}
	else
	{
		this.mIndex = (this.mIndex - 1 + entries.length) % entries.length;
	}

	this.focusEntry(this.mIndex, entries);
	this.announceEntry(this.mIndex, entries);
};

var unseenBannerEventNav = new UnseenBannerEventNav();
registerScreen('UnseenBannerEventNav', unseenBannerEventNav);

// Wrap WorldEventScreen.loadEvent so every rendered page announces itself. The
// game only notifies the backend of a "shown" event on the first appearance
// (show() early-returns while already visible), yet loadEvent runs on every
// page — first appearance and every option-driven advance alike — building the
// content and buttons synchronously, so the DOM is fully current the instant it
// returns. Base-game UI defines WorldEventScreen before mod scripts run, so the
// global is present here; guard anyway and fall back to the Squirrel hook.
UnseenBannerEventNav.loadEventWrapped = false;
if (typeof WorldEventScreen !== 'undefined' && WorldEventScreen.prototype &&
	typeof WorldEventScreen.prototype.loadEvent === 'function')
{
	var unseenBannerOriginalLoadEvent = WorldEventScreen.prototype.loadEvent;
	WorldEventScreen.prototype.loadEvent = function (_data)
	{
		unseenBannerOriginalLoadEvent.call(this, _data);
		unseenBannerEventNav.onEventRendered();
	};
	UnseenBannerEventNav.loadEventWrapped = true;
}

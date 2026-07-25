// The Unseen Banner — reads the end-of-campaign screen (defeat or retirement)
// aloud and lets the player walk it by keyboard. ES3 only: Chromium 48, no
// let/const, arrows or template literals.
//
// world_game_finish_screen.js renders one narrative ending, a score line and a
// single Quit button, and has no keyboard path of its own: the only way to leave
// is clicking Quit. Worse, world_state pushes a MenuStack entry whose backstep
// returns false, so Escape does nothing either — without this the campaign ends
// on a screen a blind player cannot hear or dismiss.
//
// The shape follows event_nav.js: announce the outcome on arrival (short, so the
// player learns immediately that the run is over and with what score), then offer
// an Up/Down/Enter cursor over a list whose entries are the ending text, the score
// and the Quit button. Enter clicks the button, firing the exact handler the game
// installed on it, so quitting goes through the game's own path
// (world_state.game_finish_dialog_onQuitPressed -> exitGame).
//
// Won versus lost is not reliably in the DOM — only the background image filename
// hints at it — so the outcome crosses the bridge from Squirrel, which receives it
// as showGameFinishScreen's own argument.
//
// Keys arrive from Squirrel (world_state.onKeyInput hook): the engine does not
// forward raw keyboard to this DOM. All game-owned text is read from the rendered
// DOM; only semantic categories cross the bridge for L10n.

var UnseenBannerGameFinishNav = function ()
{
	this.mSQHandle = null;
	this.mIndex = -1;
	this.mOutcome = 'defeat';
};

UnseenBannerGameFinishNav.prototype.onConnection = function (_handle)
{
	this.mSQHandle = _handle;
};

UnseenBannerGameFinishNav.prototype.onDisconnection = function ()
{
	this.mSQHandle = null;
};

UnseenBannerGameFinishNav.prototype.sendAnnouncement = function (_category, _text, _value, _detail)
{
	// One args value only (see menu_nav.js): pack everything in a single object,
	// which Squirrel receives as a table.
	if (this.mSQHandle !== null)
	{
		SQ.call(this.mSQHandle, 'onFinishAnnouncement', {
			categoria: _category || '',
			texto: _text || '',
			valor: _value || '',
			detalle: _detail || ''
		});
	}
};

UnseenBannerGameFinishNav.prototype.getScreen = function ()
{
	return $('.world-game-finish-screen:first');
};

UnseenBannerGameFinishNav.prototype.getBody = function ()
{
	var parts = [];
	// .html(), not .text(): the ending is XBBCODE output with real <br>/<p>/<span>
	// tags for its paragraph breaks, which .text() would collapse into one run-on
	// line. TextCleaner on the companion side turns the tags into line breaks
	// before speech.
	this.getScreen().find('.description').each(function ()
	{
		var html = $(this).html();
		if (html && html.length > 0)
		{
			parts.push(html);
		}
	});
	// The log.html bridge frames each message up to its first </div>. XBBCODE
	// description output holds only <p>/<span>/<br>, but strip any stray div tag
	// defensively so a leaked one can never truncate the payload in flight.
	return parts.join('\n').replace(/<\/?div[^>]*>/g, ' ');
};

UnseenBannerGameFinishNav.prototype.getScore = function ()
{
	return this.getScreen().find('.score-container:first').text();
};

// The navigable list: the ending text, the score line, then every visible enabled
// button (Quit is the only one vanilla creates). Rebuilt from the live DOM on
// every keystroke so it always reflects what is actually on screen.
UnseenBannerGameFinishNav.prototype.getEntries = function ()
{
	var entries = [];

	var body = this.getBody();
	if (body && body.length > 0)
	{
		entries.push({ type: 'body', text: body });
	}

	var score = this.getScore();
	if (score && score.length > 0)
	{
		entries.push({ type: 'score', text: score });
	}

	this.getScreen().find('.button-container .ui-control').each(function ()
	{
		var button = $(this);
		if (button.is(':visible') && button.attr('disabled') !== 'disabled')
		{
			entries.push({ type: 'button', button: button });
		}
	});

	return entries;
};

UnseenBannerGameFinishNav.prototype.readButtonLabel = function (_button)
{
	var label = _button.find('.label:first');
	return label.length > 0 ? label.text() : _button.text();
};

UnseenBannerGameFinishNav.prototype.focusEntry = function (_index, _entries)
{
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	// Only buttons get the visual highlight; the text entries have no single
	// control to mark, and the highlight is a sighted-debugging aid only.
	if (_index >= 0 && _index < _entries.length && _entries[_index].type === 'button')
	{
		_entries[_index].button.addClass('unseen-banner-focus');
	}
};

UnseenBannerGameFinishNav.prototype.announceEntry = function (_index, _entries)
{
	if (_index < 0 || _index >= _entries.length)
	{
		return;
	}

	var entry = _entries[_index];
	if (entry.type === 'body')
	{
		this.sendAnnouncement('world.finish.body', entry.text, '', '');
		return;
	}
	if (entry.type === 'score')
	{
		this.sendAnnouncement('world.finish.score', entry.text, '', '');
		return;
	}

	// Button: announce its label plus its position AMONG THE BUTTONS (not among
	// all entries), so the count matches what the player can actually activate.
	var buttonCount = 0;
	var ordinal = 0;
	var i;
	for (i = 0; i < _entries.length; ++i)
	{
		if (_entries[i].type === 'button')
		{
			buttonCount++;
			if (i === _index)
			{
				ordinal = buttonCount;
			}
		}
	}
	this.sendAnnouncement('world.finish.button', this.readButtonLabel(entry.button),
		'' + ordinal, '' + buttonCount);
};

// Called from Squirrel once the screen's fade-in reports onScreenShown, the
// deterministic point at which loadFromData has populated the DOM. The ending
// itself is the first list entry rather than part of this utterance: it runs to
// several paragraphs, and the player wants the verdict and the score first.
UnseenBannerGameFinishNav.prototype.onFinishShown = function (_outcome)
{
	this.mIndex = -1;
	this.mOutcome = (_outcome === 'victory') ? 'victory' : 'defeat';
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	this.sendAnnouncement('world.finish.' + this.mOutcome, this.getScore(), '', '');
};

UnseenBannerGameFinishNav.prototype.onFinishHidden = function ()
{
	this.mIndex = -1;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
};

// Called from world_state.onKeyInput with "up", "down" or "enter".
UnseenBannerGameFinishNav.prototype.onKeyForwarded = function (_name)
{
	var entries = this.getEntries();
	if (entries.length === 0)
	{
		return;
	}

	if (_name === 'enter')
	{
		// A first Enter with nothing focused jumps to the first BUTTON instead of
		// activating anything. Quit exits to the main menu with no confirmation, so
		// a stray Enter on a screen that just appeared must never trigger it.
		if (this.mIndex < 0 || this.mIndex >= entries.length)
		{
			var firstButton = -1;
			var i;
			for (i = 0; i < entries.length; ++i)
			{
				if (entries[i].type === 'button')
				{
					firstButton = i;
					break;
				}
			}
			if (firstButton < 0)
			{
				return;
			}
			this.mIndex = firstButton;
			this.focusEntry(this.mIndex, entries);
			this.announceEntry(this.mIndex, entries);
			return;
		}
		// Enter on a text entry is inert — it is not an actionable choice.
		if (entries[this.mIndex].type === 'button')
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

var unseenBannerGameFinishNav = new UnseenBannerGameFinishNav();
registerScreen('UnseenBannerGameFinishNav', unseenBannerGameFinishNav);

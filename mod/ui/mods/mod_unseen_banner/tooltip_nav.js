// The Unseen Banner — on-demand native-tooltip reader (phase 2.1).
// ES3 only: Chromium 48, no let/const, arrows or template literals.
//
// Accessible cursors call showDetail with the same stable descriptor vanilla
// binds to a visual element (skill ID, status ID, item instance ID, and so on).
// We ask TooltipModule's native backend for the data, let its one renderer build
// the localized DOM, then read that final DOM in visual order. Ordinary mouse
// hovers also pass through buildFromData but stay silent because there is no
// pending accessibility request.

var UnseenBannerTooltipNav = function ()
{
	this.mSQHandle = null;
	this.mHookReady = false;
	this.mReadyReported = false;
	this.mPending = null;
	this.mRequestSerial = 0;
	this.mBuildingRequestId = 0;
};

UnseenBannerTooltipNav.IconTokens = {
	action_points: 'action_points',
	ambition_tooltip: 'ambition',
	ammo: 'ammunition',
	armor_body: 'armor_body',
	armor_damage: 'armor_damage',
	armor_head: 'armor_head',
	asset_ammo: 'ammunition',
	asset_brothers: 'brothers',
	asset_daily_money: 'daily_wages',
	asset_food: 'food',
	asset_medicine: 'medical_supplies',
	asset_money: 'crowns',
	asset_supplies: 'tools',
	bravery: 'resolve',
	camp: 'camp',
	cancel: 'cancel',
	chance_to_hit_head: 'chance_to_hit_head',
	contract_scroll: 'contract',
	damage_dealt: 'damage',
	days_wounded: 'days_wounded',
	direct_damage: 'direct_damage',
	fatigue: 'fatigue',
	health: 'health',
	hitchance: 'hit_chance',
	icon_locked: 'locked',
	initiative: 'initiative',
	kills: 'kills',
	level: 'level',
	melee_defense: 'melee_defense',
	melee_skill: 'melee_skill',
	money: 'crowns',
	morale: 'morale',
	mouse_left_button: 'left_mouse_button',
	mouse_right_button: 'right_mouse_button',
	mouse_right_button_alt: 'right_mouse_button',
	mouse_right_button_ctrl: 'ctrl_right_mouse_button',
	papers: 'documents',
	plus: 'bonus',
	positive: 'positive',
	ranged_defense: 'ranged_defense',
	ranged_skill: 'ranged_skill',
	regular_damage: 'damage',
	relations: 'relations',
	shield_damage: 'shield_damage',
	special: 'special',
	stat_screen_dmg_dealt: 'damage',
	sturdiness: 'condition',
	vision: 'sight',
	warning: 'warning',
	negative: 'negative',
	xp_received: 'experience'
};

UnseenBannerTooltipNav.MouseOnlyInventoryGroups = {
	'combat.sheet.equipment': true,
	'world.character.equipment': true,
	'world.character.bag': true,
	'world.character.stash': true
};

UnseenBannerTooltipNav.prototype.onConnection = function (_handle)
{
	this.mSQHandle = _handle;
	this.mReadyReported = false;
	this.reportReady();
};

UnseenBannerTooltipNav.prototype.onDisconnection = function ()
{
	this.mSQHandle = null;
	this.mReadyReported = false;
	this.mPending = null;
};

UnseenBannerTooltipNav.prototype.reportReady = function ()
{
	if (this.mHookReady && !this.mReadyReported && this.mSQHandle !== null)
	{
		SQ.call(this.mSQHandle, 'onTooltipHookReady');
		this.mReadyReported = true;
	}
};

UnseenBannerTooltipNav.prototype.getTooltipModule = function ()
{
	if (typeof Screens === 'undefined' || Screens.Tooltip === null ||
		!Screens.Tooltip.isConnected())
	{
		return null;
	}
	return Screens.Tooltip.getModule('TooltipModule');
};

UnseenBannerTooltipNav.prototype.getAnchor = function ()
{
	var screen = $('.character-screen').filter(function ()
	{
		return !$(this).hasClass('display-none');
	}).last();
	if (screen.length === 0)
	{
		screen = $('.root-screen:first');
	}
	if (screen.length === 0)
	{
		return null;
	}

	var anchor = screen.children('.unseen-banner-tooltip-anchor:first');
	if (anchor.length === 0)
	{
		anchor = $('<div class="unseen-banner-tooltip-anchor"></div>');
		anchor.css({
			position: 'absolute',
			left: '50%',
			top: '50%',
			width: '1px',
			height: '1px',
			'pointer-events': 'none'
		});
		screen.append(anchor);
	}
	return anchor;
};

UnseenBannerTooltipNav.prototype.hideDetail = function ()
{
	this.mRequestSerial += 1;
	this.mPending = null;
	this.mBuildingRequestId = 0;
	var tooltip = this.getTooltipModule();
	if (tooltip !== null)
	{
		tooltip.hideTooltip();
	}
};

UnseenBannerTooltipNav.prototype.showCharacterSection = function (_section)
{
	if (typeof Screens === 'undefined' ||
		typeof Screens.WorldCharacterScreen === 'undefined' ||
		Screens.WorldCharacterScreen === null)
	{
		return;
	}
	var screen = Screens.WorldCharacterScreen;
	var panel = screen.mRightPanelModule;
	if (typeof panel === 'undefined' || panel === null ||
		typeof panel.mHeaderModule === 'undefined' || panel.mHeaderModule === null)
	{
		return;
	}

	// Perks is the only section that lives on the other native tab. Every other
	// semantic section is represented by the normal inventory/paperdoll/roster
	// view. Call the same module methods as the tab buttons without synthesizing
	// a mouse event or triggering any inventory action.
	if (_section === 'perks')
	{
		panel.switchToPerks();
		panel.mHeaderModule.mSwitchToInventoryButton.removeClass('is-selected');
		panel.mHeaderModule.mSwitchToPerksButton.addClass('is-selected');
	}
	else
	{
		panel.switchToInventory();
		panel.mHeaderModule.mSwitchToPerksButton.removeClass('is-selected');
		panel.mHeaderModule.mSwitchToInventoryButton.addClass('is-selected');
	}
};

UnseenBannerTooltipNav.prototype.announceUnavailable = function ()
{
	if (this.mSQHandle !== null)
	{
		SQ.call(this.mSQHandle, 'onTooltipUnavailable');
	}
};

UnseenBannerTooltipNav.prototype.showDetail = function (_request)
{
	var tooltip = this.getTooltipModule();
	var anchor = this.getAnchor();
	if (tooltip === null || anchor === null || _request === null ||
		typeof _request !== 'object' || !('tooltip' in _request) ||
		_request.tooltip === null || typeof _request.tooltip !== 'object' ||
		!('contentType' in _request.tooltip))
	{
		this.announceUnavailable();
		return;
	}

	// Invalidate any asynchronous response for the previous detail and remove its
	// visual tooltip before asking vanilla for the new one.
	this.mRequestSerial += 1;
	var requestId = this.mRequestSerial;
	tooltip.hideTooltip();
	this.mPending = {
		id: requestId,
		descriptor: _request.tooltip,
		indice: 'indice' in _request ? _request.indice : 1,
		total: 'total' in _request ? _request.total : 1,
		grupo: 'grupo' in _request ? _request.grupo : ''
	};

	var self = this;
	tooltip.notifyBackendQueryTooltipData(_request.tooltip, function (_data)
	{
		if (self.mPending === null || self.mPending.id !== requestId)
		{
			return;
		}
		if (_data === undefined || _data === null || !jQuery.isArray(_data))
		{
			self.mPending = null;
			self.announceUnavailable();
			return;
		}

		try
		{
			tooltip.mIsVisible = true;
			tooltip.mCurrentData = _request.tooltip;
			tooltip.mCurrentElement = anchor;
			self.mBuildingRequestId = requestId;
			tooltip.buildFromData(_data, false, _request.tooltip.contentType);
			self.mBuildingRequestId = 0;
			tooltip.setupUITooltip(anchor, _request.tooltip);
		}
		catch (e)
		{
			self.mBuildingRequestId = 0;
			self.mPending = null;
			console.log('UnseenBanner: on-demand tooltip failed: ' + e);
			self.announceUnavailable();
		}
	});
};

UnseenBannerTooltipNav.prototype.getImageFileName = function (_image)
{
	var image = $(_image);
	var source = image.attr('src') || '';
	var clean = source.split('?')[0].split('#')[0];
	var slash = Math.max(clean.lastIndexOf('/'), clean.lastIndexOf('\\'));
	var file = slash >= 0 ? clean.substring(slash + 1) : clean;
	var dot = file.lastIndexOf('.');
	if (dot > 0)
	{
		file = file.substring(0, dot);
	}
	return file.toLowerCase();
};

UnseenBannerTooltipNav.prototype.getIconToken = function (_image)
{
	var image = $(_image);
	var file = this.getImageFileName(_image);

	// Vanilla reuses the supplies icon for item durability in a progress bar.
	if (file === 'asset_supplies' &&
		image.closest('.row').find('.progressbar, .progressbar-container').length > 0)
	{
		return 'condition';
	}
	if (file.indexOf('height_') === 0)
	{
		return 'height';
	}
	return file in UnseenBannerTooltipNav.IconTokens
		? UnseenBannerTooltipNav.IconTokens[file]
		: null;
};

UnseenBannerTooltipNav.prototype.isMouseInstruction = function (_row)
{
	var self = this;
	var found = false;
	_row.find('img').each(function ()
	{
		var file = self.getImageFileName(this);
		if (file.indexOf('mouse_left_button') === 0 ||
			file.indexOf('mouse_right_button') === 0)
		{
			found = true;
			return false;
		}
	});
	return found;
};

UnseenBannerTooltipNav.prototype.readFragment = function (_fragment)
{
	var self = this;
	var clone = _fragment.clone();

	// Image-only semantics become localizable markers. Decorative portraits, item
	// art and skill art remain silent instead of guessing at their meaning.
	clone.find('img').each(function ()
	{
		var token = self.getIconToken(this);
		var replacement = token !== null
			? ' [[ub-icon:' + token + ']] '
			: ' ';
		$(this).replaceWith(document.createTextNode(replacement));
	});

	// textContent does not add separators at HTML block boundaries. Insert them
	// in a clone so the actual native tooltip DOM is never modified.
	clone.find('br').each(function ()
	{
		$(this).replaceWith(document.createTextNode('\n'));
	});
	clone.find('p').each(function ()
	{
		$(this).prepend(document.createTextNode('\n'));
		$(this).append(document.createTextNode('\n'));
	});

	return $.trim(clone.text());
};

UnseenBannerTooltipNav.prototype.punctuateText = function (_text)
{
	var lines = _text.replace(/\r/g, '\n').split('\n');
	var result = [];
	for (var i = 0; i < lines.length; ++i)
	{
		var line = $.trim(lines[i]);
		if (line.length === 0)
		{
			continue;
		}
		// Preserve punctuation already supplied by the game. Otherwise make each
		// rendered visual line a sentence so NVDA pauses before the next row.
		if (!/[.!?;:]$/.test(line))
		{
			line += '.';
		}
		result.push(line);
	}
	return result.join('\n');
};

UnseenBannerTooltipNav.prototype.labelText = function (_text)
{
	var label = $.trim(_text);
	if (label.length === 0)
	{
		return '';
	}
	return /[:.!?;]$/.test(label) ? label : label + ':';
};

UnseenBannerTooltipNav.prototype.readRow = function (_row)
{
	var parts = [];
	var left = _row.children('.l-left-column:first');
	var right = _row.children('.l-right-column:first');

	if (left.length > 0 || right.length > 0)
	{
		var label = left.length > 0
			? this.readFragment(left.find('.label:first'))
			: '';
		var value = right.length > 0 ? this.readFragment(right) : '';
		var line = '';
		if (label.length > 0 && value.length > 0)
		{
			line = this.labelText(label) + ' ' + this.punctuateText(value);
		}
		else if (value.length > 0)
		{
			line = this.punctuateText(value);
		}
		else if (label.length > 0)
		{
			line = this.punctuateText(label);
		}
		if (line.length > 0)
		{
			parts.push(line);
		}
	}
	else
	{
		// Titles, descriptions and footer headings have no two-column wrapper.
		// Exclude nested child rows here; they are handled recursively below.
		var body = _row.clone();
		body.children('.row').remove();
		var text = this.readFragment(body);
		if (text.length > 0)
		{
			parts.push(this.punctuateText(text));
		}
	}

	var self = this;
	_row.children('.row').each(function ()
	{
		var child = $(this);
		if (!child.hasClass('display-none'))
		{
			var childText = self.readRow(child);
			if (childText.length > 0)
			{
				parts.push(childText);
			}
		}
	});
	return parts.join('\n');
};

UnseenBannerTooltipNav.prototype.readTooltip = function (_container)
{
	if (_container === null || _container.length === 0)
	{
		return '';
	}

	// Select top-level rows only; readRow recursively handles child rows and
	// preserves each visual label/value relationship as "Label: value."
	var rows = _container.find(
		'.header-container:first > .row,' +
		'.content-container:first > .left-content-container:first > .row,' +
		'.content-container:first > .right-content-container:first > .row,' +
		'.footer-container:first > .row,' +
		'.hint-container:first > .row'
	);
	var parts = [];
	var self = this;
	var omitMouseInstructions = this.mPending !== null &&
		this.mPending.grupo in UnseenBannerTooltipNav.MouseOnlyInventoryGroups;
	rows.each(function ()
	{
		var row = $(this);
		if (row.hasClass('display-none') || row.parent().hasClass('display-none'))
		{
			return;
		}
		// Item tooltips end with mouse-only inventory actions. They are unusable
		// for this keyboard accessibility cursor and would falsely instruct a blind
		// player, so omit those whole hint rows in keyboard inventory details.
		if (omitMouseInstructions && self.isMouseInstruction(row))
		{
			return;
		}
		var text = self.readRow(row);
		if (text.length > 0)
		{
			parts.push(text);
		}
	});
	return parts.join('\n');
};

UnseenBannerTooltipNav.prototype.onTooltipBuilt = function (_module)
{
	if (this.mPending === null ||
		this.mBuildingRequestId !== this.mPending.id)
	{
		return;
	}

	try
	{
		var text = this.readTooltip(_module.mContainer);
		if (text.length === 0)
		{
			this.announceUnavailable();
			return;
		}
		if (this.mSQHandle !== null)
		{
			SQ.call(this.mSQHandle, 'onTooltipAnnouncement', {
				texto: text,
				indice: this.mPending.indice,
				total: this.mPending.total,
				grupo: this.mPending.grupo
			});
		}
	}
	catch (e)
	{
		console.log('UnseenBanner: tooltip DOM extraction failed: ' + e);
		this.announceUnavailable();
	}
};

var unseenBannerTooltipNav = new UnseenBannerTooltipNav();
registerScreen('UnseenBannerTooltipNav', unseenBannerTooltipNav);

UnseenBannerTooltipNav.installAttempts = 0;
UnseenBannerTooltipNav.install = function ()
{
	if (typeof TooltipModule === 'undefined' || !TooltipModule.prototype ||
		typeof TooltipModule.prototype.buildFromData !== 'function')
	{
		return false;
	}
	if (TooltipModule.prototype.unseenBannerOnDemandTooltipWrapped === true)
	{
		return true;
	}

	var originalBuildFromData = TooltipModule.prototype.buildFromData;
	TooltipModule.prototype.buildFromData = function ()
	{
		var result = originalBuildFromData.apply(this, arguments);
		unseenBannerTooltipNav.onTooltipBuilt(this);
		return result;
	};

	TooltipModule.prototype.unseenBannerOnDemandTooltipWrapped = true;
	unseenBannerTooltipNav.mHookReady = true;
	unseenBannerTooltipNav.reportReady();
	return true;
};

UnseenBannerTooltipNav.tryInstall = function ()
{
	if (UnseenBannerTooltipNav.install())
	{
		return;
	}
	UnseenBannerTooltipNav.installAttempts += 1;
	if (UnseenBannerTooltipNav.installAttempts < 50)
	{
		setTimeout(UnseenBannerTooltipNav.tryInstall, 100);
	}
	else
	{
		console.log('UnseenBanner: TooltipModule was not available for wrapping.');
	}
};

UnseenBannerTooltipNav.tryInstall();

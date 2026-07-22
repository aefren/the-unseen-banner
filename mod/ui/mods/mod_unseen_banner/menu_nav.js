// The Unseen Banner — keyboard cursor for the shared menu modules: main/pause,
// New Campaign, Load/Save and Options. ES3 only: Chromium 48, no let/const,
// arrows or template literals.
//
// The engine does not forward raw keyboard events to this DOM, so Up, Down
// and Enter arrive from Squirrel. All game-owned labels and descriptions are
// read from the rendered DOM. Only semantic categories cross the bridge for
// L10n to add the few phrases owned by the mod.

var UnseenBannerMenuNav = function ()
{
	this.mSQHandle = null;
	this.mActiveModule = null;
	this.mIndices = {
		MainMenuModule: -1,
		NewCampaignModule: -1,
		LoadCampaignModule: -1,
		SaveCampaignModule: -1,
		OptionsMenuModule: -1
	};
	this.mEditingInput = null;
	// Popup dialogs (Enter Name for a new save, Delete confirmation) have no module
	// lifecycle of their own, so when one is open this holds { type, dialog } and the
	// cursor drives it instead of the module behind it. mPopupIndex is its own cursor,
	// kept apart from mIndices so returning to the module restores its position.
	this.mPopup = null;
	this.mPopupIndex = -1;
	// Timestamp of the last edit-exit triggered by Enter. If the engine also
	// delivers that same Enter's key-release to Squirrel (now that the input
	// is blurred), the forwarded 'enter' would immediately re-open the field;
	// we swallow one forwarded Enter within a short window to prevent that.
	this.mEnterExitAt = 0;
};

UnseenBannerMenuNav.prototype.onConnection = function (_handle)
{
	this.mSQHandle = _handle;
};

UnseenBannerMenuNav.prototype.onDisconnection = function ()
{
	this.mSQHandle = null;
};

UnseenBannerMenuNav.prototype.sendAnnouncement = function (_category, _text, _value, _detail)
{
	// SQ.call's signature is (handle, method, _args, _callback): ONE args
	// value only — extra positional arguments land in _callback and the
	// engine tries to invoke them as a function. Pack everything in a
	// single object, which Squirrel receives as a table.
	if (this.mSQHandle !== null)
	{
		SQ.call(this.mSQHandle, 'onMenuAnnouncement', {
			categoria: _category || '',
			texto: _text || '',
			valor: _value || '',
			detalle: _detail || ''
		});
	}
};

UnseenBannerMenuNav.prototype.isButton = function (_element)
{
	var className = $(_element).attr('class') || '';
	return /(^|\s)button(?:-[^\s]+)?(?=\s|$)/.test(className);
};

UnseenBannerMenuNav.prototype.isAvailable = function (_element)
{
	var element = $(_element);
	return element.closest('.display-none').length === 0 && !element.is('[disabled]');
};

UnseenBannerMenuNav.prototype.readButtonLabel = function (_button)
{
	var label = $(_button).find('.label:first');
	return label.length > 0 ? label.text() : '';
};

UnseenBannerMenuNav.prototype.readControlLabel = function (_control)
{
	var id = $(_control).attr('id');
	var label = id ? $('label[for="' + id + '"]:first') : $();
	return label.length > 0 ? label.text() : '';
};

UnseenBannerMenuNav.prototype.readControlTitle = function (_control)
{
	var row = $(_control).closest('.row');
	var title = row.find('.title:first');
	return title.length > 0 ? title.text() : '';
};

UnseenBannerMenuNav.prototype.getMainItems = function ()
{
	var self = this;
	var items = [];
	$('.main-menu-module.display-block div.ui-control').each(function ()
	{
		if (self.isButton(this) && self.isAvailable(this) && $(this).is(':visible'))
		{
			items.push({ type: 'button', element: $(this) });
		}
	});
	return items;
};

UnseenBannerMenuNav.prototype.getNewCampaignModule = function ()
{
	return $('.new-campaign-menu-module.display-block:first');
};

UnseenBannerMenuNav.prototype.getActiveNewPanel = function ()
{
	var module = this.getNewCampaignModule();
	var content = module.find('.ui-control.dialog:first > .content:first');
	return content.children('.display-block:first');
};

UnseenBannerMenuNav.prototype.getNewCampaignTitles = function ()
{
	var module = this.getNewCampaignModule();
	var dialogTitle = module.find('.ui-control.dialog:first > .header:first .title:first').text();
	var panelTitle = this.getActiveNewPanel().find('.title:first').text();
	return { dialog: dialogTitle, panel: panelTitle };
};

UnseenBannerMenuNav.prototype.getNewCampaignItems = function ()
{
	var self = this;
	var module = this.getNewCampaignModule();
	var panel = this.getActiveNewPanel();
	var items = [];

	panel.find('input, div.ui-control').each(function ()
	{
		var element = $(this);
		var inputType = (element.attr('type') || '').toLowerCase();
		if (!self.isAvailable(element))
		{
			return;
		}

		if (inputType === 'radio')
		{
			items.push({ type: 'radio', element: element });
		}
		else if (inputType === 'checkbox')
		{
			items.push({ type: 'checkbox', element: element });
		}
		else if (inputType === 'text')
		{
			items.push({ type: 'input', element: element });
		}
		else if (self.isButton(element) && element.is(':visible'))
		{
			if (element.closest('.prev-banner-button').length > 0)
				items.push({ type: 'previous-banner', element: element });
			else if (element.closest('.next-banner-button').length > 0)
				items.push({ type: 'next-banner', element: element });
		}
	});

	module.find('.l-button-bar div.ui-control').each(function ()
	{
		if (self.isButton(this) && self.isAvailable(this) && $(this).is(':visible'))
		{
			items.push({ type: 'button', element: $(this) });
		}
	});

	return items;
};

// --- Load/Save campaign screens ---------------------------------------------
// Both are the same list-of-saves dialog (only the footer button differs), shown
// as their own ui_module; the module DOM class distinguishes them.

UnseenBannerMenuNav.prototype.getCampaignModule = function (_id)
{
	var cls = _id === 'LoadCampaignModule' ? '.load-campaign-menu-module' : '.save-campaign-menu-module';
	return $(cls + '.display-block:first');
};

UnseenBannerMenuNav.prototype.getCampaignItems = function (_id)
{
	var self = this;
	var module = this.getCampaignModule(_id);
	var items = [];

	// Saved-game rows, in list order. The New Savegame row (save screen only) is a
	// campaign entry too, so it arrives here with no special-casing.
	module.find('.ui-control.campaign').each(function ()
	{
		if ($(this).is(':visible'))
			items.push({ type: 'campaign', element: $(this) });
	});

	// Footer buttons (Load/Save, Cancel, Delete) always follow, enabled or not, so
	// the navigation order stays stable as a selection enables them; a disabled one
	// announces itself as unavailable and refuses activation (see activateItem).
	module.find('.footer .l-button-bar div.ui-control').each(function ()
	{
		if (self.isButton(this) && $(this).is(':visible'))
			items.push({ type: 'button', element: $(this) });
	});

	return items;
};

UnseenBannerMenuNav.prototype.readCampaignEntry = function (_entry)
{
	return {
		name: _entry.find('.is-campaign-name:first').text(),
		day: _entry.find('.is-day-name:first').text(),
		date: _entry.find('.is-date-time:first').text(),
		selected: _entry.hasClass('is-selected'),
		disabled: _entry.hasClass('is-disabled')
	};
};

UnseenBannerMenuNav.prototype.announceCampaignScreen = function (_id)
{
	var module = this.getCampaignModule(_id);
	var title = module.find('.ui-control.dialog:first > .header:first .title:first').text();
	var count = module.find('.ui-control.campaign').length;
	this.sendAnnouncement('menu.campaign.screen', title, String(count), '');
};

// --- Options screen ---------------------------------------------------------
// OptionsMenuModule is shared by the main menu and both in-game pause menus.
// Its four tabs all feed the game's own datasource; we operate the rendered
// controls and trigger their native events so Apply / Ok remain the only places
// that persist changes.

UnseenBannerMenuNav.prototype.getOptionsModule = function ()
{
	return $('.options-menu-module.display-block:first');
};

UnseenBannerMenuNav.prototype.getOptionsTabButtons = function ()
{
	return this.getOptionsModule().find('.l-tab-button-bar div.ui-control');
};

UnseenBannerMenuNav.prototype.getSelectedOptionsTab = function ()
{
	var tabs = this.getOptionsTabButtons();
	var selected = tabs.filter('.is-selected:first');
	return selected.length > 0 ? selected : tabs.first();
};

UnseenBannerMenuNav.prototype.getActiveOptionsPanel = function ()
{
	var module = this.getOptionsModule();
	var content = module.find('.ui-control.dialog:first > .content:first');
	return content.children('.display-block:first');
};

UnseenBannerMenuNav.prototype.getOptionsItems = function ()
{
	var self = this;
	var module = this.getOptionsModule();
	var panel = this.getActiveOptionsPanel();
	var items = [];
	var selectedTab = this.getSelectedOptionsTab();

	// Treat the four visual tab buttons as one semantic setting. Left / Right on
	// this item changes panel; Down then enters that panel's controls.
	if (selectedTab.length > 0)
		items.push({ type: 'options-tab', element: selectedTab });

	// Resolution is a long visual list. Expose it as one setting whose value is
	// the selected row, adjusted with Left / Right instead of making the player
	// traverse every resolution before reaching the rest of the Video panel.
	if (panel.hasClass('video-panel'))
	{
		var list = panel.find('.ui-control.list:first');
		var resolution = list.find('.list-entry.is-selected:first');
		if (resolution.length === 0)
			resolution = list.find('.list-entry:first');
		if (resolution.length > 0)
			items.push({ type: 'resolution', element: resolution, list: list });
	}

	panel.find('input').each(function ()
	{
		var element = $(this);
		var inputType = (element.attr('type') || '').toLowerCase();
		if (!self.isAvailable(element))
			return;

		if (inputType === 'range')
			items.push({ type: 'slider', element: element });
		else if (inputType === 'radio')
			items.push({ type: 'radio', element: element });
		else if (inputType === 'checkbox')
			items.push({ type: 'checkbox', element: element });
	});

	module.find('.footer .l-button-bar div.ui-control').each(function ()
	{
		if (self.isButton(this) && $(this).is(':visible'))
			items.push({ type: 'button', element: $(this) });
	});

	return items;
};

UnseenBannerMenuNav.prototype.readOptionsSliderLabel = function (_slider)
{
	var slider = $(_slider);
	var label = slider.closest('.volume-control').find('.volume-label:first');
	return label.length > 0 ? label.text() : this.readControlTitle(slider);
};

UnseenBannerMenuNav.prototype.announceOptionsScreen = function ()
{
	var module = this.getOptionsModule();
	var title = module.find('.ui-control.dialog:first > .header:first .title:first').text();
	var tab = this.getSelectedOptionsTab();
	this.sendAnnouncement('menu.options.screen', title, this.readButtonLabel(tab), '');
};

UnseenBannerMenuNav.prototype.switchOptionsTab = function (_direction)
{
	var tabs = this.getOptionsTabButtons();
	var selected = this.getSelectedOptionsTab();
	var index = tabs.index(selected);
	if (tabs.length === 0)
		return;
	if (index < 0)
		index = 0;

	index = (index + _direction + tabs.length) % tabs.length;
	$(tabs[index]).trigger('click');
	this.mIndices.OptionsMenuModule = 0;

	var items = this.getOptionsItems();
	if (items.length > 0)
	{
		this.focusItem(items[0]);
		this.announceItem(items[0]);
	}
};

UnseenBannerMenuNav.prototype.adjustOptionsSlider = function (_item, _direction)
{
	var element = _item.element;
	var value = parseFloat(element.val());
	var min = parseFloat(element.attr('min'));
	var max = parseFloat(element.attr('max'));
	var step = parseFloat(element.attr('step'));

	if (isNaN(value)) value = 0;
	if (isNaN(min)) min = value;
	if (isNaN(max)) max = value;
	if (isNaN(step) || step <= 0) step = 1;
	// The vanilla audio panel declares mVolumeStep = 10 even though the HTML
	// range keeps step=1 for mouse input. Ten percentage points per key press is
	// the intended keyboard-sized adjustment and avoids one hundred presses.
	if (element.hasClass('volume-slider')) step = 10;

	value = Math.max(min, Math.min(max, value + (_direction * step)));
	element.val(value).trigger('change');
	this.announceItem(_item);
};

UnseenBannerMenuNav.prototype.adjustResolution = function (_item, _direction)
{
	var entries = _item.list.find('.list-entry');
	var index = entries.index(_item.element);
	if (entries.length === 0)
		return;
	if (index < 0)
		index = 0;

	index = Math.max(0, Math.min(entries.length - 1, index + _direction));
	var target = $(entries[index]);
	target.trigger('click');
	_item.element = target;
	this.focusItem(_item);
	this.announceItem(_item);
};

UnseenBannerMenuNav.prototype.adjustOptionsItem = function (_item, _direction)
{
	if (_item.type === 'options-tab')
		this.switchOptionsTab(_direction);
	else if (_item.type === 'slider')
		this.adjustOptionsSlider(_item, _direction);
	else if (_item.type === 'resolution')
		this.adjustResolution(_item, _direction);
	else
		this.announceItem(_item);
};

// --- Popups (Enter Name / Delete confirmation) ------------------------------
// These are created synchronously when we click Save (on a New Savegame) or
// Delete, and live inside the module container. They fire no lifecycle event, so
// we look for them right after the click and, for the native-driven Enter Name
// field, notice when they vanish (see onKeyForwarded).

UnseenBannerMenuNav.prototype.detectPopup = function ()
{
	if (this.mActiveModule !== 'LoadCampaignModule' && this.mActiveModule !== 'SaveCampaignModule')
		return null;
	var dialog = this.getCampaignModule(this.mActiveModule).find('.popup-dialog:first');
	return dialog.length > 0 ? dialog : null;
};

UnseenBannerMenuNav.prototype.getPopupItems = function ()
{
	if (this.mPopup === null)
		return [];
	var dialog = this.mPopup.dialog;
	var items = [];
	var cancel = dialog.find('.footer .l-cancel-button .button-1:first');
	var ok = dialog.find('.footer .l-ok-button .button-1:first');
	// Cancel first, so it is the default focus on a Delete confirmation.
	if (cancel.length > 0)
		items.push({ type: 'popup-button', role: 'cancel', element: cancel });
	if (ok.length > 0)
		items.push({ type: 'popup-button', role: 'ok', element: ok });
	return items;
};

UnseenBannerMenuNav.prototype.openPopup = function (_dialog)
{
	var hasInput = _dialog.find('input:first').length > 0;
	this.mPopup = { type: hasInput ? 'enter-name' : 'delete', dialog: _dialog };
	this.mPopupIndex = -1;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');

	if (this.mPopup.type === 'enter-name')
	{
		// The game already focused the text field (its show code does), and the
		// engine routes the keyboard straight to a focused input, so typing, Enter
		// (confirm) and Escape (cancel) are all handled natively by the field. We only
		// speak the prompt and stay out of the way until the popup closes.
		this.sendAnnouncement('menu.save.name_prompt', '', '', '');
	}
	else
	{
		// The campaign name sits in the warning span of the confirmation text.
		var name = _dialog.find('.font-color-label-warning:first').text();
		this.sendAnnouncement('menu.popup.delete', name, '', '');
		var items = this.getPopupItems();
		if (items.length > 0)
		{
			this.mPopupIndex = 0; // Cancel
			this.focusItem(items[0]);
		}
	}
};

UnseenBannerMenuNav.prototype.closePopup = function (_reannounce)
{
	this.mPopup = null;
	this.mPopupIndex = -1;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	if (_reannounce && (this.mActiveModule === 'LoadCampaignModule' || this.mActiveModule === 'SaveCampaignModule'))
	{
		this.mIndices[this.mActiveModule] = -1;
		this.announceCampaignScreen(this.mActiveModule);
	}
};

UnseenBannerMenuNav.prototype.getItems = function ()
{
	if (this.mPopup !== null)
		return this.getPopupItems();
	if (this.mActiveModule === 'MainMenuModule')
		return this.getMainItems();
	if (this.mActiveModule === 'NewCampaignModule')
		return this.getNewCampaignItems();
	if (this.mActiveModule === 'LoadCampaignModule' || this.mActiveModule === 'SaveCampaignModule')
		return this.getCampaignItems(this.mActiveModule);
	if (this.mActiveModule === 'OptionsMenuModule')
		return this.getOptionsItems();
	return [];
};

UnseenBannerMenuNav.prototype.focusItem = function (_item)
{
	var focusTarget = _item.element;
	if (_item.type === 'radio' || _item.type === 'checkbox')
	{
		focusTarget = _item.element.parent();
	}
	else if (_item.type === 'slider')
	{
		var sliderControl = _item.element.closest('.volume-control, .scale-control');
		if (sliderControl.length > 0)
			focusTarget = sliderControl;
	}

	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	focusTarget.addClass('unseen-banner-focus');

	var list = _item.type === 'resolution' ? _item.list : _item.element.closest('.ui-control.list');
	if (list.length > 0 && typeof list.scrollListToElement === 'function')
	{
		var scrollTarget = _item.type === 'resolution' ? _item.element : _item.element.closest('.control');
		list.scrollListToElement(scrollTarget);
	}
};

UnseenBannerMenuNav.prototype.readBanner = function ()
{
	var src = this.getNewCampaignModule().find('.banner-image:first').attr('src') || '';
	var match = /\/([^\/]+)\.png(?:\?.*)?$/.exec(src);
	var name = match !== null ? match[1] : src;
	return name.indexOf('banner_') === 0 ? name.substring(7) : name;
};

UnseenBannerMenuNav.prototype.announceItem = function (_item)
{
	var element = _item.element;
	var label;
	var title;
	var selected;
	var detail = '';

	if (_item.type === 'button')
	{
		this.sendAnnouncement(element.is('[disabled]') ? 'menu.button.disabled' : '',
			this.readButtonLabel(element), '', '');
	}
	else if (_item.type === 'campaign')
	{
		var entry = this.readCampaignEntry(element);
		var state = entry.disabled ? 'dis' : (entry.selected ? 'sel' : '');
		this.sendAnnouncement('menu.campaign', entry.name, state, entry.day + '|' + entry.date);
	}
	else if (_item.type === 'popup-button')
	{
		this.sendAnnouncement('', this.readButtonLabel(element), '', '');
	}
	else if (_item.type === 'options-tab')
	{
		this.sendAnnouncement('menu.options.tab', this.readButtonLabel(element), '', '');
	}
	else if (_item.type === 'resolution')
	{
		this.sendAnnouncement('menu.options.value', this.readControlTitle(element),
			this.readButtonLabel(element), '');
	}
	else if (_item.type === 'slider')
	{
		this.sendAnnouncement('menu.options.percent', this.readOptionsSliderLabel(element),
			String(parseInt(element.val(), 10)), '');
	}
	else if (_item.type === 'radio')
	{
		label = this.readControlLabel(element);
		title = this.readControlTitle(element);
		selected = element.is(':checked');
		if (selected && (element.attr('name') || '') === 'scenario')
		{
			// .html(), not .text(): the description is XBBCODE output with
			// real <br>/<span> tags for paragraph breaks and styling, which
			// .text() would collapse into one run-on line. TextCleaner on
			// the companion side strips them before speech.
			detail = this.getActiveNewPanel().find('.row3.text-font-medium:first').html() || '';
		}
		this.sendAnnouncement(
			selected && detail.length > 0 ? 'menu.option.selected_detail' :
				(selected ? 'menu.option.selected' : 'menu.option.not_selected'),
			label,
			title,
			detail
		);
	}
	else if (_item.type === 'checkbox')
	{
		label = this.readControlLabel(element);
		this.sendAnnouncement(element.is(':checked') ? 'menu.checked' : 'menu.not_checked', label, '', '');
	}
	else if (_item.type === 'input')
	{
		this.sendAnnouncement('menu.value', element.val() || '', this.readControlTitle(element), '');
	}
	else if (_item.type === 'previous-banner')
	{
		this.sendAnnouncement('menu.previous_banner', '', '', '');
	}
	else if (_item.type === 'next-banner')
	{
		this.sendAnnouncement('menu.next_banner', '', '', '');
	}
};

UnseenBannerMenuNav.prototype.announceNewCampaignPage = function ()
{
	var titles = this.getNewCampaignTitles();
	this.sendAnnouncement('menu.screen', titles.dialog, titles.panel, '');
};

UnseenBannerMenuNav.prototype.stopEditing = function ()
{
	if (this.mEditingInput !== null)
	{
		var input = $(this.mEditingInput);
		input.off('keydown.unseenbanner');
		input.blur();
		this.mEditingInput = null;
	}
};

UnseenBannerMenuNav.prototype.startEditing = function (_item)
{
	var self = this;
	var element = _item.element;

	this.stopEditing();
	element.focus().select();
	this.mEditingInput = element[0];

	// While a text input holds DOM focus the engine sends the keyboard to the
	// DOM (that is how typing works) and Squirrel's onKeyInput stops firing,
	// so the keys that leave editing never reach our Squirrel hook. They must
	// be caught here, in the DOM, or the player is trapped in the field.
	// Enter and Escape both commit and return to navigation. stopPropagation
	// keeps Escape from bubbling up and closing the whole dialog.
	element.on('keydown.unseenbanner', function (_event)
	{
		var code = _event.which || _event.keyCode;
		if (code === 13 || code === 27)
		{
			_event.preventDefault();
			_event.stopPropagation();
			if (code === 13)
			{
				self.mEnterExitAt = (new Date()).getTime();
			}
			self.stopEditing();
			self.announceItem(_item);
		}
	});

	this.sendAnnouncement('menu.editing', element.val() || '', this.readControlTitle(element), '');
};

UnseenBannerMenuNav.prototype.activateItem = function (_item)
{
	var element = _item.element;
	var panelBefore;
	var panelAfter;

	if (_item.type === 'campaign')
	{
		// Clicking a row selects it (the game's handler marks it and enables the
		// footer buttons); the actual Load/Save is a separate press on that button,
		// so a stray Enter never loads or overwrites by accident.
		element.trigger('click');
		this.announceItem(_item);
		return;
	}

	if (_item.type === 'popup-button')
	{
		// Cancel dismisses; Ok confirms a delete (the game refreshes the list) — either
		// way the popup is gone afterwards, so drop back to the module and re-read it.
		element.trigger('click');
		this.closePopup(true);
		return;
	}

	if (_item.type === 'options-tab' || _item.type === 'resolution' || _item.type === 'slider')
	{
		// These settings are adjusted with Left / Right. Enter simply repeats the
		// current value so it never changes a setting unexpectedly.
		this.announceItem(_item);
		return;
	}

	if (_item.type === 'radio')
	{
		element.iCheck('check');
		this.announceItem(_item);
	}
	else if (_item.type === 'checkbox')
	{
		element.iCheck('toggle');
		this.announceItem(_item);
	}
	else if (_item.type === 'input')
	{
		if (this.mEditingInput === element[0])
		{
			this.stopEditing();
			this.announceItem(_item);
		}
		else
		{
			this.startEditing(_item);
		}
	}
	else if (_item.type === 'previous-banner' || _item.type === 'next-banner')
	{
		element.trigger('click');
		this.sendAnnouncement('menu.banner', this.readBanner(), '', '');
	}
	else if (_item.type === 'button')
	{
		if (element.is('[disabled]'))
		{
			// Load/Save/Delete before a save is chosen: nothing to do, just re-read it
			// so the player hears it is still unavailable.
			this.announceItem(_item);
			return;
		}

		if (this.mActiveModule === 'LoadCampaignModule' || this.mActiveModule === 'SaveCampaignModule')
		{
			element.trigger('click');
			// Save-on-New-Savegame and Delete open a popup synchronously; Load, Cancel
			// and overwrite-Save instead move to another module (handled by
			// onModuleShown/onModuleHidden), leaving no popup behind.
			var popup = this.detectPopup();
			if (popup !== null)
				this.openPopup(popup);
			return;
		}

		if (this.mActiveModule === 'OptionsMenuModule')
		{
			var isApply = element.closest('.l-apply-button').length > 0;
			element.trigger('click');
			// Ok and Cancel close the module and the incoming menu announces itself.
			// Apply stays on this screen, so it needs explicit confirmation.
			if (isApply)
				this.sendAnnouncement('menu.options.applied', '', '', '');
			return;
		}

		panelBefore = this.getActiveNewPanel();
		element.trigger('click');
		panelAfter = this.getActiveNewPanel();
		if (this.mActiveModule === 'NewCampaignModule' && panelBefore.length > 0 &&
			panelAfter.length > 0 && panelBefore[0] !== panelAfter[0])
		{
			this.mIndices.NewCampaignModule = -1;
			$('.unseen-banner-focus').removeClass('unseen-banner-focus');
			this.announceNewCampaignPage();
		}
	}
};

UnseenBannerMenuNav.prototype.onModuleShown = function (_id)
{
	if (!(_id in this.mIndices))
		return;

	this.stopEditing();
	this.mPopup = null;
	this.mPopupIndex = -1;
	this.mActiveModule = _id;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');

	if (_id === 'MainMenuModule')
	{
		var items = this.getMainItems();
		var index = this.mIndices.MainMenuModule;
		if (index < 0 || index >= items.length)
			index = 0;
		this.mIndices.MainMenuModule = index;
		if (items.length > 0)
		{
			this.focusItem(items[index]);
			this.sendAnnouncement('menu.main', this.readButtonLabel(items[index].element), '', '');
		}
	}
	else if (_id === 'NewCampaignModule')
	{
		this.mIndices.NewCampaignModule = -1;
		this.announceNewCampaignPage();
	}
	else if (_id === 'OptionsMenuModule')
	{
		this.mIndices.OptionsMenuModule = 0;
		var optionItems = this.getOptionsItems();
		if (optionItems.length > 0)
			this.focusItem(optionItems[0]);
		this.announceOptionsScreen();
	}
	else
	{
		this.mIndices[_id] = -1;
		this.announceCampaignScreen(_id);
	}
};

UnseenBannerMenuNav.prototype.onModuleHidden = function (_id)
{
	if (this.mActiveModule === _id)
	{
		this.stopEditing();
		this.mPopup = null;
		this.mPopupIndex = -1;
		this.mActiveModule = null;
		$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	}
};

UnseenBannerMenuNav.prototype.onStateExited = function ()
{
	this.stopEditing();
	this.mPopup = null;
	this.mPopupIndex = -1;
	this.mActiveModule = null;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
};

UnseenBannerMenuNav.prototype.setIndex = function (_inPopup, _index)
{
	if (_inPopup)
		this.mPopupIndex = _index;
	else
		this.mIndices[this.mActiveModule] = _index;
};

// Called from main_menu_state.onKeyInput, or the world/tactical equivalents,
// with "up", "down", "enter" and (for Options only) "left" / "right".
UnseenBannerMenuNav.prototype.onKeyForwarded = function (_name)
{
	// The Enter Name popup closes itself on the field's own Enter/Escape, with no
	// event we can hook; if we still think a popup is open but its DOM is gone, drop
	// the popup state first so this key resumes driving the module behind it.
	if (this.mPopup !== null && this.mPopup.dialog.closest('body').length === 0)
	{
		this.closePopup(true);
	}

	var inPopup = this.mPopup !== null;
	var items = this.getItems();
	var index;
	if (items.length === 0 || this.mActiveModule === null)
		return;

	index = inPopup ? this.mPopupIndex : this.mIndices[this.mActiveModule];
	if ((_name === 'left' || _name === 'right') && this.mActiveModule === 'OptionsMenuModule')
	{
		if (index < 0 || index >= items.length)
		{
			index = 0;
			this.setIndex(false, index);
			this.focusItem(items[index]);
			this.announceItem(items[index]);
			return;
		}
		this.adjustOptionsItem(items[index], _name === 'right' ? 1 : -1);
		return;
	}

	if (_name === 'enter')
	{
		// Swallow the key-release of the Enter that just left a text field,
		// which the engine may deliver to Squirrel now that the input is
		// blurred; without this it would immediately re-open the field. The
		// window auto-expires so a later, deliberate Enter still works.
		if (!inPopup && this.mEnterExitAt > 0 && ((new Date()).getTime() - this.mEnterExitAt) < 300)
		{
			this.mEnterExitAt = 0;
			return;
		}
		if (index < 0 || index >= items.length)
		{
			index = 0;
			this.setIndex(inPopup, index);
			this.focusItem(items[index]);
			this.announceItem(items[index]);
			return;
		}
		this.activateItem(items[index]);
		return;
	}

	if (_name !== 'up' && _name !== 'down')
		return;

	this.stopEditing();
	if (index < 0 || index >= items.length)
		index = 0;
	else if (_name === 'down')
		index = (index + 1) % items.length;
	else
		index = (index - 1 + items.length) % items.length;

	this.setIndex(inPopup, index);
	this.focusItem(items[index]);
	this.announceItem(items[index]);
};

registerScreen('UnseenBannerMenuNav', new UnseenBannerMenuNav());

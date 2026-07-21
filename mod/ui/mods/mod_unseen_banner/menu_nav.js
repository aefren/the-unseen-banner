// The Unseen Banner — keyboard cursor for the main menu and the complete
// New Campaign flow. ES3 only: Chromium 48, no let/const, arrows or template
// literals.
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
		NewCampaignModule: -1
	};
	this.mEditingInput = null;
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

UnseenBannerMenuNav.prototype.getItems = function ()
{
	if (this.mActiveModule === 'MainMenuModule')
		return this.getMainItems();
	if (this.mActiveModule === 'NewCampaignModule')
		return this.getNewCampaignItems();
	return [];
};

UnseenBannerMenuNav.prototype.focusItem = function (_item)
{
	var focusTarget = _item.element;
	if (_item.type === 'radio' || _item.type === 'checkbox')
	{
		focusTarget = _item.element.parent();
	}

	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	focusTarget.addClass('unseen-banner-focus');

	var list = _item.element.closest('.ui-control.list');
	if (list.length > 0 && typeof list.scrollListToElement === 'function')
	{
		list.scrollListToElement(_item.element.closest('.control'));
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
		this.sendAnnouncement('', this.readButtonLabel(element), '', '');
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
	if (_id !== 'MainMenuModule' && _id !== 'NewCampaignModule')
		return;

	this.stopEditing();
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
	else
	{
		this.mIndices.NewCampaignModule = -1;
		this.announceNewCampaignPage();
	}
};

UnseenBannerMenuNav.prototype.onModuleHidden = function (_id)
{
	if (this.mActiveModule === _id)
	{
		this.stopEditing();
		this.mActiveModule = null;
		$('.unseen-banner-focus').removeClass('unseen-banner-focus');
	}
};

UnseenBannerMenuNav.prototype.onStateExited = function ()
{
	this.stopEditing();
	this.mActiveModule = null;
	$('.unseen-banner-focus').removeClass('unseen-banner-focus');
};

// Called from main_menu_state.onKeyInput with "up", "down" or "enter".
UnseenBannerMenuNav.prototype.onKeyForwarded = function (_name)
{
	var items = this.getItems();
	var index;
	if (items.length === 0 || this.mActiveModule === null)
		return;

	index = this.mIndices[this.mActiveModule];
	if (_name === 'enter')
	{
		// Swallow the key-release of the Enter that just left a text field,
		// which the engine may deliver to Squirrel now that the input is
		// blurred; without this it would immediately re-open the field. The
		// window auto-expires so a later, deliberate Enter still works.
		if (this.mEnterExitAt > 0 && ((new Date()).getTime() - this.mEnterExitAt) < 300)
		{
			this.mEnterExitAt = 0;
			return;
		}
		if (index < 0 || index >= items.length)
		{
			index = 0;
			this.mIndices[this.mActiveModule] = index;
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

	this.mIndices[this.mActiveModule] = index;
	this.focusItem(items[index]);
	this.announceItem(items[index]);
};

registerScreen('UnseenBannerMenuNav', new UnseenBannerMenuNav());

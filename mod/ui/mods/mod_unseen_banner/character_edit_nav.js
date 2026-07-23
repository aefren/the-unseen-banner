// The Unseen Banner — keyboard entry into CharacterScreen's native name editor.
// ES3 only: Chromium 48, no let/const, arrows or template literals.
//
// Text fields are one of the few controls to which the engine delivers keyboard
// input. Squirrel asks this bridge to click the already-existing name header;
// vanilla builds its Change Name & Title popup and ultimately calls
// onUpdateNameAndTitle. We select the current name so typing replaces it, while
// leaving the existing title untouched.

var UnseenBannerCharacterEdit = function ()
{
	this.mSQHandle = null;
	this.mCompletionReported = false;
	this.mPopupRoot = null;
};

UnseenBannerCharacterEdit.prototype.onConnection = function (_handle)
{
	this.mSQHandle = _handle;
};

UnseenBannerCharacterEdit.prototype.onDisconnection = function ()
{
	this.mSQHandle = null;
	this.mCompletionReported = false;
	this.mPopupRoot = null;
};

UnseenBannerCharacterEdit.prototype.reportUnavailable = function ()
{
	if (this.mSQHandle !== null)
	{
		SQ.call(this.mSQHandle, 'onEditorUnavailable');
	}
};

UnseenBannerCharacterEdit.prototype.finish = function (_saved, _name)
{
	if (this.mCompletionReported)
	{
		return;
	}

	this.mCompletionReported = true;
	this.mPopupRoot = null;
	if (this.mSQHandle !== null)
	{
		SQ.call(this.mSQHandle, 'onEditorClosed', {
			saved: _saved === true,
			name: _name || ''
		});
	}
};

UnseenBannerCharacterEdit.prototype.watchForClose = function (_root)
{
	var self = this;
	window.setTimeout(function ()
	{
		if (self.mCompletionReported)
		{
			return;
		}

		if (_root === null || _root.length === 0 ||
			!document.documentElement.contains(_root[0]))
		{
			// A disappearance not already reported by the Ok button is the native
			// Cancel/Escape path.
			self.finish(false, '');
			return;
		}

		self.watchForClose(_root);
	}, 50);
};

UnseenBannerCharacterEdit.prototype.selectNativeBrother = function (_entityId)
{
	if (typeof Screens === 'undefined' ||
		!('WorldCharacterScreen' in Screens))
	{
		return false;
	}

	var screen = Screens.WorldCharacterScreen;
	var dataSource = screen !== null ? screen.getModule('DataSource') : null;
	if (dataSource === null)
	{
		return false;
	}

	// SheetNav advances in Squirrel while the native switch reaches this datasource
	// asynchronously. Select again by stable entity ID immediately before opening
	// the popup, then verify it; otherwise a fast Enter can rename the previous man.
	dataSource.selectedBrotherById(_entityId);
	var selected = dataSource.getSelectedBrother();
	return selected !== null &&
		CharacterScreenIdentifier.Entity.Id in selected &&
		'' + selected[CharacterScreenIdentifier.Entity.Id] === '' + _entityId;
};

UnseenBannerCharacterEdit.prototype.openNameEditor = function (_data)
{
	var self = this;
	if (_data === null || typeof _data !== 'object' ||
		!('entityId' in _data) ||
		!this.selectNativeBrother(_data.entityId))
	{
		this.reportUnavailable();
		return;
	}

	var nameContainer = $('.character-screen .left-panel-header-module ' +
		'.name-container.is-clickable:visible:first');
	if (nameContainer.length === 0)
	{
		this.reportUnavailable();
		return;
	}

	this.mCompletionReported = false;
	nameContainer.trigger('click');

	var popup = $('.character-screen .popup-dialog.change-name-and-title-popup:first');
	if (popup.length === 0)
	{
		this.reportUnavailable();
		return;
	}

	var root = popup.parent();
	var inputs = popup.find('.content input');
	if (inputs.length < 1)
	{
		this.reportUnavailable();
		return;
	}

	this.mPopupRoot = root;
	var nameInput = $(inputs[0]);
	var okButton = root.findPopupDialogOkButton();
	nameInput.on('keydown.unseenBannerCharacterEdit', function (_event)
	{
		var code = _event.which || _event.keyCode;
		if (code === 13 && self.mSQHandle !== null)
		{
			// Vanilla saves on this press. Tell Squirrel to consume the matching
			// release after the popup disappears, or world_state would interpret it
			// as a second request to open the editor.
			SQ.call(self.mSQHandle, 'onEditorConfirming');
		}
	});
	if (okButton !== null && okButton.length > 0)
	{
		okButton.on('click.unseenBannerCharacterEdit', function ()
		{
			self.finish(true, nameInput.getInputText());
		});
	}

	// Vanilla already focuses this field. Selecting its contents makes the
	// accessible flow simply: type the replacement, press Enter.
	nameInput.focus();
	if (inputs[0].select)
	{
		inputs[0].select();
	}

	if (this.mSQHandle !== null)
	{
		SQ.call(this.mSQHandle, 'onEditorOpened');
	}
	this.watchForClose(root);
};

registerScreen("UnseenBannerCharacterEdit", new UnseenBannerCharacterEdit());

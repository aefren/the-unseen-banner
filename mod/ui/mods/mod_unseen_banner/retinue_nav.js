// The Unseen Banner — keeps the visible Retinue screen aligned with the
// Squirrel-side keyboard cursor. ES3 only: the embedded Chromium is version 48.
//
// Keyboard input never reaches this DOM. world_state forwards it to Squirrel,
// which owns the semantic list and calls these two tiny methods after changing
// focus. Actions still go through the native Squirrel modules; this file only
// mirrors focus for sighted testing and scrolls the chosen follower into view.

if (typeof WorldCampfireScreenMainDialogModule !== 'undefined')
{
	WorldCampfireScreenMainDialogModule.prototype.setAccessibilityFocus = function (_data)
	{
		$('.world-campfire-screen .unseen-banner-focus').removeClass('unseen-banner-focus');

		if (_data === null || typeof _data !== 'object' || !('Type' in _data))
		{
			return;
		}

		var target = null;
		if (_data.Type === 'cart')
		{
			target = this.mDialogContainer.findDialogContentContainer()
				.find('.cart:not(.no-pointer-events):first');
		}
		else if (_data.Type === 'slot' && 'Index' in _data)
		{
			target = this.mDialogContainer.findDialogContentContainer()
				.find('.slot' + _data.Index + ':not(.no-pointer-events):first');
		}

		if (target !== null && target.length > 0)
		{
			target.addClass('unseen-banner-focus');
		}
	};
}

if (typeof WorldCampfireScreenHireDialogModule !== 'undefined')
{
	WorldCampfireScreenHireDialogModule.prototype.setAccessibilityFocus = function (_index)
	{
		$('.world-campfire-screen .unseen-banner-focus').removeClass('unseen-banner-focus');

		if (this.mListContainer === null)
		{
			return;
		}

		if (_index < 0)
		{
			this.selectListEntry(null, false);
			return;
		}

		var entry = this.mListContainer.findListEntryByIndex(_index);
		if (entry !== null && entry.length > 0)
		{
			this.selectListEntry(entry, true);
			entry.addClass('unseen-banner-focus');
		}
	};
}

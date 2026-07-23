// The Unseen Banner — visual suspension for the accessible pre-combat
// formation overlay. ES3 only: Chromium 48, no let/const, arrows or template
// literals.
//
// Squirrel keeps WorldCombatDialog logically visible while CharacterScreen is
// layered over it, because the encounter owns the current MenuStack entry. Hide
// only its DOM container during that overlay so its modal background cannot sit
// above the later screen or intercept mouse input. This deliberately bypasses
// WorldCombatDialog.hide(): no animation callbacks or encounter state change
// should occur until the native engage/retreat action actually closes it.

if (typeof WorldCombatDialog !== 'undefined')
{
	WorldCombatDialog.prototype.setAccessibilityFormationOverlay = function (_active)
	{
		if (this.mContainer === null)
		{
			return;
		}

		if (_active === true)
		{
			this.mContainer.removeClass('display-block').addClass('display-none');
		}
		else
		{
			this.mContainer.removeClass('display-none').addClass('display-block');
		}
	};
}

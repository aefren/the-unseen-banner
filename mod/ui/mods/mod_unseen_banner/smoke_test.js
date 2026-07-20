// The Unseen Banner — smoke test for phase 0.2.
// ES3 only: Chromium 48, no let/const, no arrows, no template literals.
// Proves the JS was injected by calling back into Squirrel once connected.

var UnseenBannerConnection = function ()
{
	this.mSQHandle = null;
};

UnseenBannerConnection.prototype.onConnection = function (_handle)
{
	this.mSQHandle = _handle;
	SQ.call(this.mSQHandle, "onJSLoaded");
};

UnseenBannerConnection.prototype.onDisconnection = function ()
{
	this.mSQHandle = null;
};

registerScreen("UnseenBannerConnection", new UnseenBannerConnection());

local Config = {
	_CONFIG_VER = "PRISM_0.9.1", -- make sure to change this value at least between major releases.
	
	BrowserDisplayName = "Prism", -- short name for the browser, used for error codes (such as {THIS_VALUE}_GENERIC_ERROR)
	Version = "0.9.1-beta", -- internal version of your browser's ui
	DisplayVersion = "0.9.1 (Beta)", -- displayed version of your browser's ui
	DefaultSearchEngineConfig = { -- used in the url bar & on the default new tab page.
		name = "BlueFinder",
		urlFormat = "bluefind.er/search?q=%s"
	},
	BrowserPagesProtocol = "prism://%s", -- protocol for the pages bundled with the browser
	DefaultTabsForActions = { -- substitutes for the '%s' in BrowserPagesProtocol
		NewTab = "new-tab",
		NotFound = "not-found",
		About = "about",
	},
	DefaultFavicon = "rbxassetid://137354814227470" -- favicon used by default on integrated pages.
}

return require(script.Parent.ConfigLoader)(Config) -- create compatible configuration files, (almost) regardless of its origin version
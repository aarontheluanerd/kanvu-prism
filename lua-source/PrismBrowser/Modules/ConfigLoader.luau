
local DefaultConfig = {
	_CONFIG_VER = "PRISM_0.9.0",
	
	BrowserDisplayName = "Prism",
	Version = "0.9.0-beta",
	DisplayVersion = "0.9.0 (Beta)",
	DefaultSearchEngineConfig = {
		name = "BlueFinder",
		urlFormat = "bluefind.er/search?q=%s"
	},
	BrowserPagesProtocol = "prism://%s",
	DefaultTabsForActions = { -- substitutes for the '%s' in BrowserPagesProtocol
		NewTab = "new-tab",
		NotFound = "not-found",
		About = "about",
	},
	DefaultFavicon = "rbxassetid://137354814227470"
}

-- Creates a compatible table from a unreliable table and a reliable table (mostly a template), if an index doesn't exist (or is a different type), it will be filled with the reliable table's index and value. It also allows for an optional index blacklist, of which the function will ignore indexes in said blacklist.
function CreateCompatibleTable(UnreliableTable : {[any] : any}, ReliableTable : {[any] : any}, IndexBlacklist : {string}?) : {[any] : any}

	local result = {}

	if IndexBlacklist == nil then IndexBlacklist = {} end

	for n,v in pairs(ReliableTable) do

		if type(v) ~= "table" then
			if UnreliableTable[n] ~= nil and typeof(UnreliableTable[n]) == typeof(ReliableTable[n]) or table.find(IndexBlacklist, n) then
				result[n] = UnreliableTable[n]
			else
				result[n] = ReliableTable[n]
			end
		else

			if UnreliableTable[n] ~= nil and not table.find(IndexBlacklist, n) then
				result[n] = CreateCompatibleTable(UnreliableTable[n], ReliableTable[n])
			elseif UnreliableTable[n] == nil then 
				result[n] = ReliableTable[n]
			else
				result[n] = UnreliableTable[n]
			end

		end

	end

	return result

end

return function(target : {[any] : any}) : {[any] : any}
	return CreateCompatibleTable(target, DefaultConfig)
end
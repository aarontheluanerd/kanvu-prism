--!nonstrict
-- READ BELOW!
--[[
	When implementing this, don't forget to add a way to store cookies & bookmarks.
	Sorry for any bad code, this is just a guide on how to "properly" implement the Prism WebView Engine.
	But using it as a browser base is fine, too.
	
	Just don't forget to credit the WebView Engine version.
	(just showing it on an obscure "browser://about" page is fine)
]]

local Loader = require(script.PrismWebViewEngine)
local DefaultTabInitializer = require(script.DefaultTabInitializer)
local StandaloneFunctions = require(script.StandaloneFunctions)
local Strings = require(script.Strings)
local Animations = require(script.Animations)

local FeatureFlags = require(script.FeatureFlags)
local FeatureFlagBehavior = require(script.FeatureFlagBehavior)

local BrowserConfig = require(script.Config)				

local cookieStorage = {}
local bookmarksData = {}

local plr = game.Players.LocalPlayer
local mouse = plr:GetMouse()

local TS = game.TweenService
local TabDataStorage  : {{
	CurrentURL : string,
	TabId : string,
	Frame : GuiObject,
	TabInstance : typeof(script.tabTemplate),
	History : {string},
	TabLoadingAnimator : typeof(require(script.tabTemplate.loading.animator)),
	CurrentHistoryIndex : number,
	IsTabDestructive : boolean,
}} = {}
setmetatable(TabDataStorage, {
	__len = function()
		local number = 0
		for _ in pairs(TabDataStorage) do
			number += 1
		end
		return number
	end	
})
local UIS = game:GetService("UserInputService")

setmetatable(TabDataStorage, {
	__len = function()
		local number = 0
		for _ in pairs(TabDataStorage) do
			number += 1
		end
		return number
	end	
})

-- built-in browser pages protocol builder

local function getBrowserPage(sub : string)
	return string.format(BrowserConfig.BrowserPagesProtocol, sub)
end

local tabSelectCache = {}

local CurrentVisibleTab = nil
local _LastVisibleTab = nil
local _LastVisibleURL = nil

script:WaitForChild("DefaultTabs")
script.Parent:WaitForChild("initialize")

local defaultTabData = { -- configuration for default tabs
	[getBrowserPage(BrowserConfig.DefaultTabsForActions.NotFound)] = {
		Favicon = BrowserConfig.DefaultFavicon,
		Title = "Not Found",
		url = "any",
		Contents = script.DefaultTabs["not-found"],
		SiteBackgroundColor3 = Color3.new(0,0,0),
		RefreshSiteOnNewURL = true,
	},
	[getBrowserPage(BrowserConfig.DefaultTabsForActions.About)] = {
		Favicon = BrowserConfig.DefaultFavicon,
		Title = "About {browser_name}",
		url = getBrowserPage(BrowserConfig.DefaultTabsForActions.About),
		Contents = script.DefaultTabs.about,
		SiteBackgroundColor3 = Color3.new(0,0,0),
		RefreshSiteOnNewURL = true,
	},
	[getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab)] = {
		Favicon = BrowserConfig.DefaultFavicon,
		Title = "New Tab",
		url = getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab),
		Contents = script.DefaultTabs["new-tab"],
		SiteBackgroundColor3 = Color3.new(0,0,0),
		RefreshSiteOnNewURL = true,
	},
}
local accesibleDefaultTabs = { -- default tabs users can type into the url bar and access
	getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab),
	getBrowserPage(BrowserConfig.DefaultTabsForActions.About),
}

local DefaultHTTPErrorCodes = {
	[404] = "{browser_name}_NOT_FOUND",
	Generic = "{browser_name}_GENERIC_ERROR"
}

-- replace {browser_name} in default http error codes & default tab titles

for _, v in pairs(DefaultHTTPErrorCodes) do
	v = string.gsub(v, "{browser_name}", string.upper(BrowserConfig.BrowserDisplayName))
end

for _, v in pairs(defaultTabData) do
	v.Title = string.gsub(v.Title, "{browser_name}", BrowserConfig.BrowserDisplayName)
end

local UI = script.Parent:WaitForChild("mainGui")

for _,v in pairs(script.Parent:GetChildren()) do
	if v:IsA("GuiObject") then
		v.Visible = false
	end
end

for _, v in pairs(script.Parent.mainGui:GetChildren()) do
	if v:IsA("GuiObject") then
		v.Visible = false
	end
end

UI.webview:ClearAllChildren()
Animations.BrowserStartupEnter(script.Parent.initialize)

FeatureFlagBehavior.apply(FeatureFlags)

-- some stuff that must be loaded

local assetTypeCheckInstances = script.Parent:WaitForChild("assetTypeCheckInstances")

-- load webview

local WebView = Loader.new({
	DefaultFavicon = BrowserConfig.DefaultFavicon,
	OnCookieGet = function(requestingFrame : Frame, cookieName : string)

		local requestingTab = nil

		for _, tab in pairs(TabDataStorage) do
			if tab.Frame == requestingFrame then
				requestingTab = tab
				break
			end
		end

		if not requestingTab then return end

		local domain = string.split(string.lower(requestingTab.CurrentURL), "/")[1]

		for GUID, cookie in pairs(cookieStorage) do
			if cookieName == cookie.Name and table.find(cookie.applyingDomains, domain) then
				return cookie.Contents
			end
		end

		return nil

	end,
	OnCookieSet = function(requestingFrame : Frame, cookieName : string, value : string, applyingDomains : {string})

		local requestingTab = nil

		for _, tab in pairs(TabDataStorage) do
			if tab.Frame == requestingFrame then
				requestingTab = tab
				break
			end
		end

		if not requestingTab then return false end

		local domain = string.split(string.lower(requestingTab.CurrentURL), "/")[1]

		for GUID, cookie in pairs(cookieStorage) do
			if cookieName == cookie.Name and table.find(cookie.applyingDomains, domain) then
				cookieStorage[GUID] = {
					Name = cookieName,
					applyingDomains = applyingDomains,
					Contents = value,
				}
				return true
			end
		end

		local cookieGUID = game.HttpService:GenerateGUID(false)

		cookieStorage[cookieGUID] = {
			Name = cookieName,
			applyingDomains = applyingDomains,
			Contents = value,
		}

		return true

	end,
	OnHTTPGet = function(requestingFrame : Frame, url : string, parameters : {})
		return game.ReplicatedStorage.HTTP.GET:InvokeServer(url, parameters)
	end,
	OnHTTPPost = function(requestingFrame : Frame, url : string, parameters : {})
		return game.ReplicatedStorage.HTTP.POST:InvokeServer(url, parameters)
	end,
})

-- essential functions

sanitizeURL = StandaloneFunctions.SanitizeURL
urlDecode = StandaloneFunctions.UrlDecode
extractParametersFromURL = StandaloneFunctions.ExtractParametersFromURL

getContentsFromUrl = require(script.GetContentsFromURL).new(UI, defaultTabData, getBrowserPage, DefaultTabInitializer, accesibleDefaultTabs, DefaultHTTPErrorCodes, BrowserConfig, assetTypeCheckInstances)

local function closeTab(tabId : string)
	local tabData = TabDataStorage[tabId]
	if tabData then
		if tabData.Frame then
			tabData.Frame:Destroy()
		end
		if tabData.TabInstance then
			Animations.OnTabClose(tabData.TabInstance)
		end
		if table.find(tabSelectCache, tabId) then
			table.remove(tabSelectCache, table.find(tabSelectCache, tabId))
		end
		CurrentVisibleTab = tabSelectCache[#tabSelectCache]
		TabDataStorage[tabId] = nil
	end
end

local function loadTab(url : string, intent : "New" | "Back" | "Forward" | "Reload" | "ForwardNew", destructive : boolean?, tabId : string?)

	if url == "" then
		return
	end

	local tabData = {
		CurrentURL = url,
		TabId = tabId,
		Frame = nil,
		TabInstance = nil,
		TabLoadingAnimator = nil,
		History = {url},
		CurrentHistoryIndex = 1,
		IsTabDestructive = true,
	}

	if intent == "New" then
		destructive = true
		tabId = game.HttpService:GenerateGUID(false)
		intent = "New"
	elseif tabId ~= nil then
		local existingTabData = TabDataStorage[tabId]
		if existingTabData and intent ~= "New" then
			local oldURL = existingTabData.CurrentURL
			existingTabData.CurrentURL = url

			do -- compare domains to make sure if destructive is set properly

				local newDomain = string.split(string.lower(sanitizeURL(url)), "/")[1]
				local oldDomain = string.split(string.lower(sanitizeURL(oldURL)), "/")[1]

				if destructive == true or newDomain ~= oldDomain then
					destructive = true
				else
					destructive = existingTabData.IsTabDestructive
				end

			end

			if intent == "Forward" or intent == "ForwardNew" then

				if existingTabData.History[existingTabData.CurrentHistoryIndex + 1] and existingTabData.History[existingTabData.CurrentHistoryIndex + 1] ~= url then
					local newHistory = {}

					for i, url in pairs(existingTabData.History) do
						if i <= existingTabData.CurrentHistoryIndex then
							table.insert(newHistory, i, url)
						else
							break
						end
					end

					existingTabData.History = newHistory -- new history to avoid data conflicts with new urls on past positions
				end

				existingTabData.CurrentHistoryIndex += 1
				if existingTabData.History[existingTabData.CurrentHistoryIndex+1] == nil and (intent == "ForwardNew" or intent == "ForwardNewUI") then
					table.insert(existingTabData.History, existingTabData.CurrentHistoryIndex, url)
				end	

			elseif intent == "Back" and existingTabData.History[existingTabData.CurrentHistoryIndex-1] then
				existingTabData.CurrentHistoryIndex -= 1
			end

			tabData = existingTabData

		else	-- treat as new tab
			destructive = true
			tabId = game.HttpService:GenerateGUID(false)
			intent = "New"
		end
	else
		destructive = true
		tabId = game.HttpService:GenerateGUID(false)
		intent = "New"
	end

	tabData.TabId = tabId

	if UI.webview:FindFirstChild(tabId) and destructive ~= false then
		UI.webview[tabId]:Destroy()
	end

	if intent == "New" then
		IsURLBookmarked(url, true)
		CurrentVisibleTab = tabId
		if table.find(tabSelectCache, tabId) then
			table.remove(tabSelectCache, table.find(tabSelectCache, tabId))
		end
		table.insert(tabSelectCache, tabId)
	end

	if tabData.TabInstance == nil then
		tabData.TabInstance = script.tabTemplate:Clone()
		tabData.TabInstance.Name = tabId
		tabData.TabInstance.title.Text= url
		tabData.TabInstance.ico.Image = "rbxassetid://137354814227470"
		tabData.TabInstance.Parent = UI.tabsContainer
		tabData.TabLoadingAnimator = require(tabData.TabInstance.loading.animator)
		tabData.TabInstance.close.MouseButton1Click:Connect(function()
			closeTab(tabId)
		end)
		tabData.TabInstance.mainClick.MouseButton1Click:Connect(function()
			CurrentVisibleTab = tabId
			if table.find(tabSelectCache, tabId) then
				table.remove(tabSelectCache, table.find(tabSelectCache, tabId))
			end
			table.insert(tabSelectCache, tabId)
		end)
		tabData.TabInstance.mainClick.MouseButton2Click:Connect(function()
			openContextMenu("TabButton", tabId)
		end)
		Animations.OnNewTab(tabData.TabInstance)
	end

	local uiTab = tabData.TabInstance
	uiTab.ico.Size = UDim2.fromOffset(20,20)
	uiTab.ico.UICorner.CornerRadius = UDim.new(0,0)
	tabData.TabLoadingAnimator.onEnter()
	uiTab.loading.Visible = true
	TS:Create(uiTab.ico, TweenInfo.new(.15, Enum.EasingStyle.Linear), {Size = UDim2.fromOffset(15,15)}):Play()
	TS:Create(uiTab.ico.UICorner, TweenInfo.new(.15, Enum.EasingStyle.Linear), {CornerRadius = UDim.new(1,0)}):Play()

	TabDataStorage[tabId] = tabData

	local Frame, Status = getContentsFromUrl(url, tabId)

	if UI.webview:FindFirstChild(tabId) and Frame ~= UI.webview:FindFirstChild(tabId) then
		UI.webview[tabId]:Destroy()
	end

	if type(Frame) == "number" then
		defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NotFound)].Contents.errorCode.Text = string.format(Strings.ui.errorPage.errorCodeFormat, Status or DefaultHTTPErrorCodes[Frame] or DefaultHTTPErrorCodes.Generic)
		Frame = defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NotFound)]
		Frame.url = url
	end

	local LoadedFrame = nil

	if tabData.Frame == nil or destructive then

		if type(Frame) == "table" then

			if Frame.Contents:IsA("VideoFrame") then
				local videoContent = Frame.Contents.VideoContent
				local newVideoViewer = script.DefaultTabs["video-viewer"]:Clone()
				DefaultTabInitializer.InitializeTab(newVideoViewer)
				newVideoViewer.VideoFrame.VideoContent = videoContent
				Frame.SiteBackgroundColor3 = Color3.new(0,0,0)
				Frame.Contents = newVideoViewer
			elseif Frame.Contents:IsA("Decal") then
				local imageContent = Frame.Contents.ColorMapContent
				local newImageViewer = script.DefaultTabs["image-viewer"]:Clone()
				DefaultTabInitializer.InitializeTab(newImageViewer)
				newImageViewer.ImageLabel.ImageContent = imageContent
				Frame.SiteBackgroundColor3 = Color3.new(0,0,0)
				Frame.Contents = newImageViewer
			elseif Frame.Contents:IsA("Sound") then
				local soundContent = Frame.Contents.SoundId
				local newAudioPlayer = script.DefaultTabs["audio-player"]:Clone()
				DefaultTabInitializer.InitializeTab(newAudioPlayer)
				newAudioPlayer.SoundFrame.Sound.SoundId = soundContent
				Frame.SiteBackgroundColor3 = Color3.new(0,0,0)
				Frame.Contents = newAudioPlayer
			end

			if string.split(tabData.CurrentURL, "?")[2] ~= nil and string.split(Frame.url , "?")[2] == nil then
				tabData.CurrentURL = Frame.url .. (string.split(tabData.CurrentURL, "?")[2] and ("?" .. string.split(tabData.CurrentURL, "?")[2]) or "")
				Frame.url = Frame.url .. (string.split(tabData.CurrentURL, "?")[2] and ("?" .. string.split(tabData.CurrentURL, "?")[2]) or "")
			else
				tabData.CurrentURL = Frame.url
			end

			local temp = WebView.LoadFromPrismWebData(Frame, UI.webview)
			if not Frame.Favicon or Frame.Favicon == "" then
				Frame.Favicon = "rbxassetid://123070198843762"
			end
			tabData.TabInstance.title.Text= Frame.Title
			tabData.TabInstance.ico.Image = Frame.Favicon
			tabData.IsTabDestructive = Frame.RefreshSiteOnNewURL
			LoadedFrame = temp
		elseif Frame:IsA("GuiObject") then
			local temp = WebView.TranslateInstanceToPrismWebData(Frame, {
				url = url,
				SiteBackgroundColor3 = Frame.BackgroundColor3,
			})
			tabData.TabInstance.title.Text= temp.Title
			tabData.TabInstance.ico.Image = temp.Favicon
			tabData.IsTabDestructive = temp.RefreshSiteOnNewURL
			local temp2 = WebView.LoadFromPrismWebData(temp, UI.webview)
			LoadedFrame = temp
		end

	else -- this is a tab with already existing data. (since empty tabs are destructive always)
		tabData.Frame.OnLoaded:Fire(url, extractParametersFromURL(url))
		LoadedFrame = tabData.Frame
	end

	tabData.Frame = LoadedFrame
	LoadedFrame.Name = tabId

	tabData.TabLoadingAnimator.onExit()
	TS:Create(uiTab.ico, TweenInfo.new(.15, Enum.EasingStyle.Linear), {Size = UDim2.fromOffset(20,20)}):Play()
	TS:Create(uiTab.ico.UICorner, TweenInfo.new(.15, Enum.EasingStyle.Linear), {CornerRadius = UDim.new(0,0)}):Play()

	TabDataStorage[tabId] = tabData

end

--hovers

local function toggleHover(hover : string | Frame, override : boolean?)

	if not hover then return end

	if type(hover) == "string" then
		hover = UI.hoverContainer:FindFirstChild(hover)
		if not hover then
			return
		end
	end

	local vis = hover.Visible

	for _,v in pairs(UI.hoverContainer:GetChildren()) do
		if v:IsA("GuiObject") then
			v.Visible = false
		end
	end
	UI.hoverContainer.Visible = true

	local visibility = nil
	if override == nil then
		visibility = not vis
	else
		visibility = override
	end

	if visibility then
		Animations.HoverOpened(hover.Name, hover)
	else
		Animations.HoverClosed(hover.Name, hover)
	end

end

UI.hoverContainer.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		for _,v in pairs(UI.hoverContainer:GetChildren()) do
			if v:IsA("GuiObject") then
				v.Visible = false
			end
		end
		UI.hoverContainer.Visible = false
	end
end)

-- context menu handling

local _lastButtonLink = ""
local _lastTabId = ""
local _lastBookmarkURL = ""
local BrowsingContextMenu = UI.hoverContainer.browsingContextMenu
local TabContextMenu = UI.hoverContainer.tabContextMenu
local BookmarkEditMenu = UI.hoverContainer.bookmarkEditMenu

local TargetContextMenus = { -- BrowsingContextMenu is used by default
	TabButton = TabContextMenu,
	BookmarkEdit = BookmarkEditMenu,
}

function openContextMenu(intent : "Open" | "LinkButton" | "TabButton" | "BookmarkEdit"?, url : string?)
	if intent == nil then intent = "Open" end

	local contextMenu = TargetContextMenus[intent] or BrowsingContextMenu

	local currTab = TabDataStorage[CurrentVisibleTab]
	local pos = UDim2.fromOffset(mouse.X-UI.AbsolutePosition.X, mouse.Y  - UI.AbsolutePosition.Y)

	if pos.Y.Offset <= UI.topbarbg.Size.Y.Offset and TargetContextMenus[intent] == nil then -- browsing context menu
		return
	end

	if contextMenu == BrowsingContextMenu then
		if intent == "LinkButton" then
			_lastButtonLink = url
		else
			_lastButtonLink = ""
		end

		contextMenu.forward.Visible = currTab.History[currTab.CurrentHistoryIndex + 1] ~= nil
		contextMenu.back.Visible = currTab.History[currTab.CurrentHistoryIndex - 1] ~= nil
		contextMenu.linkButtonDiv.Visible = intent == "LinkButton"
		contextMenu.openinnewtab.Visible = intent == "LinkButton"
		contextMenu.open.Visible = intent == "LinkButton"
	elseif contextMenu == TabContextMenu then
		local targetTabData = TabDataStorage[url] -- url argument here is repurposed into tabid
		_lastTabId = url
		contextMenu.closeothertabs.Visible = #TabDataStorage > 1
	elseif contextMenu == BookmarkEditMenu then
		local existingBookmark = IsURLBookmarked(currTab.CurrentURL)
		if not existingBookmark then
			AddBookmark(currTab.CurrentURL, currTab.TabInstance.title.Text, currTab.TabInstance.ico.Image)
			BookmarkEditMenu.title.Text = "Bookmark Added"
		else
			BookmarkEditMenu.title.Text = "Edit Bookmark"
		end
		_lastBookmarkURL = currTab.CurrentURL
		local currBookmarkData = bookmarksData[currTab.CurrentURL]
		BookmarkEditMenu.bookmarkName.input.Text = currBookmarkData.title
		BookmarkEditMenu.bookmarkURL.input.Text = currTab.CurrentURL
		toggleHover(contextMenu, true)
		return
	end

	local scale = 1 -- change to any affecting UIScale value here

	contextMenu.Position = UDim2.fromOffset(pos.X.Offset/scale, pos.Y.Offset/scale)

	local xAnchor = 0
	local yAnchor = 0

	if pos.Y.Offset > UI.AbsoluteSize.Y - contextMenu.AbsoluteSize.Y then
		yAnchor = 1-((UI.AbsoluteSize.Y-pos.Y.Offset)/contextMenu.AbsoluteSize.Y)
	end
	if pos.X.Offset > UI.AbsoluteSize.X - contextMenu.AbsoluteSize.X then
		xAnchor = 1-((UI.AbsoluteSize.X-pos.X.Offset)/contextMenu.AbsoluteSize.X)
	end

	contextMenu.AnchorPoint = Vector2.new(xAnchor,yAnchor)

	toggleHover(contextMenu, true)

end

do -- browsing context menu connections

	BrowsingContextMenu.forward.MouseButton1Click:Connect(function()
		toggleHover("browsingContextMenu", false)
		local currTab = TabDataStorage[CurrentVisibleTab]
		if currTab.History[currTab.CurrentHistoryIndex + 1] ~= nil then
			loadTab(currTab.History[currTab.CurrentHistoryIndex + 1], "Forward", currTab.IsTabDestructive, CurrentVisibleTab)
		end
	end)
	BrowsingContextMenu.back.MouseButton1Click:Connect(function()
		toggleHover("browsingContextMenu", false)
		local currTab = TabDataStorage[CurrentVisibleTab]
		if currTab.History[currTab.CurrentHistoryIndex - 1] ~= nil then
			loadTab(currTab.History[currTab.CurrentHistoryIndex - 1], "Back", currTab.IsTabDestructive, CurrentVisibleTab)
		end
	end)
	BrowsingContextMenu.reload.MouseButton1Click:Connect(function()
		toggleHover("browsingContextMenu", false)
		loadTab(TabDataStorage[CurrentVisibleTab].CurrentURL, "Reload", true, CurrentVisibleTab)
	end)
	BrowsingContextMenu.about.MouseButton1Click:Connect(function()
		toggleHover("browsingContextMenu", false)
		loadTab(getBrowserPage(BrowserConfig.DefaultTabsForActions.About), "New", true)
	end)

	BrowsingContextMenu.openinnewtab.MouseButton1Click:Connect(function()
		toggleHover("browsingContextMenu", false)
		if _lastButtonLink ~= "" then
			loadTab(_lastButtonLink, "New", true)
		end
	end)

	BrowsingContextMenu.open.MouseButton1Click:Connect(function()
		toggleHover("browsingContextMenu", false)
		if _lastButtonLink ~= "" then
			loadTab(_lastButtonLink, "ForwardNew", true, CurrentVisibleTab)
		end
	end)

end

do -- tab context menu connections

	TabContextMenu.closetab.MouseButton1Click:Connect(function()
		toggleHover("tabContextMenu", false)
		closeTab(_lastTabId)
	end)
	TabContextMenu.duplicatetab.MouseButton1Click:Connect(function()
		toggleHover("tabContextMenu", false)
		local currTab = TabDataStorage[_lastTabId]
		loadTab(currTab.CurrentURL, "New", true)
	end)
	TabContextMenu.reload.MouseButton1Click:Connect(function()
		toggleHover("tabContextMenu", false)
		loadTab(TabDataStorage[_lastTabId].CurrentURL, "Reload", true, _lastTabId)
	end)
	TabContextMenu.closeothertabs.MouseButton1Click:Connect(function()
		toggleHover("tabContextMenu", false)
		for i in pairs(TabDataStorage) do
			if i ~= _lastTabId then
				closeTab(i)
			end
		end
	end)

end

do -- bookmark context menu connections

	BookmarkEditMenu.bottomButtons.done.MouseButton1Click:Connect(function()
		toggleHover("bookmarkEditMenu", false)
		AddBookmark(
			BookmarkEditMenu.bookmarkURL.input.Text,
			BookmarkEditMenu.bookmarkName.input.Text,
			if TabDataStorage[CurrentVisibleTab].CurrentURL == BookmarkEditMenu.bookmarkURL.input.Text then TabDataStorage[CurrentVisibleTab].TabInstance.ico.Image else nil
		)
	end)

	BookmarkEditMenu.bottomButtons.delete.MouseButton1Click:Connect(function()
		toggleHover("bookmarkEditMenu", false)
		RemoveBookmark(_lastBookmarkURL)
	end)

end

-- bookmarks

function UpdateBookmarks()

	-- new tab page's bookmarks

	defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab)].Contents.bookmarks:ClearAllChildren()

	for url, data in pairs(bookmarksData) do
		local newConfig = Instance.new("Configuration")
		newConfig.Parent = defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab)].Contents.bookmarks
		newConfig.Name = url
		for i, v in pairs(data) do
			newConfig:SetAttribute(i, v)
		end
	end

end

function AddBookmark(url : string, title : string, favicon : string?)
	bookmarksData[url] = { -- set as table in case of future changes
		title = title,
		favicon = favicon or bookmarksData[url] and bookmarksData[url].favicon or "",
		bookmarkVisits = bookmarksData[url] and bookmarksData[url].bookmarkVisits or 0, -- for sorting
	}
	UpdateBookmarks()
	return true
end
function RemoveBookmark(url : string)
	bookmarksData[url] = nil
	UpdateBookmarks()
	return true
end
function IsURLBookmarked(url : string, isVisit : boolean?)
	if isVisit == true and bookmarksData[url] ~= nil then
		bookmarksData[url].bookmarkVisits += 1
	end
	return bookmarksData[url] ~= nil
end

UpdateBookmarks()

-- connections

UI.topbar.middle.bookmark.MouseButton1Click:Connect(function()
	openContextMenu("BookmarkEdit")
end)

-- webview event handling

WebView.OnRedirected:Connect(function(destructive : boolean, targetURL : string, requestingFrame : Frame)
	local targetTab = TabDataStorage[requestingFrame.Name]
	if targetTab then
		loadTab(targetURL, "ForwardNew", destructive, requestingFrame.Name)
	end
end)

WebView.OnLinkButtonAdded:Connect(function(btn : GuiButton)
	if btn:IsA("GuiButton") then
		btn.MouseButton2Click:Connect(function()
			openContextMenu("LinkButton", string.sub(btn.Name, 5))
		end)
		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton3 then
				loadTab(string.sub(btn.Name, 5), "New", true)
			end
		end)
	end	
end)

-- topbar related

UI.topbar.leftside.reload.MouseButton1Click:Connect(function()
	loadTab(TabDataStorage[CurrentVisibleTab].CurrentURL, "Reload", true, CurrentVisibleTab)
end)
UI.topbar.leftside.back.MouseButton1Click:Connect(function()
	local currTab = TabDataStorage[CurrentVisibleTab]
	if currTab.History[currTab.CurrentHistoryIndex - 1] ~= nil then
		loadTab(currTab.History[currTab.CurrentHistoryIndex - 1], "Back", currTab.IsTabDestructive, CurrentVisibleTab)
	end
end)
UI.topbar.leftside.homePage.MouseButton1Click:Connect(function()
	loadTab(getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab), "ForwardNew", true, CurrentVisibleTab)
end)
UI.topbar.leftside.forward.MouseButton1Click:Connect(function()
	local currTab = TabDataStorage[CurrentVisibleTab]
	if currTab.History[currTab.CurrentHistoryIndex + 1] ~= nil then
		loadTab(currTab.History[currTab.CurrentHistoryIndex + 1], "Forward", currTab.IsTabDestructive, CurrentVisibleTab)
	end
end)

UI.topbar.middle.urlbar.input.FocusLost:Connect(function(enter)
	if not enter then return end
	local url = UI.topbar.middle.urlbar.input.Text
	local isValidURL = false

	do -- validate url format (x.y or x://y at least)
		local url = url

		-- trim whitespace
		url = string.match(url, "^%s*(.-)%s*$")
		-- rule 2: protocol (x://y)
		if string.match(url, "^%a[%w+.-]*://.+$") then
			isValidURL = true
			-- rule 1: at least one dot between two words (x.y)
		elseif string.match(url, "^[A-Za-z0-9_]+%.[A-Za-z0-9_]+") then
			isValidURL = true
		end
	end

	if not isValidURL then
		url = string.format(BrowserConfig.DefaultSearchEngineConfig.urlFormat, game.HttpService:UrlEncode(url)) -- search instead
	end

	loadTab(url, "ForwardNew", true, CurrentVisibleTab)
end)

UI.tabsContainer.newTab.MouseButton1Click:Connect(function()
	loadTab(getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab), "New", true)
end)

UI.topbar.rightside.browser_options_button.MouseButton1Click:Connect(function()
	toggleHover("browserOptions")
end)
UI.topbar.rightside.enter_button.MouseButton1Click:Connect(function()
	local url = UI.topbar.middle.urlbar.input.Text
	local isValidURL = false

	do -- validate url format (x.y or x://y at least)
		local url = url

		-- trim whitespace
		url = string.match(url, "^%s*(.-)%s*$")
		-- rule 2: protocol (x://y)
		if string.match(url, "^%a[%w+.-]*://.+$") then
			isValidURL = true
			-- rule 1: at least one dot between two words (x.y)
		elseif string.match(url, "^[A-Za-z0-9_]+%.[A-Za-z0-9_]+") then
			isValidURL = true
		end
	end

	if not isValidURL then
		url = string.format(BrowserConfig.DefaultSearchEngineConfig.urlFormat, game.HttpService:UrlEncode(url)) -- search instead
	end

	loadTab(url, "ForwardNew", true, CurrentVisibleTab)
end)

-- browser options menu related

UI.hoverContainer.browserOptions.about.MouseButton1Click:Connect(function()
	toggleHover("browserOptions", false)
	loadTab(getBrowserPage(BrowserConfig.DefaultTabsForActions.About), "New", true)
end)
UI.hoverContainer.browserOptions.newtab.MouseButton1Click:Connect(function()
	toggleHover("browserOptions", false)
	loadTab(getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab), "New", true)
end)

-- handling user input (for shortcuts)

UIS.InputBegan:Connect(function(input, gp)

	if input.UserInputType == Enum.UserInputType.MouseButton2 and not gp then
		openContextMenu("Open")
	end

	--if gp then return end

	if (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) and (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)) then
		if input.KeyCode == Enum.KeyCode.K then -- duplicate current tab
			local currTab = TabDataStorage[CurrentVisibleTab]
			loadTab(currTab.CurrentURL, "New", true)
		end
	elseif UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) then
		if input.KeyCode == Enum.KeyCode.T then	
			toggleHover("browserOptions", false)
			loadTab(getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab), "New", true)
		elseif input.KeyCode == Enum.KeyCode.W then
			toggleHover("browserOptions", false)
			closeTab(CurrentVisibleTab)
		end
	elseif UIS:IsKeyDown(Enum.KeyCode.LeftAlt) or UIS:IsKeyDown(Enum.KeyCode.RightAlt) then
		if input.KeyCode == Enum.KeyCode.Left then -- back
			local currTab = TabDataStorage[CurrentVisibleTab]
			if currTab.History[currTab.CurrentHistoryIndex - 1] ~= nil then
				loadTab(currTab.History[currTab.CurrentHistoryIndex - 1], "Back", currTab.IsTabDestructive, CurrentVisibleTab)
			end
		elseif input.KeyCode == Enum.KeyCode.Right then -- forward
			local currTab = TabDataStorage[CurrentVisibleTab]
			if currTab.History[currTab.CurrentHistoryIndex + 1] ~= nil then
				loadTab(currTab.History[currTab.CurrentHistoryIndex + 1], "Forward", currTab.IsTabDestructive, CurrentVisibleTab)
			end
		end
	end
end)

-- initialize default tabs

do -- about

	local success, err = pcall(function()

		local tab = script.DefaultTabs.about

		local bodyText = Strings.ui.aboutPage.text
		local finalText = bodyText

		finalText = finalText:gsub("{{ver}}", WebView.WebViewVersion)
		finalText = finalText:gsub("{{ui_ver}}", BrowserConfig.DisplayVersion)

		tab.body2.Text = BrowserConfig.Version
		tab.body.Text = finalText

	end)

	if not success then
		warn("unable to initialize 'about browser' page: " .. err)
	end

end

do -- new tab

	local success, err = pcall(function()

		local tab = script.DefaultTabs["new-tab"]

		tab.DefaultSearchEngineConfig:SetAttribute("name", BrowserConfig.DefaultSearchEngineConfig.name)
		tab.DefaultSearchEngineConfig:SetAttribute("urlFormat", BrowserConfig.DefaultSearchEngineConfig.urlFormat)

	end)

	if not success then
		warn("unable to initialize 'new tab' page: " .. err)
	end

end

-- runtime

task.wait(math.random(42, 241)/100)

UI.Visible = true
UI.tabsContainer.Visible = true
UI.topbar.Visible = true
UI.webview.Visible = true
UI.topbarbg.Visible = true

coroutine.wrap(function() -- load new-tab & exit initialize screen
	loadTab(getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab), "New", true)
	Animations.BrowserStartupExit(script.Parent.initialize)
end)()

game:GetService("RunService").RenderStepped:Connect(function()

	if #TabDataStorage == 0 then -- never allow 0 tabs open
		loadTab(getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab), "New", true)
	end

	UI.topbar.middle.urlbar.input.PlaceholderText = string.format(Strings.ui.urlbar.placeholderFormat, BrowserConfig.DefaultSearchEngineConfig.name)

	for _,v in pairs(UI.webview:GetChildren()) do
		if v:IsA("GuiObject") then
			v.Visible = v.Name == CurrentVisibleTab
		end	
	end

	for _,v in pairs(UI.tabsContainer:GetChildren()) do
		if v:IsA("Frame") then
			v.BackgroundColor3 = v.Name ~= CurrentVisibleTab and Color3.fromRGB(20,20,20) or Color3.fromRGB(30,30,30)
			v.cover.BackgroundColor3 = v.Name ~= CurrentVisibleTab and Color3.fromRGB(20,20,20) or Color3.fromRGB(30,30,30)
		end
	end

	do -- current tab related

		local currTab = TabDataStorage[CurrentVisibleTab]

		if currTab then
			UI.topbar.leftside.forward.Visible = currTab.History[currTab.CurrentHistoryIndex + 1] ~= nil
			UI.topbar.leftside.back.ico.ImageTransparency = currTab.History[currTab.CurrentHistoryIndex - 1] ~= nil and 0 or 0.5
		end	

	end

	do -- bookmarks

		local currTab = TabDataStorage[CurrentVisibleTab]

		if currTab then
			local isCurrURLBookmarked = IsURLBookmarked(currTab.CurrentURL)
			UI.topbar.middle.bookmark.idle.Visible = not isCurrURLBookmarked
			UI.topbar.middle.bookmark.filled.Visible = isCurrURLBookmarked
		end	

	end

	if TabDataStorage[CurrentVisibleTab] and (CurrentVisibleTab ~= _LastVisibleTab or TabDataStorage[CurrentVisibleTab].CurrentURL ~= _LastVisibleURL) then
		_LastVisibleTab = CurrentVisibleTab
		_LastVisibleURL = TabDataStorage[CurrentVisibleTab].CurrentURL
		if UIS:GetFocusedTextBox() ~= UI.topbar.middle.urlbar.input then
			UI.topbar.middle.urlbar.input.Text = string.sub(string.lower(TabDataStorage[CurrentVisibleTab].CurrentURL), 1, #getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab)) == getBrowserPage(BrowserConfig.DefaultTabsForActions.NewTab) and "" or TabDataStorage[CurrentVisibleTab].CurrentURL
		end	
	end

end)
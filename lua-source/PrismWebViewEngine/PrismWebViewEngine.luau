--!native
--native compiling to ensure fast site loading (if somehow needed)

local PrismWebView = {}

export type PrismWebData = { -- data that server passes through via "http requests" (emulated)
	Favicon : string,
	Title : string,
	url : string,
	Contents : GuiObject,
	SiteBackgroundColor3 : Color3,
	RefreshSiteOnNewURL : boolean, -- if true, refreshes the site on new url; this will always be the case for external sites (different tld, sld and/or subdomain) (default is true)
}

local function urlDecode(str : string) : string
	return str:gsub('%%(%x%x)', function(hex)
		return string.char(tonumber(hex, 16))
	end):gsub('+', ' ')
end

-- Extracts the query parameters from a URL
local function extractParametersFromURL(unreliableUrl : string) : { [string] : any }

	local baseSplit = string.split(unreliableUrl, "?")
	local paramsTable = {}

	if baseSplit[2] ~= nil then

		local paramsSplit = string.split(baseSplit[2], "&")

		for _,v in pairs(paramsSplit) do

			local index = ""
			local value = ""

			local split = string.split(v, "=")

			if #split == 2 then
				index = split[1]
				value = urlDecode(split[2])
			end

			paramsTable[index] = value

		end

	end

	return paramsTable

end

local function LoadFromPrismWebData(config : {}, PrismWebData : PrismWebData, parent : Instance)

	local onLoadedEvent = nil
	local onRedirectEvent = nil
	local getCookieFunc = nil
	local setCookieFunc = nil
	local HTTP_GETFunc = nil
	local HTTP_POSTFunc = nil

	local newFrame = Instance.new("Frame")
	newFrame.Name = PrismWebData.url
	newFrame.Size = UDim2.fromScale(1,1)
	newFrame.BorderSizePixel = 0
	newFrame.BackgroundColor3 = PrismWebData.SiteBackgroundColor3

	-- load site contents

	for _, child in pairs(PrismWebData.Contents:GetChildren()) do
		
		local obj = child:Clone()
		obj.Parent = newFrame
		
		if obj.Name == "Redirect" and obj:IsA("BindableEvent") then
			obj.Event:Connect(function(url : string)
				if type(url) ~= "string" then return end
				if PrismWebData.RefreshSiteOnNewURL == false then
					config.OnRedirect:Fire(false, url, newFrame) -- update is sent to the requiring script to handle non-destructive redirects
				else
					for _,v in pairs(newFrame:GetDescendants()) do
						if v:IsA("LocalScript") then
							v.Enabled = false
						end
					end
					config.OnRedirect:Fire(true, url, newFrame) -- destructive, newURL, requestingFrame
				end
			end)
			onRedirectEvent = obj
		elseif obj.Name == "OnLoaded" and obj:IsA("BindableEvent") then		
			onLoadedEvent = obj
		elseif obj.Name == "GetCookie" and obj:IsA("BindableFunction") then
			getCookieFunc = obj
		elseif obj.Name == "SetCookie" and obj:IsA("BindableFunction") then
			setCookieFunc = obj
		elseif obj.Name == "HTTP_GET" and obj:IsA("BindableFunction") then
			HTTP_GETFunc = obj
		elseif obj.Name == "HTTP_POST" and obj:IsA("BindableFunction") then
			HTTP_POSTFunc = obj
		end
		
	end
	
	if not HTTP_GETFunc then
		HTTP_GETFunc = Instance.new("BindableFunction")
		HTTP_GETFunc.Name = "HTTP_GET"
		HTTP_GETFunc.Parent = newFrame
	end
	
	HTTP_GETFunc.OnInvoke = function(...)
		return config.OnHTTPGet(newFrame, ...)
	end
	
	if not HTTP_POSTFunc then
		HTTP_POSTFunc = Instance.new("BindableFunction")
		HTTP_POSTFunc.Name = "HTTP_POST"
		HTTP_POSTFunc.Parent = newFrame
	end
	
	HTTP_POSTFunc.OnInvoke = function(...)
		return config.OnHTTPPost(newFrame, ...)
	end
	
	if not getCookieFunc then
		getCookieFunc = Instance.new("BindableFunction")
		getCookieFunc.Name = "GetCookie"
		getCookieFunc.Parent = newFrame
	end
	
	getCookieFunc.OnInvoke = function(...)
		return config.OnCookieGet(newFrame, ...)
	end
	
	if not setCookieFunc then
		setCookieFunc = Instance.new("BindableFunction")
		setCookieFunc.Name = "SetCookie"
		setCookieFunc.Parent = newFrame
	end
	
	setCookieFunc.OnInvoke = function(...)
		return config.OnCookieSet(newFrame, ...)
	end
	
	if not onLoadedEvent then
		onLoadedEvent = Instance.new("BindableEvent")
		onLoadedEvent.Parent = newFrame
		onLoadedEvent.Name = "OnLoaded"
	end
	
	if not onRedirectEvent then
		onRedirectEvent = Instance.new("BindableEvent")
		onRedirectEvent.Parent = newFrame
		onRedirectEvent.Name = "Redirect"
		onRedirectEvent.Event:Connect(function(url : string)
			if type(url) ~= "string" then return end
			if PrismWebData.RefreshSiteOnNewURL == false then
				config.OnRedirect:Fire(false, url, newFrame) -- update is sent to the requiring script to handle non-destructive redirects
			else
				for _,v in pairs(newFrame:GetDescendants()) do
					if v:IsA("LocalScript") then
						v.Enabled = false
					end
				end
				config.OnRedirect:Fire(true, url, newFrame) -- destructive, newURL, requestingFrame
			end
		end)
	end
	
	-- default url-redirect linking
	
	for _, descendant in pairs(newFrame:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			if string.len(descendant.Name) > 4 and string.sub(string.lower(descendant.Name), 1, 4) == "url:" then
				config.OnLinkButtonAdded:Fire(descendant)
				descendant.MouseButton1Click:Connect(function()
					onRedirectEvent:Fire(string.sub(descendant.Name, 5))
				end)
			end
		end
	end
	
	newFrame.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") then
			if string.len(descendant.Name) > 4 and string.sub(string.lower(descendant.Name), 1, 4) == "url:" then
				config.OnLinkButtonAdded:Fire(descendant)
				descendant.MouseButton1Click:Connect(function()
					onRedirectEvent:Fire(string.sub(descendant.Name, 5))
				end)
			end
		end
	end)
	
	newFrame.Parent = parent
	
	if onLoadedEvent then
		coroutine.wrap(function()
			task.wait(.2)
			onLoadedEvent:Fire(PrismWebData.url, extractParametersFromURL(PrismWebData.url))
		end)()
	end

	return newFrame

end

local function TranslateInstanceToPrismWebData(internalConfig : {}, instance : Instance, config : {})

	local newData = {}

	newData.Favicon = config.Favicon or internalConfig.DefaultFavicon or "rbxassetid://137354814227470" -- custom favicon, config default or prism logo
	newData.url = config.url or instance.Name
	newData.Title = config.Title or instance.Name
	newData.RefreshSiteOnNewURL = config.RefreshSiteOnNewURL or true -- if the site should be refreshed on a new url
	newData.Contents = instance
	
	return newData
	
end

-- loader function

function PrismWebView.new(config : {
	DefaultFavicon : string,
	OnCookieGet : (requestingFrame : Frame, cookieName : string) -> (any),
	OnCookieSet : (requestingFrame : Frame, cookieName : string, value : any, applyingSites : {string}) -> (),
	OnHTTPGet : (requestingFrame : Frame, url : string, arguments : {}) -> (any),
	OnHTTPPost : (requestingFrame : Frame, url : string, arguments : {}) -> (any),
	})

	local onRedirect_event = Instance.new("BindableEvent")
	local onLinkButtonAdded_event = Instance.new("BindableEvent")

	local internalFunctions = table.clone(config)
	
	internalFunctions.OnLinkButtonAdded = onLinkButtonAdded_event
	internalFunctions.OnRedirect = onRedirect_event

	local functions = {
		WebViewVersion = "PRISM-2.8.0",
		OnRedirected = onRedirect_event.Event,
		OnLinkButtonAdded = onLinkButtonAdded_event.Event,
	}

	function functions.LoadFromPrismWebData(PrismWebData : PrismWebData, Parent : Instance)
		return LoadFromPrismWebData(internalFunctions, PrismWebData, Parent)
	end

	function functions.TranslateInstanceToPrismWebData(Page : Instance, Config : {})
		return TranslateInstanceToPrismWebData(internalFunctions, Page, Config)
	end

	return functions

end

return PrismWebView

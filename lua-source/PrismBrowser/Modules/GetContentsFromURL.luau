
local function new(UI, defaultTabData, getBrowserPage, DefaultTabInitializer, accesibleDefaultTabs, DefaultHTTPErrorCodes, BrowserConfig, assetTypeCheckInstances)
	
	return function(url : string, tabId : string) : (Frame, string)

			local Frame, Status = nil, nil

		coroutine.wrap(function()
			if UI.webview:FindFirstChild(tabId) then 
				Frame = UI.webview:FindFirstChild(tabId)
				Status = "OK"
			elseif defaultTabData[url] ~= nil or string.sub(url, 1, #string.format(BrowserConfig.BrowserPagesProtocol, "")) == string.format(BrowserConfig.BrowserPagesProtocol, "") then
				if table.find(accesibleDefaultTabs, url) then
					Frame = defaultTabData[url]
					DefaultTabInitializer.InitializeTab(Frame.Contents)
					Status = "OK"
				else
					Status = "PRISM_INVALID_URL"
					defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NotFound)].Contents.errorCode.Text = "Error Code: " .. Status or DefaultHTTPErrorCodes[Frame] or "PRISM_GENERIC_ERROR"
					Frame = defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NotFound)]
					DefaultTabInitializer.InitializeTab(Frame.Contents)
					Frame.url = url
				end
			elseif string.sub(url, 1, #"rbxassetid://") == "rbxassetid://" and string.len(url) > #"rbxassetid://" + 1 then -- online asset

				coroutine.wrap(function()

					local success, result = pcall(function()
						local productinfo = game.MarketplaceService:GetProductInfoAsync(tonumber(string.sub(url, #"rbxassetid://" + 1)), Enum.InfoType.Asset)
						repeat task.wait() until productinfo
						return productinfo
					end)

					if success then

						local newContent = nil

						local assetType = result.AssetTypeId

						if assetType == 1 then -- image
							newContent = Instance.new("Decal")
							newContent.ColorMap = url
						elseif assetType == 3 then -- audio
							newContent = Instance.new("Sound")
							newContent.SoundId = url
						elseif assetType == 62 then -- video
							newContent = Instance.new("VideoFrame")
							newContent.Video = "rbxassetid://" .. result.AssetId
						end

						if newContent then

							local newDat = {
								Favicon = "rbxassetid://123070198843762",
								Title = result.Name,
								url = url,
								Contents = newContent,
								SiteBackgroundColor3 = Color3.new(0,0,0),
								RefreshSiteOnNewURL = true,
							}

							Frame = newDat
							Status = "OK"

						end

					end

				end)()

			elseif (string.sub(url, 1, #"rbxasset://") == "rbxasset://" and string.len(url) > #"rbxasset://" + 1) or string.sub(url, 1, #"rbxtemp://") == "rbxtemp://" and string.len(url) > #"rbxtemp://" + 1 then

				coroutine.wrap(function()
					local timeout = 0

					assetTypeCheckInstances.Sound.SoundId = ""
					assetTypeCheckInstances.VideoFrame.Video = ""
					assetTypeCheckInstances.ImageLabel.Image = ""

					pcall(function()
						assetTypeCheckInstances.Sound.SoundId = url
					end)
					pcall(function()
						assetTypeCheckInstances.VideoFrame.Video = url
					end)
					pcall(function()	
						assetTypeCheckInstances.ImageLabel.Image = url
					end)

					repeat timeout += task.wait() until assetTypeCheckInstances.Sound.IsLoaded or assetTypeCheckInstances.VideoFrame.IsLoaded or assetTypeCheckInstances.ImageLabel.IsLoaded or timeout > 2

					local newContent = nil

					if assetTypeCheckInstances.Sound.IsLoaded then -- audio

						newContent = Instance.new("Sound")
						newContent.SoundId = url

					elseif assetTypeCheckInstances.ImageLabel.IsLoaded then -- image

						newContent = Instance.new("Decal")
						newContent.ColorMap = url

					elseif assetTypeCheckInstances.VideoFrame.IsLoaded then -- video

						newContent = Instance.new("VideoFrame")
						newContent.Video = url

					end

					if newContent then

						local newDat = {
							Favicon = "rbxassetid://123070198843762",
							Title = url,
							url = url,
							Contents = newContent,
							SiteBackgroundColor3 = Color3.new(0,0,0),
							RefreshSiteOnNewURL = true,
						}

						Frame = newDat
						Status = "OK"

					end

				end)()

			elseif string.sub(url, 1, 8) == "https://" or string.sub(url, 1, 7) == "http://" or string.split(url, "://")[1] == url then
				Frame, Status = game.ReplicatedStorage.HTTP.GET:InvokeServer(url)
			else -- what are we even trying to access
				Status = "PRISM_INVALID_URL"
				defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NotFound)].Contents.errorCode.Text = "Error Code: " .. Status or DefaultHTTPErrorCodes[Frame] or "PRISM_GENERIC_ERROR"
				Frame = defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NotFound)]
				Frame.url = url
			end
		end)()

			local timeout = 0
			repeat timeout += task.wait() until Frame ~= nil or timeout > 3

			if timeout > 5 then
				Frame = defaultTabData[getBrowserPage(BrowserConfig.DefaultTabsForActions.NotFound)]
				Frame.url = url
			end

			return Frame, Status

		end
	
end

return {
	new = new
}
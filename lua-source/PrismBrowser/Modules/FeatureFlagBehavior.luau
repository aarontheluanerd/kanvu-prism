
local MainScript = script.Parent

local perFlagFunctions = {
	FFLAG_AUDIOAPI_BASED_VIDEOPLAYER = function(state : boolean)
		if MainScript.DefaultTabs:FindFirstChild("video-viewer-audioapi") == nil then return end
		if state ~= true then
			MainScript.DefaultTabs["video-viewer-audioapi"]:Destroy()
		else
			MainScript.DefaultTabs["video-viewer"]:Destroy()
			MainScript.DefaultTabs["video-viewer-audioapi"].Name = "video-viewer"
		end
	end,
	FFLAG_AUDIOAPI_BASED_AUDIOPLAYER = function(state : boolean)
		if MainScript.DefaultTabs:FindFirstChild("audio-player-audioapi") == nil then return end
		if state ~= true then
			MainScript.DefaultTabs["audio-player-audioapi"]:Destroy()
		else
			MainScript.DefaultTabs["audio-player"]:Destroy()
			MainScript.DefaultTabs["audio-player-audioapi"].Name = "audio-player"
		end
	end,
}

return {
	apply = function(flags : {})
		for flagName, state in flags do
			if perFlagFunctions[flagName] then
				perFlagFunctions[flagName](state)
			end
		end
	end,
}

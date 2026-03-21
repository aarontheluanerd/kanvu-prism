local StandaloneFunctions = {}

local function sanitizeURL(url : string) -- function to find servers that can handle the url
	local sanitized = string.lower(url)
	if string.match(sanitized, "^http[s]?://") then
		sanitized = string.split(sanitized, "://")[2]
	end
	if string.match(sanitized, "^www%.") then
		sanitized = string.split(sanitized, "www.")[2]
	end
	return sanitized
end

local function urlDecode(str)
	return str:gsub('%%(%x%x)', function(hex)
		return string.char(tonumber(hex, 16))
	end):gsub('+', ' ')
end

local function extractParametersFromURL(unreliableUrl : string) : { [string] : any }

	unreliableUrl = urlDecode(unreliableUrl)

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
				value = split[2]
			end

			paramsTable[index] = value

		end

	end

	return paramsTable

end

StandaloneFunctions.SanitizeURL = sanitizeURL
StandaloneFunctions.ExtractParametersFromURL = extractParametersFromURL
StandaloneFunctions.UrlDecode = urlDecode

return StandaloneFunctions

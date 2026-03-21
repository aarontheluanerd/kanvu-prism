local DefaultTabInitializer = {}

function DefaultTabInitializer.InitializeTab(tab : Frame)
	for _,v in pairs(tab:GetDescendants()) do
		if (v:IsA("LocalScript") or v:IsA("Script") and v.RunContext == Enum.RunContext.Client) and v:HasTag("disabledScript") then
			v.Enabled = true
			v:RemoveTag("disabledScript")
		end
	end
end

-- disable scripts on tab templates

for _, v in pairs(script.Parent.DefaultTabs:GetDescendants()) do
	if (v:IsA("LocalScript") or v:IsA("Script") and v.RunContext == Enum.RunContext.Client) then
		v.Enabled = false
		v:AddTag("disabledScript")
	end
end

return DefaultTabInitializer

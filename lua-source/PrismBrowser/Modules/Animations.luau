local Animations = {}
local TweenService = game:GetService("TweenService")

-- these are placeholder functions, feel free to replace them to add animations to the browser!

Animations.OnNewTab = function(NewTab : Frame)
	return
end
Animations.OnTabClose = function(ClosingTab : Frame)
	ClosingTab:Destroy()
end

Animations.BrowserStartupEnter = function(Frame : Frame)
	Frame.BackgroundTransparency = 0
	Frame.logo.GroupTransparency = 1
	Frame.Visible = true
	TweenService:Create(Frame.logo, TweenInfo.new(.45, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
end
Animations.BrowserStartupExit = function(Frame : Frame)
	TweenService:Create(Frame.logo, TweenInfo.new(.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {GroupTransparency = 1}):Play()
	task.wait(.25)
	TweenService:Create(Frame, TweenInfo.new(.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
	task.wait(.25)
	Frame.Visible = false
end

Animations.HoverOpened = function(HoverName : string, HoverFrame : Frame)
	HoverFrame.Visible = true
end
Animations.HoverClosed = function(HoverName : string, HoverFrame : Frame)
	HoverFrame.Visible = false
end

return Animations

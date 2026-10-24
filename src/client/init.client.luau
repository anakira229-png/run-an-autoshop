local Players = game:GetService("Players")

local WorkView = require(script.WorkView)
require(script.UI.App).mount({
	onOverview = WorkView.overview,
	onLeave = WorkView.leave,
})
require(script.SpinGame)
require(script.CarAudio)
require(script.Beacons)

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("RunAutoshopMap"):WaitForChild("Plots")
local callouts = workspace:WaitForChild("RunAutoshopCallouts")

-- Prompts owned by other players are hidden locally; the server still rejects non-owners.
local function ownerOf(instance)
	local current = instance
	while current and current:GetAttribute("OwnerUserId") == nil do
		current = current.Parent
	end
	return current
end

local function apply(prompt, owned)
	prompt.Enabled = owned:GetAttribute("OwnerUserId") == player.UserId
end

local function watchPlot(plot)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		for _, d in plot:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				apply(d, plot)
			end
		end
	end)
end

for _, plot in plots:GetChildren() do
	watchPlot(plot)
end
plots.ChildAdded:Connect(watchPlot)

for _, root in { plots, callouts } do
	root.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			local owned = ownerOf(d)
			if owned then
				apply(d, owned)
			end
		end
	end)
	for _, d in root:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			local owned = ownerOf(d)
			if owned then
				apply(d, owned)
			end
		end
	end
end

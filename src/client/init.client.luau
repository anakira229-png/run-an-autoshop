local Players = game:GetService("Players")

require(script.Hud)
require(script.SpinGame)

local player = Players.LocalPlayer
local plots = workspace:WaitForChild("RunAutoshopMap"):WaitForChild("Plots")

-- Prompts on other players' plots are hidden locally; the server still rejects non-owners.
local function plotOf(instance)
	local current = instance
	while current and current.Parent ~= plots do
		current = current.Parent
	end
	return current
end

local function apply(prompt, plot)
	prompt.Enabled = plot:GetAttribute("OwnerUserId") == player.UserId
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

plots.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		local plot = plotOf(d)
		if plot then
			apply(d, plot)
		end
	end
end)
for _, d in plots:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		apply(d, plotOf(d))
	end
end

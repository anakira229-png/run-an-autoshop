local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)

local plotsFolder = workspace:WaitForChild("RunAutoshopMap"):WaitForChild("Plots")
local plots = plotsFolder:GetChildren()
table.sort(plots, function(a, b)
	return a:GetAttribute("PlotIndex") < b:GetAttribute("PlotIndex")
end)

local owners = {}
local byPlayer = {}

local Plots = {}

local function setSign(plot, text)
	plot.Sign.SurfaceGui.Label.Text = text
end

function Plots.claim(player)
	for _, plot in plots do
		if not owners[plot] then
			owners[plot] = player
			byPlayer[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			setSign(plot, player.DisplayName .. "'s Autoshop")
			return plot
		end
	end
	return nil
end

function Plots.release(player)
	local plot = byPlayer[player]
	if plot then
		owners[plot] = nil
		byPlayer[player] = nil
		plot:SetAttribute("OwnerUserId", 0)
		setSign(plot, "Shop for rent")
	end
end

function Plots.get(player)
	return byPlayer[player]
end

function Plots.owner(plot)
	return owners[plot]
end

function Plots.marker(plot, name)
	return plot.Markers[name].CFrame
end

function Plots.rootPart(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

function Plots.isNear(player, position, maxDistance)
	local root = Plots.rootPart(player)
	return root ~= nil and (root.Position - position).Magnitude <= maxDistance
end

-- Creates a prompt whose callback only fires for the player returned by getOwner.
function Plots.ownerPrompt(getOwner, parent, actionText, objectText, holdDuration, callback)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = Config.InteractDistance
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		if getOwner() ~= player then
			Remotes.Notify:FireClient(player, "This job isn't yours.")
			return
		end
		callback(player)
	end)
	prompt.Parent = parent
	return prompt
end

function Plots.prompt(plot, parent, actionText, objectText, holdDuration, callback)
	return Plots.ownerPrompt(function()
		return owners[plot]
	end, parent, actionText, objectText, holdDuration, callback)
end

function Plots.teleportHome(player)
	local plot = byPlayer[player]
	local character = player.Character
	if plot and character then
		character:PivotTo(Plots.marker(plot, "SpawnPoint"))
	end
end

return Plots

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)

local Shop = {}

local function buyPart(player, partType)
	local info = Config.Parts[partType]
	if not PlayerData.get(player) then
		Remotes.Notify:FireClient(player, "Still loading your save...")
	elseif PlayerData.ownedCount(player, partType) >= info.Needed then
		Remotes.Notify:FireClient(player, "You already have every " .. info.Label .. " your car needs.")
	elseif not PlayerData.trySpend(player, info.Price) then
		Remotes.Notify:FireClient(player, "Not enough money for the " .. info.Label .. ".")
	else
		PlayerData.addInventory(player, partType, 1)
		Remotes.Notify:FireClient(player, "Bought " .. info.Label .. ". Install it on your car.")
	end
end

local function buyUpgrade(player, name)
	local info = Config.Upgrades[name]
	if not PlayerData.get(player) then
		Remotes.Notify:FireClient(player, "Still loading your save...")
	elseif PlayerData.hasUpgrade(player, name) then
		Remotes.Notify:FireClient(player, "You already own " .. info.Label .. ".")
	elseif not PlayerData.trySpend(player, info.Price) then
		Remotes.Notify:FireClient(player, "Not enough money for " .. info.Label .. ".")
	else
		PlayerData.setUpgrade(player, name)
		Remotes.Notify:FireClient(player, info.Label .. " unlocked: minigames are easier.")
	end
end

function Shop.init()
	for _, plot in workspace.RunAutoshopMap.Plots:GetChildren() do
		for _, item in plot.PartsShelf.Items:GetChildren() do
			local partType = item.Name
			local info = Config.Parts[partType]
			Plots.prompt(plot, item, "Buy $" .. info.Price, info.Label, 0.3, function(player)
				buyPart(player, partType)
			end)
		end
		local upgrade = Config.Upgrades.BetterTools
		Plots.prompt(plot, plot.ToolBench.Toolbox, "Buy $" .. upgrade.Price, upgrade.Label, 0.3, function(player)
			buyUpgrade(player, "BetterTools")
		end)
	end
end

return Shop

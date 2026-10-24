local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local PersonalCar = require(script.Parent.PersonalCar)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)

local shelfPrompts = {}

local Shop = {}

local function buyPart(player, partType)
	local info = Config.Parts[partType]
	if not PlayerData.trySpend(player, info.Price) then
		Remotes.Notify:FireClient(player, "Not enough money for the " .. info.Label .. ".")
	else
		PlayerData.addInventory(player, partType, 1)
		Remotes.Notify:FireClient(player, "Bought " .. info.Label .. ". Install it on your car.")
	end
end

local function fullyInstalled(player, partType)
	local data = PlayerData.get(player)
	for _, slot in Config.Slots do
		if slot.PartType == partType and not data.Installed[slot.Name] then
			return false
		end
	end
	return true
end

-- Returns "buy", "upgrade" (with next tier), or "done" for what the shelf item should offer.
local function shelfOffer(player, partType)
	if PlayerData.ownedCount(player, partType) < Config.Parts[partType].Needed then
		return "buy"
	end
	local tiers = Config.Tiers[partType]
	local current = PlayerData.tier(player, partType)
	if tiers and current < #tiers and fullyInstalled(player, partType) then
		return "upgrade", current + 1
	end
	return "done"
end

local function buyTier(player, partType, tier)
	local info = Config.Parts[partType]
	local price = Config.Tiers[partType][tier].Price
	local name = Config.Tiers.Names[tier]
	if not PlayerData.trySpend(player, price) then
		Remotes.Notify:FireClient(player, "Not enough money for the " .. name .. " " .. info.Label .. ".")
		return
	end
	PlayerData.setTier(player, partType, tier)
	PersonalCar.refresh(player)
	Remotes.Notify:FireClient(player, name .. " " .. info.Label .. " fitted to your car!")
end

local function onShelf(player, partType)
	if not PlayerData.get(player) then
		Remotes.Notify:FireClient(player, "Still loading your save...")
		return
	end
	local offer, tier = shelfOffer(player, partType)
	if offer == "buy" then
		buyPart(player, partType)
	elseif offer == "upgrade" then
		buyTier(player, partType, tier)
	elseif Config.Tiers[partType] and PlayerData.tier(player, partType) < #Config.Tiers[partType] then
		Remotes.Notify:FireClient(player, "Install every " .. Config.Parts[partType].Label .. " before upgrading.")
	else
		Remotes.Notify:FireClient(player, "Your " .. Config.Parts[partType].Label .. " is maxed out.")
	end
end

function Shop.refresh(player)
	local plot = Plots.get(player)
	if not plot or not shelfPrompts[plot] or not PlayerData.get(player) then
		return
	end
	for partType, prompt in shelfPrompts[plot] do
		local info = Config.Parts[partType]
		local offer, tier = shelfOffer(player, partType)
		if offer == "buy" then
			prompt.ActionText = "Buy $" .. info.Price
			prompt.ObjectText = info.Label
		elseif offer == "upgrade" then
			prompt.ActionText = "Upgrade $" .. Config.Tiers[partType][tier].Price
			prompt.ObjectText = Config.Tiers.Names[tier] .. " " .. info.Label
		else
			local current = PlayerData.tier(player, partType)
			prompt.ActionText = "Check"
			prompt.ObjectText = (Config.Tiers[partType] and Config.Tiers.Names[current] .. " " or "") .. info.Label
		end
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
		shelfPrompts[plot] = {}
		for _, item in plot.PartsShelf.Items:GetChildren() do
			local partType = item.Name
			local info = Config.Parts[partType]
			shelfPrompts[plot][partType] = Plots.prompt(
				plot,
				item,
				"Buy $" .. info.Price,
				info.Label,
				0.3,
				function(player)
					onShelf(player, partType)
				end
			)
		end
		local upgrade = Config.Upgrades.BetterTools
		Plots.prompt(plot, plot.ToolBench.Toolbox, "Buy $" .. upgrade.Price, upgrade.Label, 0.3, function(player)
			buyUpgrade(player, "BetterTools")
		end)
	end
	PlayerData.onChanged(Shop.refresh)
end

return Shop

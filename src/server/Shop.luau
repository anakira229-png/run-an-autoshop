local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local PersonalCar = require(script.Parent.PersonalCar)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)

local lastPurchase = {}

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
		Plots.prompt(plot, plot.PartsShelf.Table, "Open Garage", "Parts & upgrades", 0, function(player)
			Remotes.OpenPanel:FireClient(player, "garage")
		end)
		Plots.prompt(plot, plot.ToolBench.Toolbox, "Open Upgrades", "Shop tools", 0, function(player)
			Remotes.OpenPanel:FireClient(player, "upgrades")
		end)
	end
	Remotes.ShopBuy.OnServerEvent:Connect(function(player, kind, key)
		local now = os.clock()
		if lastPurchase[player] and now - lastPurchase[player] < Config.Work.ShopCooldown then
			return
		end
		lastPurchase[player] = now
		if kind == "part" and type(key) == "string" and Config.Parts[key] then
			onShelf(player, key)
		elseif kind == "upgrade" and type(key) == "string" and Config.Upgrades[key] then
			buyUpgrade(player, key)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPurchase[player] = nil
	end)
end

return Shop

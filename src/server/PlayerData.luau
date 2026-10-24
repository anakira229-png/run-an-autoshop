local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles = {}

local PlayerData = {}

local function key(player)
	return "player_" .. player.UserId
end

local function newData()
	return { Version = 1, Money = Config.StartingMoney, Upgrades = {}, Inventory = {}, Installed = {} }
end

-- Copies only known fields so stale or malformed saves cannot inject unexpected state.
local function reconcile(saved)
	local data = newData()
	if type(saved) ~= "table" then
		return data
	end
	if type(saved.Money) == "number" and saved.Money >= 0 then
		data.Money = math.floor(saved.Money)
	end
	for name in Config.Upgrades do
		data.Upgrades[name] = type(saved.Upgrades) == "table" and saved.Upgrades[name] == true or nil
	end
	for partType, info in Config.Parts do
		local count = type(saved.Inventory) == "table" and saved.Inventory[partType]
		if type(count) == "number" then
			data.Inventory[partType] = math.clamp(math.floor(count), 0, info.Needed)
		end
	end
	for _, slot in Config.Slots do
		data.Installed[slot.Name] = type(saved.Installed) == "table" and saved.Installed[slot.Name] == true or nil
	end
	return data
end

local function retry(fn)
	local ok, result
	for attempt = 1, 3 do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	return false, result
end

local function mirror(player, data)
	player:SetAttribute("Money", data.Money)
	for name in Config.Upgrades do
		player:SetAttribute("Upgrade_" .. name, data.Upgrades[name] == true)
	end
	for partType in Config.Parts do
		player:SetAttribute("Inv_" .. partType, data.Inventory[partType] or 0)
	end
	for _, slot in Config.Slots do
		player:SetAttribute("Installed_" .. slot.Name, data.Installed[slot.Name] == true)
	end
end

local function changed(player)
	local profile = profiles[player]
	profile.dirty = true
	mirror(player, profile.data)
end

function PlayerData.load(player)
	local ok, saved = retry(function()
		return store:GetAsync(key(player))
	end)
	if not player.Parent then
		return nil
	end
	local profile = { data = reconcile(ok and saved or nil), canSave = ok, dirty = false }
	profiles[player] = profile
	mirror(player, profile.data)
	if not ok then
		warn("RunAutoshop: data load failed for", player.UserId, saved)
		Remotes.Notify:FireClient(player, "Save data unavailable. Progress this session will not be saved.")
	end
	return profile.data
end

function PlayerData.save(player)
	local profile = profiles[player]
	if not profile or not profile.canSave or not profile.dirty then
		return
	end
	profile.dirty = false
	local ok, err = retry(function()
		store:UpdateAsync(key(player), function()
			return profile.data
		end)
	end)
	if not ok then
		profile.dirty = true
		warn("RunAutoshop: data save failed for", player.UserId, err)
	end
end

function PlayerData.release(player)
	PlayerData.save(player)
	profiles[player] = nil
end

function PlayerData.get(player)
	local profile = profiles[player]
	return profile and profile.data
end

function PlayerData.hasUpgrade(player, name)
	local data = PlayerData.get(player)
	return data ~= nil and data.Upgrades[name] == true
end

function PlayerData.addMoney(player, amount)
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	data.Money += amount
	changed(player)
	return true
end

function PlayerData.trySpend(player, amount)
	local data = PlayerData.get(player)
	if not data or data.Money < amount then
		return false
	end
	data.Money -= amount
	changed(player)
	return true
end

function PlayerData.ownedCount(player, partType)
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	local count = data.Inventory[partType] or 0
	for _, slot in Config.Slots do
		if slot.PartType == partType and data.Installed[slot.Name] then
			count += 1
		end
	end
	return count
end

function PlayerData.addInventory(player, partType, delta)
	local data = PlayerData.get(player)
	local count = (data.Inventory[partType] or 0) + delta
	assert(count >= 0, "inventory underflow")
	data.Inventory[partType] = count
	changed(player)
end

function PlayerData.setInstalled(player, slotName)
	PlayerData.get(player).Installed[slotName] = true
	changed(player)
end

function PlayerData.setUpgrade(player, name)
	PlayerData.get(player).Upgrades[name] = true
	changed(player)
end

function PlayerData.start()
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(PlayerData.save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerData.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData

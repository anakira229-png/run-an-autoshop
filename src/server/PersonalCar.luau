local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local PartUtil = require(ReplicatedStorage.RunAutoshop.PartUtil)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Chassis = require(script.Parent.Chassis)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Spin = require(script.Parent.Spin)
local WorkSession = require(script.Parent.WorkSession)

local assets = ServerStorage:WaitForChild("RunAutoshopAssets")
local FRONT = { WheelFL = true, WheelFR = true }
local WHEEL_SLOTS = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }

local cars = {}
local lastReset = {}

local PersonalCar = {}

local function weld(part0, part1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
end

local function tierStats(player)
	local overrides = {}
	for partType in Config.Parts do
		local tiers = Config.Tiers[partType]
		if tiers then
			for k, v in tiers[PlayerData.tier(player, partType)] do
				if k ~= "Price" then
					overrides[k] = v
				end
			end
		end
	end
	return Chassis.stats(overrides)
end

local function paintTiers(model, player)
	for _, part in model.Installed:GetChildren() do
		local partType = part:GetAttribute("PartType")
		if Config.Tiers[partType] then
			local target = partType == "Wheel" and part:FindFirstChild("Hub") or part
			local template = assets.Parts[partType]
			local original = partType == "Wheel" and template.Hub.Color or template.Color
			target.Color = Config.Tiers.Colors[PlayerData.tier(player, partType)] or original
		end
	end
end

local function isComplete(data)
	for _, slot in Config.Slots do
		if not data.Installed[slot.Name] then
			return false
		end
	end
	return true
end

local function installVisual(model, slotName)
	local slot = model.Slots[slotName]
	local partType = slot:GetAttribute("PartType")
	local part = assets.Parts[partType]:Clone()
	part.Name = slotName
	PartUtil.place(part, slot.CFrame)
	part.Anchored = false
	if partType ~= "Wheel" then
		part.CanCollide = false
		part.Massless = true
	end
	if part:IsA("VehicleSeat") then
		part.Disabled = true
	end
	weld(model.Frame, part)
	part.Parent = model.Installed
	slot:Destroy()
end

local function assemble(entry, player)
	local model = entry.model
	local wheels = {}
	for _, slotName in WHEEL_SLOTS do
		table.insert(wheels, { part = model.Installed[slotName], front = FRONT[slotName] == true })
	end
	entry.chassis = Chassis.build({
		root = model.Frame,
		frame = model:GetPivot(),
		wheels = wheels,
		seat = model.Installed.Seat,
		driver = function()
			return player
		end,
		stats = tierStats(player),
	})
	paintTiers(model, player)
	player:SetAttribute("CarReady", true)
end

local function installSlot(entry, player, slot)
	local slotName = slot.Name
	local partType = slot:GetAttribute("PartType")
	local info = Config.Parts[partType]
	local data = PlayerData.get(player)
	if not data or data.Installed[slotName] or Spin.isBusy(player) then
		return
	end
	if (data.Inventory[partType] or 0) < 1 then
		Remotes.Notify:FireClient(player, "Buy a " .. info.Label .. " in the Garage menu first.")
		return
	end
	Spin.start(player, {
		label = "Bolt on the " .. info.Label,
		degrees = Config.Spin.InstallDegrees,
		anchor = slot,
		onComplete = function()
			local current = PlayerData.get(player)
			if cars[player] ~= entry or not current or current.Installed[slotName] then
				return
			end
			if (current.Inventory[partType] or 0) < 1 then
				return
			end
			PlayerData.addInventory(player, partType, -1)
			PlayerData.setInstalled(player, slotName)
			installVisual(entry.model, slotName)
			if isComplete(current) then
				assemble(entry, player)
				WorkSession.exit(player)
				Remotes.Notify:FireClient(player, "Your car is ready! Hop in the seat to drive.")
			end
		end,
	})
end

local function openGarage(player)
	local entry = cars[player]
	local plot = Plots.get(player)
	if not entry or not plot or WorkSession.isSeated(player) or Spin.isBusy(player) then
		return
	end
	local pad = Plots.marker(plot, "CarPad").Position
	if (entry.model:GetPivot().Position - pad).Magnitude > 20 then
		Remotes.Notify:FireClient(player, "Your car isn't on the pad. Use Reset car in the Garage menu.")
		return
	end
	WorkSession.enter(player, entry.model, "garage", function(p, part)
		local slots = entry.model:FindFirstChild("Slots")
		if slots and part.Parent == slots then
			installSlot(entry, p, part)
		end
	end)
end

function PersonalCar.despawn(player)
	local entry = cars[player]
	cars[player] = nil
	if entry then
		if entry.chassis then
			entry.chassis.destroy()
		end
		entry.model:Destroy()
	end
	player:SetAttribute("CarReady", false)
end

-- Applies current tiers to a built car without moving it.
function PersonalCar.refresh(player)
	local entry = cars[player]
	if entry and entry.chassis then
		entry.chassis.setStats(tierStats(player))
		paintTiers(entry.model, player)
	end
end

function PersonalCar.spawn(player)
	PersonalCar.despawn(player)
	local plot = Plots.get(player)
	local data = PlayerData.get(player)
	if not plot or not data then
		return
	end
	local model = assets.PersonalChassis:Clone()
	model.Name = "PersonalCar"
	local installed = Instance.new("Folder")
	installed.Name = "Installed"
	installed.Parent = model
	model:PivotTo(Plots.marker(plot, "CarPad"))

	local entry = { model = model }
	cars[player] = entry
	for _, slot in Config.Slots do
		if data.Installed[slot.Name] then
			installVisual(model, slot.Name)
		end
	end
	model.Parent = plot
	if isComplete(data) then
		assemble(entry, player)
	end
end

function PersonalCar.init()
	for _, plot in workspace.RunAutoshopMap.Plots:GetChildren() do
		Plots.prompt(plot, plot.Markers.CarPad, "Garage", "Your car", 0.2, openGarage)
	end
	Remotes.ResetCar.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastReset[player] and now - lastReset[player] < Config.Car.ResetCooldown then
			return
		end
		lastReset[player] = now
		if PlayerData.get(player) and not Spin.isBusy(player) then
			PersonalCar.spawn(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastReset[player] = nil
	end)
end

return PersonalCar

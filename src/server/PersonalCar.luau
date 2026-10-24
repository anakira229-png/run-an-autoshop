local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Spin = require(script.Parent.Spin)

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

local function attachment(parent, cframe)
	local a = Instance.new("Attachment")
	a.CFrame = cframe
	a.Parent = parent
	return a
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
	part.CFrame = slot.CFrame
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
	local frame = model.Frame
	local car = Config.Car
	local motors, servos = {}, {}

	for _, slotName in WHEEL_SLOTS do
		local wheel = model.Installed[slotName]
		wheel:FindFirstChild("WeldConstraint"):Destroy()
		local offset = frame.CFrame:ToObjectSpace(wheel.CFrame).Position
		local noCollide = Instance.new("NoCollisionConstraint")
		noCollide.Part0 = frame
		noCollide.Part1 = wheel
		noCollide.Parent = wheel
		local wheelAttachment = attachment(wheel, CFrame.new())

		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment1 = wheelAttachment
		if FRONT[slotName] then
			local knuckle = Instance.new("Part")
			knuckle.Name = "Knuckle"
			knuckle.Size = Vector3.new(1, 1, 1)
			knuckle.Transparency = 1
			knuckle.CanCollide = false
			knuckle.CanQuery = false
			knuckle.CanTouch = false
			knuckle.CFrame = frame.CFrame * CFrame.new(offset)
			knuckle.Parent = model
			-- Rotating the attachments makes the hinge axis point up for steering.
			local up = CFrame.Angles(0, 0, math.pi / 2)
			local servo = Instance.new("HingeConstraint")
			servo.Attachment0 = attachment(frame, CFrame.new(offset) * up)
			servo.Attachment1 = attachment(knuckle, up)
			servo.ActuatorType = Enum.ActuatorType.Servo
			servo.ServoMaxTorque = 1e6
			servo.AngularSpeed = 6
			servo.Parent = knuckle
			table.insert(servos, servo)
			hinge.Attachment0 = attachment(knuckle, CFrame.new())
		else
			hinge.Attachment0 = attachment(frame, CFrame.new(offset))
			hinge.ActuatorType = Enum.ActuatorType.Motor
			hinge.MotorMaxTorque = car.BrakeTorque
			hinge.MotorMaxAcceleration = car.MotorAcceleration
			hinge.AngularVelocity = 0
			table.insert(motors, hinge)
		end
		hinge.Parent = wheel
	end

	local seat = model.Installed.Seat
	seat.Disabled = false
	frame.Anchored = false

	table.insert(
		entry.conns,
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local humanoid = seat.Occupant
			if not humanoid then
				pcall(frame.SetNetworkOwnershipAuto, frame)
				return
			end
			if Players:GetPlayerFromCharacter(humanoid.Parent) ~= player then
				local seatWeld = seat:FindFirstChild("SeatWeld")
				if seatWeld then
					seatWeld:Destroy()
				end
				humanoid.Sit = false
				return
			end
			pcall(frame.SetNetworkOwner, frame, player)
		end)
	)

	table.insert(
		entry.conns,
		RunService.Heartbeat:Connect(function()
			local throttle, steer = 0, 0
			if seat.Occupant then
				throttle, steer = seat.ThrottleFloat, seat.SteerFloat
			end
			for _, motor in motors do
				if throttle ~= 0 then
					local top = throttle > 0 and car.MaxSpeed or car.ReverseSpeed
					motor.AngularVelocity = car.DriveSign * throttle * top / car.WheelRadius
					motor.MotorMaxTorque = car.MotorTorque
				else
					motor.AngularVelocity = 0
					motor.MotorMaxTorque = car.BrakeTorque
				end
			end
			local speedFraction = math.clamp(frame.AssemblyLinearVelocity.Magnitude / car.MaxSpeed, 0, 1)
			local steerScale = 1 - (1 - car.HighSpeedSteerFactor) * speedFraction
			for _, servo in servos do
				servo.TargetAngle = car.SteerSign * steer * car.MaxSteerAngle * steerScale
			end
		end)
	)
	player:SetAttribute("CarReady", true)
end

local function offerInstall(entry, player, plot, slotName)
	local slot = entry.model.Slots[slotName]
	local partType = slot:GetAttribute("PartType")
	local info = Config.Parts[partType]
	Plots.prompt(plot, slot, "Install " .. info.Label, "Your car", 0, function()
		local data = PlayerData.get(player)
		if not data or data.Installed[slotName] or Spin.isBusy(player) then
			return
		end
		if (data.Inventory[partType] or 0) < 1 then
			Remotes.Notify:FireClient(player, "Buy a " .. info.Label .. " at the parts shelf first.")
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
					Remotes.Notify:FireClient(player, "Your car is ready! Hop in the seat to drive.")
				end
			end,
		})
	end)
end

function PersonalCar.despawn(player)
	local entry = cars[player]
	cars[player] = nil
	if entry then
		for _, conn in entry.conns do
			conn:Disconnect()
		end
		entry.model:Destroy()
	end
	player:SetAttribute("CarReady", false)
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

	local entry = { model = model, conns = {} }
	cars[player] = entry
	for _, slot in Config.Slots do
		if data.Installed[slot.Name] then
			installVisual(model, slot.Name)
		else
			offerInstall(entry, player, plot, slot.Name)
		end
	end
	model.Parent = plot
	if isComplete(data) then
		assemble(entry, player)
	end
end

function PersonalCar.init()
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

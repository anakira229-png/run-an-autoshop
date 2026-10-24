local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.RunAutoshop.Config)

local Chassis = {}

local function attachment(parent, cframe)
	local a = Instance.new("Attachment")
	a.CFrame = cframe
	a.Parent = parent
	return a
end

-- Config.Car defaults with per-car overrides (tiers).
function Chassis.stats(overrides)
	local stats = table.clone(Config.Car)
	stats.Friction = 2
	for k, v in overrides or {} do
		stats[k] = v
	end
	return stats
end

-- opts: root, wheels = { { part, front } }, seat, driver() -> allowed Player?, stats
function Chassis.build(opts)
	local root, seat = opts.root, opts.seat
	local stats = opts.stats
	local motors, servos, wheels = {}, {}, {}
	local conns = {}

	for _, info in opts.wheels do
		local wheel = info.part
		table.insert(wheels, wheel)
		for _, child in wheel:GetChildren() do
			if child:IsA("WeldConstraint") and (child.Part0 == root or child.Part1 == root) then
				child:Destroy()
			end
		end
		wheel.Anchored = false
		wheel.CanCollide = true
		local offset = root.CFrame:ToObjectSpace(wheel.CFrame).Position
		local noCollide = Instance.new("NoCollisionConstraint")
		noCollide.Part0 = root
		noCollide.Part1 = wheel
		noCollide.Parent = wheel

		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment1 = attachment(wheel, CFrame.new())
		if info.front then
			local knuckle = Instance.new("Part")
			knuckle.Name = "Knuckle"
			knuckle.Size = Vector3.new(1, 1, 1)
			knuckle.Transparency = 1
			knuckle.CanCollide = false
			knuckle.CanQuery = false
			knuckle.CanTouch = false
			knuckle.CFrame = root.CFrame * CFrame.new(offset)
			knuckle.Parent = wheel.Parent
			-- Rotating the attachments makes the hinge axis point up for steering.
			local up = CFrame.Angles(0, 0, math.pi / 2)
			local servo = Instance.new("HingeConstraint")
			servo.Attachment0 = attachment(root, CFrame.new(offset) * up)
			servo.Attachment1 = attachment(knuckle, up)
			servo.ActuatorType = Enum.ActuatorType.Servo
			servo.ServoMaxTorque = 1e6
			servo.AngularSpeed = 6
			servo.Parent = knuckle
			table.insert(servos, servo)
			hinge.Attachment0 = attachment(knuckle, CFrame.new())
		else
			hinge.Attachment0 = attachment(root, CFrame.new(offset))
			hinge.ActuatorType = Enum.ActuatorType.Motor
			hinge.AngularVelocity = 0
			table.insert(motors, hinge)
		end
		hinge.Parent = wheel
	end

	-- Body decorations shouldn't change handling between car models.
	for _, part in root:GetConnectedParts(true) do
		if part ~= root and part:IsA("BasePart") and not table.find(wheels, part) then
			part.Massless = true
		end
	end

	local handle = { seat = seat, root = root }

	function handle.setStats(newStats)
		stats = newStats
		for _, motor in motors do
			motor.MotorMaxAcceleration = stats.MotorAcceleration
			motor.MotorMaxTorque = stats.BrakeTorque
		end
		for _, wheel in wheels do
			wheel.CustomPhysicalProperties = PhysicalProperties.new(0.7, stats.Friction, 0, 100, 1)
		end
	end
	handle.setStats(stats)

	function handle.driver()
		local humanoid = seat.Occupant
		return humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
	end

	function handle.destroy()
		for _, conn in conns do
			conn:Disconnect()
		end
		table.clear(conns)
	end

	seat.Disabled = false
	root.Anchored = false

	table.insert(
		conns,
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local humanoid = seat.Occupant
			if not humanoid then
				pcall(root.SetNetworkOwnershipAuto, root)
				return
			end
			local player = Players:GetPlayerFromCharacter(humanoid.Parent)
			if not player or player ~= opts.driver() then
				local seatWeld = seat:FindFirstChild("SeatWeld")
				if seatWeld then
					seatWeld:Destroy()
				end
				humanoid.Sit = false
				return
			end
			pcall(root.SetNetworkOwner, root, player)
		end)
	)

	table.insert(
		conns,
		RunService.Heartbeat:Connect(function()
			local throttle, steer = 0, 0
			if seat.Occupant then
				throttle, steer = seat.ThrottleFloat, seat.SteerFloat
			end
			for _, motor in motors do
				if throttle ~= 0 then
					local top = throttle > 0 and stats.MaxSpeed or stats.ReverseSpeed
					motor.AngularVelocity = stats.DriveSign * throttle * top / stats.WheelRadius
					motor.MotorMaxTorque = stats.MotorTorque
				else
					motor.AngularVelocity = 0
					motor.MotorMaxTorque = stats.BrakeTorque
				end
			end
			local speedFraction = math.clamp(root.AssemblyLinearVelocity.Magnitude / stats.MaxSpeed, 0, 1)
			local steerScale = 1 - (1 - stats.HighSpeedSteerFactor) * speedFraction
			for _, servo in servos do
				servo.TargetAngle = stats.SteerSign * steer * stats.MaxSteerAngle * steerScale
			end
		end)
	)

	return handle
end

function Chassis.seat(handle, player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		handle.seat:Sit(humanoid)
	end
end

function Chassis.eject(handle)
	local humanoid = handle.seat.Occupant
	local seatWeld = handle.seat:FindFirstChild("SeatWeld")
	if seatWeld then
		seatWeld:Destroy()
	end
	if humanoid then
		humanoid.Sit = false
	end
end

return Chassis

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.RunAutoshop.Config)

local isStudio = RunService:IsStudio()

local Chassis = {}

-- Attachments are placed in world space so the rig works whatever the root part's own orientation is.
local function attachment(parent, worldCFrame)
	local a = Instance.new("Attachment")
	a.Parent = parent
	a.WorldCFrame = worldCFrame
	return a
end

local function helperPart(name, cframe, size, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- AssemblyMass isn't reliable while the root is still anchored, so sum the parts that carry mass.
local function sprungMass(root)
	local total = 0
	for _, part in root:GetConnectedParts(true) do
		if part:IsA("BasePart") and (part == root or not part.Massless) then
			total += part:GetMass()
		end
	end
	return total
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

-- opts: root, frame (CFrame: car pivot, -Z forward; defaults to root.CFrame), wheels = { { part, front } }, seat,
-- driver() -> allowed Player?, stats
function Chassis.build(opts)
	local root, seat = opts.root, opts.seat
	local stats = opts.stats
	local frame = opts.frame or root.CFrame
	local frameOffset = root.CFrame:ToObjectSpace(frame)
	local up, right = frame.UpVector, frame.RightVector
	local model = root.Parent
	local gravity = workspace.Gravity
	local wheels, rear, front, servos = {}, {}, {}, {}
	local conns = {}

	-- Decorations ride along without mass or collisions, so every car model handles the same and nothing snags.
	local wheelSet = {}
	for _, info in opts.wheels do
		wheelSet[info.part] = true
		for _, d in info.part:GetDescendants() do
			wheelSet[d] = true
		end
	end
	for _, part in root:GetConnectedParts(true) do
		if part ~= root and part:IsA("BasePart") and not wheelSet[part] then
			part.Massless = true
			part.CanCollide = false
		end
	end

	-- A heavy, low ballast keeps the center of mass near axle height so the car doesn't tip in turns.
	local axleY, minX, maxX, minZ, maxZ = 0, math.huge, -math.huge, math.huge, -math.huge
	for _, info in opts.wheels do
		local p = frame:PointToObjectSpace(info.part.Position)
		axleY += p.Y / #opts.wheels
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local ballastSize = Vector3.new(math.max(maxX - minX, 1) * 0.6, 0.4, math.max(maxZ - minZ, 1) * 0.6)
	local ballast =
		helperPart("Ballast", frame * CFrame.new((minX + maxX) / 2, axleY - 0.4, (minZ + maxZ) / 2), ballastSize, model)
	local volume = ballastSize.X * ballastSize.Y * ballastSize.Z
	local density = math.clamp(sprungMass(root) * stats.BallastRatio / volume, 0.01, 100)
	ballast.CustomPhysicalProperties = PhysicalProperties.new(density, 0.3, 0, 1, 1)
	local ballastWeld = Instance.new("WeldConstraint")
	ballastWeld.Part0 = root
	ballastWeld.Part1 = ballast
	ballastWeld.Parent = ballast

	local mass = sprungMass(root)
	local cornerMass = mass / #opts.wheels
	local omega = 2 * math.pi * stats.SuspensionFrequency
	local stiffness = cornerMass * omega * omega
	local damping = 2 * stats.SuspensionDamping * math.sqrt(stiffness * cornerMass)
	-- Preload so the static sag is cancelled and the car rests at its modelled ride height.
	local sag = cornerMass * gravity / stiffness

	for _, info in opts.wheels do
		local wheel = info.part
		table.insert(wheels, wheel)
		for _, child in wheel:GetChildren() do
			if child:IsA("WeldConstraint") and (child.Part0 == root or child.Part1 == root) then
				child:Destroy()
			end
		end
		for _, d in wheel:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
			end
		end
		wheel.Anchored = false
		wheel.Massless = false
		wheel.CanCollide = true
		local noCollide = Instance.new("NoCollisionConstraint")
		noCollide.Part0 = root
		noCollide.Part1 = wheel
		noCollide.Parent = wheel

		local position = wheel.Position
		-- X axis along the car's up direction, for sliding and steering joints.
		local vertical = CFrame.fromMatrix(position, up, right)
		local strut = helperPart("Strut", CFrame.new(position) * frame.Rotation, Vector3.new(0.6, 0.6, 0.6), model)
		strut.CustomPhysicalProperties = PhysicalProperties.new(4, 0.3, 0, 1, 1)

		local slider = Instance.new("PrismaticConstraint")
		slider.Attachment0 = attachment(root, vertical)
		slider.Attachment1 = attachment(strut, vertical)
		slider.LimitsEnabled = true
		slider.LowerLimit = -stats.SuspensionTravel
		slider.UpperLimit = stats.SuspensionTravel
		slider.Restitution = 0
		slider.Parent = strut

		local spring = Instance.new("SpringConstraint")
		spring.Attachment0 = attachment(root, CFrame.new(position + up * stats.SpringHeight))
		spring.Attachment1 = attachment(strut, CFrame.new(position))
		spring.Stiffness = stiffness
		spring.Damping = damping
		spring.FreeLength = stats.SpringHeight + sag
		spring.Parent = strut

		local hub = strut
		if info.front then
			local knuckle = helperPart("Knuckle", strut.CFrame, Vector3.new(0.6, 0.6, 0.6), model)
			knuckle.CustomPhysicalProperties = PhysicalProperties.new(4, 0.3, 0, 1, 1)
			local servo = Instance.new("HingeConstraint")
			servo.Attachment0 = attachment(strut, vertical)
			servo.Attachment1 = attachment(knuckle, vertical)
			servo.ActuatorType = Enum.ActuatorType.Servo
			servo.ServoMaxTorque = 1e7
			servo.AngularSpeed = 5
			servo.Parent = knuckle
			table.insert(servos, servo)
			hub = knuckle
		end

		local axle = CFrame.new(position) * wheel.CFrame.Rotation
		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment0 = attachment(hub, axle)
		hinge.Attachment1 = attachment(wheel, axle)
		hinge.ActuatorType = Enum.ActuatorType.Motor
		hinge.AngularVelocity = 0
		hinge.MotorMaxTorque = 0
		hinge.Parent = wheel
		-- Forward rolling direction depends on which way the wheel mesh's axle points.
		local entry = {
			hinge = hinge,
			wheel = wheel,
			radius = math.min(wheel.Size.Y, wheel.Size.Z) / 2,
			spin = wheel.CFrame.XVector:Dot(right) >= 0 and -1 or 1,
		}
		table.insert(info.front and front or rear, entry)
	end

	local center = attachment(root, CFrame.new(ballast.Position) * frame.Rotation)
	local upright = Instance.new("AlignOrientation")
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.AlignType = Enum.AlignType.PrimaryAxisParallel
	upright.Attachment0 = attachment(root, CFrame.fromMatrix(ballast.Position, up, right))
	upright.PrimaryAxis = Vector3.yAxis
	upright.Responsiveness = stats.UprightResponsiveness
	upright.Parent = root
	local downforce = Instance.new("VectorForce")
	downforce.Attachment0 = center
	downforce.RelativeTo = Enum.ActuatorRelativeTo.World
	downforce.ApplyAtCenterOfMass = true
	downforce.Force = Vector3.zero
	downforce.Parent = root

	local handle = { seat = seat, root = root }
	local driveTorque, brakeTorque, coastTorque = 0, 0, 0
	local totalMass = mass
	for _, wheel in wheels do
		totalMass += wheel:GetMass()
	end

	function handle.setStats(newStats)
		stats = newStats
		local radius = rear[1] and rear[1].radius or 1.3
		-- Torques scale with mass so acceleration and braking feel the same on every car. The hinge's own
		-- acceleration cap only counts the wheel's inertia, so acceleration is set through torque instead.
		driveTorque = totalMass * stats.MotorAcceleration * radius * radius / math.max(#rear, 1)
		brakeTorque = totalMass * stats.BrakeDecel * radius / #wheels
		coastTorque = totalMass * stats.CoastDecel * radius / math.max(#rear, 1)
		for _, entry in rear do
			entry.hinge.MotorMaxAcceleration = math.huge
		end
		for _, wheel in wheels do
			wheel.CustomPhysicalProperties = PhysicalProperties.new(1.5, stats.Friction, 0, 100, 1)
		end
		upright.MaxTorque = mass * gravity * stats.UprightLever
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
			elseif isStudio then
				throttle = seat:GetAttribute("DebugThrottle") or 0
				steer = seat:GetAttribute("DebugSteer") or 0
			end
			local current = root.CFrame * frameOffset
			local velocity = root.AssemblyLinearVelocity
			local forward = velocity:Dot(current.LookVector)
			-- Pressing against the direction of travel brakes before it reverses.
			local braking = (throttle > 0 and forward < -2) or (throttle < 0 and forward > 2)
			for _, entry in rear do
				local hinge = entry.hinge
				if braking then
					hinge.AngularVelocity = 0
					hinge.MotorMaxTorque = brakeTorque
				elseif throttle ~= 0 then
					local top = throttle > 0 and stats.MaxSpeed or stats.ReverseSpeed
					hinge.AngularVelocity = entry.spin * throttle * top / entry.radius
					hinge.MotorMaxTorque = driveTorque
				else
					hinge.AngularVelocity = 0
					hinge.MotorMaxTorque = coastTorque
				end
			end
			for _, entry in front do
				entry.hinge.AngularVelocity = 0
				entry.hinge.MotorMaxTorque = braking and brakeTorque or 0
			end
			local speedFraction = math.clamp(math.abs(forward) / stats.MaxSpeed, 0, 1)
			local steerScale = 1 - (1 - stats.HighSpeedSteerFactor) * speedFraction
			for _, servo in servos do
				servo.TargetAngle = stats.SteerSign * steer * stats.MaxSteerAngle * steerScale
			end
			downforce.Force = -Vector3.yAxis * (mass * gravity * stats.Downforce * speedFraction * speedFraction)
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

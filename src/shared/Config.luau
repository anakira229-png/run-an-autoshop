return {
	DataStoreName = "RunAutoshop_Dev_v1",
	AutosaveInterval = 60,
	StartingMoney = 0,
	InteractDistance = 12,

	Work = {
		MaxDistance = 30,
		ActionCooldown = 0.1,
		ShopCooldown = 0.3,
	},

	Jobs = {
		FlatTire = { Label = "Flat tire", Payout = 60 },
		Dent = { Label = "Dented panel", Payout = 80 },
	},
	-- Stars from total misses: misses <= MaxMisses[3] gives 3 stars, <= MaxMisses[2] gives 2, otherwise 1.
	MaxMisses = { [3] = 1, [2] = 3 },
	StarMultipliers = { [3] = 1, [2] = 0.8, [1] = 0.6 },
	CustomerDelay = 4,
	CustomerSpeed = 28,
	-- Test-drive seat offset from each customer car's pivot; HideDriver for roofs too low for a seated avatar.
	CarSeats = {
		Default = { Offset = Vector3.new(-1.3, 1.25, 0.35) },
		Sedan = { Offset = Vector3.new(-1.3, 1.25, 0.35) },
		SportSedan = { Offset = Vector3.new(-1.13, 1.75, -0.65), HideDriver = true },
	},
	CustomerColors = {
		Color3.fromRGB(70, 110, 170),
		Color3.fromRGB(170, 50, 45),
		Color3.fromRGB(230, 230, 225),
		Color3.fromRGB(60, 140, 80),
		Color3.fromRGB(230, 170, 40),
		Color3.fromRGB(40, 40, 45),
	},

	Parts = {
		Engine = { Label = "Engine", Price = 150, Needed = 1 },
		Transmission = { Label = "Transmission", Price = 100, Needed = 1 },
		Battery = { Label = "Battery", Price = 50, Needed = 1 },
		Seat = { Label = "Seat", Price = 40, Needed = 1 },
		Wheel = { Label = "Wheel", Price = 25, Needed = 4 },
	},
	Slots = {
		{ Name = "Engine", PartType = "Engine" },
		{ Name = "Transmission", PartType = "Transmission" },
		{ Name = "Battery", PartType = "Battery" },
		{ Name = "Seat", PartType = "Seat" },
		{ Name = "WheelFL", PartType = "Wheel" },
		{ Name = "WheelFR", PartType = "Wheel" },
		{ Name = "WheelRL", PartType = "Wheel" },
		{ Name = "WheelRR", PartType = "Wheel" },
	},

	Upgrades = {
		BetterTools = { Label = "Better Tools", Price = 200 },
	},

	Spin = {
		LugDegrees = 1440,
		InstallDegrees = 720,
		SlipRate = 540,
		SlipCooldown = 0.6,
		BudgetSlack = 1.15,
		MaxDistance = 20,
		BetterToolsDegrees = 0.7,
		BetterToolsSlipRate = 1.4,
	},

	Dent = {
		Count = 6,
		Lifetime = 1.6,
		Gap = 0.35,
		MaxDistance = 24,
		BetterToolsLifetime = 1.5,
	},

	Car = {
		MaxSpeed = 60,
		ReverseSpeed = 25,
		-- Wheel angular acceleration cap in rad/s^2; about 2.3s from 0 to top speed.
		MotorAcceleration = 20,
		-- Decelerations in studs/s^2: brakes when pressing against travel, engine braking when coasting.
		BrakeDecel = 70,
		CoastDecel = 14,
		MaxSteerAngle = 30,
		HighSpeedSteerFactor = 0.5,
		-- Flip if playtesting shows the car steers the wrong way.
		SteerSign = -1,
		SuspensionFrequency = 2,
		SuspensionDamping = 0.6,
		SuspensionTravel = 0.7,
		SpringHeight = 2.5,
		-- Ballast mass as a fraction of the body's, placed low to keep the car flat.
		BallastRatio = 1,
		-- Extra down force at top speed as a fraction of the car's weight.
		Downforce = 0.35,
		-- Self-righting torque limit in car-weight x studs; low enough that suspension can still lean.
		UprightLever = 1.2,
		UprightResponsiveness = 12,
		ResetCooldown = 3,
	},

	-- Tier 1 is the stock part; buying a tier requires the previous one and the base part installed.
	Tiers = {
		Names = { "Stock", "Sport", "Race" },
		Colors = { nil, Color3.fromRGB(200, 45, 40), Color3.fromRGB(230, 180, 40) },
		Engine = {
			{ MaxSpeed = 60 },
			{ MaxSpeed = 72, Price = 400 },
			{ MaxSpeed = 86, Price = 900 },
		},
		Transmission = {
			{ MotorAcceleration = 20 },
			{ MotorAcceleration = 28, Price = 250 },
			{ MotorAcceleration = 38, Price = 600 },
		},
		-- Roblox clamps friction to 2.
		Wheel = {
			{ Friction = 1.4, HighSpeedSteerFactor = 0.5 },
			{ Friction = 1.7, HighSpeedSteerFactor = 0.58, Price = 200 },
			{ Friction = 2, HighSpeedSteerFactor = 0.66, Price = 500 },
		},
	},

	TestDrive = {
		OfferTime = 15,
		TimeLimit = 75,
		CheckpointRadius = 16,
		ParkRadius = 8,
		ParkMaxSpeed = 4,
		OutOfCarLimit = 10,
		TipBase = 15,
		TipPerSecondLeft = 0.5,
	},

	-- Spawn spots live in WorldData.CalloutSpots.
	Callouts = {
		FirstDelay = 45,
		Interval = 75,
		OfferTime = 20,
		ExpireTime = 240,
		PayoutMultiplier = 2,
	},
}

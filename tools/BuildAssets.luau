-- Synced by Rojo to ServerStorage.RunAutoshopTools. Owned by the Art agent. Run in edit mode with:
-- require(game.ServerStorage.RunAutoshopTools.BuildAssets:Clone())()
-- Replaces ServerStorage.RunAutoshopAssets (part templates, customer car, personal chassis).
-- Run before BuildMap, which copies part templates onto the shop shelves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PartUtil = require(ReplicatedStorage.RunAutoshop.PartUtil)

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color or Color3.fromRGB(160, 160, 160)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function weldAll(model, root)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
			d.Anchored = false
		end
	end
end

-- Part templates, shared by the parts shelf, customer cars, and the personal car.
local function buildPartTemplates(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Parts"
	local metal = Enum.Material.DiamondPlate

	local engine = part(folder, "Engine", Vector3.new(2.6, 1.4, 2.4), CFrame.new(), Color3.fromRGB(90, 95, 105), metal)
	engine:SetAttribute("PartType", "Engine")
	local trans =
		part(folder, "Transmission", Vector3.new(1.6, 1, 2), CFrame.new(), Color3.fromRGB(120, 110, 95), metal)
	trans:SetAttribute("PartType", "Transmission")
	local battery = part(folder, "Battery", Vector3.new(1.2, 1, 1), CFrame.new(), Color3.fromRGB(30, 30, 35))
	battery:SetAttribute("PartType", "Battery")

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.4, 1, 2.4)
	seat.Color = Color3.fromRGB(140, 30, 30)
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat:SetAttribute("PartType", "Seat")
	seat.Parent = folder

	local wheel = part(
		folder,
		"Wheel",
		Vector3.new(1.2, 2.6, 2.6),
		CFrame.new(),
		Color3.fromRGB(25, 25, 25),
		Enum.Material.SmoothPlastic,
		{
			Shape = Enum.PartType.Cylinder,
			CustomPhysicalProperties = PhysicalProperties.new(0.7, 2, 0, 100, 1),
		}
	)
	wheel:SetAttribute("PartType", "Wheel")
	local hub = part(
		wheel,
		"Hub",
		Vector3.new(1.3, 1.2, 1.2),
		CFrame.new(),
		Color3.fromRGB(190, 190, 195),
		Enum.Material.Metal,
		{
			Shape = Enum.PartType.Cylinder,
			Anchored = false,
			CanCollide = false,
			Massless = true,
		}
	)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = wheel
	weld.Part1 = hub
	weld.Parent = hub
	folder.Parent = parent
	return folder
end

local function buildCustomerCar(parent, parts)
	local model = Instance.new("Model")
	model.Name = "CustomerCar"
	local body = part(model, "Body", Vector3.new(6.4, 1.8, 13), CFrame.new(0, 2.5, 0), Color3.fromRGB(70, 110, 170))
	body:SetAttribute("Paint", true)
	local cabin = part(
		model,
		"Cabin",
		Vector3.new(5.6, 1.8, 6.5),
		CFrame.new(0, 4.3, 0.8),
		Color3.fromRGB(45, 55, 65),
		Enum.Material.Glass,
		{
			Transparency = 0.15,
		}
	)
	cabin:SetAttribute("Paint", false)
	part(model, "Roof", Vector3.new(5.8, 0.3, 5.6), CFrame.new(0, 5.35, 1.0), body.Color):SetAttribute("Paint", true)
	part(model, "Panel_Hood", Vector3.new(6.0, 0.2, 3.6), CFrame.new(0, 3.5, -4.4), body.Color):SetAttribute(
		"Paint",
		true
	)
	part(model, "Panel_Left", Vector3.new(0.2, 1.4, 6), CFrame.new(-3.3, 2.6, 0.5), body.Color):SetAttribute(
		"Paint",
		true
	)
	part(model, "Panel_Right", Vector3.new(0.2, 1.4, 6), CFrame.new(3.3, 2.6, 0.5), body.Color):SetAttribute(
		"Paint",
		true
	)
	part(model, "BumperFront", Vector3.new(6.6, 0.6, 0.6), CFrame.new(0, 1.9, -6.6), Color3.fromRGB(40, 40, 40))
	part(model, "BumperRear", Vector3.new(6.6, 0.6, 0.6), CFrame.new(0, 1.9, 6.6), Color3.fromRGB(40, 40, 40))
	for _, x in { -2.2, 2.2 } do
		part(
			model,
			"Headlight",
			Vector3.new(1.2, 0.5, 0.1),
			CFrame.new(x, 2.8, -6.55),
			Color3.fromRGB(255, 245, 210),
			Enum.Material.Neon
		)
		part(
			model,
			"Taillight",
			Vector3.new(1.2, 0.5, 0.1),
			CFrame.new(x, 2.8, 6.55),
			Color3.fromRGB(200, 20, 20),
			Enum.Material.Neon
		)
	end
	for name, pos in
		{
			Wheel_FL = Vector3.new(-3.5, 1.3, -4.2),
			Wheel_FR = Vector3.new(3.5, 1.3, -4.2),
			Wheel_RL = Vector3.new(-3.5, 1.3, 4.2),
			Wheel_RR = Vector3.new(3.5, 1.3, 4.2),
		}
	do
		local w = parts.Wheel:Clone()
		w.Name = name
		PartUtil.place(w, CFrame.new(pos))
		w.Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = d == body
		end
	end
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	weldAll(model, body)
	body.Anchored = true
	model.Parent = parent
end

local SLOTS = {
	{ "Engine", "Engine", Vector3.new(0, 2.9, -3.4) },
	{ "Transmission", "Transmission", Vector3.new(0, 2.7, -0.8) },
	{ "Battery", "Battery", Vector3.new(2.1, 2.7, -4.4) },
	{ "Seat", "Seat", Vector3.new(0, 2.7, 2.2) },
	{ "WheelFL", "Wheel", Vector3.new(-3.5, 1.3, -3.8) },
	{ "WheelFR", "Wheel", Vector3.new(3.5, 1.3, -3.8) },
	{ "WheelRL", "Wheel", Vector3.new(-3.5, 1.3, 3.8) },
	{ "WheelRR", "Wheel", Vector3.new(3.5, 1.3, 3.8) },
}

local function buildPersonalChassis(parent, parts)
	local model = Instance.new("Model")
	model.Name = "PersonalChassis"
	local frame = part(
		model,
		"Frame",
		Vector3.new(5.6, 0.6, 11),
		CFrame.new(0, 1.9, 0),
		Color3.fromRGB(70, 70, 75),
		Enum.Material.Metal,
		{
			CustomPhysicalProperties = PhysicalProperties.new(2, 0.3, 0, 1, 1),
		}
	)
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	for _, s in SLOTS do
		local template = parts[s[2]]
		local slot =
			part(slots, s[1], template.Size, CFrame.new(s[3]), Color3.fromRGB(80, 200, 255), Enum.Material.ForceField, {
				Shape = template:IsA("Part") and template.Shape or Enum.PartType.Block,
				CanCollide = false,
				CanQuery = true,
				CanTouch = false,
				Massless = true,
				Transparency = 0.3,
			})
		slot:SetAttribute("PartType", s[2])
	end
	model.PrimaryPart = frame
	model.WorldPivot = CFrame.new()
	weldAll(model, frame)
	frame.Anchored = true
	model.Parent = parent
end

return function()
	local old = ServerStorage:FindFirstChild("RunAutoshopAssets")
	if old then
		old:Destroy()
	end
	local assets = Instance.new("Folder")
	assets.Name = "RunAutoshopAssets"
	local parts = buildPartTemplates(assets)
	buildCustomerCar(assets, parts)
	buildPersonalChassis(assets, parts)
	assets.Parent = ServerStorage
	return "Assets built: " .. #assets:GetDescendants() .. " instances"
end

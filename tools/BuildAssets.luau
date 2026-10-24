-- Synced by Rojo to ServerStorage.RunAutoshopTools. Owned by the Art agent. Run in edit mode with:
-- require(game.ServerStorage.RunAutoshopTools.BuildAssets:Clone())()
-- Replaces ServerStorage.RunAutoshopAssets (part templates, customer car, personal chassis).
-- Run before BuildMap, which copies part templates onto the shop shelves.
-- Uses meshes from ServerStorage.RunAutoshopMeshes (see ImportPack and ImportCar) when present, else blocks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PartUtil = require(ReplicatedStorage.RunAutoshop.PartUtil)

local TRIM_LOOK = { Color3.fromRGB(40, 40, 45), Enum.Material.SmoothPlastic }

-- Looks for parts-kit meshes, keyed "<Kit>.<Mesh>"; kit root meshes take the template's own look.
local KIT_LOOKS = {
	["Engine.ValveCover"] = { Color3.fromRGB(205, 205, 212), Enum.Material.Metal },
	["Engine.Intake"] = { Color3.fromRGB(175, 178, 185), Enum.Material.Metal },
	["Engine.Exhaust"] = { Color3.fromRGB(110, 90, 75), Enum.Material.CorrodedMetal },
	["Engine.Pulleys"] = { Color3.fromRGB(30, 30, 32), Enum.Material.SmoothPlastic },
	["Transmission.Pan"] = { Color3.fromRGB(70, 68, 66), Enum.Material.Metal },
	["Transmission.Yoke"] = { Color3.fromRGB(190, 190, 195), Enum.Material.Metal },
	["Battery.TerminalPos"] = { Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic },
	["Battery.TerminalNeg"] = { Color3.fromRGB(40, 40, 45), Enum.Material.SmoothPlastic },
	["Battery.Label"] = { Color3.fromRGB(240, 190, 40), Enum.Material.SmoothPlastic },
	["Seat.Cushion"] = { Color3.fromRGB(140, 30, 30), Enum.Material.Fabric },
	["Seat.Back"] = { Color3.fromRGB(140, 30, 30), Enum.Material.Fabric },
	["Wheel.Tire"] = { Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic },
	["Wheel.Hub"] = { Color3.fromRGB(190, 190, 195), Enum.Material.Metal },
}

local function meshSource(name)
	local meshes = ServerStorage:FindFirstChild("RunAutoshopMeshes")
	return meshes and meshes:FindFirstChild(name)
end

-- A kit imported by ImportPack: a Model whose PrimaryPart is the root mesh.
local function meshKit(name)
	local kit = meshSource(name)
	return kit and kit:IsA("Model") and kit.PrimaryPart and kit or nil
end

local function weldTo(root, p)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

-- Makes p a welded, non-colliding visual child of root. The weld lives in p so root's own welds stay findable.
local function attachVisual(root, p)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	weldTo(root, p)
	p.Parent = root
end

-- Copies the kit's meshes onto root as visual children, laid out relative to the kit's root mesh.
local function addKitMeshes(root, kit, skipRoot)
	local ref = kit.PrimaryPart
	for _, mesh in kit:GetChildren() do
		if mesh:IsA("BasePart") and not (skipRoot and mesh == ref) then
			local copy = mesh:Clone()
			copy:ClearAllChildren()
			copy.CFrame = root.CFrame * ref.CFrame:ToObjectSpace(mesh.CFrame)
			local look = KIT_LOOKS[kit.Name .. "." .. mesh.Name] or TRIM_LOOK
			copy.Color = look[1]
			copy.Material = look[2]
			attachVisual(root, copy)
		end
	end
end

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
-- Engine, Transmission, and Battery use the kit's root mesh as the part; its size matches the block fallback.
local function rootPart(folder, name, size, color, blockMaterial)
	local kit = meshKit(name)
	local p
	if kit then
		p = kit.PrimaryPart:Clone()
		p:ClearAllChildren()
		p.Name = name
		p.CFrame = CFrame.new()
		p.Color = color
		p.Material = Enum.Material.Metal
		p.Anchored = true
		p.Parent = folder
		addKitMeshes(p, kit, true)
	else
		p = part(folder, name, size, CFrame.new(), color, blockMaterial)
	end
	p:SetAttribute("PartType", name)
	return p
end

local function buildPartTemplates(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Parts"
	local metal = Enum.Material.DiamondPlate

	rootPart(folder, "Engine", Vector3.new(2.6, 1.4, 2.4), Color3.fromRGB(90, 95, 105), metal)
	rootPart(folder, "Transmission", Vector3.new(1.6, 1, 2), Color3.fromRGB(120, 110, 95), metal)
	local battery =
		rootPart(folder, "Battery", Vector3.new(1.2, 1, 1), Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic)
	battery.Material = Enum.Material.SmoothPlastic

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
	local seatKit = meshKit("Seat")
	if seatKit then
		seat.CFrame = CFrame.new()
		seat.Transparency = 1
		addKitMeshes(seat, seatKit, false)
	end

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
	-- The cylinder stays the physics and click root; the kit's tire mesh encloses it and its hub covers the ends.
	local wheelKit = meshKit("Wheel")
	if wheelKit then
		addKitMeshes(wheel, wheelKit, false)
		folder.Parent = parent
		return folder
	end
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

local MESH_PAINT = {
	Body = true,
	Cabin = true,
	Roof = true,
	Panel_Hood = true,
	Panel_Left = true,
	Panel_Right = true,
	Pillar = true,
	Mirror = true,
}

-- Solid looks per imported part name; anything unlisted gets the trim look.
local MESH_LOOKS = {
	Glass = { Color3.fromRGB(40, 55, 70), Enum.Material.Glass, 0.35 },
	Interior = { Color3.fromRGB(55, 55, 60), Enum.Material.Fabric },
	Headlight = { Color3.fromRGB(255, 245, 210), Enum.Material.Neon },
	Taillight = { Color3.fromRGB(200, 20, 20), Enum.Material.Neon },
	Tire = { Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic },
	Hub = { Color3.fromRGB(190, 190, 195), Enum.Material.Metal },
	BumperFront = { Color3.fromRGB(50, 50, 55), Enum.Material.SmoothPlastic },
	BumperRear = { Color3.fromRGB(50, 50, 55), Enum.Material.SmoothPlastic },
	Plate = { Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic },
	Exhaust = { Color3.fromRGB(190, 190, 195), Enum.Material.Metal },
	EngineBlock = { Color3.fromRGB(95, 100, 110), Enum.Material.Metal },
	EngineCover = { Color3.fromRGB(200, 50, 40), Enum.Material.SmoothPlastic },
	OilCap = { Color3.fromRGB(240, 190, 40), Enum.Material.SmoothPlastic },
	Battery = { Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic },
	Reservoir = { Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic },
}
local DEFAULT_PAINT = Color3.fromRGB(70, 110, 170)
local WHEEL_NAMES = { "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR" }

-- Replaces an imported tire mesh with a cylinder physics root (template size) that carries the tire and hub meshes.
local function meshWheel(model, tire, template)
	local hub = tire:FindFirstChild("Hub")
	local wheel =
		part(model, tire.Name, template.Size, CFrame.new(tire.Position), MESH_LOOKS.Tire[1], MESH_LOOKS.Tire[2], {
			Shape = Enum.PartType.Cylinder,
			CustomPhysicalProperties = template.CustomPhysicalProperties,
			CanCollide = false,
		})
	tire.Name = "Tire"
	attachVisual(wheel, tire)
	if hub then
		attachVisual(wheel, hub)
	end
	return wheel
end

-- Customer car from ServerStorage.RunAutoshopMeshes.<name> (see ImportCar), or nil if not imported.
local function buildMeshCustomerCar(parent, parts, meshName)
	local source = meshSource(meshName)
	if not source then
		return nil
	end
	local model = source:Clone()
	model.Name = "CustomerCar"
	local body = model.Body
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			local paint = MESH_PAINT[d.Name] == true
			d:SetAttribute("Paint", paint)
			if paint then
				d.Color = DEFAULT_PAINT
				d.Material = Enum.Material.SmoothPlastic
			else
				local look = MESH_LOOKS[d.Name] or (d.Name:match("^Wheel_") and MESH_LOOKS.Tire) or TRIM_LOOK
				d.Color = look[1]
				d.Material = look[2]
				d.Transparency = look[3] or 0
			end
			d.CanCollide = d == body
			d.Anchored = true
		end
	end
	for _, name in WHEEL_NAMES do
		meshWheel(model, model[name], parts.Wheel)
	end
	-- The bay battery becomes the shelf template so the battery swap replaces it in place.
	local battery = model:FindFirstChild("Battery")
	if battery then
		local swap = parts.Battery:Clone()
		PartUtil.place(swap, CFrame.new(battery.Position))
		swap.CanCollide = false
		battery:Destroy()
		swap.Parent = model
	end
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	weldAll(model, body)
	body.Anchored = true
	model.Parent = parent
	return model
end

local function buildCustomerCar(parent, parts)
	if buildMeshCustomerCar(parent, parts, "Sedan") then
		return
	end
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

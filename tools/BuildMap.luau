-- Run in Studio edit mode (command bar or MCP) to rebuild the placeholder map and car templates.
-- Only replaces Workspace.RunAutoshopMap and ServerStorage.RunAutoshopAssets.
local ServerStorage = game:GetService("ServerStorage")

local PLOT_POSITIONS = {
	CFrame.new(-60, 0, -60),
	CFrame.new(60, 0, -60),
	CFrame.new(-60, 0, 60) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(60, 0, 60) * CFrame.Angles(0, math.pi, 0),
}

local GROUND = 0.2
local ASPHALT = Color3.fromRGB(55, 57, 62)

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

local function marker(parent, name, cframe)
	return part(parent, name, Vector3.new(1, 1, 1), cframe, Color3.new(1, 0, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
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
		w.CFrame = CFrame.new(pos)
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

local function buildPlot(parent, index, pivot)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local function at(x, y, z)
		return pivot * CFrame.new(x, y, z)
	end
	local concrete = Color3.fromRGB(175, 172, 165)
	local wall = Color3.fromRGB(205, 200, 190)

	part(model, "Floor", Vector3.new(80, 0.2, 80), at(0, 0.1, 0), concrete, Enum.Material.Concrete)
	part(model, "Apron", Vector3.new(80, 0.2, 8), at(0, 0.1, -44), ASPHALT, Enum.Material.Asphalt)
	for _, x in { -26.5, -9.5 } do
		part(
			model,
			"BayLine",
			Vector3.new(0.5, 0.05, 26),
			at(x, 0.225, 8),
			Color3.fromRGB(240, 200, 40),
			Enum.Material.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	for _, x in { 9.5, 26.5 } do
		part(
			model,
			"PadLine",
			Vector3.new(0.5, 0.05, 26),
			at(x, 0.225, 8),
			Color3.fromRGB(60, 160, 240),
			Enum.Material.SmoothPlastic,
			{ CanCollide = false }
		)
	end

	part(model, "BackWall", Vector3.new(80, 18, 2), at(0, 9.2, 39), wall, Enum.Material.Brick)
	part(model, "LeftWall", Vector3.new(2, 18, 44), at(-39, 9.2, 17), wall, Enum.Material.Brick)
	part(model, "RightWall", Vector3.new(2, 18, 44), at(39, 9.2, 17), wall, Enum.Material.Brick)
	part(model, "Roof", Vector3.new(82, 1, 47), at(0, 18.7, 16.5), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)

	local sign = part(model, "Sign", Vector3.new(30, 5, 1), at(0, 15.5, -6.5), Color3.fromRGB(30, 30, 35))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.Text = "Shop for rent"
	label.Parent = gui

	-- Parts shelf: one display item per buyable part.
	local shelf = Instance.new("Model")
	shelf.Name = "PartsShelf"
	shelf.Parent = model
	part(shelf, "Table", Vector3.new(18, 0.6, 5), at(29, 3, 34), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
	for _, x in { 21, 37 } do
		part(shelf, "Leg", Vector3.new(0.6, 2.7, 4), at(x, 1.35, 34), Color3.fromRGB(80, 60, 40), Enum.Material.Wood)
	end
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = shelf
	local order = { "Engine", "Transmission", "Battery", "Seat", "Wheel" }
	for i, name in order do
		local item = ServerStorage.RunAutoshopAssets.Parts[name]:Clone()
		item.Name = name
		item.Anchored = true
		if item:IsA("VehicleSeat") then
			item.Disabled = true
		end
		item.CFrame = at(21.5 + (i - 1) * 3.6, 3.3 + item.Size.Y / 2, 34)
		item.Parent = items
	end

	local bench = Instance.new("Model")
	bench.Name = "ToolBench"
	bench.Parent = model
	part(bench, "Table", Vector3.new(12, 0.6, 5), at(-30, 3, 34), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
	for _, x in { -35, -25 } do
		part(bench, "Leg", Vector3.new(0.6, 2.7, 4), at(x, 1.35, 34), Color3.fromRGB(80, 60, 40), Enum.Material.Wood)
	end
	part(bench, "Toolbox", Vector3.new(3, 1.5, 2), at(-30, 4.05, 34), Color3.fromRGB(200, 40, 40), Enum.Material.Metal)

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = model
	marker(markers, "Bay", at(-18, GROUND, 8) * CFrame.Angles(0, math.pi, 0))
	marker(markers, "CarPad", at(18, GROUND, 8))
	marker(markers, "SpawnPoint", at(0, 3, -20) * CFrame.Angles(0, math.pi, 0))
	local path = {
		In1 = Vector3.new(-70, GROUND, -62),
		In2 = Vector3.new(-32, GROUND, -62),
		In3 = Vector3.new(-18, GROUND, -50),
		Out1 = Vector3.new(-18, GROUND, -36),
		Out2 = Vector3.new(-4, GROUND, -56),
		Out3 = Vector3.new(70, GROUND, -58),
	}
	for name, v in path do
		marker(markers, name, at(v.X, v.Y, v.Z))
	end

	model.WorldPivot = pivot
	model.Parent = parent
end

local function buildRoads(parent)
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = parent
	local function road(size, pos)
		part(roads, "Road", size, CFrame.new(pos), ASPHALT, Enum.Material.Asphalt)
	end
	local function line(size, pos)
		part(
			roads,
			"Line",
			size,
			CFrame.new(pos),
			Color3.fromRGB(235, 200, 50),
			Enum.Material.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	-- Outer ring.
	road(Vector3.new(264, 0.2, 24), Vector3.new(0, 0.1, -120))
	road(Vector3.new(264, 0.2, 24), Vector3.new(0, 0.1, 120))
	road(Vector3.new(24, 0.2, 216), Vector3.new(-120, 0.1, 0))
	road(Vector3.new(24, 0.2, 216), Vector3.new(120, 0.1, 0))
	-- Center cross.
	road(Vector3.new(24, 0.2, 216), Vector3.new(0, 0.1, 0))
	road(Vector3.new(96, 0.2, 24), Vector3.new(-60, 0.1, 0))
	road(Vector3.new(96, 0.2, 24), Vector3.new(60, 0.1, 0))
	-- Center lines between intersections.
	for _, z in { -120, 120 } do
		for _, x in { -60, 60 } do
			line(Vector3.new(96, 0.05, 0.5), Vector3.new(x, 0.225, z))
		end
	end
	for _, x in { -120, 0, 120 } do
		for _, z in { -60, 60 } do
			line(Vector3.new(0.5, 0.05, 96), Vector3.new(x, 0.225, z))
		end
	end
	for _, x in { -60, 60 } do
		line(Vector3.new(96, 0.05, 0.5), Vector3.new(x, 0.225, 0))
	end
end

local old = workspace:FindFirstChild("RunAutoshopMap")
if old then
	old:Destroy()
end
local oldAssets = ServerStorage:FindFirstChild("RunAutoshopAssets")
if oldAssets then
	oldAssets:Destroy()
end

local assets = Instance.new("Folder")
assets.Name = "RunAutoshopAssets"
assets.Parent = ServerStorage
local parts = buildPartTemplates(assets)
buildCustomerCar(assets, parts)
buildPersonalChassis(assets, parts)

local map = Instance.new("Folder")
map.Name = "RunAutoshopMap"
local plots = Instance.new("Folder")
plots.Name = "Plots"
plots.Parent = map
for i, pivot in PLOT_POSITIONS do
	buildPlot(plots, i, pivot)
end
buildRoads(map)
map.Parent = workspace

return "Map built"

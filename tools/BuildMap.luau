-- Synced by Rojo to ServerStorage.RunAutoshopTools. Owned by the World agent. Run in edit mode with:
-- require(game.ServerStorage.RunAutoshopTools.BuildMap:Clone())()
-- Replaces Workspace.RunAutoshopMap (plots, then the city via BuildCity) and restyles Lighting, the Baseplate, and the
-- spawn. Needs BuildAssets to have run.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PartUtil = require(ReplicatedStorage.RunAutoshop.PartUtil)
local City = require(ServerStorage.RunAutoshopTools.BuildCity:Clone())

-- Plots sit on Main Street (z = 0), two per side, with their shop fronts facing it.
local PLOT_POSITIONS = {
	CFrame.new(-60, 0, -60) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(60, 0, -60) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(-60, 0, 60),
	CFrame.new(60, 0, 60),
}

local GROUND = City.GROUND
local ASPHALT = Color3.fromRGB(55, 57, 62)
local part = City.part
local marker = City.marker
local TOWN_SQUARE_SPAWN = Vector3.new(-180, City.PAD_TOP + 0.5, 25)

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
		PartUtil.place(item, at(21.5 + (i - 1) * 3.6, 3.3 + item.Size.Y / 2, 34))
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

	local props = Instance.new("Model")
	props.Name = "Props"
	props.Parent = model
	local warm = Color3.fromRGB(255, 240, 215)
	local function lamp(size, cframe, range)
		local p = part(props, "Lamp", size, cframe, warm, Enum.Material.Neon, { CanCollide = false })
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = range
		light.Brightness = 2.5
		light.Angle = 110
		light.Color = warm
		light.Parent = p
	end
	lamp(Vector3.new(1.2, 0.3, 16), at(-18, 17.9, 8), 22)
	lamp(Vector3.new(1.2, 0.3, 16), at(18, 17.9, 8), 22)
	lamp(Vector3.new(40, 0.3, 1.2), at(0, 17.9, 31), 20)

	local liftBlue = Color3.fromRGB(40, 80, 160)
	for _, x in { -23.6, -12.4 } do
		part(props, "LiftPost", Vector3.new(1, 9, 1), at(x, 4.7, 8), liftBlue, Enum.Material.Metal)
	end
	part(props, "LiftBeam", Vector3.new(12.2, 0.8, 1.2), at(-18, 9.6, 8), liftBlue, Enum.Material.Metal)
	part(
		props,
		"OilStain",
		Vector3.new(0.02, 5, 5),
		at(-18, 0.21, 6) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(25, 25, 28),
		nil,
		{
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.45,
			CanCollide = false,
		}
	)

	for _, z in { -1, 4 } do
		for i = 0, 2 do
			part(
				props,
				"Tire",
				Vector3.new(0.9, 2.6, 2.6),
				at(-34, 0.65 + i * 0.9, z) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(30, 30, 32),
				nil,
				{
					Shape = Enum.PartType.Cylinder,
				}
			)
		end
	end
	for i, color in { Color3.fromRGB(180, 40, 35), Color3.fromRGB(40, 90, 170) } do
		part(
			props,
			"Drum",
			Vector3.new(3.2, 2, 2),
			at(34, 1.8, -2 + i * 2.4) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			Enum.Material.Metal,
			{
				Shape = Enum.PartType.Cylinder,
			}
		)
	end

	part(props, "Pegboard", Vector3.new(14, 6, 0.2), at(-30, 9, 37.9), Color3.fromRGB(150, 115, 80), Enum.Material.Wood)
	for i = -2, 2 do
		part(
			props,
			"Tool",
			Vector3.new(0.3, 2.4 + (i % 2) * 0.8, 0.15),
			at(-30 + i * 2.5, 9, 37.75),
			Color3.fromRGB(60, 60, 65),
			Enum.Material.Metal
		)
	end
	local shopSign = part(props, "ShopSign", Vector3.new(22, 3.2, 0.2), at(0, 14.5, 37.9), Color3.fromRGB(30, 30, 35))
	local shopGui = Instance.new("SurfaceGui")
	shopGui.Face = Enum.NormalId.Front
	shopGui.PixelsPerStud = 40
	shopGui.LightInfluence = 0
	shopGui.Parent = shopSign
	local shopText = Instance.new("TextLabel")
	shopText.Size = UDim2.fromScale(1, 1)
	shopText.BackgroundTransparency = 1
	shopText.TextScaled = true
	shopText.Font = Enum.Font.GothamBlack
	shopText.TextColor3 = Color3.fromRGB(255, 120, 40)
	shopText.Text = "AUTO REPAIR"
	shopText.Parent = shopGui

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = model
	marker(markers, "Bay", at(-18, GROUND, 8) * CFrame.Angles(0, math.pi, 0))
	marker(markers, "CarPad", at(18, GROUND, 8))
	marker(markers, "SpawnPoint", at(0, 3, -20) * CFrame.Angles(0, math.pi, 0))
	local path = {
		In1 = Vector3.new(-70, GROUND, -54),
		In2 = Vector3.new(-32, GROUND, -54),
		In3 = Vector3.new(-18, GROUND, -50),
		Out1 = Vector3.new(-18, GROUND, -36),
		Out2 = Vector3.new(-4, GROUND, -54),
		Out3 = Vector3.new(70, GROUND, -54),
	}
	for name, v in path do
		marker(markers, name, at(v.X, v.Y, v.Z))
	end

	model.WorldPivot = pivot
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
end

local function setupLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(40, 40, 50)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 105, 115)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Haze = 1.5
	atmosphere.Glare = 0.6
	atmosphere.Color = Color3.fromRGB(200, 170, 140)
	atmosphere.Decay = Color3.fromRGB(105, 90, 120)
	atmosphere.Parent = Lighting
	local grade = Lighting:FindFirstChild("RunAutoshopGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "RunAutoshopGrade"
	grade.Saturation = 0.1
	grade.Contrast = 0.08
	grade.TintColor = Color3.fromRGB(255, 245, 235)
	grade.Parent = Lighting

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate.Material = Enum.Material.Grass
		baseplate.Color = Color3.fromRGB(78, 112, 62)
		for _, texture in baseplate:GetChildren() do
			if texture:IsA("Texture") then
				texture.Transparency = 1
			end
		end
	end
end

return function()
	assert(
		ServerStorage:FindFirstChild("RunAutoshopAssets"),
		"Run BuildAssets first; the shop shelves copy its part templates."
	)
	local old = workspace:FindFirstChild("RunAutoshopMap")
	if old then
		old:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "RunAutoshopMap"
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	for i, pivot in PLOT_POSITIONS do
		buildPlot(plots, i, pivot)
	end
	local partCount = City.build(map)
	local problems = City.validate(map)
	for _, problem in problems do
		warn("BuildMap: " .. problem)
	end
	map.Parent = workspace
	setupLighting()
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if spawn then
		spawn.Position = TOWN_SQUARE_SPAWN
	end
	return "Map built: "
		.. #map:GetDescendants()
		.. " instances ("
		.. partCount
		.. " city parts), "
		.. #problems
		.. " WorldData problems"
end

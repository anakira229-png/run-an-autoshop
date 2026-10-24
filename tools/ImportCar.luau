-- Synced by Rojo to ServerStorage.RunAutoshopTools. After importing an FBX with Studio's 3D Importer
-- (File dimensions: Studs), run in edit mode:
-- require(game.ServerStorage.RunAutoshopTools.ImportCar:Clone())("Sedan")
-- Moves the imported model into ServerStorage.RunAutoshopMeshes, normalized for BuildMap.
local ServerStorage = game:GetService("ServerStorage")

local REQUIRED = {
	"Body",
	"Cabin",
	"Roof",
	"Panel_Hood",
	"Panel_Left",
	"Panel_Right",
	"Wheel_FL",
	"Wheel_FR",
	"Wheel_RL",
	"Wheel_RR",
}
local WHEELS = { "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR" }

return function(modelName)
	local source = workspace:FindFirstChild(modelName)
	assert(source and source:IsA("Model"), "Import the FBX into Workspace first: " .. modelName)
	local report = {}

	local removed = 0
	for _, d in source:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed += 1
		end
	end
	table.insert(report, "scripts removed: " .. removed)

	-- The importer may nest parts; flatten so names resolve directly under the model.
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") and d.Parent ~= source then
			d.Parent = source
		end
	end
	for _, d in source:GetChildren() do
		if not d:IsA("BasePart") then
			d:Destroy()
		end
	end

	local missing = {}
	for _, name in REQUIRED do
		if not source:FindFirstChild(name) then
			table.insert(missing, name)
		end
	end
	assert(#missing == 0, "Missing parts: " .. table.concat(missing, ", "))

	local body = source.Body
	local headlight = source:FindFirstChild("Headlight")
	-- Roblox cars face -Z; turn the whole model if the headlights ended up at +Z.
	if headlight and headlight.Position.Z > body.Position.Z then
		source:PivotTo(source:GetPivot() * CFrame.Angles(0, math.pi, 0))
		table.insert(report, "rotated 180 degrees to face -Z")
	end

	local ground = math.huge
	for _, name in WHEELS do
		local wheel = source[name]
		ground = math.min(ground, wheel.Position.Y - wheel.Size.Y / 2)
		local axle = wheel.CFrame:VectorToWorldSpace(Vector3.xAxis)
		table.insert(report, string.format("%s size=%s axleX=%.2f", name, tostring(wheel.Size), math.abs(axle.X)))
	end
	source.WorldPivot = CFrame.new(body.Position.X, ground, body.Position.Z)
	source:PivotTo(CFrame.new())

	for _, part in source:GetChildren() do
		part.Anchored = true
	end
	source.PrimaryPart = body

	local meshes = ServerStorage:FindFirstChild("RunAutoshopMeshes")
	if not meshes then
		meshes = Instance.new("Folder")
		meshes.Name = "RunAutoshopMeshes"
		meshes.Parent = ServerStorage
	end
	local old = meshes:FindFirstChild(modelName)
	if old then
		old:Destroy()
	end
	source.Parent = meshes
	table.insert(
		report,
		string.format("stored %d parts in ServerStorage.RunAutoshopMeshes.%s", #source:GetChildren(), modelName)
	)
	return table.concat(report, "\n")
end

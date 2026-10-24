-- Synced by Rojo to ServerStorage.RunAutoshopTools. Owned by the Art agent. After importing an FBX with Studio's
-- Import 3D (File dimensions: Studs), run in Edit mode:
-- require(game.ServerStorage.RunAutoshopTools.ImportCar:Clone())("Sedan")
-- Also accepts a Model (ImportPack passes one): ImportCar(model, "Sedan") returns report, flipped.
-- Normalizes the car to the customer car contract and stores it in ServerStorage.RunAutoshopMeshes.<name>:
-- anchored parts, wheel hubs as children, Attachment HoodHinge, and an axis-aligned pivot at the ground center facing -Z.
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

-- "Sedan__Wheel_FL_Hub.001" -> "Wheel_FL_Hub". Blender duplicates arrive as ".001" or "_001".
local function partName(name)
	local base = name:gsub("[%._]%d%d%d$", "")
	return (base:gsub("^.*__", ""))
end

local function isAxisAligned(cframe)
	local _, _, _, r00, _, _, _, r11, _, _, _, r22 = cframe:GetComponents()
	return r00 > 0.999 and r11 > 0.999 and r22 > 0.999
end

return function(source, storeName)
	if type(source) == "string" then
		storeName = storeName or source
		source = workspace:FindFirstChild(source)
	end
	assert(
		typeof(source) == "Instance" and source:IsA("Model"),
		"Import the FBX into Workspace first: " .. tostring(storeName)
	)
	storeName = storeName or source.Name
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
	source.PrimaryPart = nil
	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") and d.Parent ~= source then
			d.Parent = source
		end
	end
	for _, d in source:GetChildren() do
		if d:IsA("BasePart") then
			d.Name = partName(d.Name)
		else
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
	-- Fallback for exports that face the wrong way. The parts keep a 180-degree yaw; the pivot is still axis-aligned.
	local flipped = false
	if headlight and headlight.Position.Z > body.Position.Z then
		source.WorldPivot = CFrame.new(body.Position)
		source:PivotTo(source.WorldPivot * CFrame.Angles(0, math.pi, 0))
		flipped = true
		table.insert(report, "WARNING: rotated 180 degrees to face -Z; re-export from Blender with the car facing -Y")
	end
	if source.Panel_Left.Position.X > body.Position.X then
		table.insert(report, "WARNING: Panel_Left is on the +X side, so the import is mirrored; re-export")
	end

	local rotated = 0
	for _, part in source:GetChildren() do
		part.PivotOffset = CFrame.new()
		if not isAxisAligned(part.CFrame) then
			rotated += 1
		end
	end
	table.insert(report, "parts with non-identity orientation: " .. rotated)

	local ground, center = math.huge, Vector3.zero
	for _, name in WHEELS do
		local wheel = source[name]
		ground = math.min(ground, wheel.Position.Y - wheel.Size.Y / 2)
		center += wheel.Position / #WHEELS
		local axle = wheel.CFrame:VectorToWorldSpace(Vector3.xAxis)
		table.insert(
			report,
			string.format(
				"%s radius=%.2f width=%.2f axleX=%.2f",
				name,
				wheel.Size.Y / 2,
				wheel.Size.X,
				math.abs(axle.X)
			)
		)
		local hub = source:FindFirstChild(name .. "_Hub")
		if hub then
			hub.Name = "Hub"
			hub.Parent = wheel
		else
			table.insert(report, name .. " has no " .. name .. "_Hub")
		end
	end

	for _, d in source:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end

	-- PrimaryPart first: setting it replaces the model pivot with Body's own pivot.
	source.PrimaryPart = body
	body.PivotOffset = body.CFrame:ToObjectSpace(CFrame.new(center.X, ground, center.Z))
	source:PivotTo(CFrame.new())

	local hood = source.Panel_Hood
	local oldHinge = hood:FindFirstChild("HoodHinge")
	if oldHinge then
		oldHinge:Destroy()
	end
	-- Rear edge of the hood (+Z, since the front faces -Z), mid-thickness, axis along X.
	local hinge = Instance.new("Attachment")
	hinge.Name = "HoodHinge"
	hinge.Parent = hood
	hinge.WorldCFrame = CFrame.new(hood.Position + Vector3.new(0, 0, hood.Size.Z / 2))
	table.insert(report, string.format("HoodHinge at %s", tostring(hinge.WorldPosition)))

	local meshes = ServerStorage:FindFirstChild("RunAutoshopMeshes")
	if not meshes then
		meshes = Instance.new("Folder")
		meshes.Name = "RunAutoshopMeshes"
		meshes.Parent = ServerStorage
	end
	local old = meshes:FindFirstChild(storeName)
	if old then
		old:Destroy()
	end
	source.Name = storeName
	source.Parent = meshes
	table.insert(
		report,
		string.format(
			"stored %d parts in ServerStorage.RunAutoshopMeshes.%s (pivot %s)",
			#source:GetChildren(),
			storeName,
			tostring(source:GetPivot().Position)
		)
	)
	return table.concat(report, "\n"), flipped
end

-- Synced by Rojo to ServerStorage.RunAutoshopTools. Owned by the Art agent. After importing assets/models/Pack1.fbx
-- with Studio's Import 3D (File dimensions: Studs), run in Edit mode:
-- require(game.ServerStorage.RunAutoshopTools.ImportPack:Clone())("Pack1")
-- Splits Workspace.<pack> by mesh name prefix (<Model>__<Part>) into ServerStorage.RunAutoshopMeshes.<Model>.
-- Cars go through ImportCar; kits get their root mesh as PrimaryPart with the pivot at its center.
local ServerStorage = game:GetService("ServerStorage")

local importCar = require(ServerStorage.RunAutoshopTools.ImportCar:Clone())

local CARS = { Sedan = true }
-- Kit root meshes; their bounding boxes match the part template sizes in BuildAssets.
local KIT_ROOTS = {
	Engine = "Block",
	Transmission = "Case",
	Battery = "Case",
	Seat = "Cushion",
	Wheel = "Tire",
}

local function store(model)
	local meshes = ServerStorage:FindFirstChild("RunAutoshopMeshes")
	if not meshes then
		meshes = Instance.new("Folder")
		meshes.Name = "RunAutoshopMeshes"
		meshes.Parent = ServerStorage
	end
	local old = meshes:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = meshes
end

local function importKit(model, flipped)
	local rootName = KIT_ROOTS[model.Name]
	local root = rootName and model:FindFirstChild(rootName)
	if not root then
		return string.format("%s: missing root mesh %s, skipped", model.Name, tostring(rootName))
	end
	if flipped then
		model.WorldPivot = CFrame.new(root.Position)
		model:PivotTo(model.WorldPivot * CFrame.Angles(0, math.pi, 0))
	end
	for _, part in model:GetChildren() do
		part.PivotOffset = CFrame.new()
		part.Anchored = true
	end
	model.PrimaryPart = root
	root.PivotOffset = root.CFrame:ToObjectSpace(CFrame.new(root.Position))
	model:PivotTo(CFrame.new())
	store(model)
	return string.format(
		"%s: %d meshes, root %s size %s",
		model.Name,
		#model:GetChildren(),
		rootName,
		tostring(root.Size)
	)
end

return function(packName)
	local pack = workspace:FindFirstChild(packName)
	assert(pack, "Import the FBX into Workspace first: " .. packName)
	local report = {}

	local removed = 0
	for _, d in pack:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed += 1
		end
	end
	table.insert(report, "scripts removed: " .. removed)

	local groups, order, unknown = {}, {}, {}
	for _, d in pack:GetDescendants() do
		if d:IsA("BasePart") then
			local name = d.Name:gsub("[%._]%d%d%d$", "")
			local modelName, partName = name:match("^(.-)__(.+)$")
			if modelName then
				if not groups[modelName] then
					local model = Instance.new("Model")
					model.Name = modelName
					groups[modelName] = model
					table.insert(order, modelName)
				end
				d.Name = partName
				d.Parent = groups[modelName]
			else
				table.insert(unknown, d:GetFullName())
			end
		end
	end
	if #unknown > 0 then
		table.insert(report, "left in place (no <Model>__ prefix): " .. table.concat(unknown, ", "))
	end

	-- Cars first: the importer's facing applies to the whole file, so kits follow the car's flip.
	table.sort(order, function(a, b)
		if (CARS[a] == true) ~= (CARS[b] == true) then
			return CARS[a] == true
		end
		return a < b
	end)
	local flipped = false
	for _, modelName in order do
		local model = groups[modelName]
		if CARS[modelName] then
			local carReport, carFlipped = importCar(model, modelName)
			flipped = flipped or carFlipped
			table.insert(report, modelName .. ":\n  " .. carReport:gsub("\n", "\n  "))
		elseif KIT_ROOTS[modelName] then
			table.insert(report, importKit(model, flipped))
		else
			model.Parent = pack
			table.insert(report, modelName .. ": unknown model, left in Workspace." .. packName)
		end
	end
	if flipped then
		table.insert(report, "WARNING: the pack came in facing +Z; kit meshes keep a 180-degree yaw, so re-export")
	end

	if #pack:GetDescendants() == 0 then
		pack:Destroy()
	end
	table.insert(report, "Next: require(game.ServerStorage.RunAutoshopTools.BuildAssets:Clone())()")
	return table.concat(report, "\n")
end

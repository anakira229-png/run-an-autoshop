local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Store = require(script.Parent.Store)

local peek = Fusion.peek

local ROUTE_COLOR = Color3.fromRGB(50, 150, 255)
local PARK_COLOR = Color3.fromRGB(60, 200, 90)
local CALL_COLOR = Color3.fromRGB(255, 120, 40)

-- Created locally so only this player sees their own beacons.
local folder = Instance.new("Folder")
folder.Name = "RunAutoshopBeacons"
folder.Parent = workspace
local beacons = {}

local function setBeacon(key, position, color)
	local beacon = beacons[key]
	if not position then
		if beacon then
			beacon:Destroy()
			beacons[key] = nil
		end
		return
	end
	if not beacon then
		beacon = Instance.new("Part")
		beacon.Name = key
		beacon.Shape = Enum.PartType.Cylinder
		beacon.Size = Vector3.new(60, 10, 10)
		beacon.Material = Enum.Material.Neon
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.CanTouch = false
		beacon.CastShadow = false
		beacon.Parent = folder
		beacons[key] = beacon
	end
	beacon.Color = color
	beacon.CFrame = CFrame.new(position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end

Store.scope:Observer(Store.route):onChange(function()
	local route = peek(Store.route)
	setBeacon("Route", route and route.target, route and route.parking and PARK_COLOR or ROUTE_COLOR)
end)

Store.scope:Observer(Store.call):onChange(function()
	local call = peek(Store.call)
	setBeacon("Callout", call and call.position, CALL_COLOR)
end)

RunService.RenderStepped:Connect(function()
	local transparency = 0.5 + math.sin(os.clock() * 4) * 0.1
	for _, beacon in beacons do
		beacon.Transparency = transparency
	end
end)

return true

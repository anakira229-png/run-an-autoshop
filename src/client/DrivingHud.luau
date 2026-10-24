local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Store = require(script.Parent.Store)
local Kit = require(script.Parent.UI.Kit)

local Children, peek = Fusion.Children, Fusion.peek
local C = Kit.Colors
local scope = Store.scope
local player = Players.LocalPlayer

local STUDS_TO_MPH = 0.63
-- The dial tops out at the best engine tier so upgrades visibly fill it further.
local DIAL_TOP_SPEED = Config.Tiers.Engine[#Config.Tiers.Engine].MaxSpeed
local DIAL_SIZE = 200
local TICKS = 28
local SWEEP_START, SWEEP = 135, 270
local MARGIN = 24
local BASE_FOV_BOOST = 10
local PILL = Color3.fromRGB(58, 52, 84)
local WARN = Color3.fromRGB(255, 170, 40)

local seat = nil
local driving = scope:Value(false)
local mph = scope:Value(0)
local fraction = scope:Value(0)
local smoothFraction = scope:Spring(fraction, 30, 1)

local function tickColor(i)
	local t = i / TICKS
	if t > 0.85 then
		return C.Red
	elseif t > 0.6 then
		return WARN
	end
	return C.Green
end

local function tick(i)
	local a = math.rad(SWEEP_START + (i - 1) / (TICKS - 1) * SWEEP)
	return scope:New("Frame")({
		Name = "Tick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + math.cos(a) * 0.4, 0.5 + math.sin(a) * 0.4),
		Size = UDim2.fromOffset(20, 9),
		Rotation = math.deg(a),
		BackgroundColor3 = scope:Computed(function(use)
			return (i - 0.5) / TICKS > use(smoothFraction) and C.Paper or tickColor(i)
		end),
		BackgroundTransparency = scope:Computed(function(use)
			return (i - 0.5) / TICKS > use(smoothFraction) and 0.7 or 0
		end),
		[Children] = { Kit.Corner(scope, 4), Kit.Outline(scope, 2) },
	})
end

local ticks = {}
for i = 1, TICKS do
	table.insert(ticks, tick(i))
end

local function speedometer()
	return scope:New("Frame")({
		Name = "Speedometer",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
		Size = UDim2.fromOffset(DIAL_SIZE, DIAL_SIZE),
		BackgroundColor3 = PILL,
		[Children] = {
			Kit.Corner(scope, DIAL_SIZE),
			Kit.Outline(scope, 5),
			ticks,
			Kit.Label(scope, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromOffset(110, 64),
				TextSize = 60,
				Fit = true,
				Text = scope:Computed(function(use)
					return tostring(use(mph))
				end),
			}),
			Kit.Label(scope, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.7),
				Size = UDim2.fromOffset(80, 26),
				TextSize = 24,
				Color = C.Yellow,
				Text = "MPH",
			}),
		},
	})
end

scope:New("ScreenGui")({
	Name = "RunAutoshopDrive",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 1,
	Enabled = driving,
	Parent = player:WaitForChild("PlayerGui"),
	[Children] = Kit.ScaledRoot(scope, Store.uiScale, { Children = speedometer() }),
})

local function onSeated(active, seatPart)
	seat = active and seatPart and seatPart:IsA("VehicleSeat") and seatPart or nil
	driving:set(seat ~= nil)
	if not seat then
		mph:set(0)
		fraction:set(0)
	end
end

local function onCharacter(character)
	onSeated(false)
	character:WaitForChild("Humanoid").Seated:Connect(onSeated)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

-- Speed FOV: eased in while driving and eased back out afterwards; the work view owns FOV otherwise.
local baseFov = nil
local fovBlend = 0

RunService:BindToRenderStep("RunAutoshopDrive", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	if peek(Store.work) then
		baseFov, fovBlend = nil, 0
		return
	end

	local current = seat
	local speed = current and current.Parent and current.AssemblyLinearVelocity.Magnitude or 0
	if current then
		mph:set(math.round(speed * STUDS_TO_MPH))
		fraction:set(math.clamp(speed / DIAL_TOP_SPEED, 0, 1))
	end

	if current and not baseFov then
		baseFov = camera.FieldOfView
	end
	if baseFov then
		local t = math.clamp(speed / Config.Car.MaxSpeed, 0, 1)
		local target = current and t * t * (3 - 2 * t) or 0
		fovBlend += (target - fovBlend) * (1 - math.exp(-dt * (current and 3 or 5)))
		camera.FieldOfView = baseFov + BASE_FOV_BOOST * fovBlend
		if not current and fovBlend < 0.005 then
			camera.FieldOfView = baseFov
			baseFov, fovBlend = nil, 0
		end
	end
end)

return true

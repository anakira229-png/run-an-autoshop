local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Effects = require(script.Parent.Effects)
local Store = require(script.Parent.Store)
local Kit = require(script.Parent.UI.Kit)

local Children, Out, peek = Fusion.Children, Fusion.Out, Fusion.peek
local C = Kit.Colors
local scope = Store.scope

local SEND_INTERVAL = 0.1
local RING_SIZE = 260
local TICKS = 40
local TICK_LENGTH = 22
local START_ANGLE = -math.pi / 2
local WARN = Color3.fromRGB(255, 170, 40)
local PILL = Color3.fromRGB(58, 52, 84)

local player = Players.LocalPlayer

local ringPosition = scope:Value(Vector2.zero)
local ringSize = scope:Value(Vector2.zero)
local angle = scope:Value(START_ANGLE)
local holding = scope:Value(false)
local rate = scope:Value(0)
local flash = scope:Value(false)
local shake = scope:Value(0)

local progress = scope:Computed(function(use)
	local state = use(Store.spin)
	return state and math.clamp(state.progress / state.required, 0, 1) or 0
end)
local smoothProgress = scope:Spring(progress, 25, 1)
local shakeOffset = scope:Spring(shake, 400, 0.2)
local knobPosition = scope:Spring(
	scope:Computed(function(use)
		local a = use(angle)
		return UDim2.fromScale(0.5 + math.cos(a) / 2, 0.5 + math.sin(a) / 2)
	end),
	60,
	0.8
)

-- Speed relative to the slip threshold: under 1 is safe.
local speedRatio = scope:Computed(function(use)
	local state = use(Store.spin)
	return state and use(rate) / state.slipRate or 0
end)
local smoothSpeed = scope:Spring(speedRatio, 30, 1)

local function tick(i)
	local a = (i - 1) / TICKS * 2 * math.pi - math.pi / 2
	return scope:New("Frame")({
		Name = "Tick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + math.cos(a) / 2, 0.5 + math.sin(a) / 2),
		Size = UDim2.fromOffset(TICK_LENGTH, 9),
		Rotation = math.deg(a),
		BackgroundColor3 = scope:Computed(function(use)
			if (i - 0.5) / TICKS > use(smoothProgress) then
				return C.Paper
			end
			return use(flash) and C.Red or C.Green
		end),
		BackgroundTransparency = scope:Computed(function(use)
			return (i - 0.5) / TICKS > use(smoothProgress) and 0.6 or 0
		end),
		[Children] = { Kit.Corner(scope, 4), Kit.Outline(scope, 2) },
	})
end

local ticks = {}
for i = 1, TICKS do
	table.insert(ticks, tick(i))
end

local function ringFrame()
	return scope:New("Frame")({
		Name = "Shaker",
		Size = UDim2.fromScale(1, 1),
		Position = scope:Computed(function(use)
			return UDim2.fromOffset(use(shakeOffset), 0)
		end),
		BackgroundTransparency = 1,
		[Children] = {
			-- Inset so the stroke is centered on the ring the ticks sit on.
			scope:New("Frame")({
				Name = "Track",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(RING_SIZE - TICK_LENGTH - 4, RING_SIZE - TICK_LENGTH - 4),
				BackgroundTransparency = 1,
				[Children] = {
					Kit.Corner(scope, RING_SIZE),
					scope:New("UIStroke")({
						Thickness = TICK_LENGTH + 8,
						Color = C.Ink,
						Transparency = 0.45,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				},
			}),
			ticks,
			scope:New("Frame")({
				Name = "Knob",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = knobPosition,
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = scope:Computed(function(use)
					return use(flash) and C.Red or C.Yellow
				end),
				[Children] = { Kit.Corner(scope, 15), Kit.Outline(scope, 4) },
			}),
		},
	})
end

local function speedGauge()
	return scope:New("Frame")({
		Name = "Gauge",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = C.Ink,
		[Children] = {
			Kit.Corner(scope, 9),
			scope:New("Frame")({
				Name = "Fill",
				Size = scope:Computed(function(use)
					return UDim2.fromScale(math.clamp(use(smoothSpeed) / 1.5, 0, 1), 1)
				end),
				BackgroundColor3 = scope:Computed(function(use)
					local ratio = use(smoothSpeed)
					if ratio > 1 then
						return C.Red
					elseif ratio > 0.75 then
						return WARN
					end
					return C.Green
				end),
				[Children] = Kit.Corner(scope, 9),
			}),
			scope:New("Frame")({
				Name = "Limit",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(1 / 1.5, 0.5),
				Size = UDim2.new(0, 4, 1, 8),
				BackgroundColor3 = C.White,
				[Children] = { Kit.Corner(scope, 2), Kit.Outline(scope, 2) },
			}),
		},
	})
end

local function statusPill()
	return Kit.Panel(scope, {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 36),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Color = PILL,
		Radius = 16,
		Padding = 10,
		Children = {
			Kit.List(scope, 8),
			Kit.Label(scope, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 26),
				TextSize = 22,
				Text = scope:Computed(function(use)
					local state = use(Store.spin)
					local text = string.format("%d%%", math.floor(use(smoothProgress) * 100 + 0.5))
					if state and state.slips > 0 then
						text ..= "  •  Slips: " .. state.slips
					end
					return text
				end),
			}),
			speedGauge(),
		},
	})
end

scope:New("ScreenGui")({
	Name = "RunAutoshopSpin",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = scope:Computed(function(use)
		return use(Store.spin) ~= nil
	end),
	Parent = player:WaitForChild("PlayerGui"),
	[Children] = scope:New("Frame")({
		Name = "SpinGame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING_SIZE, RING_SIZE),
		BackgroundTransparency = 1,
		[Out("AbsolutePosition")] = ringPosition,
		[Out("AbsoluteSize")] = ringSize,
		[Children] = {
			ringFrame(),
			Kit.Label(scope, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -30),
				Size = UDim2.fromOffset(440, 34),
				TextSize = 28,
				Text = scope:Computed(function(use)
					local state = use(Store.spin)
					return state and state.label or ""
				end),
			}),
			Kit.Label(scope, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -6),
				Size = UDim2.fromOffset(520, 22),
				TextSize = 18,
				Visible = scope:Computed(function(use)
					return not use(holding)
				end),
				Text = "Hold left mouse and circle the cursor around the ring. Too fast slips!",
			}),
			statusPill(),
		},
	}),
})

local accumulated = 0
local window = 0
local lastAngle = nil
local flashToken = 0
local wrench = Effects.loop("Wrench", 0.5)
local previous = nil

Remotes.SpinState.OnClientEvent:Connect(function(state, completed)
	if state and previous and state.slips > previous.slips then
		flashToken += 1
		local token = flashToken
		flash:set(true)
		shake:set(14)
		task.delay(0.05, function()
			shake:set(0)
		end)
		task.delay(0.4, function()
			if token == flashToken then
				flash:set(false)
			end
		end)
		Effects.play("Slip", 0.7)
		Effects.shake(1.5, 0.2)
	end
	if completed then
		Effects.play("StepDone", 0.5)
	end
	-- A new bolt starts with the knob back at the top.
	if state and (not previous or previous.label ~= state.label) then
		angle:set(START_ANGLE)
	end
	previous = state
	Store.spin:set(state)
	Store.spinActive:set(state ~= nil)
	if not state then
		wrench:Stop()
		holding:set(false)
		rate:set(0)
		lastAngle = nil
		accumulated = 0
		window = 0
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if peek(Store.spin) and input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding:set(true)
		lastAngle = nil
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding:set(false)
		lastAngle = nil
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local state = peek(Store.spin)
	if not state then
		return
	end
	window += dt
	if peek(holding) then
		local center = peek(ringPosition) + peek(ringSize) / 2
		local offset = UserInputService:GetMouseLocation() - center
		if offset.Magnitude > 20 then
			local current = math.atan2(offset.Y, offset.X)
			if lastAngle then
				local delta = current - lastAngle
				if delta > math.pi then
					delta -= 2 * math.pi
				elseif delta < -math.pi then
					delta += 2 * math.pi
				end
				accumulated += math.abs(math.deg(delta))
			end
			lastAngle = current
			angle:set(current)
		else
			lastAngle = nil
		end
	end
	if window >= SEND_INTERVAL then
		if accumulated > 0 then
			Remotes.SpinInput:FireServer(accumulated, window)
		end
		rate:set(accumulated / window)
		accumulated = 0
		window = 0
	end

	local current = peek(rate)
	local working = peek(holding) and current > 30 and current <= state.slipRate
	if working and not wrench.IsPlaying then
		wrench:Play()
	elseif not working and wrench.IsPlaying then
		wrench:Stop()
	end
	wrench.PlaybackSpeed = 0.85 + math.clamp(current / state.slipRate, 0, 1) * 0.35
end)

return {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)

local SEND_INTERVAL = 0.1
local RING_SIZE = 240
local GOOD = Color3.fromRGB(110, 220, 120)
local BAD = Color3.fromRGB(235, 70, 60)
local RING = Color3.fromRGB(230, 230, 235)

local player = Players.LocalPlayer

local function make(className, props, children)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextStrokeTransparency = 0.5
	return make("TextLabel", props)
end

local ringStroke = make("UIStroke", { Thickness = 6, Color = RING })
local knob = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(26, 26),
	BackgroundColor3 = Color3.fromRGB(255, 200, 60),
	Position = UDim2.fromScale(1, 0.5),
}, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
local ring = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(RING_SIZE, RING_SIZE),
	BackgroundTransparency = 1,
}, { make("UICorner", { CornerRadius = UDim.new(0.5, 0) }), ringStroke, knob })

local title = text({ Position = UDim2.new(-0.5, 0, 0, -70), Size = UDim2.new(2, 0, 0, 30), TextSize = 24 })
local hint = text({
	Position = UDim2.new(-0.5, 0, 0, -40),
	Size = UDim2.new(2, 0, 0, 22),
	TextSize = 15,
	Font = Enum.Font.Gotham,
	Text = "Hold left mouse and circle the cursor around the ring. Too fast slips!",
})
local progressFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOOD, BorderSizePixel = 0 })
local progressBar = make("Frame", {
	Position = UDim2.new(0, 0, 1, 20),
	Size = UDim2.new(1, 0, 0, 14),
	BackgroundColor3 = Color3.fromRGB(40, 40, 45),
	BorderSizePixel = 0,
}, { progressFill })
local speedFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOOD, BorderSizePixel = 0 })
local speedLimit = make("Frame", {
	Position = UDim2.fromScale(2 / 3, 0),
	Size = UDim2.new(0, 3, 1, 0),
	BackgroundColor3 = BAD,
	BorderSizePixel = 0,
})
local speedBar = make("Frame", {
	Position = UDim2.new(0, 0, 1, 42),
	Size = UDim2.new(1, 0, 0, 10),
	BackgroundColor3 = Color3.fromRGB(40, 40, 45),
	BorderSizePixel = 0,
}, { speedFill, speedLimit })
local slipLabel = text({ Position = UDim2.new(0, 0, 1, 58), Size = UDim2.new(1, 0, 0, 24), TextSize = 18 })

local root = make("Frame", {
	Name = "SpinGame",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(RING_SIZE, RING_SIZE),
	BackgroundTransparency = 1,
	Visible = false,
}, { ring, title, hint, progressBar, speedBar, slipLabel })

local gui = make("ScreenGui", {
	Name = "RunAutoshopSpin",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
}, { root })
gui.Parent = player:WaitForChild("PlayerGui")

local state = nil
local holding = false
local lastAngle = nil
local accumulated = 0
local window = 0
local rate = 0
local flashUntil = 0

Remotes.SpinState.OnClientEvent:Connect(function(newState)
	if newState and state and newState.slips > state.slips then
		flashUntil = os.clock() + 0.4
	end
	state = newState
	root.Visible = state ~= nil
	if not state then
		holding = false
		lastAngle = nil
		accumulated = 0
		window = 0
		return
	end
	title.Text = state.label
	progressFill.Size = UDim2.fromScale(math.clamp(state.progress / state.required, 0, 1), 1)
	slipLabel.Text = state.slips > 0 and ("Slips: " .. state.slips) or ""
end)

UserInputService.InputBegan:Connect(function(input)
	if state and input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = true
		lastAngle = nil
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = false
		lastAngle = nil
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not state then
		return
	end
	window += dt
	if holding then
		local center = ring.AbsolutePosition + ring.AbsoluteSize / 2
		local offset = UserInputService:GetMouseLocation() - center
		if offset.Magnitude > 20 then
			local angle = math.atan2(offset.Y, offset.X)
			if lastAngle then
				local delta = angle - lastAngle
				if delta > math.pi then
					delta -= 2 * math.pi
				elseif delta < -math.pi then
					delta += 2 * math.pi
				end
				accumulated += math.abs(math.deg(delta))
			end
			lastAngle = angle
			knob.Position = UDim2.fromScale(0.5 + math.cos(angle) / 2, 0.5 + math.sin(angle) / 2)
		else
			lastAngle = nil
		end
	end
	if window >= SEND_INTERVAL then
		if accumulated > 0 then
			Remotes.SpinInput:FireServer(accumulated, window)
		end
		rate = accumulated / window
		accumulated = 0
		window = 0
	end
	local fraction = math.clamp(rate / (state.slipRate * 1.5), 0, 1)
	speedFill.Size = UDim2.fromScale(fraction, 1)
	speedFill.BackgroundColor3 = rate > state.slipRate and BAD or GOOD
	ringStroke.Color = os.clock() < flashUntil and BAD or RING
end)

return gui

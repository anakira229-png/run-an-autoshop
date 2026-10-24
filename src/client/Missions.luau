local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer

local DARK = Color3.fromRGB(25, 27, 32)
local TEXT = Color3.fromRGB(240, 240, 240)
local ROUTE_COLOR = Color3.fromRGB(80, 200, 255)
local CALL_COLOR = Color3.fromRGB(255, 150, 40)

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

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.Gotham
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextWrapped = true
	return make("TextLabel", props)
end

local function button(text, color, position)
	return make("TextButton", {
		Position = position,
		Size = UDim2.new(0.5, -4, 0, 30),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = TEXT,
		Text = text,
	}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })
end

local gui = make("ScreenGui", { Name = "RunAutoshopMissions", ResetOnSpawn = false, IgnoreGuiInset = true })

-- Call-out card: offer (accept/decline) or active call (cancel).
local callTitle =
	label({ Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, TextSize = 19, TextColor3 = CALL_COLOR })
local callBody = label({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 40), TextSize = 15 })
local acceptButton = button("Accept", Color3.fromRGB(50, 140, 70), UDim2.new(0, 0, 1, -30))
local declineButton = button("Decline", Color3.fromRGB(90, 60, 60), UDim2.new(0.5, 4, 1, -30))
local cancelButton = button("Cancel call", Color3.fromRGB(90, 60, 60), UDim2.new(0.5, 4, 1, -30))
local callCard = make("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -150),
	Size = UDim2.fromOffset(300, 112),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = gui,
}, {
	make("UICorner", { CornerRadius = UDim.new(0, 8) }),
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}),
	callTitle,
	callBody,
	acceptButton,
	declineButton,
	cancelButton,
})

local routeLabel = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	Size = UDim2.fromOffset(460, 34),
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	TextColor3 = ROUTE_COLOR,
	TextStrokeTransparency = 0.4,
	Visible = false,
	Parent = gui,
})

gui.Parent = player:WaitForChild("PlayerGui")

-- World beacons are created locally so only this player sees them.
local beaconFolder = Instance.new("Folder")
beaconFolder.Name = "RunAutoshopBeacons"
beaconFolder.Parent = workspace
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
		beacon = make("Part", {
			Name = key,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(60, 10, 10),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = beaconFolder,
		})
		beacons[key] = beacon
	end
	beacon.Color = color
	beacon.CFrame = CFrame.new(position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end

local offer, call, route = nil, nil, nil
local offerDeadline, routeDeadline = 0, 0

local function distanceTo(position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and math.floor((root.Position - position).Magnitude) or 0
end

local function refreshCard()
	callCard.Visible = offer ~= nil or call ~= nil
	acceptButton.Visible = offer ~= nil
	declineButton.Visible = offer ~= nil
	cancelButton.Visible = offer == nil and call ~= nil
	if offer then
		callTitle.Text = "Roadside call!"
	elseif call then
		callTitle.Text = call.label
	end
end

Remotes.CalloutOffer.OnClientEvent:Connect(function(newOffer)
	offer = newOffer
	if offer then
		offerDeadline = os.clock() + offer.timeLeft
		Effects.play("Horn", 0.3)
	end
	refreshCard()
end)

Remotes.CalloutState.OnClientEvent:Connect(function(newCall)
	call = newCall
	setBeacon("Callout", call and call.position, CALL_COLOR)
	refreshCard()
end)

Remotes.RouteState.OnClientEvent:Connect(function(newRoute)
	if newRoute and route and newRoute.index > route.index then
		Effects.play("StepDone", 0.5)
	end
	route = newRoute
	routeLabel.Visible = route ~= nil
	setBeacon("Route", route and route.target, route and route.parking and Color3.fromRGB(120, 255, 140) or ROUTE_COLOR)
	if route then
		routeDeadline = os.clock() + route.timeLeft
	end
end)

acceptButton.Activated:Connect(function()
	Remotes.CalloutRespond:FireServer(true)
end)
declineButton.Activated:Connect(function()
	Remotes.CalloutRespond:FireServer(false)
end)
cancelButton.Activated:Connect(function()
	Remotes.CalloutRespond:FireServer("cancel")
end)

RunService.RenderStepped:Connect(function()
	if offer then
		local left = math.max(math.ceil(offerDeadline - os.clock()), 0)
		callBody.Text = string.format("%s on %s. Pays $%d.  (%ds)", offer.label, offer.place, offer.payout, left)
	elseif call then
		callBody.Text = string.format("%s - %dm away", call.place, distanceTo(call.position))
	end
	if route then
		local left = math.max(math.ceil(routeDeadline - os.clock()), 0)
		local goal = route.parking and "Park in the bay"
			or string.format("Checkpoint %d/%d", route.index, route.total - 1)
		routeLabel.Text = string.format("%s: %s  -  %ds", route.label, goal, left)
	end
	local now = os.clock()
	for _, beacon in beacons do
		beacon.Transparency = 0.5 + math.sin(now * 4) * 0.1
	end
end)

return gui

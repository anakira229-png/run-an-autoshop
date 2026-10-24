local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer

local DARK = Color3.fromRGB(25, 27, 32)
local ACCENT = Color3.fromRGB(255, 200, 60)
local TEXT = Color3.fromRGB(240, 240, 240)
local GOOD = Color3.fromRGB(110, 220, 120)
local MUTED = Color3.fromRGB(150, 150, 155)

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

local function panel(props, children)
	props.BackgroundColor3 = DARK
	props.BackgroundTransparency = 0.15
	table.insert(children, make("UICorner", { CornerRadius = UDim.new(0, 8) }))
	table.insert(
		children,
		make("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		})
	)
	return make("Frame", props, children)
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.Gotham
	props.TextColor3 = props.TextColor3 or TEXT
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextWrapped = true
	return make("TextLabel", props)
end

local gui = make("ScreenGui", {
	Name = "RunAutoshopHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local money = label({
	Name = "Money",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.fromOffset(200, 40),
	Font = Enum.Font.GothamBold,
	TextSize = 30,
	TextColor3 = GOOD,
	TextStrokeTransparency = 0.5,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = gui,
})

local jobTitle =
	label({ Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = ACCENT })
local jobPay =
	label({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18), TextSize = 15, TextColor3 = MUTED })
local jobStep = label({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 44), TextSize = 16 })
local jobCard = panel({
	Name = "JobCard",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0.25, 0),
	Size = UDim2.fromOffset(290, 112),
	Visible = false,
	Parent = gui,
}, { jobTitle, jobPay, jobStep })

local buildRows = {}
local buildChildren = {
	label({
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = ACCENT,
		Text = "Your car",
	}),
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
}
for i, slot in Config.Slots do
	local row = label({ Name = slot.Name, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 18), TextSize = 15 })
	buildRows[slot.Name] = row
	table.insert(buildChildren, row)
end
local toolsRow = label({ LayoutOrder = 50, Size = UDim2.new(1, 0, 0, 36), TextSize = 15 })
table.insert(buildChildren, toolsRow)
local resetButton = make("TextButton", {
	LayoutOrder = 60,
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundColor3 = Color3.fromRGB(60, 62, 70),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = TEXT,
	Text = "Reset car to pad",
}, { make("UICorner", { CornerRadius = UDim.new(0, 6) }) })
table.insert(buildChildren, resetButton)
panel({
	Name = "BuildPanel",
	Position = UDim2.new(0, 16, 0.25, 0),
	Size = UDim2.fromOffset(240, 272),
	Parent = gui,
}, buildChildren)

local toast = label({
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 106),
	Size = UDim2.fromOffset(460, 40),
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextStrokeTransparency = 0.4,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextTransparency = 1,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	Parent = gui,
})

local dentLabel = label({ Size = UDim2.fromScale(1, 1), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center })
local dentPanel = panel({
	Name = "DentPanel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -120),
	Size = UDim2.fromOffset(360, 48),
	Visible = false,
	Parent = gui,
}, { dentLabel })

local bannerScale = make("UIScale", { Scale = 1 })
local bannerStars = label({
	Size = UDim2.new(1, 0, 0, 56),
	Font = Enum.Font.GothamBlack,
	TextSize = 54,
	TextColor3 = ACCENT,
	TextStrokeTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local bannerText = label({
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 0, 30),
	Font = Enum.Font.GothamBold,
	TextSize = 24,
	TextStrokeTransparency = 0.3,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local banner = make("Frame", {
	Name = "ResultBanner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.32),
	Size = UDim2.fromOffset(420, 90),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
}, { bannerScale, bannerStars, bannerText })

gui.Parent = player:WaitForChild("PlayerGui")

local function moneyPopup(delta)
	local popup = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(200, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 26,
		TextColor3 = delta > 0 and GOOD or Color3.fromRGB(240, 90, 80),
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = (delta > 0 and "+$" or "-$") .. math.abs(delta),
		Parent = gui,
	})
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goal = delta > 0 and UDim2.new(0.5, 0, 0, 40) or UDim2.new(0.5, 0, 0, 140)
	TweenService:Create(popup, info, { Position = goal, TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, popup.Destroy, popup)
	money.TextSize = 38
	TweenService:Create(money, TweenInfo.new(0.3, Enum.EasingStyle.Back), { TextSize = 30 }):Play()
end

local bannerToken = 0
local function showBanner(stars, text)
	bannerToken += 1
	local token = bannerToken
	bannerStars.Text = string.rep("★", stars) .. string.rep("☆", 3 - stars)
	bannerText.Text = text
	banner.Visible = true
	bannerScale.Scale = 0.4
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.5, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

local function refreshMoney()
	money.Text = "$" .. (player:GetAttribute("Money") or 0)
end

local function refreshBuild()
	for _, slot in Config.Slots do
		local row = buildRows[slot.Name]
		local partLabel = Config.Parts[slot.PartType].Label
		local tier = player:GetAttribute("Tier_" .. slot.PartType)
		if tier and tier > 1 then
			partLabel = Config.Tiers.Names[tier] .. " " .. partLabel
		end
		local name = slot.PartType == "Wheel" and partLabel .. " " .. slot.Name:sub(-2) or partLabel
		if player:GetAttribute("Installed_" .. slot.Name) then
			row.Text = "[x] " .. name
			row.TextColor3 = GOOD
		else
			row.Text = "[  ] " .. name
			row.TextColor3 = TEXT
		end
	end
	local stock = {}
	for partType, info in Config.Parts do
		local count = player:GetAttribute("Inv_" .. partType) or 0
		if count > 0 then
			table.insert(stock, info.Label .. " x" .. count)
		end
	end
	local owned = player:GetAttribute("Upgrade_BetterTools")
	toolsRow.Text = #stock > 0 and ("To install: " .. table.concat(stock, ", "))
		or (owned and "Better Tools: owned" or "Better Tools: not owned")
	toolsRow.TextColor3 = #stock > 0 and ACCENT or MUTED
end

local toastToken = 0
local function showToast(text, color)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color or TEXT
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	task.delay(3, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local lastMoney = player:GetAttribute("Money")
player.AttributeChanged:Connect(function(name)
	if name == "Money" then
		local current = player:GetAttribute("Money")
		if lastMoney and current and current ~= lastMoney then
			moneyPopup(current - lastMoney)
			Effects.play(current > lastMoney and "Cash" or "Coins", 0.6)
		end
		lastMoney = current
		refreshMoney()
	else
		refreshBuild()
	end
end)
refreshMoney()
refreshBuild()

resetButton.Activated:Connect(function()
	Remotes.ResetCar:FireServer()
end)

Remotes.Notify.OnClientEvent:Connect(function(text)
	showToast(text)
end)

Remotes.JobUpdate.OnClientEvent:Connect(function(job)
	jobCard.Visible = job ~= nil
	if job then
		jobTitle.Text = job.label
		jobPay.Text = "Pays up to $" .. job.payout
		jobStep.Text = job.step
	end
end)

Remotes.JobResult.OnClientEvent:Connect(function(result)
	showBanner(result.stars, string.format("%s fixed!  +$%d", result.label, result.payout))
end)

local lastHits, lastMisses = 0, 0
Remotes.DentState.OnClientEvent:Connect(function(state)
	dentPanel.Visible = state ~= nil
	if state then
		if state.hits > lastHits then
			Effects.shake(1.2, 0.15)
		elseif state.misses > lastMisses then
			dentLabel.TextColor3 = Color3.fromRGB(240, 90, 80)
			TweenService:Create(dentLabel, TweenInfo.new(0.4), { TextColor3 = TEXT }):Play()
		end
		lastHits, lastMisses = state.hits, state.misses
		dentLabel.Text =
			string.format("Click the glowing dents!  %d/%d   Missed: %d", state.hits, state.required, state.misses)
	else
		lastHits, lastMisses = 0, 0
	end
end)

return gui

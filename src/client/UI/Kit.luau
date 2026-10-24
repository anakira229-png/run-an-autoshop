local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

local Kit = {}

Kit.Font = Enum.Font.FredokaOne
Kit.Colors = {
	Orange = Color3.fromRGB(255, 150, 30),
	Green = Color3.fromRGB(60, 200, 90),
	Blue = Color3.fromRGB(50, 150, 255),
	Red = Color3.fromRGB(240, 70, 70),
	Purple = Color3.fromRGB(150, 90, 240),
	Yellow = Color3.fromRGB(255, 205, 40),
	Ink = Color3.fromRGB(35, 30, 50),
	Paper = Color3.fromRGB(250, 248, 255),
	Muted = Color3.fromRGB(120, 115, 140),
	White = Color3.new(1, 1, 1),
}

local SHINE = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(210, 210, 210))

function Kit.Corner(scope, radius)
	return scope:New("UICorner")({ CornerRadius = UDim.new(0, radius or 14) })
end

function Kit.Outline(scope, thickness)
	return scope:New("UIStroke")({
		Thickness = thickness or 3,
		Color = Kit.Colors.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.Padding(scope, px)
	return scope:New("UIPadding")({
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

-- Chunky outlined text, the core of the simulator look.
function Kit.Label(scope, props)
	return scope:New("TextLabel")({
		Name = props.Name,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		AutomaticSize = props.AutomaticSize,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = props.Text,
		TextSize = props.TextSize or 20,
		TextColor3 = props.Color or Kit.Colors.White,
		TextStrokeColor3 = Kit.Colors.Ink,
		TextStrokeTransparency = props.Stroke == false and 1 or 0,
		TextWrapped = true,
		TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlignment or Enum.TextYAlignment.Center,
		RichText = props.RichText,
	})
end

function Kit.Button(scope, props)
	local hovering = scope:Value(false)
	local pressing = scope:Value(false)
	local scale = scope:Spring(
		scope:Computed(function(use)
			return use(pressing) and 0.92 or use(hovering) and 1.07 or 1
		end),
		35,
		0.55
	)
	return scope:New("TextButton")({
		Name = props.Name,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		AutoButtonColor = false,
		BackgroundColor3 = props.Color or Kit.Colors.Orange,
		Font = Kit.Font,
		Text = props.Text,
		TextSize = props.TextSize or 22,
		TextColor3 = Kit.Colors.White,
		TextStrokeColor3 = Kit.Colors.Ink,
		TextStrokeTransparency = 0,
		TextWrapped = true,
		[OnEvent("MouseEnter")] = function()
			hovering:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovering:set(false)
			pressing:set(false)
		end,
		[OnEvent("MouseButton1Down")] = function()
			pressing:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			pressing:set(false)
		end,
		[OnEvent("Activated")] = props.OnClick,
		[Children] = {
			Kit.Corner(scope, props.Radius or 14),
			Kit.Outline(scope, 3),
			scope:New("UIGradient")({ Color = SHINE, Rotation = 90 }),
			scope:New("UIScale")({ Scale = scale }),
		},
	})
end

-- Light card with a thick outline; children go in props.Children.
function Kit.Panel(scope, props)
	return scope:New("Frame")({
		Name = props.Name,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		AutomaticSize = props.AutomaticSize,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		BackgroundColor3 = props.Color or Kit.Colors.Paper,
		[Children] = {
			Kit.Corner(scope, props.Radius or 18),
			Kit.Outline(scope, 4),
			Kit.Padding(scope, props.Padding or 12),
			props.Children,
		},
	})
end

-- Colored title strip for panels and cards.
function Kit.Header(scope, props)
	return scope:New("Frame")({
		Name = "Header",
		LayoutOrder = props.LayoutOrder or 0,
		Size = UDim2.new(1, 0, 0, props.Height or 40),
		BackgroundColor3 = props.Color or Kit.Colors.Orange,
		[Children] = {
			Kit.Corner(scope, 12),
			Kit.Outline(scope, 3),
			scope:New("UIGradient")({ Color = SHINE, Rotation = 90 }),
			Kit.Label(scope, {
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.fromOffset(8, 0),
				Text = props.Text,
				TextSize = props.TextSize or 24,
				XAlignment = props.XAlignment,
			}),
			props.Children,
		},
	})
end

function Kit.List(scope, padding, horizontal)
	return scope:New("UIListLayout")({
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 8),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = horizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
	})
end

return Kit

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Effects = require(script.Parent.Parent.Effects)
local Store = require(script.Parent.Parent.Store)
local Kit = require(script.Parent.Kit)

local Children, peek = Fusion.Children, Fusion.peek
local C = Kit.Colors
local player = Players.LocalPlayer
local scope = Store.scope

local PART_ICONS = { Engine = "⚙️", Transmission = "🔩", Battery = "🔋", Seat = "💺", Wheel = "⭕" }
local PART_COLORS = {
	Engine = C.Red,
	Transmission = C.Purple,
	Battery = C.Yellow,
	Seat = C.Blue,
	Wheel = C.Orange,
}
local DONE_CARD = Color3.fromRGB(222, 250, 228)
local PART_ORDER = { "Engine", "Transmission", "Wheel", "Battery", "Seat" }

-- Layout is in scaled-root pixels (Store.uiScale), which keeps the window at least 1280x720.
local MARGIN = 16
local TOP_BAR = 58
local PANEL_X, PANEL_TOP, PANEL_WIDTH = 116, 72, 360
local RIGHT_COLUMN_WIDTH, RIGHT_COLUMN_TOP = 340, 130
local RESULT_Y = 0.52

local function formatMoney(n)
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then
			return s
		end
	end
end

local App = {}

-- Top bar ------------------------------------------------------------------

local moneyBounce = scope:Value(1)
local moneyScale = scope:Spring(moneyBounce, 40, 0.4)

local function moneyPill()
	return Kit.Panel(scope, {
		Name = "Money",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(210, 54),
		Color = C.Yellow,
		Radius = 27,
		Padding = 4,
		Children = {
			scope:New("UIScale")({ Scale = moneyScale }),
			Kit.Label(scope, {
				Size = UDim2.fromScale(1, 1),
				TextSize = 32,
				Text = scope:Computed(function(use)
					return "$" .. formatMoney(use(Store.money))
				end),
			}),
		},
	})
end

local function routeBanner()
	return Kit.Panel(scope, {
		Name = "Route",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(320, 48),
		Color = C.Blue,
		Radius = 24,
		Padding = 4,
		Visible = scope:Computed(function(use)
			return use(Store.route) ~= nil
		end),
		Children = Kit.Label(scope, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 24,
			Fit = true,
			Text = scope:Computed(function(use)
				local route = use(Store.route)
				if not route then
					return ""
				end
				local left = math.max(math.ceil(route.deadline - use(Store.clock)), 0)
				local goal = route.parking and "🅿️ Park in the bay"
					or string.format("🏁 Checkpoint %d/%d", route.index, route.total - 1)
				return string.format("%s  •  %ds", goal, left)
			end),
		}),
	})
end

local function toasts()
	return scope:New("Frame")({
		Name = "Toasts",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			Kit.List(scope, 6),
			scope:ForValues(Store.toasts, function(_, inner, toast)
				return Kit.Panel(inner, {
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = toast.id,
					Color = toast.color or C.Ink,
					Radius = 14,
					Padding = 8,
					Children = Kit.Label(inner, {
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextSize = 20,
						Text = toast.text,
					}),
				})
			end),
		},
	})
end

-- Money, route or dent banner and toasts stack top-center so they never overlap each other.
local function dentCounter()
	return Kit.Panel(scope, {
		Name = "Dents",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(320, 48),
		Color = C.Orange,
		Radius = 24,
		Padding = 4,
		Visible = scope:Computed(function(use)
			return use(Store.dent) ~= nil
		end),
		Children = Kit.Label(scope, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 24,
			Fit = true,
			Text = scope:Computed(function(use)
				local dent = use(Store.dent)
				return dent and string.format("🔨 %d/%d dents  •  missed %d", dent.hits, dent.required, dent.misses)
					or ""
			end),
		}),
	})
end

local function topColumn()
	return scope:New("Frame")({
		Name = "TopColumn",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP_BAR),
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			Kit.List(scope, 8),
			moneyPill(),
			routeBanner(),
			dentCounter(),
			toasts(),
		},
	})
end

-- Left side menu and panels ------------------------------------------------

local function sideMenu()
	return scope:New("Frame")({
		Name = "SideMenu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, MARGIN, 0.5, 0),
		Size = UDim2.fromOffset(96, 210),
		BackgroundTransparency = 1,
		[Children] = {
			Kit.List(scope, 12),
			Kit.Button(scope, {
				Size = UDim2.fromOffset(92, 92),
				Color = C.Orange,
				Text = "🔧\nGarage",
				TextSize = 20,
				Radius = 20,
				LayoutOrder = 1,
				OnClick = function()
					Store.togglePanel("garage")
				end,
			}),
			Kit.Button(scope, {
				Size = UDim2.fromOffset(92, 92),
				Color = C.Purple,
				Text = "⚡\nUpgrades",
				TextSize = 20,
				Radius = 20,
				LayoutOrder = 2,
				OnClick = function()
					Store.togglePanel("upgrades")
				end,
			}),
		},
	})
end

local function installedCount(attrs, partType)
	local count = 0
	for _, slot in Config.Slots do
		if slot.PartType == partType and attrs["Installed_" .. slot.Name] then
			count += 1
		end
	end
	return count
end

-- Returns name, status, button text, button color, price, done.
local function partOffer(attrs, partType)
	local info = Config.Parts[partType]
	local installed = installedCount(attrs, partType)
	local inBag = attrs["Inv_" .. partType] or 0
	local tier = attrs["Tier_" .. partType] or 1
	local tiers = Config.Tiers[partType]
	local name = (tiers and tier > 1 and Config.Tiers.Names[tier] .. " " or "") .. info.Label
	if installed + inBag < info.Needed then
		return name,
			string.format("%d/%d installed", installed, info.Needed),
			"Buy $" .. info.Price,
			C.Green,
			info.Price
	elseif installed < info.Needed then
		return name, string.format("%d in your bag - bolt it on!", inBag), nil
	elseif tiers and tier < #tiers then
		local nextTier = Config.Tiers.Names[tier + 1]
		local price = tiers[tier + 1].Price
		return name, "Installed ✓", nextTier .. " $" .. price, C.Purple, price, true
	end
	return name, tiers and "MAXED ★" or "Installed ✓", nil, nil, nil, true
end

local function pips(partType)
	local needed = Config.Parts[partType].Needed
	local row = {
		Kit.List(scope, 4, true),
	}
	for i = 1, needed do
		table.insert(
			row,
			scope:New("Frame")({
				LayoutOrder = i,
				Size = UDim2.fromOffset(18, 10),
				BackgroundColor3 = scope:Computed(function(use)
					local attrs = use(Store.attrs)
					local installed = installedCount(attrs, partType)
					if installed >= i then
						return C.Green
					elseif installed + (attrs["Inv_" .. partType] or 0) >= i then
						return C.Yellow
					end
					return C.Muted
				end),
				[Children] = { Kit.Corner(scope, 5), Kit.Outline(scope, 2) },
			})
		)
	end
	return scope:New("Frame")({
		Name = "Pips",
		Position = UDim2.fromOffset(60, 41),
		Size = UDim2.fromOffset(120, 10),
		BackgroundTransparency = 1,
		[Children] = row,
	})
end

local function partCard(partType, order)
	local offer = scope:Computed(function(use)
		return { partOffer(use(Store.attrs), partType) }
	end)
	return Kit.Panel(scope, {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 68),
		Padding = 8,
		Radius = 14,
		Color = scope:Computed(function(use)
			return use(offer)[6] and DONE_CARD or C.Paper
		end),
		Children = {
			scope:New("Frame")({
				Name = "Badge",
				Size = UDim2.fromOffset(52, 52),
				BackgroundColor3 = PART_COLORS[partType],
				[Children] = {
					Kit.Corner(scope, 14),
					Kit.Outline(scope, 3),
					Kit.Label(scope, {
						Size = UDim2.fromScale(1, 1),
						TextSize = 32,
						Text = PART_ICONS[partType],
						Stroke = false,
					}),
				},
			}),
			pips(partType),
			Kit.Label(scope, {
				Position = UDim2.fromOffset(60, 0),
				Size = UDim2.new(1, -176, 0, 24),
				XAlignment = Enum.TextXAlignment.Left,
				TextSize = 22,
				Fit = true,
				Color = C.Ink,
				Stroke = false,
				Text = scope:Computed(function(use)
					return use(offer)[1]
				end),
			}),
			Kit.Label(scope, {
				Position = UDim2.fromOffset(60, 22),
				Size = UDim2.new(1, -176, 0, 18),
				XAlignment = Enum.TextXAlignment.Left,
				TextSize = 16,
				Fit = true,
				Color = C.Muted,
				Stroke = false,
				Text = scope:Computed(function(use)
					return use(offer)[2]
				end),
			}),
			Kit.Button(scope, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(112, 44),
				TextSize = 18,
				Visible = scope:Computed(function(use)
					return use(offer)[3] ~= nil
				end),
				Text = scope:Computed(function(use)
					return use(offer)[3] or ""
				end),
				Color = scope:Computed(function(use)
					local offered = use(offer)
					if offered[5] and use(Store.money) < offered[5] then
						return C.Muted
					end
					return offered[4] or C.Green
				end),
				OnClick = function()
					Remotes.ShopBuy:FireServer("part", partType)
				end,
			}),
		},
	})
end

local function closeButton()
	return Kit.Button(scope, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		Color = C.Red,
		Text = "✖",
		TextSize = 18,
		Radius = 10,
		OnClick = function()
			Store.panel:set(nil)
		end,
	})
end

local function garagePanel()
	local cards = {}
	for i, partType in PART_ORDER do
		table.insert(cards, partCard(partType, i + 1))
	end
	return Kit.Panel(scope, {
		Name = "GaragePanel",
		Position = UDim2.fromOffset(PANEL_X, PANEL_TOP),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = scope:Computed(function(use)
			return use(Store.panel) == "garage"
		end),
		Children = {
			Kit.List(scope, 6),
			Kit.Header(scope, { Text = "🔧 Garage", Color = C.Orange, Children = closeButton() }),
			cards,
			Kit.Label(scope, {
				LayoutOrder = 20,
				Size = UDim2.new(1, 0, 0, 28),
				TextSize = 15,
				Fit = true,
				Color = C.Muted,
				Stroke = false,
				Text = scope:Computed(function(use)
					local work = use(Store.work)
					if work and work.kind == "garage" then
						return "Click a glowing slot on your car to bolt on a part."
					end
					return "Bolt parts on at the Garage pad next to your car."
				end),
			}),
			Kit.Button(scope, {
				LayoutOrder = 21,
				Size = UDim2.new(1, 0, 0, 40),
				Color = C.Blue,
				Text = "🚗 Reset car to pad",
				TextSize = 20,
				OnClick = function()
					Remotes.ResetCar:FireServer()
				end,
			}),
		},
	})
end

local function upgradesPanel()
	local info = Config.Upgrades.BetterTools
	local owned = scope:Computed(function(use)
		return use(Store.attrs).Upgrade_BetterTools == true
	end)
	return Kit.Panel(scope, {
		Name = "UpgradesPanel",
		Position = UDim2.fromOffset(PANEL_X, PANEL_TOP),
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = scope:Computed(function(use)
			return use(Store.panel) == "upgrades"
		end),
		Children = {
			Kit.List(scope, 6),
			Kit.Header(scope, { Text = "⚡ Upgrades", Color = C.Purple, Children = closeButton() }),
			Kit.Panel(scope, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 90),
				Padding = 8,
				Radius = 14,
				Children = {
					Kit.Label(scope, { Size = UDim2.fromOffset(52, 52), TextSize = 38, Text = "🧰", Stroke = false }),
					Kit.Label(scope, {
						Position = UDim2.fromOffset(60, 0),
						Size = UDim2.new(1, -176, 0, 28),
						XAlignment = Enum.TextXAlignment.Left,
						TextSize = 22,
						Fit = true,
						Color = C.Ink,
						Stroke = false,
						Text = info.Label,
					}),
					Kit.Label(scope, {
						Position = UDim2.fromOffset(60, 28),
						Size = UDim2.new(1, -176, 0, 44),
						XAlignment = Enum.TextXAlignment.Left,
						YAlignment = Enum.TextYAlignment.Top,
						TextSize = 16,
						Color = C.Muted,
						Stroke = false,
						Text = "Slower slips and longer-lasting dents.",
					}),
					Kit.Button(scope, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(112, 44),
						TextSize = 18,
						Color = scope:Computed(function(use)
							return use(owned) and C.Muted or C.Green
						end),
						Text = scope:Computed(function(use)
							return use(owned) and "Owned ✓" or "Buy $" .. info.Price
						end),
						OnClick = function()
							if not peek(owned) then
								Remotes.ShopBuy:FireServer("upgrade", "BetterTools")
							end
						end,
					}),
				},
			}),
		},
	})
end

-- Right side: job tracker and roadside calls --------------------------------

local function jobCard()
	return Kit.Panel(scope, {
		Name = "JobCard",
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = scope:Computed(function(use)
			return use(Store.job) ~= nil
		end),
		Children = {
			Kit.List(scope, 8),
			Kit.Header(scope, {
				Color = C.Blue,
				TextSize = 22,
				Text = scope:Computed(function(use)
					local job = use(Store.job)
					return job and "🛠️ " .. job.label or ""
				end),
			}),
			Kit.Label(scope, {
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 20,
				Color = C.Ink,
				Stroke = false,
				Text = scope:Computed(function(use)
					local job = use(Store.job)
					return job and job.step or ""
				end),
			}),
			Kit.Label(scope, {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 26),
				TextSize = 20,
				Color = C.Green,
				Text = scope:Computed(function(use)
					local job = use(Store.job)
					return job and "Pays up to $" .. job.payout or ""
				end),
			}),
		},
	})
end

local function distanceTo(position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and math.floor((root.Position - position).Magnitude) or 0
end

local function calloutCard()
	return Kit.Panel(scope, {
		Name = "Callout",
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = scope:Computed(function(use)
			return use(Store.offer) ~= nil or use(Store.call) ~= nil
		end),
		Children = {
			Kit.List(scope, 8),
			Kit.Header(scope, {
				Color = C.Red,
				Text = scope:Computed(function(use)
					local call = use(Store.call)
					return use(Store.offer) and "🚨 Roadside call!" or call and "🚨 " .. call.label or ""
				end),
			}),
			Kit.Label(scope, {
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 20,
				Color = C.Ink,
				Stroke = false,
				Text = scope:Computed(function(use)
					local offer, call = use(Store.offer), use(Store.call)
					local now = use(Store.clock)
					if offer then
						local left = math.max(math.ceil(offer.deadline - now), 0)
						return string.format("%s on %s\nPays $%d  (%ds)", offer.label, offer.place, offer.payout, left)
					elseif call then
						return string.format("%s - %dm away", call.place, distanceTo(call.position))
					end
					return ""
				end),
			}),
			scope:New("Frame")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				[Children] = {
					Kit.List(scope, 10, true),
					Kit.Button(scope, {
						Size = UDim2.fromScale(0.48, 1),
						Color = C.Green,
						Text = "Accept",
						Visible = scope:Computed(function(use)
							return use(Store.offer) ~= nil
						end),
						OnClick = function()
							Remotes.CalloutRespond:FireServer(true)
						end,
					}),
					Kit.Button(scope, {
						Size = UDim2.fromScale(0.48, 1),
						Color = C.Red,
						Text = scope:Computed(function(use)
							return use(Store.offer) and "Decline" or "Cancel call"
						end),
						OnClick = function()
							Remotes.CalloutRespond:FireServer(peek(Store.offer) and false or "cancel")
						end,
					}),
				},
			}),
		},
	})
end

-- Bottom: work view bar ------------------------------------------------------

local function workBar(onOverview, onLeave)
	return Kit.Panel(scope, {
		Name = "WorkBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		Size = UDim2.fromOffset(480, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Padding = 8,
		Visible = scope:Computed(function(use)
			return use(Store.work) ~= nil
		end),
		Children = {
			Kit.List(scope, 6),
			Kit.Label(scope, {
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 22,
				Color = C.Ink,
				Stroke = false,
				Text = scope:Computed(function(use)
					local work, job = use(Store.work), use(Store.job)
					if work and work.kind == "garage" then
						return "🔧 Click a glowing slot to bolt on a part"
					end
					return job and job.step or "Inspect the car"
				end),
			}),
			Kit.Label(scope, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 18),
				TextSize = 15,
				Fit = true,
				Color = C.Muted,
				Stroke = false,
				Text = "Right-drag: rotate  •  Scroll: zoom  •  Click glowing parts",
			}),
			scope:New("Frame")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				[Children] = {
					Kit.List(scope, 12, true),
					Kit.Button(scope, {
						Size = UDim2.fromOffset(170, 38),
						Color = C.Blue,
						Text = "🔭 Overview",
						OnClick = onOverview,
					}),
					Kit.Button(scope, {
						Size = UDim2.fromOffset(170, 38),
						Color = C.Red,
						Text = "✖ Leave",
						OnClick = onLeave,
					}),
				},
			}),
		},
	})
end

-- Right side: job tracker above the roadside call so they never overlap.
local function rightColumn()
	return scope:New("Frame")({
		Name = "RightColumn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, RIGHT_COLUMN_TOP),
		Size = UDim2.fromOffset(RIGHT_COLUMN_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			Kit.List(scope, 10),
			jobCard(),
			calloutCard(),
		},
	})
end

-- Celebrations ---------------------------------------------------------------

local resultSpring = scope:Spring(scope:Value(1), 25, 0.45)
local function resultBanner()
	return scope:New("Frame")({
		Name = "Result",
		ZIndex = 10,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, RESULT_Y),
		Size = UDim2.fromOffset(460, 150),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return use(Store.result) ~= nil
		end),
		[Children] = {
			scope:New("UIScale")({ Scale = resultSpring }),
			Kit.Label(scope, {
				Size = UDim2.new(1, 0, 0, 80),
				TextSize = 76,
				Color = C.Yellow,
				Text = scope:Computed(function(use)
					local result = use(Store.result)
					return result and string.rep("★", result.stars) .. string.rep("☆", 3 - result.stars) or ""
				end),
			}),
			Kit.Label(scope, {
				Position = UDim2.fromOffset(0, 84),
				Size = UDim2.new(1, 0, 0, 56),
				TextSize = 40,
				Fit = true,
				Text = scope:Computed(function(use)
					local result = use(Store.result)
					return result and string.format("%s fixed!  +$%d", result.label, result.payout) or ""
				end),
			}),
		},
	})
end

local CONFETTI = { C.Orange, C.Green, C.Blue, C.Red, C.Purple, C.Yellow }
local function confetti(parent)
	for _ = 1, 40 do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
		piece.BackgroundColor3 = CONFETTI[math.random(#CONFETTI)]
		piece.BorderSizePixel = 0
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.new(0.5, math.random(-120, 120), RESULT_Y, 0)
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 9
		piece.Parent = parent
		local target = UDim2.new(0.5, math.random(-500, 500), RESULT_Y, math.random(150, 450))
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(1.4 + math.random() * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = target, Rotation = piece.Rotation + math.random(-360, 360), BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Once(function()
			piece:Destroy()
		end)
	end
end

local function moneyPopup(parent, delta)
	local popup = Instance.new("TextLabel")
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Position = UDim2.new(0.5, 0, 0, TOP_BAR + 54)
	popup.Size = UDim2.fromOffset(220, 40)
	popup.BackgroundTransparency = 1
	popup.Font = Kit.Font
	popup.TextSize = 34
	popup.TextColor3 = delta > 0 and C.Green or C.Red
	popup.TextStrokeColor3 = C.Ink
	popup.TextStrokeTransparency = 0
	popup.Text = (delta > 0 and "+$" or "-$") .. math.abs(delta)
	popup.ZIndex = 9
	popup.Parent = parent
	local goal = UDim2.new(0.5, 0, 0, delta > 0 and 20 or TOP_BAR + 120)
	TweenService:Create(popup, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
		Position = goal,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.3, popup.Destroy, popup)
end

function App.mount(options)
	local root = Kit.ScaledRoot(scope, Store.uiScale, {
		Children = {
			topColumn(),
			sideMenu(),
			garagePanel(),
			upgradesPanel(),
			rightColumn(),
			workBar(options.onOverview, options.onLeave),
			resultBanner(),
		},
	})
	local gui = scope:New("ScreenGui")({
		Name = "RunAutoshopUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 2,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = root,
	})

	local lastMoney = peek(Store.money)
	scope:Observer(Store.money):onChange(function()
		local current = peek(Store.money)
		local delta = current - lastMoney
		lastMoney = current
		if delta ~= 0 then
			moneyPopup(root, delta)
			Effects.play(delta > 0 and "Cash" or "Coins", 0.6)
			moneyBounce:set(1.25)
			task.delay(0.12, function()
				moneyBounce:set(1)
			end)
		end
	end)

	scope:Observer(Store.result):onChange(function()
		local result = peek(Store.result)
		if not result then
			return
		end
		resultSpring:setPosition(0.2)
		confetti(root)
		task.delay(2.6, function()
			if peek(Store.result) == result then
				Store.result:set(nil)
			end
		end)
	end)
	return gui
end

return App

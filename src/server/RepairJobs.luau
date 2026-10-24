local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Spin = require(script.Parent.Spin)

local assets = ServerStorage:WaitForChild("RunAutoshopAssets")
local JOB_TYPES = { "FlatTire", "Dent" }
local WHEELS = { "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR" }
local PANELS = { "Panel_Hood", "Panel_Left", "Panel_Right" }
local DENT_COLOR = Color3.fromRGB(70, 70, 75)
local DENT_ACTIVE = Color3.fromRGB(255, 220, 40)

local active = {}
local states = {}

local RepairJobs = {}

local function alive(state)
	return states[state.plot] == state
end

local function weld(part0, part1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
end

local function decor(name, shape, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	return p
end

local function highlight(target)
	local h = Instance.new("Highlight")
	h.Name = "FaultHighlight"
	h.FillColor = Color3.fromRGB(255, 140, 0)
	h.FillTransparency = 0.7
	h.OutlineColor = Color3.fromRGB(255, 140, 0)
	h.Adornee = target
	h.Parent = target
end

local function addNuts(wheel, side, transparency)
	local nuts = {}
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local cf = wheel.CFrame * CFrame.new(side * 0.72, math.cos(a) * 0.38, math.sin(a) * 0.38)
		local nut = decor(
			"LugNut",
			Enum.PartType.Cylinder,
			Vector3.new(0.25, 0.28, 0.28),
			cf,
			Color3.fromRGB(225, 225, 230),
			Enum.Material.Metal
		)
		nut.CanQuery = false
		nut.Transparency = transparency
		weld(wheel, nut)
		nut.Parent = wheel
		nuts[i] = nut
	end
	return nuts
end

local function showNuts(nuts, fraction)
	for i, nut in nuts do
		nut.Transparency = i / #nuts <= fraction + 1e-6 and 0 or 1
	end
end

local function sendStep(state, text)
	local owner = Plots.owner(state.plot)
	if owner then
		Remotes.JobUpdate:FireClient(owner, { label = state.job.Label, payout = state.job.Payout, step = text })
	end
end

local function clearPrompt(state)
	if state.prompt then
		state.prompt:Destroy()
		state.prompt = nil
	end
end

local function tweenTo(state, target)
	local car = state.car
	local value = Instance.new("CFrameValue")
	value.Value = car:GetPivot()
	local conn = value.Changed:Connect(function(cf)
		if car.Parent then
			car:PivotTo(cf)
		end
	end)
	local duration = math.max((target.Position - value.Value.Position).Magnitude / Config.CustomerSpeed, 0.1)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = target })
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	value:Destroy()
	return alive(state)
end

local function holdStep(state, part, actionText, hint, onDone)
	sendStep(state, hint)
	state.prompt = Plots.prompt(state.plot, part, actionText, state.job.Label, 0.5, function(player)
		if Spin.isBusy(player) or not state.prompt then
			return
		end
		clearPrompt(state)
		onDone()
	end)
end

local function spinStep(state, part, actionText, hint, onProgress, onDone)
	sendStep(state, hint)
	local function offer()
		if not alive(state) then
			return
		end
		state.prompt = Plots.prompt(state.plot, part, actionText, state.job.Label, 0, function(player)
			if not state.prompt then
				return
			end
			local started = Spin.start(player, {
				label = hint,
				degrees = Config.Spin.LugDegrees,
				anchor = part,
				onProgress = onProgress,
				onComplete = function(slips)
					if alive(state) then
						state.misses += slips
						onDone()
					end
				end,
				onCancel = function()
					onProgress(0)
					offer()
				end,
			})
			if started then
				clearPrompt(state)
			end
		end)
	end
	offer()
end

local function finish(state)
	if state.phase ~= "Active" then
		return
	end
	state.phase = "Done"
	clearPrompt(state)

	local stars = 1
	if state.misses <= Config.MaxMisses[3] then
		stars = 3
	elseif state.misses <= Config.MaxMisses[2] then
		stars = 2
	end
	local payout = math.floor(state.job.Payout * Config.StarMultipliers[stars] + 0.5)
	local owner = Plots.owner(state.plot)
	if owner and PlayerData.addMoney(owner, payout) then
		Remotes.JobUpdate:FireClient(owner, nil)
		Remotes.JobResult:FireClient(owner, { label = state.job.Label, stars = stars, payout = payout })
	end

	local car = state.car
	if state.oldWheel then
		state.oldWheel:Destroy()
	end
	for _, d in car:GetDescendants() do
		if d.Name == "FaultHighlight" or d.Name == "FaultLabel" then
			d:Destroy()
		end
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 0
	sparkle.Speed = NumberRange.new(6, 12)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Color = ColorSequence.new(Color3.fromRGB(120, 255, 140))
	sparkle.Parent = car.Body
	sparkle:Emit(40)

	task.wait(1.5)
	if not alive(state) then
		return
	end
	local plot = state.plot
	local out1 = Plots.marker(plot, "Out1").Position
	local out2 = Plots.marker(plot, "Out2").Position
	local out3 = Plots.marker(plot, "Out3").Position
	local bay = Plots.marker(plot, "Bay")
	local ok = tweenTo(state, bay.Rotation + out1)
		and tweenTo(state, CFrame.lookAt(out2, out3))
		and tweenTo(state, CFrame.lookAt(out3, out3 + (out3 - out2)))
	if ok then
		car:Destroy()
		states[plot] = nil
		task.delay(Config.CustomerDelay, RepairJobs.spawnCustomer, plot)
	end
end

local function runFlatTire(state)
	local car = state.car
	local wheel = car[state.wheelName]
	spinStep(state, wheel, "Loosen lug nuts", "Loosen the lug nuts on the flat wheel.", function(f)
		showNuts(state.nuts, 1 - f)
	end, function()
		holdStep(state, wheel, "Remove wheel", "Pull off the flat wheel.", function()
			local body = car.Body
			local fitCFrame = body.CFrame * state.wheelOffset
			wheel:FindFirstChild("WeldConstraint"):Destroy()
			wheel.Anchored = true
			wheel.FaultHighlight:Destroy()
			wheel.Name = "OldWheel"
			wheel.Parent = state.plot
			state.oldWheel = wheel
			local outward = body.CFrame:VectorToWorldSpace(Vector3.new(state.side, 0, 0))
			local ground = car:GetPivot().Position.Y
			local drop = CFrame.new(Vector3.new(wheel.Position.X, ground + 0.6, wheel.Position.Z) + outward * 3.5)
				* CFrame.Angles(0, 0, math.pi / 2)
			TweenService:Create(wheel, TweenInfo.new(0.4), { CFrame = drop }):Play()

			local ghost = decor(
				"WheelGhost",
				Enum.PartType.Cylinder,
				wheel.Size,
				fitCFrame,
				Color3.fromRGB(80, 200, 255),
				Enum.Material.ForceField
			)
			ghost.Anchored = true
			ghost.Parent = car
			holdStep(state, ghost, "Fit new wheel", "Fit a new wheel.", function()
				ghost:Destroy()
				local newWheel = assets.Parts.Wheel:Clone()
				newWheel.Name = state.wheelName
				newWheel.CFrame = fitCFrame
				newWheel.Anchored = false
				newWheel.CanCollide = false
				weld(body, newWheel)
				newWheel.Parent = car
				local nuts = addNuts(newWheel, state.side, 1)
				spinStep(state, newWheel, "Tighten lug nuts", "Tighten the lug nuts.", function(f)
					showNuts(nuts, f)
				end, function()
					finish(state)
				end)
			end)
		end)
	end)
end

local function dentGame(state, player, retry)
	local panel = state.panel
	local better = PlayerData.hasUpgrade(player, "BetterTools")
	local lifetime = Config.Dent.Lifetime * (better and Config.Dent.BetterToolsLifetime or 1)
	local function report(show)
		if player.Parent then
			Remotes.DentState:FireClient(player, show and {
				hits = state.dentHits,
				required = Config.Dent.Count,
				misses = state.dentMisses,
			} or nil)
		end
	end

	state.dentRunning = true
	report(true)
	while alive(state) and #state.dents > 0 do
		if not Plots.isNear(player, panel.Position, Config.Dent.MaxDistance) then
			state.dentRunning = false
			report(false)
			Remotes.Notify:FireClient(player, "Stopped: you moved away from the work.")
			retry()
			return
		end
		local dent = state.dents[math.random(#state.dents)]
		dent.Color = DENT_ACTIVE
		dent.Material = Enum.Material.Neon
		local hit = false
		local detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = Config.Dent.MaxDistance
		detector.MouseClick:Connect(function(clicker)
			if clicker == player then
				hit = true
			end
		end)
		detector.Parent = dent
		local deadline = os.clock() + lifetime
		while not hit and os.clock() < deadline and alive(state) do
			task.wait()
		end
		detector:Destroy()
		if hit then
			table.remove(state.dents, table.find(state.dents, dent))
			dent:Destroy()
			state.dentHits += 1
		else
			dent.Color = DENT_COLOR
			dent.Material = Enum.Material.Metal
			state.dentMisses += 1
		end
		report(true)
		task.wait(Config.Dent.Gap)
	end
	state.dentRunning = false
	report(false)
	if alive(state) then
		state.misses += state.dentMisses
		panel.Color = state.paint
		finish(state)
	end
end

local function runDent(state)
	local function offer()
		if not alive(state) then
			return
		end
		sendStep(state, "Hammer out the dents on the highlighted panel.")
		state.prompt = Plots.prompt(state.plot, state.panel, "Hammer dents", state.job.Label, 0, function(player)
			if Spin.isBusy(player) or state.dentRunning or not state.prompt then
				return
			end
			clearPrompt(state)
			sendStep(state, "Click each glowing dent before it fades.")
			task.spawn(dentGame, state, player, offer)
		end)
	end
	offer()
end

local function setupFault(state)
	local car = state.car
	if state.jobType == "FlatTire" then
		local wheel = car[WHEELS[math.random(#WHEELS)]]
		state.wheelName = wheel.Name
		state.wheelOffset = car.Body.CFrame:ToObjectSpace(wheel.CFrame)
		state.side = wheel.Name:sub(-1) == "L" and -1 or 1
		state.nuts = addNuts(wheel, state.side, 0)
		local bulge = decor(
			"FlatBulge",
			Enum.PartType.Block,
			Vector3.new(1.25, 0.45, 2.1),
			wheel.CFrame * CFrame.new(0, -1.05, 0),
			wheel.Color,
			wheel.Material
		)
		weld(wheel, bulge)
		bulge.Parent = wheel
		highlight(wheel)
	else
		local panel = car[PANELS[math.random(#PANELS)]]
		state.panel = panel
		panel.Color = state.paint:Lerp(Color3.fromRGB(60, 60, 60), 0.4)
		state.dents = {}
		state.dentHits = 0
		state.dentMisses = 0
		local half = panel.Size / 2
		for i = 1, Config.Dent.Count do
			local t = (i - 0.5) / Config.Dent.Count * 2 - 1
			local offset
			if panel.Name == "Panel_Hood" then
				offset = Vector3.new(t * (half.X - 0.4), half.Y, (math.random() * 2 - 1) * (half.Z - 0.5))
			else
				local sign = panel.Name == "Panel_Left" and -1 or 1
				offset = Vector3.new(sign * half.X, (math.random() * 2 - 1) * (half.Y - 0.3), t * (half.Z - 0.4))
			end
			local dent = decor(
				"Dent",
				Enum.PartType.Ball,
				Vector3.new(0.8, 0.8, 0.8),
				panel.CFrame * CFrame.new(offset),
				DENT_COLOR,
				Enum.Material.Metal
			)
			weld(panel, dent)
			dent.Parent = panel
			table.insert(state.dents, dent)
		end
		highlight(panel)
	end

	local label = Instance.new("BillboardGui")
	label.Name = "FaultLabel"
	label.Size = UDim2.fromOffset(160, 36)
	label.StudsOffset = Vector3.new(0, 5, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 80
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	text.BackgroundTransparency = 0.2
	text.TextColor3 = Color3.fromRGB(255, 180, 60)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = state.job.Label
	text.Parent = label
	label.Parent = car.Body
end

function RepairJobs.spawnCustomer(plot)
	if not active[plot] or states[plot] then
		return
	end
	local jobType = JOB_TYPES[math.random(#JOB_TYPES)]
	local car = assets.CustomerCar:Clone()
	local paint = Config.CustomerColors[math.random(#Config.CustomerColors)]
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Paint") then
			d.Color = paint
		end
	end
	local state = {
		plot = plot,
		car = car,
		jobType = jobType,
		job = Config.Jobs[jobType],
		paint = paint,
		phase = "Arriving",
		misses = 0,
	}
	states[plot] = state
	setupFault(state)

	local p1 = Plots.marker(plot, "In1").Position
	local p2 = Plots.marker(plot, "In2").Position
	local p3 = Plots.marker(plot, "In3").Position
	local bay = Plots.marker(plot, "Bay")
	car:PivotTo(CFrame.lookAt(p1, p2))
	car.Parent = plot
	local ok = tweenTo(state, CFrame.lookAt(p2, p3))
		and tweenTo(state, CFrame.lookAt(p3, bay.Position))
		and tweenTo(state, bay)
	if not ok then
		return
	end

	state.phase = "Waiting"
	sendStep(state, "A customer is waiting. Accept the job at their car.")
	state.prompt = Plots.prompt(
		plot,
		car.Body,
		"Accept job",
		state.job.Label .. " - $" .. state.job.Payout,
		0.3,
		function()
			if state.phase ~= "Waiting" then
				return
			end
			state.phase = "Active"
			clearPrompt(state)
			if jobType == "FlatTire" then
				runFlatTire(state)
			else
				runDent(state)
			end
		end
	)
end

function RepairJobs.start(plot)
	active[plot] = true
	task.delay(2, RepairJobs.spawnCustomer, plot)
end

function RepairJobs.stop(plot)
	active[plot] = nil
	local state = states[plot]
	states[plot] = nil
	if state then
		state.car:Destroy()
		if state.oldWheel then
			state.oldWheel:Destroy()
		end
	end
end

return RepairJobs

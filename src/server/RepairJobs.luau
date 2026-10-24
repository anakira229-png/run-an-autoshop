local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local PartUtil = require(ReplicatedStorage.RunAutoshop.PartUtil)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Sounds = require(ReplicatedStorage.RunAutoshop.Sounds)
local WorldData = require(ReplicatedStorage.RunAutoshop.WorldData)
local Chassis = require(script.Parent.Chassis)
local Effects = require(script.Parent.Effects)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Route = require(script.Parent.Route)
local Spin = require(script.Parent.Spin)
local WorkSession = require(script.Parent.WorkSession)

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
	return state.active == true
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
	if text then
		state.lastHint = text
	end
	local owner = state.owner()
	if owner then
		-- New parts may not have streamed in yet, so also send a name path the client can resolve later.
		local path
		if state.target then
			path = {}
			local node = state.target.part
			while node and node ~= state.car do
				table.insert(path, 1, node.Name)
				node = node.Parent
			end
		end
		Remotes.JobUpdate:FireClient(owner, {
			label = state.job.Label,
			payout = state.job.Payout,
			step = text,
			target = state.target and state.target.part,
			targetPath = path,
			car = state.car,
		})
	end
end

local function clearPrompt(state)
	if state.prompt then
		state.prompt:Destroy()
		state.prompt = nil
	end
end

-- run(player) fires when the owner clicks part (or a descendant) in the work view.
local function setTarget(state, part, hint, run)
	state.target = { part = part, run = run }
	sendStep(state, hint)
end

local function onWorkClick(state, player, part)
	if state.owner() ~= player or not alive(state) then
		return
	end
	if state.activeDent and part == state.activeDent then
		state.dentHit = true
		return
	end
	local target = state.target
	if not target or Spin.isBusy(player) or state.dentRunning then
		return
	end
	if part == target.part or part:IsDescendantOf(target.part) then
		state.target = nil
		target.run(player)
	end
end

local function enterWork(state, player)
	WorkSession.enter(player, state.car, "job", function(p, part)
		onWorkClick(state, p, part)
	end)
	sendStep(state, state.lastHint)
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

local function holdStep(state, part, hint, onDone)
	setTarget(state, part, hint, function()
		onDone()
	end)
end

local function spinStep(state, part, hint, onProgress, onDone)
	local function offer()
		if not alive(state) then
			return
		end
		setTarget(state, part, hint, function(player)
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
			if not started then
				offer()
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
	state.target = nil
	clearPrompt(state)
	if state.workPrompt then
		state.workPrompt:Destroy()
		state.workPrompt = nil
	end

	local stars = 1
	if state.misses <= Config.MaxMisses[3] then
		stars = 3
	elseif state.misses <= Config.MaxMisses[2] then
		stars = 2
	end
	local payout = math.floor(state.job.Payout * Config.StarMultipliers[stars] + 0.5)
	local owner = state.owner()
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
	if owner and WorkSession.isIn(owner, car) then
		WorkSession.exit(owner)
	end
	if alive(state) then
		state.onFinished(state)
	end
end

local function depart(state)
	local plot = state.plot
	local out1 = Plots.marker(plot, "Out1").Position
	local out2 = Plots.marker(plot, "Out2").Position
	local out3 = Plots.marker(plot, "Out3").Position
	local bay = Plots.marker(plot, "Bay")
	local ok = tweenTo(state, bay.Rotation + out1)
		and tweenTo(state, CFrame.lookAt(out2, out3))
		and tweenTo(state, CFrame.lookAt(out3, out3 + (out3 - out2)))
	if ok then
		RepairJobs.endCustomer(state)
	end
end

local function testDriveRoute(plot)
	local corners = WorldData.TestDriveLoop
	local start = Plots.marker(plot, "In3").Position
	local nearest = 1
	for i, corner in corners do
		if (corner - start).Magnitude < (corners[nearest] - start).Magnitude then
			nearest = i
		end
	end
	local points = {}
	for i = 0, #corners - 1 do
		table.insert(points, corners[(nearest - 1 + i) % #corners + 1])
	end
	table.insert(points, start)
	return points
end

local function startTestDrive(state, player)
	local car, body = state.car, state.car.Body
	state.phase = "TestDrive"
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CFrame = body.CFrame * CFrame.new(-1.3, 1.2, 0.8)
	weld(body, seat)
	seat.Parent = car

	local wheels = {}
	for _, name in WHEELS do
		table.insert(wheels, { part = car[name], front = name:sub(-2, -2) == "F" })
	end
	state.chassis = Chassis.build({
		root = body,
		wheels = wheels,
		seat = seat,
		driver = state.owner,
		stats = Chassis.stats(),
	})
	Chassis.seat(state.chassis, player)
	sendStep(state, "Drive through every checkpoint, then park back in the bay.")

	local td = Config.TestDrive
	Route.start(player, {
		label = "Test drive",
		root = body,
		seat = seat,
		points = testDriveRoute(state.plot),
		park = {
			position = Plots.marker(state.plot, "Bay").Position,
			radius = td.ParkRadius,
			maxSpeed = td.ParkMaxSpeed,
		},
		radius = td.CheckpointRadius,
		timeLimit = td.TimeLimit,
		outOfCarLimit = td.OutOfCarLimit,
		onEnd = function(success, timeLeft)
			if not alive(state) then
				return
			end
			Chassis.eject(state.chassis)
			local owner = state.owner()
			if owner then
				Remotes.JobUpdate:FireClient(owner, nil)
				if success then
					local tip = td.TipBase + math.floor(timeLeft * td.TipPerSecondLeft)
					PlayerData.addMoney(owner, tip)
					Remotes.Notify:FireClient(owner, "The customer loved the test drive! Tip: $" .. tip)
				else
					Remotes.Notify:FireClient(owner, "Test drive failed. No tip this time.")
					Plots.teleportHome(owner)
				end
			end
			RepairJobs.endCustomer(state)
		end,
	})
end

local function offerTestDrive(state)
	local td = Config.TestDrive
	local maxTip = td.TipBase + td.TimeLimit * td.TipPerSecondLeft
	state.phase = "Offer"
	sendStep(state, "Take the car for a test drive to earn a tip, or let the customer leave.")
	state.prompt = Plots.ownerPrompt(
		state.owner,
		state.car.Body,
		"Test drive",
		"Tip up to $" .. maxTip,
		0.3,
		function(player)
			if state.phase ~= "Offer" or Spin.isBusy(player) then
				return
			end
			clearPrompt(state)
			startTestDrive(state, player)
		end
	)
	task.delay(td.OfferTime, function()
		if alive(state) and state.phase == "Offer" then
			clearPrompt(state)
			local owner = state.owner()
			if owner then
				Remotes.JobUpdate:FireClient(owner, nil)
			end
			state.phase = "Leaving"
			depart(state)
		end
	end)
end

local function runFlatTire(state)
	local car = state.car
	local wheel = car[state.wheelName]
	spinStep(state, wheel, "Click the flat wheel and spin off the lug nuts.", function(f)
		showNuts(state.nuts, 1 - f)
	end, function()
		holdStep(state, wheel, "Click the wheel to pull it off.", function()
			local body = car.Body
			wheel:FindFirstChild("WeldConstraint"):Destroy()
			wheel.Anchored = true
			wheel.FaultHighlight:Destroy()
			wheel.Name = "OldWheel"
			wheel.Parent = car.Parent
			state.oldWheel = wheel
			local outward = body.CFrame:VectorToWorldSpace(Vector3.new(state.side, 0, 0))
			local ground = car:GetPivot().Position.Y
			local drop = CFrame.new(Vector3.new(wheel.Position.X, ground + 0.6, wheel.Position.Z) + outward * 3.5)
				* CFrame.Angles(0, 0, math.pi / 2)
			TweenService:Create(wheel, TweenInfo.new(0.4, Enum.EasingStyle.Bounce), { CFrame = drop }):Play()
			task.delay(0.3, Effects.sound, wheel, Sounds.WheelDrop, 0.7)

			-- Sag toward the missing corner.
			local level = car:GetPivot()
			local front = math.sign(state.wheelOffset.Position.Z)
			car:PivotTo(level * CFrame.Angles(math.rad(front * 1.5), 0, math.rad(-state.side * 2)))
			local fitCFrame = body.CFrame * state.wheelOffset

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
			holdStep(state, ghost, "Click the glowing spot to fit a new wheel.", function()
				ghost:Destroy()
				car:PivotTo(level)
				fitCFrame = body.CFrame * state.wheelOffset
				local newWheel = assets.Parts.Wheel:Clone()
				newWheel.Name = state.wheelName
				PartUtil.place(newWheel, fitCFrame)
				newWheel.Anchored = false
				newWheel.CanCollide = false
				weld(body, newWheel)
				newWheel.Parent = car
				local nuts = addNuts(newWheel, state.side, 1)
				spinStep(state, newWheel, "Click the new wheel and spin the lug nuts tight.", function(f)
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
		if not WorkSession.isIn(player, state.car) then
			state.dentRunning = false
			report(false)
			retry()
			return
		end
		local dent = state.dents[math.random(#state.dents)]
		dent.Color = DENT_ACTIVE
		dent.Material = Enum.Material.Neon
		state.dentHit = false
		state.activeDent = dent
		local deadline = os.clock() + lifetime
		while not state.dentHit and os.clock() < deadline and alive(state) do
			task.wait()
		end
		state.activeDent = nil
		if state.dentHit then
			table.remove(state.dents, table.find(state.dents, dent))
			Effects.sound(panel, Sounds.DentPop, 0.8)
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
		setTarget(state, state.panel, "Click the dented panel to start hammering.", function(player)
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

function RepairJobs.randomJobType()
	local forced = RunService:IsStudio() and workspace:GetAttribute("DebugJobType")
	if forced and Config.Jobs[forced] then
		return forced
	end
	return JOB_TYPES[math.random(#JOB_TYPES)]
end

-- Clones a customer car with a random paint job and the job's fault; caller positions and parents it.
function RepairJobs.createJob(jobType, owner, job, onFinished)
	local car = assets.CustomerCar:Clone()
	local paint = Config.CustomerColors[math.random(#Config.CustomerColors)]
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Paint") then
			d.Color = paint
		end
	end
	local state = {
		car = car,
		jobType = jobType,
		job = job,
		paint = paint,
		phase = "Arriving",
		misses = 0,
		active = true,
		owner = owner,
		onFinished = onFinished,
	}
	setupFault(state)
	return state
end

function RepairJobs.begin(state)
	state.phase = "Active"
	clearPrompt(state)
	if state.jobType == "FlatTire" then
		runFlatTire(state)
	else
		runDent(state)
	end
end

-- Single prompt on the car that starts the job if needed and opens the work view.
function RepairJobs.addWorkPrompt(state, actionText)
	state.workPrompt = Plots.ownerPrompt(
		state.owner,
		state.car.Body,
		actionText,
		state.job.Label .. " - $" .. state.job.Payout,
		0.2,
		function(player)
			if WorkSession.isSeated(player) or Spin.isBusy(player) then
				return
			end
			if state.phase == "Waiting" then
				RepairJobs.begin(state)
			end
			if state.phase == "Active" then
				state.workPrompt.ActionText = "Work on car"
				enterWork(state, player)
			end
		end
	)
end

function RepairJobs.cancel(state)
	state.active = false
	if state.chassis then
		state.chassis.destroy()
	end
	state.car:Destroy()
	if state.oldWheel then
		state.oldWheel:Destroy()
	end
end

-- Removes a shop customer's car and schedules the next one.
function RepairJobs.endCustomer(state)
	RepairJobs.cancel(state)
	if states[state.plot] == state then
		states[state.plot] = nil
		task.delay(Config.CustomerDelay, RepairJobs.spawnCustomer, state.plot)
	end
end

function RepairJobs.spawnCustomer(plot)
	if not active[plot] or states[plot] then
		return
	end
	local jobType = RepairJobs.randomJobType()
	local state = RepairJobs.createJob(jobType, function()
		return Plots.owner(plot)
	end, Config.Jobs[jobType], offerTestDrive)
	state.plot = plot
	states[plot] = state
	local car = state.car

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

	Effects.sound(car.Body, Sounds.Horn, 0.5)
	state.phase = "Waiting"
	sendStep(state, "A customer is waiting. Start the job at their car.")
	RepairJobs.addWorkPrompt(state, "Start job")
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
		RepairJobs.cancel(state)
	end
end

return RepairJobs

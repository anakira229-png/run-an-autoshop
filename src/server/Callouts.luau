local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local WorldData = require(ReplicatedStorage.RunAutoshop.WorldData)
local RepairJobs = require(script.Parent.RepairJobs)

local cfg = Config.Callouts
local nextOffer = {}
local offers = {}
local calls = {}
local folder

local Callouts = {}

local function spotTaken(spot)
	for _, call in calls do
		if call.spot == spot then
			return true
		end
	end
	return false
end

local function blinkHazards(state)
	local lights = {}
	for _, part in state.car:GetChildren() do
		if part.Name == "Headlight" or part.Name == "Taillight" then
			table.insert(lights, part)
		end
	end
	task.spawn(function()
		local on = true
		while state.active and state.phase == "Active" do
			on = not on
			for _, light in lights do
				light.Color = on and Color3.fromRGB(255, 170, 30) or Color3.fromRGB(60, 40, 20)
			end
			task.wait(0.5)
		end
	end)
end

local function endCall(player, message)
	local call = calls[player]
	if not call then
		return
	end
	calls[player] = nil
	RepairJobs.cancel(call.state)
	nextOffer[player] = os.clock() + cfg.Interval
	if player.Parent then
		Remotes.CalloutState:FireClient(player, nil)
		Remotes.JobUpdate:FireClient(player, nil)
		if message then
			Remotes.Notify:FireClient(player, message)
		end
	end
end

local function startCall(player, offer)
	local job = { Label = "Roadside: " .. Config.Jobs[offer.jobType].Label, Payout = offer.payout }
	local state
	state = RepairJobs.createJob(
		offer.jobType,
		function()
			return player.Parent and calls[player] and calls[player].state == state and player or nil
		end,
		job,
		function()
			task.delay(2, function()
				if calls[player] and calls[player].state == state then
					endCall(player, nil)
				end
			end)
		end
	)
	local car = state.car
	car:SetAttribute("OwnerUserId", player.UserId)
	car:PivotTo(CFrame.new(offer.spot.Position) * CFrame.Angles(0, math.rad(offer.spot.Yaw), 0))
	car.Parent = folder
	calls[player] = { state = state, spot = offer.spot, expires = os.clock() + cfg.ExpireTime }
	RepairJobs.begin(state)
	RepairJobs.addWorkPrompt(state, "Work on car")
	blinkHazards(state)
	Remotes.CalloutState:FireClient(
		player,
		{ position = offer.spot.Position, label = job.Label, place = offer.spot.Name }
	)
end

local function onRespond(player, answer)
	if answer == "cancel" then
		endCall(player, "Call cancelled.")
		return
	end
	local offer = offers[player]
	if type(answer) ~= "boolean" or not offer then
		return
	end
	offers[player] = nil
	Remotes.CalloutOffer:FireClient(player, nil)
	if answer and not calls[player] then
		startCall(player, offer)
	else
		nextOffer[player] = os.clock() + cfg.Interval
	end
end

local function update()
	local now = os.clock()
	for player, offer in offers do
		if now > offer.expires then
			offers[player] = nil
			nextOffer[player] = now + cfg.Interval
			Remotes.CalloutOffer:FireClient(player, nil)
		end
	end
	for player, call in calls do
		if now > call.expires and call.state.phase == "Active" then
			endCall(player, "The roadside customer gave up waiting.")
		end
	end
	for player, due in nextOffer do
		if now >= due and not offers[player] and not calls[player] and player:GetAttribute("CarReady") then
			local free = {}
			for _, spot in WorldData.CalloutSpots do
				if not spotTaken(spot) then
					table.insert(free, spot)
				end
			end
			if #free > 0 then
				local jobType = RepairJobs.randomJobType()
				local offer = {
					spot = free[math.random(#free)],
					jobType = jobType,
					payout = Config.Jobs[jobType].Payout * cfg.PayoutMultiplier,
					expires = now + cfg.OfferTime,
				}
				offers[player] = offer
				Remotes.CalloutOffer:FireClient(player, {
					label = Config.Jobs[jobType].Label,
					payout = offer.payout,
					place = offer.spot.Name,
					timeLeft = cfg.OfferTime,
				})
			end
		end
	end
end

function Callouts.track(player)
	nextOffer[player] = os.clock() + cfg.FirstDelay
end

function Callouts.untrack(player)
	nextOffer[player] = nil
	offers[player] = nil
	endCall(player, nil)
end

function Callouts.init()
	folder = Instance.new("Folder")
	folder.Name = "RunAutoshopCallouts"
	folder.Parent = workspace
	Remotes.CalloutRespond.OnServerEvent:Connect(onRespond)
	Players.PlayerRemoving:Connect(Callouts.untrack)
	task.spawn(function()
		while true do
			task.wait(1)
			update()
		end
	end)
end

return Callouts

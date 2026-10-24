local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)

local sessions = {}

local Spin = {}

local function sendState(player, session)
	Remotes.SpinState:FireClient(player, {
		label = session.label,
		required = session.required,
		progress = session.progress,
		slipRate = session.slipRate,
		slips = session.slips,
	})
end

-- opts: label, degrees, anchor (BasePart), onProgress(fraction)?, onComplete(slips), onCancel()?
function Spin.start(player, opts)
	if sessions[player] then
		return false
	end
	local better = PlayerData.hasUpgrade(player, "BetterTools")
	local session = {
		label = opts.label,
		required = opts.degrees * (better and Config.Spin.BetterToolsDegrees or 1),
		slipRate = Config.Spin.SlipRate * (better and Config.Spin.BetterToolsSlipRate or 1),
		progress = 0,
		slips = 0,
		lastSlip = 0,
		started = os.clock(),
		opts = opts,
	}
	sessions[player] = session
	sendState(player, session)
	return true
end

function Spin.cancel(player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if player.Parent then
		Remotes.SpinState:FireClient(player, nil)
	end
	if session.opts.onCancel then
		session.opts.onCancel()
	end
end

function Spin.isBusy(player)
	return sessions[player] ~= nil
end

local function onInput(player, degrees, dt)
	local session = sessions[player]
	if not session then
		return
	end
	if type(degrees) ~= "number" or type(dt) ~= "number" or degrees ~= degrees or dt ~= dt then
		return
	end
	if degrees <= 0 or degrees > 5000 or dt <= 0 or dt > 1 then
		return
	end
	local now = os.clock()
	if degrees / math.max(dt, 1 / 30) > session.slipRate then
		if now - session.lastSlip >= Config.Spin.SlipCooldown then
			session.lastSlip = now
			session.slips += 1
			sendState(player, session)
		end
		return
	end
	-- Server-timed budget caps progress no matter what rate the client reports.
	local budget = session.slipRate * Config.Spin.BudgetSlack * (now - session.started)
	session.progress = math.min(session.progress + degrees, budget, session.required)
	if session.opts.onProgress then
		session.opts.onProgress(session.progress / session.required)
	end
	if session.progress >= session.required then
		sessions[player] = nil
		Remotes.SpinState:FireClient(player, nil)
		session.opts.onComplete(session.slips)
	else
		sendState(player, session)
	end
end

function Spin.init()
	Remotes.SpinInput.OnServerEvent:Connect(onInput)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, session in sessions do
				local anchor = session.opts.anchor
				if not anchor.Parent or not Plots.isNear(player, anchor.Position, Config.Spin.MaxDistance) then
					Spin.cancel(player)
					if player.Parent then
						Remotes.Notify:FireClient(player, "Stopped: you moved away from the work.")
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return Spin

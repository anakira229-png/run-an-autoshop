local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Plots = require(script.Parent.Plots)
local Spin = require(script.Parent.Spin)

local sessions = {}
local lastAction = {}

local WorkSession = {}

function WorkSession.exit(player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	for _, conn in session.conns do
		conn:Disconnect()
	end
	Spin.cancel(player)
	if player.Parent then
		Remotes.WorkState:FireClient(player, nil)
	end
end

-- handler(player, part) receives validated clicks on parts of the car.
function WorkSession.enter(player, car, kind, handler)
	WorkSession.exit(player)
	local session = { car = car, kind = kind, handler = handler, conns = {} }
	sessions[player] = session
	table.insert(
		session.conns,
		car.AncestryChanged:Connect(function()
			if not car:IsDescendantOf(workspace) then
				WorkSession.exit(player)
			end
		end)
	)
	table.insert(
		session.conns,
		player.CharacterRemoving:Connect(function()
			WorkSession.exit(player)
		end)
	)
	Remotes.WorkState:FireClient(player, { car = car, kind = kind })
end

function WorkSession.isIn(player, car)
	local session = sessions[player]
	return session ~= nil and session.car == car
end

function WorkSession.isSeated(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end

function WorkSession.init()
	Remotes.WorkAction.OnServerEvent:Connect(function(player, part)
		local session = sessions[player]
		if not session or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
			return
		end
		local now = os.clock()
		if lastAction[player] and now - lastAction[player] < Config.Work.ActionCooldown then
			return
		end
		lastAction[player] = now
		if not part:IsDescendantOf(session.car) then
			return
		end
		if not Plots.isNear(player, session.car:GetPivot().Position, Config.Work.MaxDistance) then
			WorkSession.exit(player)
			return
		end
		session.handler(player, part)
	end)
	Remotes.WorkExit.OnServerEvent:Connect(WorkSession.exit)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		lastAction[player] = nil
	end)
end

return WorkSession

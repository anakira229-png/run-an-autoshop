local Players = game:GetService("Players")

local PlayerData = require(script.PlayerData)
local Plots = require(script.Plots)
local Spin = require(script.Spin)
local WorkSession = require(script.WorkSession)
local Route = require(script.Route)
local RepairJobs = require(script.RepairJobs)
local Shop = require(script.Shop)
local PersonalCar = require(script.PersonalCar)
local Callouts = require(script.Callouts)
local Remotes = require(game:GetService("ReplicatedStorage").RunAutoshop.Remotes)

PlayerData.start()
Spin.init()
WorkSession.init()
Route.init()
Shop.init()
PersonalCar.init()
Callouts.init()

local function onPlayerAdded(player)
	local plot = Plots.claim(player)
	if not plot then
		Remotes.Notify:FireClient(player, "All shops are taken on this server.")
		return
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		task.wait()
		Plots.teleportHome(player)
	end)
	if player.Character then
		Plots.teleportHome(player)
	end

	if not PlayerData.load(player) then
		return
	end
	PersonalCar.spawn(player)
	RepairJobs.start(plot)
	Callouts.track(player)
end

local function onPlayerRemoving(player)
	Spin.cancel(player)
	local plot = Plots.get(player)
	if plot then
		RepairJobs.stop(plot)
	end
	PersonalCar.despawn(player)
	Plots.release(player)
	PlayerData.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local engine = Effects.loop("Engine", 0.35)
local skid = Effects.loop("Skid", 0)
local seat = nil

RunService.Heartbeat:Connect(function(dt)
	if not seat then
		return
	end
	local speed = seat.AssemblyLinearVelocity.Magnitude
	local speedFraction = math.clamp(speed / Config.Car.MaxSpeed, 0, 1)
	local throttle = math.abs(seat.ThrottleFloat)
	engine.PlaybackSpeed = 0.7 + speedFraction * 0.8 + throttle * 0.1
	engine.Volume = 0.3 + throttle * 0.15
	local skidding = math.abs(seat.SteerFloat) > 0.5 and speed > Config.Car.MaxSpeed * 0.55
	local target = skidding and 0.45 or 0
	skid.Volume += (target - skid.Volume) * math.min(dt * 8, 1)
end)

local function onSeated(active, seatPart)
	local mine = active and seatPart and seatPart:IsA("VehicleSeat") and seatPart:FindFirstAncestor("PersonalCar")
	seat = mine and seatPart or nil
	if seat then
		engine:Play()
		skid:Play()
	else
		engine:Stop()
		skid:Stop()
		skid.Volume = 0
	end
end

local function onCharacter(character)
	onSeated(false)
	character:WaitForChild("Humanoid").Seated:Connect(onSeated)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter(player.Character)
end

return true

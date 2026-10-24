local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.RunAutoshop.Sounds)

local Effects = {}

function Effects.play(name, volume, speed)
	local sound = Instance.new("Sound")
	sound.SoundId = Sounds[name]
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = speed or 1
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	return sound
end

function Effects.loop(name, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = Sounds[name]
	sound.Volume = volume or 0.5
	sound.Looped = true
	sound.Parent = SoundService
	return sound
end

local shakeUntil, shakeStrength = 0, 0
function Effects.shake(strength, duration)
	shakeStrength = math.max(strength, os.clock() < shakeUntil and shakeStrength or 0)
	shakeUntil = os.clock() + duration
end

-- Runs after the work-view camera (Camera + 1) so its absolute CFrame doesn't overwrite the shake.
RunService:BindToRenderStep("RunAutoshopShake", Enum.RenderPriority.Camera.Value + 2, function()
	local remaining = shakeUntil - os.clock()
	if remaining <= 0 then
		return
	end
	local s = shakeStrength * math.min(remaining * 4, 1)
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * s), math.rad((math.random() - 0.5) * s), 0)
end)

return Effects

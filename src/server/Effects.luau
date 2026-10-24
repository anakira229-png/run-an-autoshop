local Effects = {}

function Effects.sound(parent, soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 120
	sound.Parent = parent
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(15, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

function Effects.sparks(parent)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Sparks"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Lifetime = NumberRange.new(0.15, 0.35)
	emitter.Size = NumberSequence.new(0.25, 0)
	emitter.LightEmission = 1
	emitter.Acceleration = Vector3.new(0, -60, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
	emitter.Parent = attachment
	attachment.Parent = parent
	return emitter
end

return Effects

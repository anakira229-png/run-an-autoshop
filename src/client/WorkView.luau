local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.RunAutoshop.Config)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Store = require(script.Parent.Store)

local peek = Fusion.peek
local player = Players.LocalPlayer

local OVERVIEW_DISTANCE = 24
local FOCUS_DISTANCE = 10
local STEP_DISTANCE = 15
local INTRO_DISTANCE = 52
local MIN_DISTANCE, MAX_DISTANCE = 6, 45
local OVERVIEW_FOV, FOCUS_FOV = 70, 56
local MIN_PITCH, MAX_PITCH = math.rad(5), math.rad(80)
local OVERVIEW_PITCH = math.rad(28)

local active = nil
local yaw, yawGoal = 0, 0
local pitch, pitchGoal = OVERVIEW_PITCH, OVERVIEW_PITCH
local distance, distanceGoal = OVERVIEW_DISTANCE, OVERVIEW_DISTANCE
local focus, focusGoal = Vector3.zero, Vector3.zero
local lastStep = nil
local rotating = false
local saved = {}

local highlightFolder = Instance.new("Folder")
highlightFolder.Name = "RunAutoshopWorkHighlights"
local highlights = {}

local WorkView = {}

local function carCenter()
	return active.car:GetPivot().Position + Vector3.new(0, 2.5, 0)
end

-- Eases the camera onto a target, orbiting to the side of the car it is on so the body isn't in the way.
local function frameTarget(target, goalDistance)
	focusGoal = target:IsA("BasePart") and target.Position or target:GetPivot().Position
	distanceGoal = goalDistance
	pitchGoal = OVERVIEW_PITCH
	local outward = focusGoal - active.car:GetPivot().Position
	outward = Vector3.new(outward.X, 0, outward.Z)
	if outward.Magnitude > 0.5 then
		local wrapped = (math.atan2(outward.X, outward.Z) - yawGoal + math.pi) % (2 * math.pi) - math.pi
		yawGoal += wrapped
	end
end

local function setCharacterHidden(hidden)
	local character = player.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function resolveTarget(job)
	if job.target and job.target.Parent then
		return job.target
	end
	local node = job.targetPath and active.car
	for _, name in job.targetPath or {} do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function stepKey()
	local job = peek(Store.job)
	if not job then
		return nil
	end
	local target = job.target or job.targetPath and table.concat(job.targetPath, "/")
	return tostring(job.step) .. "|" .. tostring(target)
end

local function highlightTargets()
	local wanted = {}
	local job = peek(Store.job)
	local target = active.kind == "job" and job and resolveTarget(job)
	if target then
		table.insert(wanted, target)
	elseif active.kind == "garage" then
		local slots = active.car:FindFirstChild("Slots")
		local attrs = peek(Store.attrs)
		for _, slot in slots and slots:GetChildren() or {} do
			if (attrs["Inv_" .. slot:GetAttribute("PartType")] or 0) > 0 then
				table.insert(wanted, slot)
			end
		end
	end
	local pulse = 0.45 + math.sin(os.clock() * 5) * 0.25
	for i, part in wanted do
		local h = highlights[i]
		if not h then
			h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 220, 60)
			h.OutlineColor = Color3.fromRGB(255, 255, 255)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = highlightFolder
			highlights[i] = h
		end
		h.Adornee = part
		h.FillTransparency = pulse
		h.Enabled = true
	end
	for i = #wanted + 1, #highlights do
		highlights[i].Enabled = false
		highlights[i].Adornee = nil
	end
end

local function render(dt)
	if not active or not active.car.Parent then
		return
	end
	-- Frame-rate independent easing; orbit follows the mouse more tightly than focus and zoom.
	local alpha = 1 - math.exp(-dt * 8)
	local orbitAlpha = 1 - math.exp(-dt * 18)
	focus = focus:Lerp(focusGoal, alpha)
	distance += (distanceGoal - distance) * alpha
	yaw += (yawGoal - yaw) * orbitAlpha
	pitch += (pitchGoal - pitch) * orbitAlpha
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.new(focus)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(-pitch, 0, 0)
		* CFrame.new(0, 0, distance)
	-- Closer zoom narrows the FOV for a lens-in feel.
	local zoom = math.clamp((OVERVIEW_DISTANCE - distance) / (OVERVIEW_DISTANCE - FOCUS_DISTANCE), 0, 1)
	camera.FieldOfView = OVERVIEW_FOV + (FOCUS_FOV - OVERVIEW_FOV) * zoom
	highlightTargets()
end

function WorkView.overview()
	if active then
		focusGoal = carCenter()
		distanceGoal = OVERVIEW_DISTANCE
		pitchGoal = math.max(pitchGoal, OVERVIEW_PITCH)
	end
end

local function enter(work)
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	active = work
	saved.cameraType = camera.CameraType
	saved.fieldOfView = camera.FieldOfView
	if humanoid then
		saved.walkSpeed, saved.jumpPower, saved.jumpHeight = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
	end
	camera.CameraType = Enum.CameraType.Scriptable
	ProximityPromptService.Enabled = false
	setCharacterHidden(true)
	local look = camera.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	yawGoal = yaw
	pitch, pitchGoal = OVERVIEW_PITCH, OVERVIEW_PITCH
	focus = carCenter()
	focusGoal = focus
	-- Start far out and ease in to the overview.
	distance, distanceGoal = INTRO_DISTANCE, OVERVIEW_DISTANCE
	lastStep = stepKey()
	local job = work.kind == "job" and peek(Store.job)
	local target = job and resolveTarget(job)
	if target then
		frameTarget(target, STEP_DISTANCE)
	end
	highlightFolder.Parent = workspace
	RunService:BindToRenderStep("RunAutoshopWorkView", Enum.RenderPriority.Camera.Value + 1, render)
end

local function exit()
	if not active then
		return
	end
	active = nil
	rotating = false
	RunService:UnbindFromRenderStep("RunAutoshopWorkView")
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local camera = workspace.CurrentCamera
	camera.CameraType = saved.cameraType or Enum.CameraType.Custom
	camera.FieldOfView = saved.fieldOfView or 70
	ProximityPromptService.Enabled = true
	setCharacterHidden(false)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and saved.walkSpeed then
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = saved.walkSpeed, saved.jumpPower, saved.jumpHeight
	end
	highlightFolder.Parent = nil
end

function WorkView.leave()
	Remotes.WorkExit:FireServer()
	exit()
	Store.work:set(nil)
end

local function isTarget(part)
	for _, h in highlights do
		if h.Enabled and h.Adornee and (part == h.Adornee or part:IsDescendantOf(h.Adornee)) then
			return h.Adornee
		end
	end
	return nil
end

local function click(position)
	local ray = workspace.CurrentCamera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { active.car }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not hit then
		return
	end
	Remotes.WorkAction:FireServer(hit.Instance)
	local target = isTarget(hit.Instance)
	if target then
		frameTarget(target, FOCUS_DISTANCE)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not active then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rotating = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed and not peek(Store.spinActive) then
		click(UserInputService:GetMouseLocation())
	elseif input.KeyCode == Enum.KeyCode.F then
		WorkView.overview()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and rotating then
		rotating = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not active then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement and rotating then
		yawGoal -= input.Delta.X * 0.008
		pitchGoal = math.clamp(pitchGoal + input.Delta.Y * 0.006, MIN_PITCH, MAX_PITCH)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		distanceGoal = math.clamp(distanceGoal * 0.85 ^ input.Position.Z, MIN_DISTANCE, MAX_DISTANCE)
	end
end)

Store.scope:Observer(Store.work):onChange(function()
	local work = peek(Store.work)
	if work and (not active or active.car ~= work.car) then
		if active then
			exit()
		end
		enter(work)
	elseif not work then
		exit()
	end
end)

-- Frame each new step's target; steps without one (minigames) keep the current framing.
Store.scope:Observer(Store.job):onChange(function()
	local key = stepKey()
	if active and key and key ~= lastStep then
		local job = peek(Store.job)
		local target = active.kind == "job" and job and resolveTarget(job)
		if target then
			frameTarget(target, STEP_DISTANCE)
		end
	end
	lastStep = key
end)

-- Leave the view if the character walks or gets moved too far away.
task.spawn(function()
	while true do
		task.wait(0.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if active and root and (root.Position - active.car:GetPivot().Position).Magnitude > Config.Work.MaxDistance then
			WorkView.leave()
		end
	end
end)

return WorkView

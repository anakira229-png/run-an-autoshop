-- Synced by Rojo to ServerStorage.RunAutoshopTools. Owned by the World agent. Called by BuildMap, not run directly.
-- Generates the street grid, highway loop, and every district under the map folder from the layout tables below.
-- Axes: +X is east, +Z is north (matching the street names in WorldData). Units are studs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local City = {}

City.GROUND = 0.2
City.PAD_TOP = 0.5

local ROAD = 24
local HALF = ROAD / 2
local ROAD_THICK = 0.2
local PAD_TOP = City.PAD_TOP
local LAWN_TOP = 0.55
local HIGHWAY_C = 450
local HIGHWAY_W = 56
local HIGHWAY_R = 100
local STRAIGHT = HIGHWAY_C - HIGHWAY_R
local ARC_STEPS = 12
local WALL_DIST = 600
local CENTERS = { -300, -180, -60, 60, 180, 300 }

-- Street centerlines. EW streets run along X at z = c; NS streets run along Z at x = c.
local STREETS = {
	{ dir = "EW", c = 0, a = -423, b = 423, name = "Main Street" },
	{ dir = "EW", c = 120, a = -360, b = 360, name = "North Street" },
	{ dir = "EW", c = -120, a = -360, b = 360, name = "South Street" },
	{ dir = "EW", c = 240, a = -360, b = 360, name = "Park Avenue" },
	{ dir = "EW", c = -240, a = -360, b = 240, name = "Market Street" },
	{ dir = "EW", c = 360, a = -360, b = 360, name = "North Perimeter" },
	{ dir = "EW", c = -360, a = -360, b = 360, name = "South Perimeter" },
	{ dir = "NS", c = 0, a = -423, b = 423, name = "Center Boulevard" },
	{ dir = "NS", c = -120, a = -360, b = 240, name = "West Avenue" },
	{ dir = "NS", c = 120, a = -360, b = 240, name = "East Avenue" },
	{ dir = "NS", c = -240, a = -360, b = 360, name = "Maple Avenue" },
	{ dir = "NS", c = 240, a = -360, b = 360, name = "Foundry Road" },
	{ dir = "NS", c = -360, a = -360, b = 360, name = "West Perimeter" },
	{ dir = "NS", c = 360, a = -360, b = 360, name = "East Perimeter" },
}

local SIDES = {
	{ n = Vector3.new(1, 0, 0), t = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(-1, 0, 0), t = Vector3.new(0, 0, 1) },
	{ n = Vector3.new(0, 0, 1), t = Vector3.new(1, 0, 0) },
	{ n = Vector3.new(0, 0, -1), t = Vector3.new(1, 0, 0) },
}

local CORNERS = {
	{ center = Vector3.new(STRAIGHT, 0, STRAIGHT), a0 = 0 },
	{ center = Vector3.new(-STRAIGHT, 0, STRAIGHT), a0 = 90 },
	{ center = Vector3.new(-STRAIGHT, 0, -STRAIGHT), a0 = 180 },
	{ center = Vector3.new(STRAIGHT, 0, -STRAIGHT), a0 = 270 },
}

local FACES = {
	{ n = Vector3.new(0, 0, 1), alongX = true },
	{ n = Vector3.new(0, 0, -1), alongX = true },
	{ n = Vector3.new(1, 0, 0), alongX = false },
	{ n = Vector3.new(-1, 0, 0), alongX = false },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local ASPHALT = rgb(55, 57, 62)
local CONCRETE = rgb(165, 162, 155)
local DARK = rgb(45, 45, 50)
local YELLOW = rgb(235, 200, 50)
local WHITE = rgb(235, 235, 230)
local LAMP_COLOR = rgb(255, 220, 170)
local WARM = rgb(190, 145, 90)
local DARK_GLASS = rgb(40, 55, 75)
local LAWN = rgb(92, 138, 68)
local TRUNK = rgb(90, 65, 45)
local LEAVES = { rgb(60, 110, 50), rgb(75, 130, 60), rgb(88, 140, 66), rgb(70, 120, 58) }
local CAR_COLORS = {
	rgb(170, 50, 45),
	rgb(70, 110, 170),
	rgb(220, 220, 215),
	rgb(40, 40, 45),
	rgb(230, 190, 60),
	rgb(60, 130, 90),
	rgb(150, 150, 160),
}

local created = 0

local function make(class, parent, name, size, cframe, color, material, props)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color or Color3.fromRGB(160, 160, 160)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	created += 1
	if created % 400 == 0 then
		task.wait()
	end
	return p
end

function City.part(parent, name, size, cframe, color, material, props)
	return make("Part", parent, name, size, cframe, color, material, props)
end
local part = City.part

local function wedge(parent, name, size, cframe, color, material, props)
	return make("WedgePart", parent, name, size, cframe, color, material, props)
end

function City.marker(parent, name, cframe)
	return part(parent, name, Vector3.new(1, 1, 1), cframe, Color3.new(1, 0, 1), nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

local function slab(parent, name, x0, x1, z0, z1, top, thick, color, material, props)
	return part(
		parent,
		name,
		Vector3.new(x1 - x0, thick, z1 - z0),
		CFrame.new((x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2),
		color,
		material,
		props
	)
end

local function sign(parent, cframe, size, text, bg, fg)
	local p = part(parent, "Sign", size, cframe, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = fg
	label.Text = text
	label.Parent = gui
	return p
end

local function cylinder(parent, name, diameter, height, cframe, color, material, props)
	-- Roblox cylinders run along X, so the CFrame rotates them upright.
	local p = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		props
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Art's models replace the stylized stand-ins when present: ServerStorage.RunAutoshopAssets.CityKit.<Name> (House, Tree,
-- ParkedCar, WreckCar), built in studs with the pivot at ground center and the front facing -Z. Parts with the
-- attribute Paint = true take the tint. Scripts are stripped and parts anchored. Returns whether a model was placed.
local function placeKit(parent, name, cframe, scale, tint)
	local assets = ServerStorage:FindFirstChild("RunAutoshopAssets")
	local kit = assets and assets:FindFirstChild("CityKit")
	local template = kit and kit:FindFirstChild(name)
	if not template then
		return false
	end
	local clone = template:Clone()
	for _, d in clone:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			if tint and d:GetAttribute("Paint") then
				d.Color = tint
			end
		end
	end
	if clone:IsA("Model") then
		if scale then
			clone:ScaleTo(scale)
		end
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CFrame = cframe
	end
	clone.Parent = parent
	return true
end

local function tree(parent, rng, x, z, base, scale)
	local s = scale or rng:NextNumber(0.8, 1.25)
	if placeKit(parent, "Tree", CFrame.new(x, base, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), s) then
		return
	end
	cylinder(parent, "Trunk", 1.4 * s, 7 * s, CFrame.new(x, base + 3.5 * s, z), TRUNK, Enum.Material.Wood)
	local size = 9 * s
	part(
		parent,
		"Leaves",
		Vector3.new(size, size, size),
		CFrame.new(x, base + 9 * s, z),
		pick(rng, LEAVES),
		Enum.Material.Grass,
		{
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		}
	)
end

local function parkedCar(parent, rng, x, z, base, yaw)
	local frame = CFrame.new(x, base, z) * CFrame.Angles(0, yaw, 0)
	local color = pick(rng, CAR_COLORS)
	if placeKit(parent, "ParkedCar", frame, nil, color) then
		return
	end
	part(parent, "Skirt", Vector3.new(5.6, 1.2, 11.6), frame * CFrame.new(0, 0.6, 0), DARK)
	part(parent, "Body", Vector3.new(6, 1.8, 12.5), frame * CFrame.new(0, 1.9, 0), color)
	part(parent, "Cabin", Vector3.new(5, 1.6, 6.5), frame * CFrame.new(0, 3.6, 0.6), DARK_GLASS, Enum.Material.Glass)
end

local function lamp(parent, base, toRoad, lit)
	local top = base + Vector3.new(0, 15, 0)
	part(
		parent,
		"LampPost",
		Vector3.new(0.6, 15.5, 0.6),
		CFrame.new(base + Vector3.new(0, 7.75, 0)),
		DARK,
		Enum.Material.Metal
	)
	part(
		parent,
		"LampArm",
		Vector3.new(0.4, 0.4, 5),
		CFrame.lookAt(top + toRoad * 2.5, top + toRoad * 5),
		DARK,
		Enum.Material.Metal
	)
	local head = part(
		parent,
		"LampHead",
		Vector3.new(1.4, 0.4, 2.2),
		CFrame.lookAt(top + toRoad * 5 - Vector3.new(0, 0.3, 0), top + toRoad * 6 - Vector3.new(0, 0.3, 0)),
		LAMP_COLOR,
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	if lit then
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Range = 45
		spot.Angle = 110
		spot.Brightness = 3
		spot.Color = LAMP_COLOR
		spot.Shadows = false
		spot.Parent = head
	end
end

-- Lamp on the highway median with a head over each carriageway; n is the outward direction of the arm.
local function highwayLamp(parent, base, n)
	local top = base + Vector3.new(0, 17, 0)
	part(
		parent,
		"LampPost",
		Vector3.new(0.8, 17, 0.8),
		CFrame.new(base + Vector3.new(0, 8.5, 0)),
		DARK,
		Enum.Material.Metal
	)
	part(parent, "LampBeam", Vector3.new(0.5, 0.5, 32), CFrame.lookAt(top, top + n), DARK, Enum.Material.Metal)
	for _, s in { -1, 1 } do
		local head = part(
			parent,
			"LampHead",
			Vector3.new(2.2, 0.4, 1.4),
			CFrame.lookAt(top + n * 14 * s - Vector3.new(0, 0.3, 0), top + n * 15 * s - Vector3.new(0, 0.3, 0)),
			LAMP_COLOR,
			Enum.Material.Neon,
			{ CanCollide = false }
		)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Range = 55
		spot.Angle = 120
		spot.Brightness = 3
		spot.Color = LAMP_COLOR
		spot.Shadows = false
		spot.Parent = head
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Streets
------------------------------------------------------------------------------------------------------------------------

local function inDowntown(x, z)
	return math.abs(x) <= 252 and math.abs(z) <= 252
end

local function buildStreets(parent, props)
	local roads = folder(parent, "Roads")
	local stops = {}
	for _, s in STREETS do
		stops[s] = {}
	end
	local junctions = {}
	for _, ew in STREETS do
		if ew.dir == "EW" then
			for _, ns in STREETS do
				if ns.dir == "NS" and ns.c >= ew.a and ns.c <= ew.b and ew.c >= ns.a and ew.c <= ns.b then
					table.insert(junctions, Vector3.new(ns.c, 0, ew.c))
					table.insert(stops[ew], ns.c)
					table.insert(stops[ns], ew.c)
				end
			end
		end
	end
	for _, j in junctions do
		part(
			roads,
			"Junction",
			Vector3.new(ROAD, ROAD_THICK, ROAD),
			CFrame.new(j.X, ROAD_THICK / 2, j.Z),
			ASPHALT,
			Enum.Material.Asphalt
		)
	end

	local function piece(s, from, to)
		local len = to - from
		if len < 0.5 then
			return
		end
		local mid = (from + to) / 2
		local ew = s.dir == "EW"
		part(
			roads,
			"Road",
			ew and Vector3.new(len, ROAD_THICK, ROAD) or Vector3.new(ROAD, ROAD_THICK, len),
			CFrame.new(ew and Vector3.new(mid, ROAD_THICK / 2, s.c) or Vector3.new(s.c, ROAD_THICK / 2, mid)),
			ASPHALT,
			Enum.Material.Asphalt
		)
		if len >= 20 then
			local n = math.floor((len - 8) / 16) + 1
			for i = 1, n do
				local t = mid + (i - (n + 1) / 2) * 16
				part(
					roads,
					"Line",
					ew and Vector3.new(8, 0.05, 0.5) or Vector3.new(0.5, 0.05, 8),
					CFrame.new(ew and Vector3.new(t, 0.225, s.c) or Vector3.new(s.c, 0.225, t)),
					YELLOW,
					Enum.Material.SmoothPlastic,
					{ CanCollide = false }
				)
			end
		end
		-- Streetlights: one at each end of a piece on alternating sides, plus extras on long runs.
		if len >= 30 then
			local spots = { { from + 5, 1 }, { to - 5, -1 } }
			for k = 1, math.floor(len / 90) do
				table.insert(spots, { from + len * k / (math.floor(len / 90) + 1), k % 2 == 0 and 1 or -1 })
			end
			for _, spot in spots do
				local t, side = spot[1], spot[2]
				local offset = (HALF + 1.5) * side
				local base = ew and Vector3.new(t, 0, s.c + offset) or Vector3.new(s.c + offset, 0, t)
				local toRoad = ew and Vector3.new(0, 0, -side) or Vector3.new(-side, 0, 0)
				local lit = inDowntown(base.X, base.Z) or math.abs(t) % 180 < 20
				lamp(props, base, toRoad, lit)
			end
		end
	end

	for _, s in STREETS do
		table.sort(stops[s])
		local from = s.a
		for _, p in stops[s] do
			piece(s, from, p - HALF)
			from = p + HALF
		end
		piece(s, from, s.b)
	end
	return roads
end

------------------------------------------------------------------------------------------------------------------------
-- Highway
------------------------------------------------------------------------------------------------------------------------

-- A ribbon following the highway at a lateral offset from its centerline (positive is outward).
local function ribbon(parent, name, offset, width, y0, height, color, material, props, opts)
	opts = opts or {}
	if opts.straights ~= false then
		local gap = opts.gap
		local spans = gap and { { -STRAIGHT, -gap }, { gap, STRAIGHT } } or { { -STRAIGHT, STRAIGHT } }
		for _, side in SIDES do
			for _, span in spans do
				local mid = (span[1] + span[2]) / 2
				local pos = side.n * (HIGHWAY_C + offset) + side.t * mid + Vector3.new(0, y0 + height / 2, 0)
				part(
					parent,
					name,
					Vector3.new(width, height, span[2] - span[1]),
					CFrame.lookAt(pos, pos + side.t),
					color,
					material,
					props
				)
			end
		end
	end
	local radius = HIGHWAY_R + offset
	local step = math.rad(90 / ARC_STEPS)
	for _, corner in CORNERS do
		for i = 0, ARC_STEPS - 1 do
			local a = math.rad(corner.a0) + i * step
			local pa = corner.center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius
			local pb = corner.center + Vector3.new(math.cos(a + step), 0, math.sin(a + step)) * radius
			local mid = (pa + pb) / 2 + Vector3.new(0, y0 + height / 2, 0)
			local len = (pb - pa).Magnitude + width * math.tan(step / 2) + 0.2
			part(
				parent,
				name,
				Vector3.new(width, height, len),
				CFrame.lookAt(mid, mid + (pb - pa).Unit),
				color,
				material,
				props
			)
		end
	end
end

local function buildHighway(parent, props)
	local hw = folder(parent, "Highway")
	ribbon(hw, "Road", 0, HIGHWAY_W, 0, ROAD_THICK, ASPHALT, Enum.Material.Asphalt)
	ribbon(hw, "Median", 0, 8, ROAD_THICK, 0.05, rgb(120, 120, 122), Enum.Material.Concrete, { CanCollide = false })
	ribbon(hw, "Barrier", 0, 1.6, ROAD_THICK, 2.6, rgb(190, 188, 182), Enum.Material.Concrete, nil, { gap = 26 })
	local noCollide = { CanCollide = false }
	for _, o in { -27, 27 } do
		ribbon(hw, "Line", o, 0.6, ROAD_THICK, 0.05, WHITE, Enum.Material.SmoothPlastic, noCollide)
	end
	for _, o in { -16, 16 } do
		ribbon(
			hw,
			"Line",
			o,
			0.5,
			ROAD_THICK,
			0.05,
			WHITE,
			Enum.Material.SmoothPlastic,
			noCollide,
			{ straights = false }
		)
		for _, side in SIDES do
			for u = -330, 330, 20 do
				if math.abs(u) > 24 then
					local pos = side.n * (HIGHWAY_C + o) + side.t * u + Vector3.new(0, 0.225, 0)
					part(
						hw,
						"Line",
						Vector3.new(0.5, 0.05, 8),
						CFrame.lookAt(pos, pos + side.t),
						WHITE,
						Enum.Material.SmoothPlastic,
						noCollide
					)
				end
			end
		end
	end
	for _, side in SIDES do
		for u = -315, 315, 70 do
			if math.abs(u) > 30 then
				highwayLamp(props, side.n * HIGHWAY_C + side.t * u, side.n)
			end
		end
	end
	for _, corner in CORNERS do
		local a = math.rad(corner.a0 + 45)
		local radial = Vector3.new(math.cos(a), 0, math.sin(a))
		highwayLamp(props, corner.center + radial * HIGHWAY_R, radial)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Buildings
------------------------------------------------------------------------------------------------------------------------

local DOWNTOWN_COLORS = {
	rgb(150, 85, 70),
	rgb(190, 180, 160),
	rgb(95, 105, 120),
	rgb(170, 130, 95),
	rgb(120, 125, 110),
	rgb(80, 90, 105),
}
local STOREFRONTS = { rgb(200, 155, 95), rgb(170, 200, 225), rgb(225, 170, 150) }

local function faceStrip(parent, name, cx, y, cz, w, d, face, span, height, color, material, props)
	local half = face.alongX and d / 2 or w / 2
	local pos = Vector3.new(cx, y, cz) + face.n * (half + 0.15)
	return part(parent, name, Vector3.new(span, height, 0.3), CFrame.lookAt(pos, pos + face.n), color, material, props)
end

local function tower(parent, rng, cx, cz, w, d, h, color)
	local m = model(parent, "Building")
	local material = rng:NextNumber() < 0.4 and Enum.Material.Brick or Enum.Material.Concrete
	part(m, "Shell", Vector3.new(w, h, d), CFrame.new(cx, PAD_TOP + h / 2, cz), color, material)
	part(
		m,
		"Roof",
		Vector3.new(w + 1, 1, d + 1),
		CFrame.new(cx, PAD_TOP + h + 0.5, cz),
		rgb(60, 60, 65),
		Enum.Material.Concrete
	)
	local floors = math.floor(h / 10)
	local storefront = pick(rng, STOREFRONTS)
	for _, face in FACES do
		local span = (face.alongX and w or d) - 6
		faceStrip(m, "Storefront", cx, PAD_TOP + 3.5, cz, w, d, face, span, 5, storefront, Enum.Material.Neon, {
			CanCollide = false,
		})
		for floor = 1, floors - 1 do
			local lit = rng:NextNumber() < 0.4
			faceStrip(
				m,
				"Windows",
				cx,
				PAD_TOP + floor * 10 + 2,
				cz,
				w,
				d,
				face,
				span,
				3.2,
				lit and WARM or DARK_GLASS,
				lit and Enum.Material.Neon or Enum.Material.Glass,
				{ CanCollide = false, Reflectance = lit and 0 or 0.2 }
			)
		end
	end
	part(
		m,
		"Vent",
		Vector3.new(6, 3, 6),
		CFrame.new(cx + rng:NextNumber(-w / 4, w / 4), PAD_TOP + h + 2.5, cz + rng:NextNumber(-d / 4, d / 4)),
		rgb(110, 112, 118),
		Enum.Material.Metal
	)
	if h > 70 then
		part(
			m,
			"Crown",
			Vector3.new(w * 0.6, 12, d * 0.6),
			CFrame.new(cx, PAD_TOP + h + 7, cz),
			rgb(75, 85, 100),
			Enum.Material.Concrete
		)
		part(m, "Antenna", Vector3.new(0.6, 16, 0.6), CFrame.new(cx, PAD_TOP + h + 20, cz), DARK, Enum.Material.Metal)
		part(
			m,
			"Beacon",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(cx, PAD_TOP + h + 28.5, cz),
			rgb(255, 60, 40),
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball, CanCollide = false }
		)
	end
end

local function bench(parent, x, z, yaw)
	local frame = CFrame.new(x, PAD_TOP, z) * CFrame.Angles(0, yaw, 0)
	local wood = rgb(120, 85, 55)
	part(parent, "Seat", Vector3.new(6, 0.5, 2), frame * CFrame.new(0, 1.6, 0), wood, Enum.Material.Wood)
	part(parent, "Back", Vector3.new(6, 1.8, 0.4), frame * CFrame.new(0, 2.7, -0.9), wood, Enum.Material.Wood)
	for _, s in { -2.5, 2.5 } do
		part(parent, "Leg", Vector3.new(0.4, 1.4, 1.6), frame * CFrame.new(s, 0.9, 0), DARK, Enum.Material.Metal)
	end
end

local function townSquare(parent, props, cx, cz)
	local rng = Random.new(11)
	slab(
		parent,
		"Pad",
		cx - 48,
		cx + 48,
		cz - 48,
		cz + 48,
		PAD_TOP,
		PAD_TOP,
		rgb(205, 200, 188),
		Enum.Material.Concrete
	)
	local stone = rgb(185, 182, 172)
	cylinder(parent, "Basin", 26, 1.4, CFrame.new(cx, PAD_TOP + 0.7, cz), stone, Enum.Material.Concrete)
	cylinder(parent, "Water", 22, 0.3, CFrame.new(cx, PAD_TOP + 1.5, cz), rgb(90, 170, 225), Enum.Material.Glass, {
		Transparency = 0.25,
		CanCollide = false,
	})
	cylinder(parent, "Column", 3, 5, CFrame.new(cx, PAD_TOP + 3.9, cz), stone, Enum.Material.Concrete)
	cylinder(parent, "Bowl", 9, 0.8, CFrame.new(cx, PAD_TOP + 6.6, cz), stone, Enum.Material.Concrete)
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		bench(parent, cx + math.cos(a) * 24, cz + math.sin(a) * 24, -a + math.pi / 2)
	end
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		tree(props, rng, cx + corner[1] * 38, cz + corner[2] * 38, PAD_TOP, 1)
		lamp(
			props,
			Vector3.new(cx + corner[1] * 30, PAD_TOP, cz + corner[2] * 30),
			Vector3.new(-corner[1], 0, -corner[2]),
			true
		)
	end
end

local function downtownBlock(parent, cx, cz)
	local rng = Random.new(math.floor(cx * 7 + cz * 13) + 5)
	slab(parent, "Pad", cx - 48, cx + 48, cz - 48, cz + 48, PAD_TOP, PAD_TOP, CONCRETE, Enum.Material.Concrete)
	local variant = rng:NextInteger(1, 3)
	if variant == 1 then
		tower(
			parent,
			rng,
			cx,
			cz,
			rng:NextInteger(70, 82),
			rng:NextInteger(70, 82),
			pick(rng, { 70, 85, 100, 115 }),
			pick(rng, DOWNTOWN_COLORS)
		)
	elseif variant == 2 then
		local alongX = rng:NextNumber() < 0.5
		for _, s in { -1, 1 } do
			local h = pick(rng, { 45, 55, 65, 85 })
			local color = pick(rng, DOWNTOWN_COLORS)
			if alongX then
				tower(parent, rng, cx + s * 22, cz, 40, 84, h, color)
			else
				tower(parent, rng, cx, cz + s * 22, 84, 40, h, color)
			end
		end
	else
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				tower(
					parent,
					rng,
					cx + sx * 22,
					cz + sz * 22,
					40,
					40,
					pick(rng, { 30, 40, 50, 60 }),
					pick(rng, DOWNTOWN_COLORS)
				)
			end
		end
	end
end

-- Pads around a shop plot: the plot itself fills the middle, and its apron is the sidewalk on the street side.
local function shopBlock(parent, cx, cz)
	local back = cz > 0 and 1 or -1
	slab(parent, "Pad", cx - 48, cx - 40, cz - 48, cz + 48, PAD_TOP, PAD_TOP, CONCRETE, Enum.Material.Concrete)
	slab(parent, "Pad", cx + 40, cx + 48, cz - 48, cz + 48, PAD_TOP, PAD_TOP, CONCRETE, Enum.Material.Concrete)
	local z0, z1 = cz + back * 40, cz + back * 48
	slab(
		parent,
		"Pad",
		cx - 40,
		cx + 40,
		math.min(z0, z1),
		math.max(z0, z1),
		PAD_TOP,
		PAD_TOP,
		CONCRETE,
		Enum.Material.Concrete
	)
end

------------------------------------------------------------------------------------------------------------------------
-- Suburbs
------------------------------------------------------------------------------------------------------------------------

local HOUSE_WALLS = {
	rgb(232, 220, 190),
	rgb(190, 210, 225),
	rgb(215, 215, 210),
	rgb(240, 210, 150),
	rgb(205, 130, 105),
	rgb(170, 200, 170),
}
local HOUSE_ROOFS = { rgb(90, 62, 50), rgb(70, 78, 90), rgb(130, 70, 55), rgb(60, 60, 64) }

local function house(parent, rng, pos, front)
	local frame = CFrame.lookAt(pos, pos + front)
	local function at(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	local m = model(parent, "House")
	if placeKit(m, "House", frame * CFrame.new(0, LAWN_TOP, 0)) then
		return
	end
	local wall = pick(rng, HOUSE_WALLS)
	local roof = pick(rng, HOUSE_ROOFS)
	local top = LAWN_TOP + 9
	part(m, "Body", Vector3.new(22, 9, 16), at(0, LAWN_TOP + 4.5, 0), wall)
	wedge(m, "Roof", Vector3.new(24, 5, 8.8), at(0, top + 2.5, -4.4), roof, Enum.Material.Slate)
	wedge(
		m,
		"Roof",
		Vector3.new(24, 5, 8.8),
		at(0, top + 2.5, 4.4) * CFrame.Angles(0, math.pi, 0),
		roof,
		Enum.Material.Slate
	)
	part(
		m,
		"Door",
		Vector3.new(3.6, 6.4, 0.3),
		at(0, LAWN_TOP + 3.2, -8.1),
		pick(rng, { rgb(120, 60, 45), rgb(50, 80, 120), rgb(60, 100, 70) })
	)
	for _, x in { -6.5, 6.5 } do
		local lit = rng:NextNumber() < 0.4
		part(
			m,
			"Window",
			Vector3.new(4.4, 3.6, 0.3),
			at(x, LAWN_TOP + 5.2, -8.1),
			lit and WARM or DARK_GLASS,
			lit and Enum.Material.Neon or Enum.Material.Glass,
			{ CanCollide = false }
		)
	end
	for _, x in { -11.1, 11.1 } do
		part(
			m,
			"Window",
			Vector3.new(0.3, 3.6, 4.4),
			at(x, LAWN_TOP + 5.2, 0),
			DARK_GLASS,
			Enum.Material.Glass,
			{ CanCollide = false }
		)
	end
	part(m, "Chimney", Vector3.new(2.4, 7, 2.4), at(7, top + 3.5, 1.5), rgb(130, 90, 75), Enum.Material.Brick)
	part(m, "Porch", Vector3.new(6, 0.4, 3), at(0, LAWN_TOP + 0.2, -9.5), CONCRETE, Enum.Material.Concrete)
	part(
		m,
		"Driveway",
		Vector3.new(6, 0.1, 8.4),
		at(-6.5, LAWN_TOP + 0.05, -12.2),
		rgb(120, 120, 122),
		Enum.Material.Concrete,
		{
			CanCollide = false,
		}
	)
end

local function suburbBlock(parent, props, cx, cz)
	local rng = Random.new(math.floor(cx * 5 + cz * 3) + 77)
	slab(parent, "Pad", cx - 48, cx + 48, cz - 48, cz + 48, PAD_TOP, PAD_TOP, CONCRETE, Enum.Material.Concrete)
	slab(parent, "Lawn", cx - 43, cx + 43, cz - 43, cz + 43, LAWN_TOP, 0.1, LAWN, Enum.Material.Grass)
	local lots = {}
	for _, x in { -30, 0, 30 } do
		table.insert(lots, { Vector3.new(cx + x, 0, cz + 27), Vector3.new(0, 0, 1) })
		table.insert(lots, { Vector3.new(cx + x, 0, cz - 27), Vector3.new(0, 0, -1) })
	end
	table.insert(lots, { Vector3.new(cx + 27, 0, cz), Vector3.new(1, 0, 0) })
	table.insert(lots, { Vector3.new(cx - 27, 0, cz), Vector3.new(-1, 0, 0) })
	for _, lot in lots do
		house(parent, rng, Vector3.new(lot[1].X, 0, lot[1].Z), lot[2])
		local frame = CFrame.lookAt(lot[1], lot[1] + lot[2])
		local spot = (frame * CFrame.new(15, 0, -11)).Position
		if math.abs(spot.X - cx) < 40 and math.abs(spot.Z - cz) < 40 then
			tree(props, rng, spot.X, spot.Z, LAWN_TOP, nil)
		end
	end
	if rng:NextNumber() < 0.5 then
		slab(
			parent,
			"Pool",
			cx - 7,
			cx + 7,
			cz - 4,
			cz + 4,
			LAWN_TOP + 0.1,
			0.12,
			rgb(80, 175, 225),
			Enum.Material.Glass,
			{
				CanCollide = false,
				Transparency = 0.2,
			}
		)
	end
	for _, p in { { -10, 10 }, { 10, -10 }, { 12, 10 } } do
		tree(props, rng, cx + p[1], cz + p[2], LAWN_TOP, nil)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Industrial district and junkyard
------------------------------------------------------------------------------------------------------------------------

local INDUSTRIAL_PAD = rgb(140, 140, 135)
local CONTAINER_COLORS = {
	rgb(180, 55, 45),
	rgb(50, 95, 160),
	rgb(45, 130, 120),
	rgb(215, 140, 50),
	rgb(200, 200, 195),
	rgb(95, 110, 60),
}

local function warehouse(parent, rng, cx, cz, front)
	local frame = CFrame.lookAt(Vector3.new(cx, 0, cz), Vector3.new(cx, 0, cz) + front)
	local function at(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	local m = model(parent, "Warehouse")
	local wall = pick(rng, { rgb(150, 160, 170), rgb(190, 175, 140), rgb(130, 150, 140) })
	part(m, "Body", Vector3.new(80, 22, 60), at(0, PAD_TOP + 11, 0), wall, Enum.Material.CorrodedMetal)
	part(m, "Roof", Vector3.new(82, 1, 62), at(0, PAD_TOP + 22.5, 0), rgb(85, 88, 95), Enum.Material.Metal)
	part(
		m,
		"Stripe",
		Vector3.new(80.4, 2.4, 60.4),
		at(0, PAD_TOP + 16, 0),
		pick(rng, { rgb(200, 70, 50), rgb(60, 100, 170) })
	)
	for _, x in { -27, -9, 9, 27 } do
		part(m, "RollDoor", Vector3.new(12, 14, 0.4), at(x, PAD_TOP + 7, -30.15), rgb(70, 72, 78), Enum.Material.Metal)
		part(
			m,
			"DockLight",
			Vector3.new(1, 0.5, 0.4),
			at(x, PAD_TOP + 15.4, -30.2),
			WARM,
			Enum.Material.Neon,
			{ CanCollide = false }
		)
	end
	for i = -1, 1 do
		cylinder(m, "RoofVent", 4, 3, at(i * 22, PAD_TOP + 24.5, 6), rgb(110, 112, 118), Enum.Material.Metal)
	end
	for i = 1, 5 do
		part(
			m,
			"Crate",
			Vector3.new(4, 3.5, 4),
			at(-34 + i * 11 + rng:NextNumber(-2, 2), PAD_TOP + 1.75, -36),
			rgb(150, 115, 75),
			Enum.Material.Wood
		)
	end
end

local function containerYard(parent, rng, cx, cz)
	local m = model(parent, "ContainerYard")
	for _, x in { -30, 0, 30 } do
		for row = -3, 3 do
			local stack = rng:NextInteger(1, 3)
			if rng:NextNumber() < 0.85 then
				for level = 1, stack do
					part(
						m,
						"Container",
						Vector3.new(20, 8, 8),
						CFrame.new(cx + x, PAD_TOP + 4 + (level - 1) * 8, cz + row * 12),
						pick(rng, CONTAINER_COLORS),
						Enum.Material.CorrodedMetal
					)
				end
			end
		end
	end
	local yellow = rgb(235, 190, 40)
	for _, sx in { -45, 45 } do
		for _, sz in { -2, 2 } do
			part(
				m,
				"GantryLeg",
				Vector3.new(2, 36, 2),
				CFrame.new(cx + sx, PAD_TOP + 18, cz + sz * 18),
				yellow,
				Enum.Material.Metal
			)
		end
	end
	part(m, "GantryBeam", Vector3.new(92, 3, 3), CFrame.new(cx, PAD_TOP + 37, cz - 36), yellow, Enum.Material.Metal)
	part(m, "GantryBeam", Vector3.new(92, 3, 3), CFrame.new(cx, PAD_TOP + 37, cz + 36), yellow, Enum.Material.Metal)
end

local function factory(parent, rng, cx, cz)
	local m = model(parent, "Factory")
	part(
		m,
		"Hall",
		Vector3.new(60, 22, 44),
		CFrame.new(cx - 14, PAD_TOP + 11, cz - 18),
		rgb(150, 110, 90),
		Enum.Material.Brick
	)
	part(
		m,
		"Roof",
		Vector3.new(62, 1, 46),
		CFrame.new(cx - 14, PAD_TOP + 22.5, cz - 18),
		rgb(80, 80, 85),
		Enum.Material.Metal
	)
	for i = -2, 2 do
		part(
			m,
			"Saw",
			Vector3.new(10, 6, 44),
			CFrame.new(cx - 14 + i * 12, PAD_TOP + 26, cz - 18),
			rgb(95, 95, 100),
			Enum.Material.Metal
		)
		part(
			m,
			"SawGlass",
			Vector3.new(0.3, 5, 40),
			CFrame.new(cx - 14 + i * 12 + 5.1, PAD_TOP + 26, cz - 18),
			WARM,
			Enum.Material.Neon,
			{
				CanCollide = false,
			}
		)
	end
	for i = 0, 2 do
		cylinder(
			m,
			"Stack",
			6,
			20,
			CFrame.new(cx + 22, PAD_TOP + 10 + i * 20, cz + 26),
			i % 2 == 0 and rgb(200, 60, 45) or rgb(235, 235, 230),
			Enum.Material.Concrete
		)
	end
	part(
		m,
		"Beacon",
		Vector3.new(2, 2, 2),
		CFrame.new(cx + 22, PAD_TOP + 62, cz + 26),
		rgb(255, 60, 40),
		Enum.Material.Neon,
		{
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		}
	)
	for i, x in { -28, -8 } do
		cylinder(m, "Silo", 14, 32, CFrame.new(cx + x, PAD_TOP + 16, cz + 30), rgb(190, 190, 185), Enum.Material.Metal)
		part(
			m,
			"SiloDome",
			Vector3.new(14, 14, 14),
			CFrame.new(cx + x, PAD_TOP + 32, cz + 30),
			rgb(170, 170, 165),
			Enum.Material.Metal,
			{
				Shape = Enum.PartType.Ball,
			}
		)
		cylinder(
			m,
			"Pipe",
			2,
			20,
			CFrame.new(cx + x, PAD_TOP + 8 + i, cz + 14) * CFrame.Angles(math.pi / 2, 0, 0),
			rgb(120, 125, 130),
			Enum.Material.Metal
		)
	end
	for _ = 1, 4 do
		cylinder(
			m,
			"Barrel",
			2.4,
			3.4,
			CFrame.new(cx + 34 + rng:NextNumber(-2, 2), PAD_TOP + 1.7, cz - 30 + rng:NextNumber(-6, 6)),
			pick(rng, { rgb(180, 50, 40), rgb(50, 90, 170) }),
			Enum.Material.Metal
		)
	end
end

local function tankFarm(parent, cx, cz)
	local m = model(parent, "TankFarm")
	local steel = rgb(205, 208, 212)
	for _, sx in { -24, 24 } do
		for _, sz in { -24, 24 } do
			cylinder(m, "Tank", 30, 22, CFrame.new(cx + sx, PAD_TOP + 11, cz + sz), steel, Enum.Material.Metal)
			cylinder(
				m,
				"TankCap",
				30.6,
				1,
				CFrame.new(cx + sx, PAD_TOP + 22.5, cz + sz),
				rgb(150, 155, 160),
				Enum.Material.Metal
			)
			part(
				m,
				"Ladder",
				Vector3.new(0.6, 22, 2),
				CFrame.new(cx + sx + (sx > 0 and -15 or 15), PAD_TOP + 11, cz + sz),
				DARK,
				Enum.Material.Metal
			)
		end
	end
	part(m, "PipeRack", Vector3.new(2, 2, 72), CFrame.new(cx, PAD_TOP + 5, cz), rgb(190, 60, 45), Enum.Material.Metal)
	part(
		m,
		"PipeRack",
		Vector3.new(72, 2, 2),
		CFrame.new(cx, PAD_TOP + 6.5, cz),
		rgb(200, 170, 50),
		Enum.Material.Metal
	)
	for _, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(
			m,
			"RackPost",
			Vector3.new(1.2, 6, 1.2),
			CFrame.new(cx + p[1] * 36, PAD_TOP + 3, cz),
			DARK,
			Enum.Material.Metal
		)
		part(
			m,
			"RackPost",
			Vector3.new(1.2, 6, 1.2),
			CFrame.new(cx, PAD_TOP + 3, cz + p[2] * 36),
			DARK,
			Enum.Material.Metal
		)
	end
end

local function industrialBlock(parent, cx, cz)
	local rng = Random.new(math.floor(cz * 3) + 191)
	slab(parent, "Pad", cx - 48, cx + 48, cz - 48, cz + 48, PAD_TOP, PAD_TOP, INDUSTRIAL_PAD, Enum.Material.Concrete)
	if cz == 300 then
		factory(parent, rng, cx, cz)
	elseif cz == 180 then
		warehouse(parent, rng, cx, cz, Vector3.new(-1, 0, 0))
	elseif cz == 60 then
		containerYard(parent, rng, cx, cz)
	else
		tankFarm(parent, cx, cz)
	end
end

local function wreck(parent, rng, x, level, z, yaw)
	local rust =
		pick(rng, { rgb(140, 85, 55), rgb(120, 120, 118), rgb(95, 110, 130), rgb(150, 60, 50), rgb(175, 160, 120) })
	local frame = CFrame.new(x, PAD_TOP + level * 3.6, z) * CFrame.Angles(0, yaw, 0)
	if placeKit(parent, "WreckCar", frame, nil, rust) then
		return
	end
	part(parent, "Wreck", Vector3.new(6, 2.4, 12.5), frame * CFrame.new(0, 1.2, 0), rust, Enum.Material.CorrodedMetal)
	part(
		parent,
		"WreckCabin",
		Vector3.new(5, 2, 6),
		frame * CFrame.new(0, 3.4, 0.8),
		rust:Lerp(DARK, 0.4),
		Enum.Material.CorrodedMetal
	)
end

-- Fenced scrapyard filling the two southeast blocks (x 252..348, z -348..-132); the gate faces North Street.
local function junkyard(parent, props)
	local rng = Random.new(404)
	local x0, x1, z0, z1 = 252, 348, -348, -132
	slab(parent, "Ground", x0, x1, z0, z1, PAD_TOP, PAD_TOP, rgb(95, 80, 62), Enum.Material.Ground)
	-- The fence sits just inside the lot so posts never reach into the streets around it.
	local fx0, fx1, fz0, fz1 = x0 + 1.5, x1 - 1.5, z0 + 1.5, z1 - 1.5
	local fence = rgb(150, 155, 160)
	local function fenceRun(ax, az, bx, bz)
		local a, b = Vector3.new(ax, 0, az), Vector3.new(bx, 0, bz)
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		part(
			parent,
			"Fence",
			Vector3.new(len, 7, 0.3),
			CFrame.lookAt(
				mid + Vector3.new(0, PAD_TOP + 3.5, 0),
				mid + Vector3.new(0, PAD_TOP + 3.5, 0) + (b - a).Unit:Cross(Vector3.yAxis)
			),
			fence,
			Enum.Material.Metal,
			{ Transparency = 0.45 }
		)
		for i = 0, math.floor(len / 12) do
			local p = a + (b - a).Unit * math.min(i * 12, len)
			part(
				parent,
				"FencePost",
				Vector3.new(0.8, 8, 0.8),
				CFrame.new(p.X, PAD_TOP + 4, p.Z),
				DARK,
				Enum.Material.Metal
			)
		end
	end
	fenceRun(fx0, fz0, fx1, fz0)
	fenceRun(fx0, fz0, fx0, fz1)
	fenceRun(fx1, fz0, fx1, fz1)
	fenceRun(fx0, fz1, 288, fz1)
	fenceRun(312, fz1, fx1, fz1)
	-- Gate arch and sign.
	for _, x in { 288, 312 } do
		part(
			parent,
			"GatePost",
			Vector3.new(2, 14, 2),
			CFrame.new(x, PAD_TOP + 7, fz1),
			rgb(180, 140, 40),
			Enum.Material.Metal
		)
	end
	sign(
		parent,
		CFrame.lookAt(Vector3.new(300, PAD_TOP + 12.5, fz1), Vector3.new(300, PAD_TOP + 12.5, fz1 + 1)),
		Vector3.new(26, 4, 1),
		"JUNKYARD",
		rgb(40, 40, 44),
		rgb(255, 190, 50)
	)
	-- Office shed by the gate.
	part(
		parent,
		"Office",
		Vector3.new(16, 10, 12),
		CFrame.new(268, PAD_TOP + 5, -146),
		rgb(110, 120, 130),
		Enum.Material.Metal
	)
	part(
		parent,
		"OfficeRoof",
		Vector3.new(17, 0.8, 13),
		CFrame.new(268, PAD_TOP + 10.4, -146),
		rgb(70, 72, 78),
		Enum.Material.Metal
	)
	part(
		parent,
		"OfficeWindow",
		Vector3.new(8, 3.4, 0.3),
		CFrame.new(276.1, PAD_TOP + 6, -146) * CFrame.Angles(0, math.pi / 2, 0),
		WARM,
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	-- Wreck stacks along both sides of the central aisle.
	for _, x in { 266, 334 } do
		for i = 0, 12 do
			local z = -162 - i * 14
			if not (x == 266 and z > -180) then
				for level = 0, rng:NextInteger(0, 2) do
					wreck(parent, rng, x + rng:NextNumber(-2, 2), level, z, rng:NextNumber(-0.15, 0.15))
				end
			end
		end
	end
	for _ = 1, 10 do
		local x = rng:NextNumber(284, 316)
		local z = rng:NextNumber(-340, -220)
		part(
			parent,
			"Scrap",
			Vector3.new(rng:NextNumber(2, 6), rng:NextNumber(0.5, 2), rng:NextNumber(2, 6)),
			CFrame.new(x, PAD_TOP + 0.5, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
			rgb(110, 90, 75),
			Enum.Material.CorrodedMetal
		)
	end
	for _ = 1, 6 do
		cylinder(
			parent,
			"Tire",
			2.8,
			1,
			CFrame.new(rng:NextNumber(272, 328), PAD_TOP + 0.5, rng:NextNumber(-160, -150)) * CFrame.Angles(0, 0, 0),
			rgb(30, 30, 32),
			Enum.Material.SmoothPlastic
		)
	end
	-- Gantry crane over a car crusher at the back of the yard.
	local yellow = rgb(235, 190, 40)
	for _, x in { 284, 316 } do
		for _, z in { -316, -332 } do
			part(parent, "CraneLeg", Vector3.new(2, 28, 2), CFrame.new(x, PAD_TOP + 14, z), yellow, Enum.Material.Metal)
		end
	end
	part(
		parent,
		"CraneBeam",
		Vector3.new(38, 2.6, 2.6),
		CFrame.new(300, PAD_TOP + 29, -316),
		yellow,
		Enum.Material.Metal
	)
	part(
		parent,
		"CraneBeam",
		Vector3.new(38, 2.6, 2.6),
		CFrame.new(300, PAD_TOP + 29, -332),
		yellow,
		Enum.Material.Metal
	)
	part(
		parent,
		"CraneTrolley",
		Vector3.new(3, 2.6, 18),
		CFrame.new(300, PAD_TOP + 29, -324),
		yellow,
		Enum.Material.Metal
	)
	part(
		parent,
		"CraneCable",
		Vector3.new(0.4, 14, 0.4),
		CFrame.new(300, PAD_TOP + 21, -324),
		DARK,
		Enum.Material.Metal
	)
	cylinder(parent, "CraneMagnet", 8, 1.4, CFrame.new(300, PAD_TOP + 13.3, -324), DARK, Enum.Material.Metal)
	wreck(parent, rng, 300, 3.1, -324, 0.4)
	part(
		parent,
		"Crusher",
		Vector3.new(14, 7, 20),
		CFrame.new(300, PAD_TOP + 3.5, -324),
		rgb(70, 75, 85),
		Enum.Material.Metal
	)
	for _, p in { { 258, -222 }, { 342, -200 }, { 342, -300 }, { 258, -330 } } do
		tree(props, rng, p[1], p[2], PAD_TOP, 0.8)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Market Row (south retail strip)
------------------------------------------------------------------------------------------------------------------------

-- Block pad plus an asphalt parking lot inset from the sidewalk.
local function lotBlock(parent, cx, cz)
	slab(parent, "Pad", cx - 48, cx + 48, cz - 48, cz + 48, PAD_TOP, PAD_TOP, CONCRETE, Enum.Material.Concrete)
	slab(parent, "Lot", cx - 44, cx + 44, cz - 44, cz + 44, LAWN_TOP, 0.1, rgb(62, 64, 70), Enum.Material.Asphalt)
end

local function stalls(parent, rng, cx, zFrom, zTo, facing, fill)
	local mid = (zFrom + zTo) / 2
	for i = -5, 5 do
		part(
			parent,
			"StallLine",
			Vector3.new(0.4, 0.05, math.abs(zTo - zFrom)),
			CFrame.new(cx + i * 8, LAWN_TOP + 0.1, mid),
			WHITE,
			Enum.Material.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	for i = -5, 4 do
		if rng:NextNumber() < fill then
			parkedCar(parent, rng, cx + i * 8 + 4, mid, LAWN_TOP, facing + rng:NextNumber(-0.05, 0.05))
		end
	end
end

local function stripMall(parent, rng, cx, cz)
	lotBlock(parent, cx, cz)
	local m = model(parent, "StripMall")
	local fy = PAD_TOP + 5.5
	part(m, "Body", Vector3.new(84, 11, 24), CFrame.new(cx, fy, cz - 30), rgb(215, 205, 185), Enum.Material.Concrete)
	part(
		m,
		"Roof",
		Vector3.new(86, 1, 26),
		CFrame.new(cx, PAD_TOP + 11.5, cz - 30),
		rgb(80, 80, 85),
		Enum.Material.Concrete
	)
	local names = { "TIRES", "PIZZA", "COFFEE", "PARTS" }
	local colors = { rgb(200, 50, 40), rgb(230, 150, 40), rgb(60, 110, 70), rgb(50, 90, 170) }
	for i = 1, 4 do
		local x = cx - 42 + (i - 0.5) * 21
		local n = Vector3.new(0, 0, 1)
		part(
			m,
			"Storefront",
			Vector3.new(17, 6, 0.4),
			CFrame.new(x, PAD_TOP + 3.6, cz - 17.9),
			DARK_GLASS,
			Enum.Material.Glass,
			{ Reflectance = 0.2 }
		)
		sign(
			m,
			CFrame.lookAt(Vector3.new(x, PAD_TOP + 8.6, cz - 17.8), Vector3.new(x, PAD_TOP + 8.6, cz - 17.8) + n),
			Vector3.new(17, 3, 0.5),
			names[i],
			colors[i],
			rgb(255, 245, 225)
		)
		part(
			m,
			"Awning",
			Vector3.new(18, 0.4, 3),
			CFrame.new(x, PAD_TOP + 6.9, cz - 16.5),
			colors[i],
			Enum.Material.Fabric
		)
	end
	stalls(parent, rng, cx, cz - 15, cz - 1, math.pi, 0.55)
	stalls(parent, rng, cx, cz + 13, cz + 27, 0, 0.5)
end

local function gasStation(parent, props, rng, cx, cz)
	lotBlock(parent, cx, cz)
	local m = model(parent, "GasStation")
	part(
		m,
		"Kiosk",
		Vector3.new(24, 10, 12),
		CFrame.new(cx, PAD_TOP + 5, cz - 34),
		rgb(235, 235, 230),
		Enum.Material.Concrete
	)
	part(
		m,
		"KioskRoof",
		Vector3.new(26, 1, 14),
		CFrame.new(cx, PAD_TOP + 10.5, cz - 34),
		rgb(200, 50, 40),
		Enum.Material.Metal
	)
	part(
		m,
		"KioskWindow",
		Vector3.new(18, 4.5, 0.4),
		CFrame.new(cx, PAD_TOP + 5, cz - 27.9),
		WARM,
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	part(
		m,
		"Canopy",
		Vector3.new(38, 1.2, 22),
		CFrame.new(cx, PAD_TOP + 15, cz - 2),
		rgb(235, 235, 230),
		Enum.Material.Metal
	)
	part(
		m,
		"CanopyTrim",
		Vector3.new(38.4, 0.8, 22.4),
		CFrame.new(cx, PAD_TOP + 14.2, cz - 2),
		rgb(200, 50, 40),
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	for _, x in { -14, 14 } do
		for _, z in { -10, 6 } do
			part(
				m,
				"CanopyPost",
				Vector3.new(1.4, 14, 1.4),
				CFrame.new(cx + x, PAD_TOP + 7, cz + z),
				rgb(200, 200, 195),
				Enum.Material.Metal
			)
		end
	end
	for _, x in { -8, 8 } do
		part(
			m,
			"Pump",
			Vector3.new(2, 6, 1.6),
			CFrame.new(cx + x, PAD_TOP + 3, cz - 2),
			rgb(200, 50, 40),
			Enum.Material.Metal
		)
		part(
			m,
			"PumpScreen",
			Vector3.new(1.4, 1.6, 0.2),
			CFrame.new(cx + x, PAD_TOP + 4.6, cz - 2.9),
			WARM,
			Enum.Material.Neon,
			{ CanCollide = false }
		)
	end
	part(
		m,
		"PylonPole",
		Vector3.new(1.5, 24, 1.5),
		CFrame.new(cx + 36, PAD_TOP + 12, cz + 34),
		DARK,
		Enum.Material.Metal
	)
	sign(
		m,
		CFrame.lookAt(Vector3.new(cx + 36, PAD_TOP + 25, cz + 34), Vector3.new(cx + 36, PAD_TOP + 25, cz + 35)),
		Vector3.new(9, 6, 1),
		"GAS\n$2.49",
		rgb(30, 30, 34),
		rgb(255, 210, 60)
	)
	for _, p in { { -38, 36 }, { 38, -10 } } do
		tree(props, rng, cx + p[1], cz + p[2], LAWN_TOP, 0.9)
	end
	parkedCar(m, rng, cx - 8, cz + 14, LAWN_TOP, 0)
	parkedCar(m, rng, cx + 22, cz + 24, LAWN_TOP, math.pi)
end

local function dealership(parent, rng, cx, cz)
	lotBlock(parent, cx, cz)
	local m = model(parent, "Dealership")
	part(
		m,
		"Showroom",
		Vector3.new(56, 14, 28),
		CFrame.new(cx, PAD_TOP + 7, cz - 28),
		rgb(235, 235, 232),
		Enum.Material.Concrete
	)
	part(
		m,
		"Glass",
		Vector3.new(50, 10, 0.4),
		CFrame.new(cx, PAD_TOP + 6, cz - 13.9),
		rgb(150, 190, 215),
		Enum.Material.Glass,
		{ Transparency = 0.45 }
	)
	part(
		m,
		"Roof",
		Vector3.new(58, 1, 30),
		CFrame.new(cx, PAD_TOP + 14.5, cz - 28),
		rgb(60, 60, 66),
		Enum.Material.Concrete
	)
	sign(
		m,
		CFrame.lookAt(Vector3.new(cx, PAD_TOP + 18.5, cz - 14), Vector3.new(cx, PAD_TOP + 18.5, cz - 13)),
		Vector3.new(36, 6, 1),
		"AUTO SALES",
		rgb(30, 30, 36),
		rgb(255, 90, 60)
	)
	for i = -2, 2 do
		part(
			m,
			"Platform",
			Vector3.new(9, 0.6, 15),
			CFrame.new(cx + i * 15, LAWN_TOP + 0.4, cz + 2),
			rgb(200, 200, 195),
			Enum.Material.Concrete
		)
		parkedCar(m, rng, cx + i * 15, cz + 2, LAWN_TOP + 0.7, math.pi + rng:NextNumber(-0.2, 0.2))
		part(
			m,
			"PriceTag",
			Vector3.new(2.4, 1.2, 0.2),
			CFrame.new(cx + i * 15, LAWN_TOP + 3, cz + 9.5),
			rgb(255, 230, 80),
			Enum.Material.Neon,
			{ CanCollide = false }
		)
	end
	stalls(m, rng, cx, cz + 18, cz + 32, 0, 0.6)
end

local function dinerAndTires(parent, rng, cx, cz)
	lotBlock(parent, cx, cz)
	local m = model(parent, "DinerAndTires")
	local dx = cx - 22
	part(
		m,
		"Diner",
		Vector3.new(40, 11, 20),
		CFrame.new(dx, PAD_TOP + 5.5, cz - 30),
		rgb(225, 225, 220),
		Enum.Material.Metal
	)
	part(
		m,
		"DinerBand",
		Vector3.new(40.4, 2, 20.4),
		CFrame.new(dx, PAD_TOP + 8, cz - 30),
		rgb(200, 50, 40),
		Enum.Material.Metal
	)
	part(
		m,
		"DinerWindow",
		Vector3.new(34, 4, 0.4),
		CFrame.new(dx, PAD_TOP + 4.6, cz - 19.9),
		WARM,
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	part(
		m,
		"DinerRoof",
		Vector3.new(42, 1, 22),
		CFrame.new(dx, PAD_TOP + 11.5, cz - 30),
		rgb(70, 70, 76),
		Enum.Material.Metal
	)
	sign(
		m,
		CFrame.lookAt(Vector3.new(dx, PAD_TOP + 15, cz - 20), Vector3.new(dx, PAD_TOP + 15, cz - 19)),
		Vector3.new(20, 5, 1),
		"DINER",
		rgb(30, 30, 36),
		rgb(80, 230, 255)
	)
	local tx = cx + 30
	part(
		m,
		"TireShop",
		Vector3.new(26, 13, 24),
		CFrame.new(tx, PAD_TOP + 6.5, cz - 28),
		rgb(190, 190, 195),
		Enum.Material.Concrete
	)
	part(
		m,
		"TireRoof",
		Vector3.new(27, 1, 25),
		CFrame.new(tx, PAD_TOP + 13.5, cz - 28),
		rgb(60, 60, 66),
		Enum.Material.Concrete
	)
	for _, x in { -6, 6 } do
		part(
			m,
			"BayDoor",
			Vector3.new(10, 9, 0.4),
			CFrame.new(tx + x, PAD_TOP + 4.5, cz - 15.9),
			rgb(70, 72, 78),
			Enum.Material.Metal
		)
	end
	sign(
		m,
		CFrame.lookAt(Vector3.new(tx, PAD_TOP + 11, cz - 15.8), Vector3.new(tx, PAD_TOP + 11, cz - 14.8)),
		Vector3.new(18, 2.6, 0.5),
		"TIRE SHOP",
		rgb(220, 190, 40),
		DARK
	)
	for i = 0, 3 do
		cylinder(
			m,
			"Tire",
			3.2,
			1.2,
			CFrame.new(tx + 16, PAD_TOP + 0.6 + i * 1.2, cz - 14),
			rgb(30, 30, 32),
			Enum.Material.SmoothPlastic
		)
	end
	stalls(m, rng, cx, cz - 8, cz + 6, math.pi, 0.5)
end

local function marketBlock(parent, props, cx, cz)
	local rng = Random.new(math.floor(cx * 3) + 909)
	if cx == -180 then
		stripMall(parent, rng, cx, cz)
	elseif cx == -60 then
		gasStation(parent, props, rng, cx, cz)
	elseif cx == 60 then
		dealership(parent, rng, cx, cz)
	else
		dinerAndTires(parent, rng, cx, cz)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Greenfield Park (north)
------------------------------------------------------------------------------------------------------------------------

local function scatterTrees(parent, rng, cx, cz, halfX, halfZ, count, avoid)
	local placed = 0
	local tries = 0
	while placed < count and tries < count * 8 do
		tries += 1
		local x = cx + rng:NextNumber(-halfX, halfX)
		local z = cz + rng:NextNumber(-halfZ, halfZ)
		if not avoid(x, z) then
			tree(parent, rng, x, z, LAWN_TOP, nil)
			placed += 1
		end
	end
end

local function parkHalf(parent, props, cx, east)
	local cz = 300
	local rng = Random.new(east and 31 or 32)
	slab(parent, "Pad", cx - 108, cx + 108, cz - 48, cz + 48, PAD_TOP, PAD_TOP, CONCRETE, Enum.Material.Concrete)
	slab(parent, "Lawn", cx - 103, cx + 103, cz - 43, cz + 43, LAWN_TOP, 0.1, rgb(100, 150, 72), Enum.Material.Grass)
	local pathColor = rgb(200, 190, 170)
	local function path(x0, x1, z0, z1)
		slab(
			parent,
			"Path",
			x0,
			x1,
			z0,
			z1,
			LAWN_TOP + 0.05,
			0.1,
			pathColor,
			Enum.Material.Concrete,
			{ CanCollide = false }
		)
	end
	path(cx - 103, cx + 103, cz - 3, cz + 3)
	path(cx - 3, cx + 3, cz - 43, cz + 43)
	local avoid
	if east then
		local px, pz = cx + 40, cz + 12
		cylinder(
			parent,
			"PondEdge",
			50,
			0.3,
			CFrame.new(px, LAWN_TOP + 0.1, pz),
			rgb(215, 200, 160),
			Enum.Material.Sand,
			{ CanCollide = false }
		)
		cylinder(parent, "Pond", 44, 0.3, CFrame.new(px, LAWN_TOP + 0.2, pz), rgb(70, 150, 205), Enum.Material.Glass, {
			Transparency = 0.25,
			CanCollide = false,
		})
		-- Gazebo.
		local gx, gz = cx - 50, cz + 22
		slab(
			parent,
			"GazeboFloor",
			gx - 7,
			gx + 7,
			gz - 7,
			gz + 7,
			LAWN_TOP + 0.5,
			0.5,
			rgb(170, 140, 100),
			Enum.Material.WoodPlanks
		)
		for _, p in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
			part(
				parent,
				"GazeboPost",
				Vector3.new(0.8, 9, 0.8),
				CFrame.new(gx + p[1], LAWN_TOP + 5, gz + p[2]),
				rgb(235, 235, 230),
				Enum.Material.Wood
			)
		end
		part(
			parent,
			"GazeboRoof",
			Vector3.new(16, 1, 16),
			CFrame.new(gx, LAWN_TOP + 9.8, gz),
			rgb(130, 70, 55),
			Enum.Material.Slate
		)
		wedge(
			parent,
			"GazeboCap",
			Vector3.new(10, 3, 5),
			CFrame.new(gx, LAWN_TOP + 11.8, gz - 2.5),
			rgb(130, 70, 55),
			Enum.Material.Slate
		)
		wedge(
			parent,
			"GazeboCap",
			Vector3.new(10, 3, 5),
			CFrame.new(gx, LAWN_TOP + 11.8, gz + 2.5) * CFrame.Angles(0, math.pi, 0),
			rgb(130, 70, 55),
			Enum.Material.Slate
		)
		avoid = function(x, z)
			return (x - px) ^ 2 + (z - pz) ^ 2 < 32 ^ 2
				or math.abs(z - cz) < 6
				or math.abs(x - cx) < 6
				or (math.abs(x - gx) < 12 and math.abs(z - gz) < 12)
		end
	else
		-- Soccer pitch with goals.
		local fx, fz = cx - 20, cz
		slab(
			parent,
			"Pitch",
			fx - 40,
			fx + 40,
			fz - 24,
			fz + 24,
			LAWN_TOP + 0.05,
			0.1,
			rgb(70, 150, 70),
			Enum.Material.Grass,
			{ CanCollide = false }
		)
		local function line(x0, x1, z0, z1)
			slab(
				parent,
				"PitchLine",
				x0,
				x1,
				z0,
				z1,
				LAWN_TOP + 0.12,
				0.05,
				WHITE,
				Enum.Material.SmoothPlastic,
				{ CanCollide = false }
			)
		end
		line(fx - 40, fx + 40, fz - 24, fz - 23.6)
		line(fx - 40, fx + 40, fz + 23.6, fz + 24)
		line(fx - 40, fx - 39.6, fz - 24, fz + 24)
		line(fx + 39.6, fx + 40, fz - 24, fz + 24)
		line(fx - 0.2, fx + 0.2, fz - 24, fz + 24)
		for _, s in { -1, 1 } do
			for _, dz in { -4, 4 } do
				part(
					parent,
					"GoalPost",
					Vector3.new(0.5, 7, 0.5),
					CFrame.new(fx + s * 40, LAWN_TOP + 3.5, fz + dz),
					WHITE,
					Enum.Material.Metal
				)
			end
			part(
				parent,
				"GoalBar",
				Vector3.new(0.5, 0.5, 8.5),
				CFrame.new(fx + s * 40, LAWN_TOP + 7, fz),
				WHITE,
				Enum.Material.Metal
			)
		end
		-- Swing set.
		local sx, sz = cx + 70, cz - 20
		for _, dx in { -7, 7 } do
			part(
				parent,
				"SwingLeg",
				Vector3.new(0.6, 9, 0.6),
				CFrame.new(sx + dx, LAWN_TOP + 4.5, sz - 2) * CFrame.Angles(0.2, 0, 0),
				rgb(200, 60, 45),
				Enum.Material.Metal
			)
			part(
				parent,
				"SwingLeg",
				Vector3.new(0.6, 9, 0.6),
				CFrame.new(sx + dx, LAWN_TOP + 4.5, sz + 2) * CFrame.Angles(-0.2, 0, 0),
				rgb(200, 60, 45),
				Enum.Material.Metal
			)
		end
		part(
			parent,
			"SwingBeam",
			Vector3.new(16, 0.7, 0.7),
			CFrame.new(sx, LAWN_TOP + 9, sz),
			rgb(200, 60, 45),
			Enum.Material.Metal
		)
		for _, dx in { -3, 3 } do
			part(
				parent,
				"SwingSeat",
				Vector3.new(2, 0.3, 1),
				CFrame.new(sx + dx, LAWN_TOP + 2.2, sz),
				rgb(60, 110, 190),
				Enum.Material.Plastic
			)
		end
		avoid = function(x, z)
			return (math.abs(x - fx) < 46 and math.abs(z - fz) < 30)
				or math.abs(z - cz) < 6
				or math.abs(x - cx) < 6
				or (math.abs(x - sx) < 12 and math.abs(z - sz) < 8)
		end
	end
	scatterTrees(props, rng, cx, cz, 100, 40, 34, avoid)
	for _, s in { -1, 1 } do
		bench(parent, cx + s * 25, cz - 6.5, math.pi)
		bench(parent, cx + s * 25, cz + 6.5, 0)
	end
	for _, p in { { -60, 0 }, { 60, 0 } } do
		lamp(props, Vector3.new(cx + p[1], LAWN_TOP, cz + 4), Vector3.new(0, 0, -1), true)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Perimeter, boundary and validation
------------------------------------------------------------------------------------------------------------------------

local function perimeter(props)
	local rng = Random.new(2024)
	-- Strip between the perimeter road and the highway, and two tree rows beyond it.
	for _, side in SIDES do
		for t = -395, 395, 18 do
			if math.abs(t) > 22 then
				local d = 392 + rng:NextNumber(-4, 4)
				local pos = side.n * d + side.t * (t + rng:NextNumber(-3, 3))
				tree(props, rng, pos.X, pos.Z, 0, nil)
			end
		end
		for _, d in { 505, 535 } do
			for t = -560, 560, 24 do
				local pos = side.n * (d + rng:NextNumber(-6, 6)) + side.t * (t + rng:NextNumber(-6, 6))
				tree(props, rng, pos.X, pos.Z, 0, rng:NextNumber(1.1, 1.6))
			end
		end
	end
	local walls = folder(props, "Boundary")
	for _, side in SIDES do
		local pos = side.n * WALL_DIST + Vector3.new(0, 40, 0)
		part(
			walls,
			"Wall",
			Vector3.new(math.abs(side.t.X) * 1260 + 4, 80, math.abs(side.t.Z) * 1260 + 4),
			CFrame.new(pos),
			WHITE,
			nil,
			{ Transparency = 1, CanQuery = false, CanTouch = false }
		)
	end
end

local function onRoad(roads, point)
	for _, p in roads:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "Road" or p.Name == "Junction") then
			local o = p.CFrame:PointToObjectSpace(Vector3.new(point.X, p.Position.Y, point.Z))
			if math.abs(o.X) <= p.Size.X / 2 and math.abs(o.Z) <= p.Size.Z / 2 then
				return true
			end
		end
	end
	return false
end

-- Returns a list of problems: WorldData points or plot lane markers that are not on a built road.
function City.validate(map)
	local roads = map.Roads
	local problems = {}
	local worldData = require(ReplicatedStorage.RunAutoshop.WorldData:Clone())
	for i, v in worldData.TestDriveLoop do
		if not onRoad(roads, v) then
			table.insert(problems, "TestDriveLoop[" .. i .. "] is off the road")
		end
	end
	for i, spot in worldData.CalloutSpots do
		if not onRoad(roads, spot.Position) and not onRoad(map.Highway, spot.Position) then
			table.insert(problems, "CalloutSpots[" .. i .. "] (" .. spot.Name .. ") is off the road")
		end
	end
	for _, plot in map.Plots:GetChildren() do
		for _, name in { "In1", "In2", "Out2", "Out3" } do
			if not onRoad(roads, plot.Markers[name].Position) then
				table.insert(problems, plot.Name .. "." .. name .. " is off the road")
			end
		end
	end
	return problems
end

function City.build(map)
	created = 0
	local props = folder(map, "Props")
	buildStreets(map, props)
	buildHighway(map, props)

	local city = folder(map, "City")
	local districts = {}
	local function district(name)
		districts[name] = districts[name] or folder(city, name)
		return districts[name]
	end

	for _, cx in CENTERS do
		for _, cz in CENTERS do
			if cx < -252 then
				suburbBlock(district("MapleHeights"), props, cx, cz)
			elseif cx > 252 then
				if cz == -180 or cz == -300 then
					if cz == -300 then
						junkyard(district("Junkyard"), props)
					end
				else
					industrialBlock(district("FoundryFlats"), cx, cz)
				end
			elseif cz < -252 then
				marketBlock(district("MarketRow"), props, cx, cz)
			elseif cz > 252 then
				if cx == -180 or cx == 60 then
					parkHalf(district("GreenfieldPark"), props, cx == 60 and 120 or -120, cx == 60)
				end
			elseif math.abs(cx) == 60 and math.abs(cz) == 60 then
				shopBlock(district("Downtown"), cx, cz)
			elseif cx == -180 and cz == 60 then
				townSquare(district("Downtown"), props, cx, cz)
			else
				downtownBlock(district("Downtown"), cx, cz)
			end
		end
	end
	perimeter(props)
	return created
end

return City

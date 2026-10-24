local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)

local routes = {}

local Route = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function send(player, route)
	if not player.Parent then
		return
	end
	if not route then
		Remotes.RouteState:FireClient(player, nil)
		return
	end
	local parking = route.index > #route.points
	Remotes.RouteState:FireClient(player, {
		label = route.label,
		target = parking and route.park.position or route.points[route.index],
		parking = parking,
		index = route.index,
		total = #route.points + 1,
		timeLeft = route.deadline - os.clock(),
	})
end

local function finish(player, route, success)
	if routes[player] ~= route then
		return
	end
	routes[player] = nil
	send(player, nil)
	route.onEnd(success, math.max(route.deadline - os.clock(), 0))
end

-- opts: label, root, seat, points, park = { position, radius, maxSpeed }, radius, timeLimit, outOfCarLimit, onEnd(success, timeLeft)
function Route.start(player, opts)
	Route.cancel(player)
	local route = {
		label = opts.label,
		points = opts.points,
		park = opts.park,
		index = 1,
		deadline = os.clock() + opts.timeLimit,
		onEnd = opts.onEnd,
	}
	routes[player] = route
	send(player, route)

	task.spawn(function()
		local outSince = nil
		local lastSync = os.clock()
		while routes[player] == route do
			task.wait(0.1)
			if routes[player] ~= route then
				return
			end
			local now = os.clock()
			local occupant = opts.seat.Occupant
			local driving = occupant and Players:GetPlayerFromCharacter(occupant.Parent) == player
			if not opts.root.Parent or now > route.deadline then
				finish(player, route, false)
				return
			end
			if driving then
				outSince = nil
			else
				outSince = outSince or now
				if now - outSince > opts.outOfCarLimit then
					finish(player, route, false)
					return
				end
			end

			local position = opts.root.Position
			if route.index <= #route.points then
				if (flat(position) - flat(route.points[route.index])).Magnitude <= opts.radius then
					route.index += 1
					send(player, route)
				end
			elseif
				(flat(position) - flat(route.park.position)).Magnitude <= route.park.radius
				and opts.root.AssemblyLinearVelocity.Magnitude <= route.park.maxSpeed
			then
				finish(player, route, true)
				return
			end
			if now - lastSync > 1 then
				lastSync = now
				send(player, route)
			end
		end
	end)
end

function Route.cancel(player)
	if routes[player] then
		routes[player] = nil
		send(player, nil)
	end
end

function Route.init()
	Players.PlayerRemoving:Connect(function(player)
		routes[player] = nil
	end)
end

return Route

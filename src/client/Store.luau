local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Remotes = require(ReplicatedStorage.RunAutoshop.Remotes)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local scope = Fusion.scoped(Fusion)
local peek = Fusion.peek

-- Client-side view state; the server stays authoritative for everything here.
local Store = {
	scope = scope,
	money = scope:Value(player:GetAttribute("Money") or 0),
	attrs = scope:Value(player:GetAttributes()),
	job = scope:Value(nil),
	dent = scope:Value(nil),
	route = scope:Value(nil),
	offer = scope:Value(nil),
	call = scope:Value(nil),
	work = scope:Value(nil),
	panel = scope:Value(nil),
	result = scope:Value(nil),
	toasts = scope:Value({}),
	spin = scope:Value(nil),
	spinActive = scope:Value(false),
	clock = scope:Value(os.clock()),
}

local toastId = 0
function Store.toast(text, color)
	toastId += 1
	local id = toastId
	local list = table.clone(peek(Store.toasts))
	table.insert(list, { id = id, text = text, color = color })
	if #list > 4 then
		table.remove(list, 1)
	end
	Store.toasts:set(list)
	task.delay(3.5, function()
		local current = {}
		for _, toast in peek(Store.toasts) do
			if toast.id ~= id then
				table.insert(current, toast)
			end
		end
		Store.toasts:set(current)
	end)
end

function Store.togglePanel(name)
	Store.panel:set(peek(Store.panel) ~= name and name or nil)
end

player.AttributeChanged:Connect(function(name)
	if name == "Money" then
		Store.money:set(player:GetAttribute("Money") or 0)
	end
	Store.attrs:set(player:GetAttributes())
end)

Remotes.Notify.OnClientEvent:Connect(function(text)
	Store.toast(text)
end)
Remotes.JobUpdate.OnClientEvent:Connect(function(job)
	Store.job:set(job)
end)
Remotes.JobResult.OnClientEvent:Connect(function(result)
	result.at = os.clock()
	Store.result:set(result)
end)
Remotes.DentState.OnClientEvent:Connect(function(dent)
	local previous = peek(Store.dent)
	if dent and previous and dent.hits > previous.hits then
		Effects.shake(1.2, 0.15)
	end
	Store.dent:set(dent)
end)
Remotes.RouteState.OnClientEvent:Connect(function(route)
	local previous = peek(Store.route)
	if route and previous and route.index > previous.index then
		Effects.play("StepDone", 0.5)
	end
	if route then
		route.deadline = os.clock() + route.timeLeft
	end
	Store.route:set(route)
end)
Remotes.CalloutOffer.OnClientEvent:Connect(function(offer)
	if offer then
		offer.deadline = os.clock() + offer.timeLeft
		Effects.play("Horn", 0.3)
	end
	Store.offer:set(offer)
end)
Remotes.CalloutState.OnClientEvent:Connect(function(call)
	Store.call:set(call)
end)
Remotes.WorkState.OnClientEvent:Connect(function(work)
	Store.work:set(work)
	if work then
		Store.panel:set(work.kind == "garage" and "garage" or nil)
	end
end)
Remotes.OpenPanel.OnClientEvent:Connect(function(name)
	Store.panel:set(name)
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		Store.clock:set(os.clock())
	end
end)

return Store

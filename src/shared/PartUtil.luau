local PartUtil = {}

-- Welds don't move attached parts outside Workspace, so move every descendant part explicitly.
function PartUtil.place(part, cframe)
	local delta = cframe * part.CFrame:Inverse()
	for _, d in part:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
	part.CFrame = cframe
end

return PartUtil

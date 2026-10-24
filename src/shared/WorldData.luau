-- Owned by the World agent: map-dependent data that gameplay reads. Keep it in sync with tools/BuildMap.luau.
return {
	-- Test drives visit these in loop order, starting from the one nearest the shop.
	TestDriveLoop = {
		Vector3.new(-120, 0.2, -120),
		Vector3.new(120, 0.2, -120),
		Vector3.new(120, 0.2, 120),
		Vector3.new(-120, 0.2, 120),
	},

	-- Road shoulders for roadside call-outs; yaw in degrees is the broken-down car's heading.
	CalloutSpots = {
		{ Name = "South Street", Position = Vector3.new(-75, 0.2, -128), Yaw = 90 },
		{ Name = "South Street", Position = Vector3.new(70, 0.2, -128), Yaw = -90 },
		{ Name = "North Street", Position = Vector3.new(-60, 0.2, 128), Yaw = 90 },
		{ Name = "North Street", Position = Vector3.new(85, 0.2, 128), Yaw = -90 },
		{ Name = "West Avenue", Position = Vector3.new(-128, 0.2, -50), Yaw = 0 },
		{ Name = "West Avenue", Position = Vector3.new(-128, 0.2, 70), Yaw = 180 },
		{ Name = "East Avenue", Position = Vector3.new(128, 0.2, -80), Yaw = 0 },
		{ Name = "East Avenue", Position = Vector3.new(128, 0.2, 40), Yaw = 180 },
	},
}

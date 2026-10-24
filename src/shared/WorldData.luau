-- Owned by the World agent: map-dependent data that gameplay reads. Keep it in sync with tools/BuildCity.luau; BuildMap
-- warns when a point here is not on a built road.
-- +X is east and +Z is north. Traffic keeps right: yaw 0 faces -Z, 90 faces -X, 180 faces +Z, -90 faces +X.

local function spot(district, name, x, z, yaw)
	return { District = district, Name = name, Position = Vector3.new(x, 0.2, z), Yaw = yaw }
end

return {
	-- Test drives visit these in loop order, starting from the one nearest the shop: the downtown ring.
	TestDriveLoop = {
		Vector3.new(-120, 0.2, -120),
		Vector3.new(120, 0.2, -120),
		Vector3.new(120, 0.2, 120),
		Vector3.new(-120, 0.2, 120),
	},

	-- Road shoulders for roadside call-outs; yaw in degrees is the broken-down car's heading. District is optional
	-- extra data for filtering by distance or area.
	CalloutSpots = {
		spot("Downtown", "Main Street", -180, 8, -90),
		spot("Downtown", "Main Street", 180, -8, 90),
		spot("Downtown", "North Street", -60, 128, -90),
		spot("Downtown", "North Street", 80, 112, 90),
		spot("Downtown", "South Street", -80, -112, -90),
		spot("Downtown", "South Street", 70, -128, 90),
		spot("Downtown", "West Avenue", -112, 60, 0),
		spot("Downtown", "West Avenue", -128, -60, 180),
		spot("Downtown", "East Avenue", 128, 60, 0),
		spot("Downtown", "East Avenue", 112, -60, 180),
		spot("Downtown", "Center Boulevard", 8, 70, 0),
		spot("Downtown", "Center Boulevard", -8, -70, 180),
		spot("Downtown", "Park Avenue", -60, 248, -90),
		spot("Downtown", "Park Avenue", 90, 232, 90),
		spot("Downtown", "Market Street", -150, -232, -90),
		spot("Downtown", "Market Street", 100, -248, 90),

		spot("Maple Heights", "Main Street", -300, 8, -90),
		spot("Maple Heights", "North Street", -300, 128, -90),
		spot("Maple Heights", "South Street", -300, -128, 90),
		spot("Maple Heights", "Park Avenue", -300, 248, -90),
		spot("Maple Heights", "Market Street", -300, -232, -90),
		spot("Maple Heights", "Maple Avenue", -248, 180, 180),
		spot("Maple Heights", "West Perimeter", -352, 60, 0),
		spot("Maple Heights", "West Perimeter", -368, -60, 180),

		spot("Foundry Flats", "Main Street", 300, 8, -90),
		spot("Foundry Flats", "North Street", 330, 112, 90),
		spot("Foundry Flats", "Park Avenue", 300, 248, -90),
		spot("Foundry Flats", "South Street", 336, -128, 90),
		spot("Foundry Flats", "Foundry Road", 248, 180, 0),
		spot("Foundry Flats", "Foundry Road", 232, -60, 180),
		spot("Foundry Flats", "East Perimeter", 368, 60, 0),
		spot("Foundry Flats", "East Perimeter", 352, -180, 180),

		spot("Market Row", "South Perimeter", -180, -352, -90),
		spot("Market Row", "South Perimeter", 100, -368, 90),
		spot("Market Row", "West Avenue", -112, -300, 0),
		spot("Market Row", "East Avenue", 112, -300, 180),
		spot("Market Row", "Maple Avenue", -232, -300, 0),
		spot("Market Row", "Foundry Road", 232, -300, 180),

		spot("Greenfield Park", "North Perimeter", -100, 368, -90),
		spot("Greenfield Park", "North Perimeter", 150, 352, 90),
		spot("Greenfield Park", "Center Boulevard", 8, 300, 0),
		spot("Greenfield Park", "Center Boulevard", -8, 290, 180),

		spot("Highway", "Ring Highway", 474, 150, 0),
		spot("Highway", "Ring Highway", 426, -200, 180),
		spot("Highway", "Ring Highway", -474, -150, 180),
		spot("Highway", "Ring Highway", -426, 200, 0),
		spot("Highway", "Ring Highway", -150, 474, -90),
		spot("Highway", "Ring Highway", 200, 426, 90),
		spot("Highway", "Ring Highway", 150, -474, 90),
		spot("Highway", "Ring Highway", -200, -426, -90),
	},
}

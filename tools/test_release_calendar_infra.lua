-- Infrastructure events of the nj_event_calendar_1 mod (infra_events.tl) on a fake api.res with years from the game's
-- files: grouping by notification group / filter category, old versions replaced by namesakes, era templates,
-- placeholders and "never" years skipped, items available at the start skipped.
local root = arg[0]:match("^(.*)/tools/[^/]+$") or "."
package.path = root .. "/tools/?.lua;" .. package.path
local tlrun = require("tlrun")
local PATH = root .. "/mod/nj_event_calendar_1/content/gui/release_calendar/infra_events.tl"

local warnings = {}
log = { warning = function(s) warnings[#warnings + 1] = s end, message = function() end }
_ = function(s) return s end

local function av(from, to, group, sortKey)
	return { yearFrom = from, yearTo = to, notificationGroup = group or "", notificationSortKey = sortKey or 0 }
end
local function menu(cat)
	return { categories = cat and { { category = cat, order = 0 } } or {} }
end
local function desc(name, icon)
	return { name = name, icon = icon or (name .. ".tga") }
end
-- a repository over a list of resources: getAll() -> {id: name}, get(id)
local function rep(list)
	return {
		getAll = function()
			local all = {}
			for i, r in ipairs(list) do all[i] = r.resName or ("res" .. i) end
			return all
		end,
		get = function(id) return list[id] end,
	}
end
local function vector(list)
	return { size = function(self) return #list end, at = function(self, i) return list[i] end }
end

local STREET, TRACK = "STREET", "TRACK"
local streets = {
	{ roadType = STREET, menuCategory = menu("roads_small"), availability = av(0, 1940), description = desc("Small Street", "old_small") },
	{ roadType = STREET, menuCategory = menu("roads_small"), availability = av(1940, 0, "townNew", 2), description = desc("Small Street", "new_small"),
		cost = 50, maintenanceCost = 2, laneConfigs = { { speed = 1.5 }, { speed = 13.9 } } },
	{ roadType = STREET, menuCategory = menu("roads_large"), availability = av(1940, 0, "townNew", 1), description = desc("Large Street", "new_large") },
	{ roadType = STREET, menuCategory = menu("roads_highway"), availability = av(1940, 0, "highwayNew"), description = desc("Highway") },
	{ roadType = STREET, menuCategory = menu("roads_large"), availability = av(0, 1910), description = desc("Large Street with Tram") },
	-- not in the menu (airport runway): skipped
	{ roadType = STREET, menuCategory = menu(nil), availability = av(1925, 0), description = desc("Runway") },
	-- depot track: placeholder year
	{ roadType = TRACK, menuCategory = menu("tracks"), availability = av(100000, 0), description = desc("Depot Track") },
	{ roadType = TRACK, menuCategory = menu("tracks"), availability = av(1930, 0, "tracksStandard"), description = desc("Standard Track") },
	{ roadType = TRACK, menuCategory = menu("tracks"), availability = av(1930, 0, "tracksStandard"), description = desc("Standard Track with Catenary") },
}
local function template(from, to, cat, name)
	return { availability = av(from, to), menuCategory = menu(cat), desc = desc(name) }
end
local constructions = {
	{ resName = "depots/road/road_depot/road_depot.con", availability = av(0, 0), menuCategory = menu(nil), description = desc("Road Depot"),
		constructionTemplates_native = vector({ template(1900, 1940, "road_buildings", "Road Depot"), template(1940, 1980, "road_buildings", "Road Depot"), template(1980, 0, "road_buildings", "Road Depot") }) },
	{ resName = "depots/rail/rail_maint_station.con", availability = av(0, 0), menuCategory = menu(nil), description = desc("Rail Maintenance"),
		constructionTemplates_native = vector({ template(1850, 1940, "rail_buildings", "Rail Maintenance"), template(1940, 0, "rail_buildings", "Rail Maintenance") }) },
	{ resName = "street_construction/roundabout.con", availability = av(1960, 0, "roadConstructions"), menuCategory = menu("street_constructions"), costsYearProgression = true,
		description = { name = "Roundabout", icon = "rb.tga", previewIcon = "rb_preview.tga", description = "A roundabout.", attributes = { cost = { 120000, -1 }, maintenanceCost = { 3000, -1 } } } },
	{ resName = "stations/air/helipad.con", availability = av(1950, 0, "helicopterBuildings"), menuCategory = menu("air_buildings"), description = desc("Helipad") },
	-- assets and town buildings: not listed
	{ resName = "assets/bench.con", availability = av(1950, 0), menuCategory = menu("road_assets"), description = desc("Bench") },
	{ resName = "town/house.con", availability = av(1950, 0), menuCategory = menu("town_buildings_res"), description = desc("House") },
	-- a broken (modded) resource does not hide the others
	{ resName = "mods/broken.con", menuCategory = setmetatable({}, { __index = function() error("broken resource") end }), availability = av(1960, 0), description = desc("Broken") },
}
local bridges = {
	{ availability = av(0, 1970), description = desc("Trestle Bridge") },
	{ availability = av(0, 1970), description = desc("Trestle Bridge", "trestle_s") },
	{ availability = av(1940, 0), description = desc("Steel Bridge") },
	{ availability = av(1940, 0), description = desc("Suspension Bridge") },
	{ availability = av(-1, -1), description = desc("Placeholder") },
}
local tunnels = {
	{ availability = av(1970, 0), description = desc("Concrete Tunnel", "tunnel_b") },
	{ availability = av(1970, 0), description = desc("Concrete Tunnel", "tunnel_b_car") },
}
local crossings = {
	{ availability = av(1850, 1925), description = desc("Simple Crossing", "a_eu") },
	{ availability = av(1850, 1925), description = desc("Simple Crossing", "a_us") },
	{ availability = av(1925, 1975), description = desc("Crossing with Barriers") },
}
local lights = { { availability = av(1980, 0), description = desc("Type C") } }
local edges = {
	-- buildable until 4000: "never" ends
	{ availability = av(1940, 4000), menuCategory = menu("roads_tools"), desc = desc("Alley") },
}

local function setup()
	api = {
		type = { enum = { RoadType = { STREET = STREET, TRACK = TRACK } } },
		res = {
			streetTemplateRep = rep(streets), constructionRep = rep(constructions), metaConstructionRep = rep({}),
			bridgeTypeRep = rep(bridges), tunnelTypeRep = rep(tunnels), railroadCrossingTypeRep = rep(crossings),
			trafficLightTypeRep = rep(lights), edgeDecorationRep = rep(edges),
			getBaseConfig = function() return { trackCatenaryYearFrom = 1921, busLaneYearFrom = 1925 } end,
			genericRep = { find = function() return 1 end, get = function() return { data = { trafficLightYearFrom = 1925 } } end },
		},
	}
	ug_require = function(path)
		assert(path:find("param_util"), path)
		return { tramCatenaryYearFrom = 1910 }
	end
end

local function collect(startYear)
	setup()
	warnings = {}
	local entries = tlrun.load(PATH).collect(startYear)
	local byKey = {}
	for _, e in ipairs(entries) do
		local key = e.year .. " " .. e.kind .. " " .. e.category .. " " .. e.name
		assert(not byKey[key], "duplicate " .. key)
		byKey[key] = e
	end
	return byKey, entries
end

local function has(byKey, key)
	assert(byKey[key], "missing: " .. key)
	return byKey[key]
end
local function hasNot(byKey, prefix)
	for key in pairs(byKey) do
		assert(key:sub(1, #prefix) ~= prefix, "unexpected: " .. key)
	end
end

local e, all = collect(1850)
-- town roads of 1940: one entry for the group, first by sort key, all names as variants
local town = has(e, "1940 new road Large Street (+1)")
assert(#town.variants == 2 and town.variants[2] == "Small Street", "variants")
assert(#town.icons == 2, "icons")
-- details for the info window: one per variant name, street prices per km, the fastest lane
local small = town.details[2]
assert(#town.details == 2 and small.name == "Small Street" and small.yearFrom == 1940 and small.yearTo == 0, "town details")
assert(small.cost == 50000 and small.maintenanceCost == 2000 and small.costPerKm and small.speedLimit == 13.9, "street numbers")
local rb = has(e, "1960 new road Roundabout").details[1]
assert(rb.cost == 120000 and rb.maintenanceCost == 3000 and rb.yearProgression and not rb.costPerKm, "construction numbers")
assert(rb.previewIcon == "rb_preview.tga" and rb.description == "A roundabout.", "construction texts")
assert(has(e, "1921 milestone track Electrification (Catenary)").details[1].yearFrom == 1921, "milestone detail")
-- the old small street is replaced by its namesake: no "retire" row; the tram street (no namesake) does retire
hasNot(e, "1940 retire road")
has(e, "1910 retire road Large Street with Tram")
has(e, "1940 new road Highway")
has(e, "1940 new road Alley")
hasNot(e, "4000")
hasNot(e, "1925 new road Runway")
hasNot(e, "100000")
has(e, "1930 new track Standard Track (+1)")
-- depot era templates: new versions in 1900 (after the start), 1940, 1980; the older version ending the same year is
-- not listed separately; the rail maintenance station of 1850 is available at the start
has(e, "1900 new depot Road Depot")
has(e, "1940 new depot Rail Maintenance (+1)")
has(e, "1980 new depot Road Depot")
hasNot(e, "1940 retire depot")
-- available when the game starts: without a year of its own under the start year ("start"), with a year at that year
has(e, "1850 start bridge Trestle Bridge")
has(e, "1850 start road Large Street with Tram (+1)")
has(e, "1850 new depot Rail Maintenance")
has(e, "1850 new track Simple Crossing")
hasNot(e, "1850 start depot")
hasNot(e, "1850 start track")
hasNot(e, "1850 start bridge Placeholder")
hasNot(e, "1850 start road Runway")
has(e, "1950 new station Helipad")
hasNot(e, "1950 new road Bench")
-- bridges and tunnels: same names collapse, icons kept apart
has(e, "1940 new bridge Steel Bridge (+1)")
local trestle = has(e, "1970 retire bridge Trestle Bridge")
assert(#trestle.icons == 2 and #trestle.variants == 1, "trestle icons / variants")
has(e, "1970 new bridge Concrete Tunnel")
hasNot(e, "-1")
-- crossings change per era; the regional variants of one era are one row
has(e, "1925 retire track Simple Crossing")
has(e, "1925 new track Crossing with Barriers")
has(e, "1975 retire track Crossing with Barriers")
has(e, "1980 new road Traffic Lights: Type C")
-- base config switches
has(e, "1921 milestone track Electrification (Catenary)")
has(e, "1925 milestone road Bus Lane Tool")
has(e, "1910 milestone road Tram Track Catenary")
has(e, "1925 milestone road Traffic Lights")
assert(#warnings == 1 and warnings[1]:find("broken"), "one warning for the broken resource, got " .. #warnings)

e = collect(1950)
-- a later start: what appeared before it and is still there stays at its own year; what ended before it is gone
has(e, "1940 new bridge Steel Bridge (+1)")
has(e, "1940 new depot Rail Maintenance (+1)")
hasNot(e, "1910")
hasNot(e, "1940 retire")
hasNot(e, "1950 start road Large Street with Tram (+1)")
has(e, "1950 start bridge Trestle Bridge")
has(e, "1970 retire bridge Trestle Bridge")
has(e, "1980 new depot Road Depot")
hasNot(e, "1921")

print("ok: " .. #all .. " entries")

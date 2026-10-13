-- Infrastructure that becomes available or can no longer be built: roads and tracks (street templates), bridges,
-- tunnels, stations and depots (constructions, their era templates, meta constructions), railroad crossings,
-- traffic light types, edge decorations (alleys, barriers), and the year switches of the base config (track and tram
-- catenary, bus lanes, traffic lights). The sources of the game's own "now available" notifications
-- (game_mechanics/notifications/availability_notifications.script.tl), plus what the game does not announce:
-- bridges, tunnels, construction templates (e.g. the depot of a new era) and items that stop being buildable.
-- Items of one notification group (or, without a group, of one filter category) that change in the same year are
-- one entry with all their names as variants, like the game's notification lists them.

local param_util = ug_require "::/scripts/construction/param_util.tl" as ParamUtil

local infra_events : ReleaseCalendarInfra = {}

-- years from here on mean "never" (an alley is buildable until 4000); placeholders have -1 or 100000
local MAX_YEAR <const> = 3000

local record Item
	year : integer
	kind : string -- "new" | "retire" | "milestone"
	category : string
	group : string
	sortKey : integer
	name : string
	icon : string
	detail : ReleaseCalendarInfra.Detail
end

-- name, texts and pictures of a menu item; the menu's preview picture is the larger one
local function describe(desc : ModelMetadata.Description, fallback? : ModelMetadata.Description) : ReleaseCalendarInfra.Detail
	local d = desc or fallback
	if not d then
		return nil
	end
	local function field(key : string) : string
		local v = desc and (desc as {string : string})[key]
		if (not v or v == "") and fallback then
			v = (fallback as {string : string})[key]
		end
		return v ~= "" and v or nil
	end
	return { name = field("name"), description = field("description"), icon = field("icon"), previewIcon = field("previewIcon") }
end

-- construction menu attributes ({value, max}): cost, upkeep, noise, pollution
local function withAttributes(detail : ReleaseCalendarInfra.Detail, desc : ModelMetadata.Description) : ReleaseCalendarInfra.Detail
	local attrs = detail and desc and desc.attributes
	if attrs then
		local function first(key : string) : number
			local v = attrs[key]
			return v and v[1] and v[1] > 0 and v[1] or nil
		end
		detail.cost = first("cost")
		detail.maintenanceCost = first("maintenanceCost")
		detail.noise = first("noise")
		detail.pollution = first("pollution")
	end
	return detail
end

-- filter category (calendar_window CATEGORIES) by the construction menu category; nil: not listed (assets, tools of
-- other carriers, town buildings, industries …). Stations and depots share the "*_buildings" menu categories: depots
-- are told apart by the resource name (depots/…, *_maint_station)
local function categoryOfMenu(menu : ModelMetadata.MenuCategory, resName : string) : string
	local first = menu and menu.categories and menu.categories[1]
	local cat = first and first.category or nil
	if not cat or cat:match("_assets$") then
		return nil
	end
	if cat:match("_buildings$") then
		local res = (resName or ""):lower()
		return (res:find("depot") or res:find("maint_station")) and "depot" or "station"
	end
	if cat:match("^roads?_") or cat == "street_constructions" then
		return "road"
	end
	if cat == "tracks" or cat:match("^rail_") then
		return "track"
	end
	return nil
end

local function add(items : {Item}, startYear : integer, category : string, av : ModelMetadata.Availability, detail : ReleaseCalendarInfra.Detail, namePrefix? : string)
	if not category or not av or not detail or not detail.name then
		return
	end
	local name = (namePrefix or "") .. detail.name
	local icon = detail.icon
	local from = av.yearFrom or 0
	local to = av.yearTo or 0
	if from < 0 or from >= MAX_YEAR then
		return
	end
	local group = av.notificationGroup or ""
	local sortKey = av.notificationSortKey or 0
	detail.name = name
	detail.yearFrom = from
	detail.yearTo = to
	-- available when the game started (13.10.2026, user's rule): without a year of its own under the start year
	-- ("start"), with an earlier year at that year, as a past "new"
	local atStart = from <= startYear and (to <= 0 or to > startYear)
	if atStart and from <= 0 then
		items[#items + 1] = { year = startYear, kind = "start", category = category, group = group, sortKey = sortKey, name = name, icon = icon, detail = detail }
	elseif from > 0 and (from > startYear or atStart) then
		items[#items + 1] = { year = from, kind = "new", category = category, group = group, sortKey = sortKey, name = name, icon = icon, detail = detail }
	end
	if to > 0 and to >= startYear and to < MAX_YEAR then
		items[#items + 1] = { year = to, kind = "retire", category = category, group = group, sortKey = sortKey, name = name, icon = icon, detail = detail }
	end
end

-- every source in its own pcall: one broken (modded) resource must not hide the rest
local function each(label : string, fn : function())
	local ok, err = pcall(function() : boolean
		fn()
		return true
	end)
	if not ok then
		log.warning("release_calendar: infrastructure " .. label .. ": " .. tostring(err))
	end
end

local function collectItems(startYear : integer) : {Item}
	local items : {Item} = {}
	each("streets", function()
		for id, __ in pairs(api.res.streetTemplateRep.getAll()) do
			local st = api.res.streetTemplateRep.get(id)
			-- without a menu category the template is not buildable by the player (runways, entrances, depot tracks)
			if st and st.menuCategory and st.menuCategory.categories and #st.menuCategory.categories > 0 then
				local category = st.roadType == api.type["enum"].RoadType.TRACK and "track" or "road"
				local detail = describe(st.description)
				if detail then
					-- per metre in the template; the menu shows it per km (priceScale 1000, construction_react_util)
					detail.cost = st.cost and st.cost > 0 and st.cost * 1000 or nil
					detail.maintenanceCost = st.maintenanceCost and st.maintenanceCost > 0 and st.maintenanceCost * 1000 or nil
					detail.costPerKm = true
					local speed = 0.0
					for __, lane in ipairs(st.laneConfigs or {}) do
						speed = math.max(speed, lane.speed or 0)
					end
					detail.speedLimit = speed > 0 and speed or nil
				end
				add(items, startYear, category, st.availability, detail)
			end
		end
	end)
	each("constructions", function()
		for id, resName in pairs(api.res.constructionRep.getAll()) do
			each(resName, function()
				local desc = api.res.constructionRep.get(id)
				local templates = desc and desc.constructionTemplates_native
				local n = templates and templates:size() or 0
				if n == 0 then
					if desc then
						local detail = withAttributes(describe(desc.description), desc.description)
						if detail then
							detail.yearProgression = desc.costsYearProgression == true
						end
						add(items, startYear, categoryOfMenu(desc.menuCategory, resName), desc.availability, detail)
					end
				else
					-- era templates (depots: 1900-1940, 1940-1980, 1980-), as the construction menu lists them
					for i = 1, n do
						local t = templates:at(i)
						local av = t.availability or desc.availability
						local detail = withAttributes(describe(t.desc, desc.description), t.desc and t.desc.attributes and t.desc or desc.description)
						if detail then
							detail.yearProgression = desc.costsYearProgression == true
						end
						add(items, startYear, categoryOfMenu(t.menuCategory, resName), av, detail)
					end
				end
			end)
		end
	end)
	each("meta constructions", function()
		for id, resName in pairs(api.res.metaConstructionRep.getAll()) do
			local desc = api.res.metaConstructionRep.get(id)
			if desc then
				local detail = withAttributes(describe(desc.description), desc.description)
				if detail then
					-- the construction menu treats all meta constructions as following the year (costsYearProgression)
					detail.yearProgression = true
				end
				add(items, startYear, categoryOfMenu(desc.menuCategory, resName), desc.availability, detail)
			end
		end
	end)
	each("bridges", function()
		for id, __ in pairs(api.res.bridgeTypeRep.getAll()) do
			local b = api.res.bridgeTypeRep.get(id)
			local detail = describe(b.description)
			if detail then
				detail.speedLimit = b.speedLimit and b.speedLimit > 0 and b.speedLimit or nil
			end
			add(items, startYear, "bridge", b.availability, detail)
		end
	end)
	each("tunnels", function()
		for id, __ in pairs(api.res.tunnelTypeRep.getAll()) do
			local b = api.res.tunnelTypeRep.get(id)
			local detail = describe(b.description)
			if detail then
				detail.speedLimit = b.speedLimit and b.speedLimit > 0 and b.speedLimit or nil
			end
			add(items, startYear, "bridge", b.availability, detail)
		end
	end)
	each("railroad crossings", function()
		for id, __ in pairs(api.res.railroadCrossingTypeRep.getAll()) do
			local c = api.res.railroadCrossingTypeRep.get(id)
			local detail = describe(c.description)
			if detail then
				detail.speedLimit = c.speedLimit and c.speedLimit > 0 and c.speedLimit or nil
			end
			add(items, startYear, "track", c.availability, detail)
		end
	end)
	each("traffic lights", function()
		for id, __ in pairs(api.res.trafficLightTypeRep.getAll()) do
			local l = api.res.trafficLightTypeRep.get(id)
			-- type names alone ("Type C") say nothing
			add(items, startYear, "road", l.availability, describe(l.description), _("Traffic Lights") .. ": ")
		end
	end)
	each("edge decorations", function()
		for id, path in pairs(api.res.edgeDecorationRep.getAll()) do
			local d = api.res.edgeDecorationRep.get(id)
			add(items, startYear, categoryOfMenu(d.menuCategory, path), d.availability, describe(d.desc))
		end
	end)
	-- year switches of the base config; names are game strings (translated into all its languages)
	-- for the info window: the game's text and preview picture of the tool (construction/tools/*_tool.script.tl,
	-- notifications/types/con_availability.script.tl)
	local function milestone(year : integer, category : string, name : string, icon : string, description : string, preview : string)
		if year and year > startYear and year < MAX_YEAR then
			items[#items + 1] = { year = year, kind = "milestone", category = category, group = "", sortKey = 0, name = name, icon = icon,
				detail = { name = name, icon = icon, previewIcon = preview, description = description, yearFrom = year, yearTo = 0 } }
		end
	end
	each("base config", function()
		local base = api.res.getBaseConfig()
		milestone(base.trackCatenaryYearFrom, "track", _("Electrification") .. " (" .. _("Catenary") .. ")", "::/gui/game_bar/icons/infrastructure_tracks_30.tga",
			_("Upgrade tracks with catenary, enabling the use of electric trains."), "::/gui/construction/tools/electrify_preview.tga")
		milestone(base.busLaneYearFrom, "road", _("Bus Lane Tool"), "::/gui/game_bar/icons/infrastructure_street_30.tga",
			_("Upgrade roads with bus lanes, making them exclusive to buses and trucks."), "::/gui/construction/tools/bus_new_preview.tga")
	end)
	each("tram catenary", function()
		milestone(param_util.tramCatenaryYearFrom, "road", _("Tram Track Catenary"), "::/infrastructure/street/tram/tram_old_electrified.tga",
			_("The era of electric trams has arrived and the first vehicles are now available for purchase. New tram tracks will automatically include catenaries, while existing infrastructure can be easily modernized using the tram track tool."),
			"::/gui/construction/tools/tram_new_preview.tga")
	end)
	each("traffic light config", function()
		local res = api.res.genericRep.get(api.res.genericRep.find("::/infrastructure/traffic_light/traffic_light_config.res"))
		local config = res and res.data as TrafficLightConfig
		milestone(config and config.trafficLightYearFrom, "road", _("Traffic Lights"), "::/gui/construction/tools/traffic_light_control_new.tga",
			_("Crossings can now be equipped with traffic lights. These improve traffic flow, as their phases can be configured according to specific needs."),
			"::/gui/construction/tools/traffic_light_control_new_preview.tga")
	end)
	return items
end

local MAX_ICONS <const> = 3

infra_events.collect = function(startYear : integer) : {ReleaseCalendarInfra.Entry}
	local items = collectItems(startYear)
	-- an item that ends in the year a namesake of its category appears was replaced by a new version (old and new
	-- town roads, depots of the next era): only the new one is listed
	local appears : {string : boolean} = {}
	for __, it in ipairs(items) do
		if it.kind == "new" then
			appears[it.year .. "|" .. it.category .. "|" .. it.name] = true
		end
	end
	local groups : {string : {Item}} = {}
	local order : {string} = {}
	for __, it in ipairs(items) do
		if not (it.kind == "retire" and appears[it.year .. "|" .. it.category .. "|" .. it.name]) then
			-- base config switches stay single entries
			local key = it.year .. "|" .. it.kind .. "|" .. it.category .. "|" .. (it.kind == "milestone" and it.name or it.group)
			if not groups[key] then
				groups[key] = {}
				order[#order + 1] = key
			end
			table.insert(groups[key], it)
		end
	end
	local entries : {ReleaseCalendarInfra.Entry} = {}
	for __, key in ipairs(order) do
		local list = groups[key]
		table.sort(list, function(a : Item, b : Item) : boolean
			if a.sortKey ~= b.sortKey then
				return a.sortKey < b.sortKey
			end
			return a.name < b.name
		end)
		local variants : {string} = {}
		local details : {ReleaseCalendarInfra.Detail} = {}
		local icons : {string} = {}
		local seenName : {string : boolean} = {}
		local seenIcon : {string : boolean} = {}
		for __, it in ipairs(list) do
			-- variants for other carriers or climates often share the name (rail and road tunnels, crossings by region)
			if not seenName[it.name] then
				seenName[it.name] = true
				variants[#variants + 1] = it.name
				details[#details + 1] = it.detail
			end
			if it.icon and it.icon ~= "" and not seenIcon[it.icon] and #icons < MAX_ICONS then
				seenIcon[it.icon] = true
				icons[#icons + 1] = it.icon
			end
		end
		local first = list[1]
		entries[#entries + 1] = {
			year = first.year,
			kind = first.kind,
			category = first.category,
			name = #variants > 1 and string.format("%s (+%d)", variants[1], #variants - 1) or variants[1],
			variants = variants,
			details = details,
			icons = icons,
		}
	end
	log.message(string.format("release_calendar: infrastructure %d items, %d entries", #items, #entries))
	return entries
end

return infra_events

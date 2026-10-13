-- Event calendar window: everything that appeared in or left the store since the game started and will do so (vehicle models and multiple-unit
-- trains, by availability as in the vehicle store: vehicle_store_util.makeVehicleData; no time limit), infrastructure
-- that becomes available or stops being buildable (infra_events.tl) and base config milestones (construction costs by
-- year), with filters by type, engine and cargo class. Opened by the clock
-- button in the bottom bar (clock_plugin.script.tl). The game's own calendar window ("Weather and time") is a local recipe,
-- nothing can be added to it, hence a window of our own. Clicking a model shows the native store info (vehicle_details.tl).

local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local game_react_globals = ug_require "::/gui/main/game_react_globals.tl" as GameReactGlobals
local react = ug_require "::/gui/main/react.lua" as React
local vehicle_store_util = ug_require "::/gui/line_vehicle_mgmt/vehicle_store_util.tl" as VehicleStoreUtil
local vehicle_details = ug_require "/gui/release_calendar/vehicle_details.tl" as VehicleDetails
local i18n = ug_require "/gui/release_calendar/i18n.tl" as ReleaseCalendarI18n
local lang_util = ug_require "::/scripts/lang_util.tl" as LangUtil
local infra_events = ug_require "/gui/release_calendar/infra_events.tl" as ReleaseCalendarInfra
local info_cards = ug_require "/gui/release_calendar/info_cards.tl" as ReleaseCalendarInfoCards

local tr = i18n.tr

local WINDOW_ID = "relcal_events_window"

local record CargoClassInfo
	tag : string
	icon : string
	name : string
end

local record Event
	year : integer
	kind : string       -- "new" | "retire" | "milestone" | "start" (available when the game started, under its first year)
	name : string
	icon : string
	pictures : {string} -- small side views of the model (multiple unit: one per vehicle), as in the store list
	flips : {boolean}   -- mirrored pictures (reversed vehicles of a multiple unit)
	category : string  -- filter category (CATEGORIES)
	engine : string    -- engine types, short ("" when none: ships, aircraft, wagons)
	engines : {string : boolean} -- engine type keys (ENGINE_KEYS) for the filter
	classes : {CargoClassInfo} -- cargo specialization (cargo classes the vehicle loads)
	details : string   -- tooltip of rows without vehicle info: milestone note, infrastructure variants
	repId : integer    -- model / multiple unit (nil for milestones), for the info window on click
	infra : ReleaseCalendarInfra.Entry -- infrastructure entry, for its info window
	inflation : number -- inflation step: its factor, for the info window
	multipleUnit : boolean
	carrier : Carrier
end

-- carrier: metadata transportVehicle.carrier of the model, or of the first vehicle of a multiple unit
local function carrierOf(repId : integer, multipleUnit : boolean) : Carrier
	local ok, v = pcall(function() : VehicleStoreUtil.Vehicle
		if multipleUnit then
			return vehicle_store_util.makeMultipleVehicles(api.res.multipleUnitRep.get(repId))[1]
		end
		return vehicle_store_util.makeSingleVehicle(api.res.modelRep.get(repId))
	end)
	return ok and v and (v as VehicleStoreUtil.Vehicle).tv and (v as VehicleStoreUtil.Vehicle).tv.carrier or nil
end

-- filter categories, in the order of the filter buttons (a "|" between groups); tooltips are game strings where the
-- game has them
local record Category
	key : string
	group : string -- "vehicle" | "infra" | "other"
	icon : string
	tooltip : function() : string
end
local CATEGORIES : {Category} = {
	{ key = "bus", group = "vehicle", icon = "::/gui/statistics/icons/vehicle_bus_18.tga", tooltip = function() : string return _("Buses") end },
	{ key = "truck", group = "vehicle", icon = "::/gui/statistics/icons/vehicle_car.tga", tooltip = function() : string return _("Trucks") end },
	{ key = "tram", group = "vehicle", icon = "::/gui/statistics/icons/vehicle_tram_18.tga", tooltip = function() : string return _("Trams") end },
	{ key = "train", group = "vehicle", icon = "::/gui/statistics/icons/vehicle_train_18.tga", tooltip = function() : string return _("Trains") end },
	{ key = "ship", group = "vehicle", icon = "::/gui/statistics/icons/vehicle_ship_18.tga", tooltip = function() : string return _("Ships") end },
	{ key = "plane", group = "vehicle", icon = "::/gui/statistics/icons/vehicle_airplane_18.tga", tooltip = function() : string return _("Planes") end },
	{ key = "road", group = "infra", icon = "::/gui/game_bar/icons/infrastructure_street_30.tga", tooltip = function() : string return _("Roads") end },
	{ key = "track", group = "infra", icon = "::/gui/game_bar/icons/infrastructure_tracks_30.tga", tooltip = function() : string return _("Tracks") end },
	{ key = "bridge", group = "infra", icon = "::/gui/construction/menu/filter_categories/bridge.tga", tooltip = function() : string return _("Bridges") .. " / " .. _("Tunnels") end },
	{ key = "station", group = "infra", icon = "::/gui/game_bar/icons/statistics_station.tga", tooltip = function() : string return _("Stations") end },
	{ key = "depot", group = "infra", icon = "::/gui/game_bar/icons/statistics_depot.tga", tooltip = function() : string return _("Depots") end },
	{ key = "milestone", group = "other", icon = "::/gui/construction/menu/symbol_coin_stack.tga", tooltip = function() : string return tr("milestones") end },
}
local CATEGORY_ICON : {string : string} = {}
local CATEGORY_ORDER : {string : integer} = {}
for i, c in ipairs(CATEGORIES) do
	CATEGORY_ICON[c.key] = c.icon
	CATEGORY_ORDER[c.key] = i
end

-- road vehicles are split into buses (passengers only) and trucks
local function categoryOf(carrier : Carrier, vd : VehicleStoreUtil.VehicleData) : string
	local C = api.type["enum"].Carrier
	if carrier == C.WATER then return "ship" end
	if carrier == C.AIR then return "plane" end
	if carrier == C.TRAM then return "tram" end
	if carrier == C.RAIL then return "train" end
	if vd.passengers and not vd.anyCargo then return "bus" end
	return "truck"
end

-- engine types of the model (a model can have several, e.g. bi-mode); icons are the mod's own
-- (icons/engine_*@2x.tga, drawn by tools/make_engine_icons.py)
local ENGINE_KEYS : {{VehicleEngineType, string}} = {
	{ api.type["enum"].VehicleEngineType.HORSE, "engine_horse" },
	{ api.type["enum"].VehicleEngineType.STEAM, "engine_steam" },
	{ api.type["enum"].VehicleEngineType.DIESEL, "engine_diesel" },
	{ api.type["enum"].VehicleEngineType.ELECTRIC, "engine_electric" },
}
local function engineIcon(key : string) : string
	return "nj_event_calendar_1::/gui/release_calendar/icons/" .. key .. ".tga"
end
local function engineText(vd : VehicleStoreUtil.VehicleData) : string, {string : boolean}
	local parts : {string} = {}
	local keys : {string : boolean} = {}
	for __, pair in ipairs(ENGINE_KEYS) do
		if vd.engines and vd.engines[pair[1]] then
			parts[#parts + 1] = tr(pair[2])
			keys[pair[2]] = true
		end
	end
	return table.concat(parts, " / "), keys
end

-- cargo classes with the game's icon and display name (api.res.cargoClassRep, like cargo_util)
local function cargoClasses(vd : VehicleStoreUtil.VehicleData) : {CargoClassInfo}
	local result : {CargoClassInfo} = {}
	for __, tag in ipairs(vd.cargoClasses or {}) do
		local id = api.res.cargoClassRep.getCargoClassId(tag)
		local cls = id and id ~= -1 and api.res.cargoClassRep.get(id as integer) or nil
		if cls and cls.icon and cls.icon ~= "" then
			result[#result + 1] = { tag = tag, icon = cls.icon, name = _(cls.name) }
		end
	end
	return result
end

-- filter selection by group: vehicle type (CATEGORIES keys), engine (ENGINE_KEYS keys), cargo class (tags).
-- Within a group any selected value matches; groups combine with AND; an empty group does not filter (like the
-- vanilla statistics filter). Kept for the session, so reopening the window keeps the filter
local record Selection
	types : {string : boolean}
	engines : {string : boolean}
	classes : {string : boolean}
	query : string -- search text: the event's name or one of its variants (like the vanilla statistics search)
end
local selection : Selection = { types = {}, engines = {}, classes = {}, query = "" }

local function matches(e : Event, sel : Selection) : boolean
	if sel.query and sel.query ~= "" and not (lang_util.stringContains(e.name, sel.query)
		or (e.details and e.details ~= "" and lang_util.stringContains(e.details, sel.query))) then
		return false
	end
	if next(sel.types) ~= nil and not sel.types[e.category] then
		return false
	end
	if next(sel.engines) ~= nil then
		local any = false
		for key, __ in pairs(e.engines) do
			any = any or sel.engines[key] == true
		end
		if not any then
			return false
		end
	end
	if next(sel.classes) ~= nil then
		local any = false
		for __, c in ipairs(e.classes) do
			any = any or sel.classes[c.tag] == true
		end
		if not any then
			return false
		end
	end
	return true
end

-- the group "available from the start" (no year of its own) at the very top of the list (13.10.2026, user's rule);
-- a year below any real one, so it sorts first
local START_GROUP_YEAR <const> = -1

local MAX_PICTURES <const> = 3 -- vehicles of a multiple unit shown in the picture column

-- events from the game's start on (past ones stay in the list), and what was available at the start: under its own
-- earlier year, or under the start year when it has none
local function collectEvents(startYear : integer) : {Event}
	local year = startYear
	local events : {Event} = {}
	local seen : {string : boolean} = {}
	local function add(repId : integer, multipleUnit : boolean)
		local ok, vdAny = pcall(vehicle_store_util.makeVehicleData, repId, multipleUnit)
		if not ok or not vdAny then
			return
		end
		local vd = vdAny as VehicleStoreUtil.VehicleData
		local okN, nameAny = pcall(vehicle_store_util.getVehicleNameAndIcons, repId, multipleUnit, true)
		local nameAndIcons = okN and nameAny and nameAny as VehicleStoreUtil.VehicleNameAndIcon or nil
		local name = nameAndIcons and nameAndIcons.name or tostring(repId)
		-- variants of one model (box / universal …) as one row, like in the store
		local key = (vd.variantGroup and vd.variantGroup ~= "") and vd.variantGroup or name
		local function make(kind : string, eventYear : integer) : Event -- only for listed entries: makeSingleVehicle is not free
			local carrier = carrierOf(repId, multipleUnit)
			local category = categoryOf(carrier, vd)
			local engine, engines = engineText(vd)
			local pictures : {string} = {}
			local flips : {boolean} = {}
			for i, path in ipairs(nameAndIcons and nameAndIcons.icons or {}) do
				if i <= MAX_PICTURES and path and path ~= "" then
					pictures[#pictures + 1] = path
					flips[#flips + 1] = nameAndIcons.iconOrientations[i] == true
				end
			end
			return { year = eventYear, kind = kind, name = name, icon = CATEGORY_ICON[category], category = category,
				pictures = pictures, flips = flips,
				engine = engine, engines = engines, classes = cargoClasses(vd), repId = repId, multipleUnit = multipleUnit, carrier = carrier }
		end
		-- In the store when the game started (13.10.2026, user's rule): without a year of its own under the start year
		-- ("start"), with an earlier year at that year, as a past release. Placeholder models of the game have the
		-- year 100000: not real events
		local from = vd.yearFrom or 0
		local to = vd.yearTo or 0
		local atStart = from <= year and (to <= 0 or to > year)
		if atStart and from <= 0 and not seen["start" .. key] then
			seen["start" .. key] = true
			events[#events + 1] = make("start", START_GROUP_YEAR)
		elseif from > 0 and from < 10000 and (from > year or atStart) and not seen["new" .. key] then
			seen["new" .. key] = true
			events[#events + 1] = make("new", from)
		end
		-- yearTo 0 or a huge year: never leaves the store
		if vd.yearTo and vd.yearTo > 0 and vd.yearTo >= year and vd.yearTo < 10000 and not seen["retire" .. key] then
			seen["retire" .. key] = true
			events[#events + 1] = make("retire", vd.yearTo)
		end
	end
	api.res.modelRep.forEachModelWithMetadata("transportVehicle", function(path : string)
		add(api.res.modelRep.find(path) as integer, false)
	end)
	for muId, __ in pairs(api.res.multipleUnitRep.getAll()) do
		add(muId as integer, true)
	end
	-- base config milestones
	local base = api.res.getBaseConfig()
	local mult = base and base.treeCostYearMultipliers or nil
	if mult then
		for y, m in pairs(mult) do
			if y > year then
				events[#events + 1] = { year = y, kind = "milestone", name = tr("cost_mult", { mult = string.format("%.1f", m) }),
					icon = "::/gui/construction/menu/symbol_coin_stack.tga", category = "milestone", pictures = {}, flips = {},
					engine = "", engines = {}, classes = {}, details = tr("cost_mult_note"), inflation = m }
			end
		end
	end
	-- infrastructure (the catenary switch is there too, under tracks); variants go to the name tooltip
	local okI, infraAny = pcall(infra_events.collect, year)
	if not okI then
		log.warning("release_calendar: infrastructure: " .. tostring(infraAny))
	end
	for __, entry in ipairs(okI and infraAny as {ReleaseCalendarInfra.Entry} or {}) do
		local flips : {boolean} = {}
		for i = 1, #entry.icons do
			flips[i] = false
		end
		events[#events + 1] = { year = entry.kind == "start" and START_GROUP_YEAR or entry.year, kind = entry.kind, name = entry.name, icon = CATEGORY_ICON[entry.category],
			category = entry.category, pictures = entry.icons, flips = flips, engine = "", engines = {}, classes = {},
			details = #entry.variants > 1 and table.concat(entry.variants, "\n") or "",
			infra = entry }
	end
	-- within a year: milestones, new, retiring; then by filter category (vehicles before infrastructure); then by name
	table.sort(events, function(a : Event, b : Event) : boolean
		if a.year ~= b.year then return a.year < b.year end
		if a.kind ~= b.kind then return a.kind < b.kind end
		local oa, ob = CATEGORY_ORDER[a.category] or 0, CATEGORY_ORDER[b.category] or 0
		if oa ~= ob then return oa < ob end
		return a.name < b.name
	end)
	return events
end

-- how much game time this is at the current calendar speed
local function gameTimeUntil(years : number) : string
	local speed = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED) as Engine.Component.GameSpeed
	if not speed or not speed.millisPerDay or speed.millisPerDay <= 0 then
		return ""
	end
	local seconds = math.floor(years * 365.25 * speed.millisPerDay / 1000)
	local h, m = math.floor(seconds / 3600), math.floor(seconds / 60) % 60
	return h > 0 and string.format("%d:%02d:%02d", h, m, seconds % 60) or string.format("%d:%02d", m, seconds % 60)
end

local function text(value : string, classes? : string, tooltip? : string) : TreeNodeId
	return builtin.TextView{
		meta = { class = "font-scale-body" .. (classes and (", " .. classes) or ""), tooltip = tooltip },
		text = value,
	}
end

-- ===== vehicle info: the native vehicle store block (copy in vehicle_details.tl) =====
local INFO_WINDOW_ID = "relcal_vehicle_info_window"

-- The vehicle info window opens to the right of the list window, top-aligned. Not bottom-aligned: the game places
-- a window by its height in the first frame, and that differs per model, so bottom-anchored info windows drifted
-- down by up to a quarter of the screen even with a fixed size (log 12.10.2026). The list window's top-right corner
-- is computed from where it was opened and its size in UI units (the wrapper's self ref is not the window: it
-- reported (0, 0)); fallback: the measured top-right corner of the list content.
local LIST_UNITS_H <const> = 688 -- Window!relcal-events-window height (release_calendar.css.lua)
-- the list takes the left half of the screen, the info window the right one, the gap is centered (13.10.2026)
local GAP_UNITS <const> = 20
local infoPlace : Vec2f = nil  -- top-left corner for the info window (screen fractions)
local listCorner : Vec2f = nil -- top-right of the list content (fallback)
local INFO_GAP <const> = 0.004
local infoWindowKey = 0
-- Top alignment with the list: the list window is compact (no title bar, the search in its place, like the vanilla
-- line manager), so the measured top of its content (listCorner) is the top of the window, and the info window's
-- point is the top of its frame (13.10.2026). Before, with a title bar, the card's content was aligned with the list
-- content minus the measured title bar of the card
local unitScale : Vec2f = nil -- screen fraction per UI unit (from toggle)

local function infoTopLeft() : Vec2f
	if infoPlace and listCorner and unitScale then
		return api.type.Vec2f.new(infoPlace.x, listCorner.y)
	end
	return infoPlace or (listCorner and api.type.Vec2f.new(listCorner.x + INFO_GAP, listCorner.y)) or nil
end

local record InfoParams
	place : Vec2f -- top-left corner of the info window (screen fractions); nil: near the screen bottom
	title : string
	-- one of: a vehicle (repId), an infrastructure entry, an inflation step (year + factor)
	repId : integer
	infra : ReleaseCalendarInfra.Entry
	inflationYear : integer
	inflation : number
	name : string -- for the log
	multipleUnit : boolean
	carrier : Carrier
	onClose : function()
end

-- The card appears a few frames after the window: the game places a window by its size in the first frame, before
-- the texts are laid out, and that size differed per model (log 13.10.2026: the content of trains with longer
-- descriptions landed 0.04 of the screen lower than requested, earlier windows jumped by up to half the screen). An
-- empty first frame is the same for every model; afterwards the window only grows down from its top-left corner.
local CARD_DELAY_STEPS <const> = 2
-- Scrolling: a default by card kind, corrected once by the card's own height (13.10.2026, user's rule). Vehicle and
-- inflation cards start without a scroll area, infrastructure cards with 3 variants or more start with one; a few
-- frames after it is shown the card measures itself (CardMeasure) and the mode switches if the default was wrong,
-- either way. The card is 588 wide in both modes, so its height is the same and the switch happens at most once. A
-- scroll area (only a maximum height, relcal-info-scroll) keeps a slot for its bar even with nothing to scroll, so
-- the card padding has less on the right there (relcal-info-scrolling). Always switching after measuring made
-- every window jump; showing long cards in full first made them jump past the list's height
local CARD_MAX_UNITS <const> = 624 -- the info window's bottom on the list's (relcal-info-scroll)
local SCROLL_DEFAULT_VARIANTS <const> = 3

local record CardMeasureParams
	content : TreeNodeId
	onHeight : function(number) -- screen fraction, once
end

local CardMeasure = react.RegisterRecipe("ReleaseCalendarCardMeasure", function(params : CardMeasureParams) : TreeNodeId
	local selfRef = react.useSelfRef()
	local stepsRef = react.useRef(0)
	react.onStep(function()
		local n = stepsRef:get() as integer
		stepsRef:set(n + 1)
		if n == 2 then
			local ok, h = pcall(function() : number
				local a, b = selfRef:get():getPosition(0.0, 0.0), selfRef:get():getPosition(1.0, 1.0)
				return b.y - a.y
			end)
			if ok and h then
				params.onHeight(h as number)
			end
		end
	end)
	return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = { params.content } }
end)

-- logs once where the info window ended up, next to the requested corner (windows opened at the requested point
-- but some drifted, 12.10.2026)
local InfoProbe = react.RegisterRecipe("ReleaseCalendarInfoProbe", function(params : InfoParams) : TreeNodeId
	local selfRef = react.useSelfRef()
	local stepsRef = react.useRef(0)
	local readyState = react.useState(false) as ReactStateT<boolean>
	local scrollState = react.useState(params.infra ~= nil and #(params.infra.details or {}) >= SCROLL_DEFAULT_VARIANTS) as ReactStateT<boolean>
	local switchedRef = react.useRef(false)
	react.onStep(function()
		local n = stepsRef:get() as integer
		stepsRef:set(n + 1)
		if n == CARD_DELAY_STEPS then
			readyState:set(true)
		end
		if n == 10 + CARD_DELAY_STEPS then
			pcall(function() : boolean
				local a, b = selfRef:get():getPosition(0.0, 0.0), selfRef:get():getPosition(1.0, 1.0)
				log.message(string.format("release_calendar: info window %s (%s): requested top-left %s, content (%.3f, %.3f)-(%.3f, %.3f); computed corner %s, content corner %s; scroll %s",
					tostring(params.repId), tostring(params.name), params.place and string.format("(%.3f, %.3f)", params.place.x, params.place.y) or "centered",
					a.x, a.y, b.x, b.y,
					infoPlace and string.format("(%.3f, %.3f)", infoPlace.x, infoPlace.y) or "nil",
					listCorner and string.format("(%.3f, %.3f)", listCorner.x, listCorner.y) or "nil",
					tostring(scrollState:old())))
				return true
			end)
		end
	end)
	-- the card is built only once shown: elements built but not attached are logged every frame ("Preserved props")
	local card : TreeNodeId = nil
	if readyState:old() then
		if params.infra then
			card = info_cards.Infra({ entry = params.infra })
		elseif params.inflation then
			card = info_cards.Inflation({ year = params.inflationYear, mult = params.inflation })
		else
			card = vehicle_details.Details({ repId = params.repId, multipleUnit = params.multipleUnit })
		end
	end
	local scroll = scrollState:old()
	if card then
		card = CardMeasure({ content = card, onHeight = function(h : number)
			if switchedRef:get() or not unitScale then
				return
			end
			local tall = h > CARD_MAX_UNITS * unitScale.y
			if tall ~= scrollState:old() then
				switchedRef:set(true)
				scrollState:set(tall)
			end
		end })
		if scroll then
			card = builtin.ScrollArea{
				meta = { class = "relcal-info-scroll" },
				horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
				verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
				content = builtin.Component{
					meta = { class = "relcal-info-scroll-content" },
					layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = { card } },
				},
			}
		end
	end
	-- width as the store's right column (rightColumnWidth 588, vehicle_store.css.lua): there the block stretches to
	-- the column, without it to the whole screen
	return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = {
		builtin.Component{
			meta = { class = scroll and "relcal-vehicle-info, relcal-info-scrolling" or "relcal-vehicle-info" },
			layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = card and { card } or {} },
		},
	} }
end)

local InfoWindow = react.RegisterWrapperRecipe("ReleaseCalendarVehicleInfoWindow", builtin.Window, function(params : InfoParams) : TreeNodeId
	return builtin.Window{
		id = INFO_WINDOW_ID,
		title = params.title,
		-- the class sets anchorPoint {0, 0}: the point below is the top-left corner, so the height does not move the
		-- window and it follows the content (13.10.2026: a fixed height of 640 left an empty half under short cards);
		-- long cards scroll (InfoProbe)
		meta = { class = "relcal-info-window" },
		closable = true,
		movable = true,
		initialX = params.place and params.place.x or 0.5,
		initialY = params.place and params.place.y or 0.9,
		onClose = params.onClose,
		content = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = { InfoProbe(params) } },
	}
end)

local function hasInfo(e : Event) : boolean
	return e.repId ~= nil or e.infra ~= nil or e.inflation ~= nil
end

local function categoryName(key : string) : string
	for __, c in ipairs(CATEGORIES) do
		if c.key == key then
			return c.tooltip()
		end
	end
	return ""
end

local function openInfo(e : Event)
	local container = game_react_globals.getDefaultWindowContainer()
	if not container or not container:get() then
		return
	end
	local windowApi = container:get():getApi()
	windowApi.removeAllWindows(InfoWindow)
	-- a new key for every click: addSingletonWindow reuses an open window and keeps showing the first model
	infoWindowKey = infoWindowKey + 1
	local key = "relcal_info_" .. tostring(infoWindowKey)
	windowApi.addWindow(InfoWindow, key, {
		place = infoTopLeft(),
		title = e.infra and categoryName(e.category) or (e.inflation and tr("inflation_title") or _("Vehicle")), -- game strings
		repId = e.repId,
		infra = e.infra,
		inflationYear = e.inflation and e.year or nil,
		inflation = e.inflation,
		name = e.name,
		multipleUnit = e.multipleUnit,
		carrier = e.carrier,
		-- only this window: the replaced window's onClose fires after the new one is added (12.10.2026: the new
		-- window flashed and closed when its onClose removed all info windows)
		onClose = function()
			windowApi.removeWindow(InfoWindow, key)
		end,
	})
end

local EventsContent = react.RegisterRecipe("ReleaseCalendarEventsContent", function() : TreeNodeId
	local gt = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME) as Engine.Component.GameTime
	local date = api.engine.util.getCalendarDate(gt.gameTime)
	local yearFraction = ((date.month - 1) + (date.day - 1) / 30.5) / 12
	-- game time 0 is the start of the game
	local startYear = math.min(api.engine.util.getCalendarDate(0).year, date.year)
	local eventsRef = react.useRefLazy(function() : {Event}
		return collectEvents(startYear)
	end) as ReactRefT<{Event}>
	-- on open, scroll so that the latest unlocked year (the last one up to the current year: its vehicles are
	-- already in the store) is at the top: first to the end of the list, then back up to that year's bar —
	-- ensureVisible scrolls just enough, so an element above the view ends up at its top
	local nowRef = react.useNodeRef()
	local endRef = react.useNodeRef()
	local scrollStepsRef = react.useRef(0)
	react.onStep(function()
		local n = scrollStepsRef:get() as integer
		if n > 5 then
			return
		end
		scrollStepsRef:set(n + 1)
		local target = n == 3 and endRef or (n == 5 and nowRef or nil)
		if target and target:get() then
			pcall(function() : boolean
				(target:get() as ReactNodeRefT<any>):ensureVisible() -- the type of useNodeRef() without a recipe has no ensureVisible; same object
				return true
			end)
		end
	end)
	local selfRef = react.useSelfRef()
	react.onStep(function()
		local ok, corner = pcall(function() : Vec2f return selfRef:get():getPosition(1.0, 0.0) end)
		listCorner = ok and corner or listCorner
	end)
	local filterState = react.useState(selection) as ReactStateT<Selection>
	local sel = filterState:old()
	-- filter buttons above the list, like the vanilla statistics filter (statistics_react_util.createCarrierCategoryFilter)
	local function groupOf(s2 : Selection, group : string) : {string : boolean}
		return group == "types" and s2.types or (group == "engines" and s2.engines or s2.classes)
	end
	local function toggle(group : string, key : string, content : TreeNodeId) : TreeNodeId
		return builtin.ToggleButton{
			meta = { class = "relcal-filter-button" },
			content = content,
			value = groupOf(sel, group)[key] and 1 or 0,
			onValueChange = function(value : integer)
				local old = filterState:old()
				local changed : {string : boolean} = {}
				for k, v in pairs(groupOf(old, group)) do
					changed[k] = v
				end
				changed[key] = value == 1 or nil
				local nextSel : Selection = {
					types = group == "types" and changed or old.types,
					engines = group == "engines" and changed or old.engines,
					classes = group == "classes" and changed or old.classes,
					query = old.query,
				}
				selection = nextSel
				filterState:set(nextSel)
			end,
		}
	end
	local function setQuery(text : string)
		local old = filterState:old()
		if (text or "") == (old.query or "") then
			return
		end
		local nextSel : Selection = { types = old.types, engines = old.engines, classes = old.classes, query = text or "" }
		selection = nextSel
		filterState:set(nextSel)
	end
	local function icon(path : string, tooltip : string) : TreeNodeId
		return builtin.ImageView{
			meta = { class = "relcal-filter-icon", tooltip = tooltip },
			path = path,
			scaling = builtin.type.ImageViewScaling.AutoFit,
		}
	end
	-- what: vehicle types | infrastructure | milestones
	local typeGroups : {{TreeNodeId}} = {}
	local lastGroup : string = nil
	for __, c in ipairs(CATEGORIES) do
		if c.group ~= lastGroup then
			typeGroups[#typeGroups + 1] = {}
			lastGroup = c.group
		end
		local g = typeGroups[#typeGroups]
		g[#g + 1] = toggle("types", c.key, icon(c.icon, c.tooltip()))
	end
	local engineButtons : {TreeNodeId} = {}
	for __, pair in ipairs(ENGINE_KEYS) do
		engineButtons[#engineButtons + 1] = toggle("engines", pair[2], icon(engineIcon(pair[2]), tr("engine") .. ": " .. tr(pair[2])))
	end
	-- cargo classes that occur in the list, in order of first appearance
	local classButtons : {TreeNodeId} = {}
	local seenClass : {string : boolean} = {}
	for __, e in ipairs(eventsRef:get()) do
		for __, c in ipairs(e.classes) do
			if not seenClass[c.tag] then
				seenClass[c.tag] = true
				classButtons[#classButtons + 1] = toggle("classes", c.tag, icon(c.icon, _("Specialization") .. ": " .. c.name))
			end
		end
	end
	-- two rows (in one row they no longer fit the window once infrastructure was added): what, then engine | cargo
	-- class; groups within a row are separated by "|"
	local function filterRow(groups : {{TreeNodeId}}) : TreeNodeId
		local buttons : {TreeNodeId} = {}
		for __, group in ipairs(groups) do
			if #group > 0 then
				if #buttons > 0 then
					buttons[#buttons + 1] = builtin.TextView{ meta = { class = "font-scale-body, relcal-filter-separator" }, text = "|" }
				end
				for __, button in ipairs(group) do
					buttons[#buttons + 1] = button
				end
			end
		end
		return builtin.Component{
			meta = { class = "relcal-filter" },
			layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = buttons },
		}
	end
	-- the latest unlocked year in the filtered list (or the first one, if all are in the future)
	local anchorYear : integer = nil
	local firstYear : integer = nil
	for __, e in ipairs(eventsRef:get()) do
		if matches(e, sel) then
			firstYear = firstYear or e.year
			if e.year <= date.year then
				anchorYear = e.year
			end
		end
	end
	anchorYear = anchorYear or firstYear
	local blocks : {TreeNodeId} = {}
	local tableRows : {TreeNodeId} = nil
	-- every row is a one-row table of its own on a striped background like the vanilla tables (13.10.2026; a Row has
	-- no class of its own). The column weights and the table width are the same everywhere, so the columns line up
	local function flush()
		for i, row in ipairs(tableRows or {}) do
			blocks[#blocks + 1] = builtin.Component{
				meta = { class = i % 2 == 0 and "relcal-event-row, relcal-row-alt" or "relcal-event-row" },
				layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = {
					builtin.TableLayout{
						meta = { class = "relcal-event-table" },
						columnWeights = { 0.3, 1.2, 3.0, 0.7, 0.35, 0.9 },
						rows = { row },
					},
				} },
			}
		end
		tableRows = nil
	end
	local lastYear : integer = nil
	for __, e in ipairs(eventsRef:get()) do
		if matches(e, sel) then
			if e.year ~= lastYear then
				flush()
				tableRows = {}
				lastYear = e.year
				local inYears = math.max(0, e.year - date.year - yearFraction)
				local note : TreeNodeId = nil
				if e.year == START_GROUP_YEAR then
					note = text("", "font-scale-annotation, relcal-event-year-note")
				elseif e.year == startYear then
					note = text(tr("year_start"), "font-scale-annotation, relcal-event-year-note")
				elseif e.year > date.year then
					note = text(tr("year_in", { time = gameTimeUntil(inYears) }), "font-scale-annotation, relcal-event-year-note", tr("year_in_tip"))
				elseif e.year == date.year then
					note = text(tr("year_now"), "font-scale-annotation, relcal-event-year-note")
				else
					note = text("", "font-scale-annotation, relcal-event-year-note")
				end
				-- the year is a full-width separator bar; past years are dimmed
				local barClass = e.year < date.year and "relcal-event-year, relcal-past" or "relcal-event-year"
				local barLayout = builtin.BoxLayout{
					orientation = builtin.type.Orientation.Horizontal,
					children = { text(e.year == START_GROUP_YEAR and tr("start_group") or tostring(e.year), "font-scale-headline"), note },
				}
				if e.year == anchorYear then
					blocks[#blocks + 1] = builtin.Component(react.ref(nowRef), { meta = { class = barClass }, layout = barLayout })
				else
					blocks[#blocks + 1] = builtin.Component{ meta = { class = barClass }, layout = barLayout }
				end
			end
			local statusKey = e.kind == "new" and "status_new" or (e.kind == "retire" and "status_retire" or (e.kind == "start" and "status_start" or "status_milestone"))
			-- infrastructure is not sold: "no longer buildable" (the short text is the same)
			local statusTip = (e.kind == "retire" and not e.repId) and tr("status_retire_infra") or tr(statusKey)
			local past = e.year < date.year
			local cls = past and "relcal-past" or (e.kind == "new" and "positive" or (e.kind == "retire" and "warning" or nil))
			local pictures : {TreeNodeId} = {}
			for i, path in ipairs(e.pictures) do
				pictures[#pictures + 1] = builtin.ImageView{
					meta = { class = past and "relcal-picture, relcal-past" or "relcal-picture" },
					path = path,
					flippedHorizontally = e.flips[i],
					scaling = builtin.type.ImageViewScaling.AutoFit,
				}
			end
			local engineIcons : {TreeNodeId} = {}
			for __, pair in ipairs(ENGINE_KEYS) do
				if e.engines[pair[2]] then
					engineIcons[#engineIcons + 1] = builtin.ImageView{ meta = { class = "relcal-class-icon" }, path = engineIcon(pair[2]), scaling = builtin.type.ImageViewScaling.AutoFit }
				end
			end
			local classIcons : {TreeNodeId} = {}
			local classNames : {string} = {}
			for __, c in ipairs(e.classes) do
				classIcons[#classIcons + 1] = builtin.ImageView{ meta = { class = "relcal-class-icon" }, path = c.icon, scaling = builtin.type.ImageViewScaling.AutoFit }
				classNames[#classNames + 1] = c.name
			end
			-- rows with an info window: vehicles, infrastructure, inflation; the tooltip of a group lists its variants
			local info = hasInfo(e)
			local infoTip : string = nil
			if e.repId then
				infoTip = tr("show_details")
			elseif info then
				infoTip = tr("show_info") .. ((e.details and e.details ~= "") and ("\n\n" .. e.details) or "")
			end
			-- every row has the same cell types: after a filter change the table reuses cells by position, and a
			-- Button replaced by a TextView kept its old vehicle name (12.10.2026)
			tableRows[#tableRows + 1] = builtin.Row{ cells = {
				builtin.ImageView{ meta = { class = "relcal-event-icon" }, path = e.icon, scaling = builtin.type.ImageViewScaling.AutoFit },
				-- the picture opens the vehicle info too
				builtin.Button{
					meta = { class = info and "relcal-event-name, relcal-pictures" or "relcal-event-name, relcal-event-static, relcal-pictures",
						tooltip = infoTip },
					content = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = pictures },
					onClick = function()
						if info then
							openInfo(e)
						end
					end,
				},
				builtin.Button{
					meta = {
						class = info and "relcal-event-name" or "relcal-event-name, relcal-event-static",
						tooltip = infoTip or (e.details ~= "" and e.details or nil),
					},
					content = text(e.name, info and (past and "relcal-event-link, relcal-past" or "relcal-event-link") or (past and "relcal-past" or nil)),
					onClick = function()
						if info then
							openInfo(e)
						end
					end,
				},
				text(tr(statusKey .. "_short"), cls, statusTip),
				builtin.Component{
					meta = { class = "relcal-classes", tooltip = e.engine ~= "" and (tr("engine") .. ": " .. e.engine) or nil },
					layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = engineIcons },
				},
				builtin.Component{
					meta = { class = "relcal-classes", tooltip = #classNames > 0 and (_("Specialization") .. ": " .. table.concat(classNames, ", ")) or nil },
					layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = classIcons },
				},
			} }
		end
	end
	flush()
	if #blocks == 0 then
		blocks[#blocks + 1] = text(tr("nothing"))
	end
	-- end of the list, for the first scroll step
	blocks[#blocks + 1] = builtin.Component(react.ref(endRef), { meta = { class = "relcal-list-end" } })
	-- inside the ScrollArea a FloatingLayout (with a BoxLayout the window grows along with the list);
	-- the recipe itself must return a layout ("Recipe child must be a layout", 12.10.2026): ScrollArea in a BoxLayout
	return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = {
		-- search above the panel, like the vanilla line manager and statistics (statistics_react_util.createSearchField)
		builtin.Component{ meta = { class = "relcal-search-row" }, layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = {
			builtin.TextInputField{
				meta = { class = "font-scale-body, search, relcal-search" },
				placeholderText = _("Search..."), -- game string
				value = sel.query or "",
				onTyping = setQuery,
				onValueChange = setQuery,
			},
		} } },
		-- the filters and the list in one panel like the vanilla lists (R::LineManager in line_vehicle_mgmt.css.lua)
		builtin.Component{ meta = { class = "relcal-events-panel" }, layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = {
			filterRow(typeGroups),
			filterRow({ engineButtons, classButtons }),
			builtin.ScrollArea{
			meta = { class = "relcal-events-scroll" },
			horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
			verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
			content = builtin.Component{
				meta = { class = "relcal-events" },
				layout = builtin.FloatingLayout{ children = {
					builtin.FloatingLayoutChild{
						h = 0,
						v = 0,
						-- padding goes on a Component: a BoxLayout ignored it (no left gap, 12.10.2026)
						item = builtin.Component{
							meta = { class = "relcal-events-list" },
							layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = blocks },
						},
					},
				} },
			},
		} } } },
	} }
end)

local record WindowParams
	place : Vec2f -- screen point (fractions) for the bottom-right corner of the window; nil: near the screen bottom
	onClose : function()
end

local EventsWindow = react.RegisterWrapperRecipe("ReleaseCalendarEventsWindow", builtin.Window, function(params : WindowParams) : TreeNodeId
	return builtin.Window{
		id = WINDOW_ID,
		-- the class sets the size and anchorPoint {1, 1}: the point below is the bottom-right corner of the window
		-- (like vanilla popovers: Window!popover anchors {0, 1} at the button position)
		meta = { class = "relcal-events-window" },
		title = tr("window_title"),
		-- no title bar: the content (the search first) fills the window and the close button overlaps it, like the
		-- vanilla line manager (manager_window.ManagerToolWindow)
		compact = true,
		closable = true,
		movable = true,
		initialX = params.place and params.place.x or 0.5,
		initialY = params.place and params.place.y or 0.9,
		onClose = params.onClose,
		content = EventsContent(),
	}
end)

local calendar_window : ReleaseCalendarWindow = {}

-- open / close the window (a second click closes it); place: see WindowParams; unit: screen fraction per UI unit
calendar_window.toggle = function(place? : Vec2f, unit? : Vec2f)
	local container = game_react_globals.getDefaultWindowContainer()
	if not container or not container:get() then
		log.warning("release_calendar: no window container")
		return
	end
	local windowApi = container:get():getApi()
	if api.gui.byId.isVisibleRecursive(WINDOW_ID) then
		windowApi.removeAllWindows(EventsWindow)
		return
	end
	windowApi.removeAllWindows(EventsWindow)
	unitScale = unit
	-- the list's bottom-right corner (anchorPoint {1, 1}) half a gap left of the screen center, the info window's
	-- top-left corner half a gap right of it: no window width is needed (measured and computed widths differed)
	if place and unit then
		place = api.type.Vec2f.new(0.5 - GAP_UNITS / 2 * unit.x, place.y)
	end
	infoPlace = (place and unit) and api.type.Vec2f.new(0.5 + GAP_UNITS / 2 * unit.x,
		place.y - LIST_UNITS_H * unit.y) or nil
	windowApi.addSingletonWindow(EventsWindow, {
		place = place,
		onClose = function()
			windowApi.removeAllWindows(EventsWindow)
		end,
	})
end

return calendar_window

-- The game's "reporting year" clock as a button in the bottom bar's info strip (official extension point
-- GameBarInfoDisplayExtension, next to Earnings / Transported). The game's reports and charges follow a nominal
-- year of getDefaultYearDuration() ms of simulation (24:21 at calendar 1x), not the calendar. The clock shows how
-- much of the current such year has passed (gameTime mod year; that it counts from the start of the game is an
-- assumption) and wraps around. Click: event calendar window (calendar_window.tl).

local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local react = ug_require "::/gui/main/react.lua" as React
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl" as EngineReactUtil
local game_bar_widgets = ug_require "::/gui/game_bar/game_bar_widgets.tl" as GameBarWidgets
local i18n = ug_require "/gui/release_calendar/i18n.tl" as ReleaseCalendarI18n
local tr = i18n.tr

-- UI units: the clock icon is 18 x 18 (release_calendar.css.lua); the bottom bar is at most 80 high
-- (game_bar.css.lua: the right menu is 51 + 1 + 28, the full-width background 24 + 1 + 28)
local ICON_UNITS <const> = 18
local BAR_UNITS <const> = 80
local GAP_UNITS <const> = 6

-- screen point (fractions) for the bottom center of the window: centered on screen (centered at the clock it
-- looked shifted, 12.10.2026), vertically right above the bottom bar; and the screen fraction per UI unit on each
-- axis, measured from the clock icon (its size is known)
local function windowPlace(iconRef : ReactRefWrap) : Vec2f, Vec2f
	local node = iconRef:get()
	if not node then
		return nil, nil
	end
	local p0 = node:getPosition(0.0, 0.0)
	local p1 = node:getPosition(1.0, 1.0)
	local unitX, unitY = (p1.x - p0.x) / ICON_UNITS, (p1.y - p0.y) / ICON_UNITS
	if unitX <= 0 or unitY <= 0 then
		return nil, nil
	end
	return api.type.Vec2f.new(0.5, 1.0 - (BAR_UNITS + GAP_UNITS) * unitY), api.type.Vec2f.new(unitX, unitY)
end

local function clock(seconds : number) : string
	local t = math.floor(seconds)
	return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

local record CycleState
	elapsed : number      -- seconds since the start of the current nominal year
	year : number         -- length of the nominal year, s
	nextDate : string     -- calendar date when the next nominal year starts (nil: calendar paused)
end

local ReleaseCalendarClockPlugin = react.RegisterPluginRecipe(game_bar_widgets.GameBarInfoDisplayExtension, "ReleaseCalendarClockPlugin", function() : TreeNodeId
	local isMapEditorRef = react.useRefLazy(function() : boolean return api.gui.game.isMapEditor() end) as ReactRefT<boolean>
	local state = engine_react_util.useStepState(function() : CycleState
		local gameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME) as Engine.Component.GameTime
		local year = api.util.getDefaultYearDuration()
		local speed = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED) as Engine.Component.GameSpeed
		local elapsedMs = year > 0 and gameTime.gameTime % year or 0
		local nextDate : string = nil
		if year > 0 and speed and speed.millisPerDay and speed.millisPerDay > 0 then
			local d = api.engine.util.getCalendarDate(gameTime.gameTime + (year - elapsedMs))
			nextDate = api.util.formatDate(api.type.Date.new(d.year, d.month, d.day), api.type["enum"].DateFormat.MEDIUM)
		end
		return {
			elapsed = elapsedMs / 1000,
			year = year / 1000,
			nextDate = nextDate,
		}
	end)
	local iconRef = react.useNodeRef()
	-- positions are only readable during a step (like vanilla popovers), so measure here for the click
	local placeRef = react.useRef(nil) as ReactRefT<Vec2f>
	local unitRef = react.useRef(nil) as ReactRefT<Vec2f>
	react.onStep(function()
		local ok, place, unit = pcall(windowPlace, iconRef)
		placeRef:set(ok and place or nil)
		unitRef:set(ok and unit or nil)
	end)
	if isMapEditorRef:get() then
		return nil
	end
	local st = state:old()
	-- short, several lines: a long tooltip stretches across half the screen and covers the button
	local lines : {string} = { tr("clock_year", { elapsed = clock(st.elapsed), total = clock(st.year) }) }
	-- the date of the next reporting year instead of its length in calendar days: "≈ 3 months" at calendar speed
	-- 0.25x looked like a wrong year length (12.10.2026)
	if st.nextDate then
		lines[#lines + 1] = tr("clock_next", { date = st.nextDate })
	end
	lines[#lines + 1] = tr("clock_click")
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			builtin.Button{
				meta = { class = "relcal-cycle-clock", tooltip = table.concat(lines, "\n") },
				onClick = function()
					-- the window module is loaded lazily on click. The path includes the mod name: inside a click
					-- handler a relative "/gui/…" is looked up among the game files ("module not found", 12.10.2026)
					local calendar_window = ug_require "nj_event_calendar_1::/gui/release_calendar/calendar_window.tl" as ReleaseCalendarWindow
					calendar_window.toggle(placeRef:get(), unitRef:get())
				end,
				content = builtin.BoxLayout{
					orientation = builtin.type.Orientation.Horizontal,
					children = {
						builtin.ImageView(react.ref(iconRef), {
							meta = { class = "relcal-cycle-icon", mouseTransparent = true },
							path = "::/gui/entity_window/icons/symbol_stop_watch.tga",
							scaling = builtin.type.ImageViewScaling.AutoFit,
						}),
						builtin.TextView{
							meta = { class = "font-scale-headline", mouseTransparent = true },
							text = clock(st.elapsed),
						},
					},
				},
			},
		},
	}
end)

local result = {
	ReleaseCalendarClockPlugin = ReleaseCalendarClockPlugin,
}

return result

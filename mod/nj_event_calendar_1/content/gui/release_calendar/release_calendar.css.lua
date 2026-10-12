-- Styles of the event calendar mod: clock in the bottom bar info strip, calendar window, vehicle info window.
local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
	local result = {}
	local a = ssu.makeAdder(result)

	-- reporting-year clock in the bottom bar's info strip: a flat button like the strip's texts
	a("Button!relcal-cycle-clock", {
		backgroundColor1 = { 0, 0, 0, 0 },
		borderColor = { 0, 0, 0, 0 },
		padding = { 0, 6, 0, 6 },
	})
	a("Button!relcal-cycle-clock:hover", {
		backgroundColor1 = { 1, 1, 1, 0.08 },
	})
	a("ImageView!relcal-cycle-icon", {
		size = { 18, 18 },
		minSize = { 18, 18 },
		maxSize = { 18, 18 },
		gravity = { 0, 0.5 },
		margin = { 0, 4, 0, 0 },
	})

	-- calendar window (calendar_window.tl). Id without dots: a "Window#a.b.c" selector seems to be read as classes,
	-- the window size was not applied (12.10.2026); the width comes from the list and the scroll area
	-- the bottom center of the window sits at initialX / initialY (clock_plugin.script.tl). The size is set on the
	-- window and the scroll area fills it: a fixed-size scroll area spilled below a shorter window (12.10.2026)
	a("Window!relcal-events-window", {
		anchorPoint = { 0.5, 1.0 },
		size = { 700, 640 },
	})
	a("ScrollArea!relcal-events-scroll", {
		gravity = { -1, -1 },
		minSize = { 660, 200 },
	})
	-- vehicle type filter above the list (like R::StatisticsContainer !filter in statistics.css.lua)
	a("!relcal-filter", {
		padding = { 6, 16, 4, 16 },
	})
	a("!relcal-filter BoxLayout", {
		innerSpacing = { 4, 0 },
	})
	a("ToggleButton!relcal-filter-button", {
		padding = { 0, 0, 0, 0 },
	})
	a("TextView!relcal-filter-separator", {
		gravity = { 0, 0.5 },
		margin = { 0, 6, 0, 6 },
		color = { 1, 1, 1, 0.35 },
	})
	a("ImageView!relcal-filter-icon", {
		size = { 18, 18 },
		padding = { 6, 6, 6, 6 },
	})
	-- equal left and right padding: the list starts away from the window edge
	a("!relcal-events-list", {
		minSize = { 650, 0 },
		padding = { 8, 16, 16, 16 },
	})
	a("!relcal-events-list BoxLayout", {
		innerSpacing = { 0, 2 },
	})
	-- the year is a full-width separator bar
	a("!relcal-event-year", {
		gravity = { -1, 0 },
		minSize = { 618, 0 },
		backgroundColor = { 0.20, 0.28, 0.38, 0.95 },
		padding = { 4, 10, 4, 10 },
		margin = { 10, 0, 4, 0 },
	})
	a("!relcal-event-year BoxLayout", {
		innerSpacing = { 12, 0 },
	})
	a("TextView!relcal-event-year-note", {
		gravity = { 0, 0.5 },
	})
	a("!relcal-event-table", {
		gravity = { -1, 0 },
		minSize = { 618, 0 },
		padding = { 2, 4, 6, 12 },
	})
	-- spacing between table columns and rows
	a("!relcal-event-table TextView", {
		margin = { 2, 18, 2, 0 },
	})
	a("!relcal-event-table ImageView!relcal-event-icon", {
		margin = { 2, 10, 2, 0 },
	})
	a("ImageView!relcal-event-icon", {
		size = { 18, 18 },
		minSize = { 18, 18 },
		maxSize = { 18, 18 },
		gravity = { 0, 0.5 },
	})
	-- model pictures (side views from the store list): fixed height, width follows the picture
	a("!relcal-pictures", {
		gravity = { 0, 0.5 },
		maxSize = { 110, 22 },
	})
	a("ImageView!relcal-picture", {
		maxSize = { 60, 20 },
		margin = { 0, 1, 0, 0 },
	})
	-- events before the current year: dimmed with gray colors (the alpha of a text color was ignored, 12.10.2026)
	a("TextView!relcal-past", {
		color = { 0.58, 0.60, 0.64, 1.0 },
	})
	a("TextView!relcal-event-link!relcal-past", {
		color = { 0.45, 0.55, 0.72, 1.0 },
	})
	a("ImageView!relcal-past", {
		color = { 0.65, 0.65, 0.65, 1.0 },
	})
	a("!relcal-list-end", {
		size = { 1, 1 },
	})
	a("!relcal-event-year!relcal-past", {
		backgroundColor = { 0.20, 0.24, 0.30, 0.85 },
	})
	-- cargo specialization icons
	a("ImageView!relcal-class-icon", {
		size = { 18, 18 },
		minSize = { 18, 18 },
		maxSize = { 18, 18 },
		margin = { 0, 2, 0, 0 },
	})
	a("!relcal-classes", {
		gravity = { 0, 0.5 },
	})
	-- vehicle info window next to the list: its top-left corner sits at initialX / initialY
	a("Window!relcal-info-window", {
		anchorPoint = { 0.0, 0.0 },
		size = { 624, 640 },
	})
	a("ScrollArea!relcal-info-scroll", {
		gravity = { -1, -1 },
		minSize = { 604, 200 },
	})
	-- model name links to the vehicle info
	a("Button!relcal-event-name", {
		backgroundColor1 = { 0, 0, 0, 0 },
		borderColor = { 0, 0, 0, 0 },
		padding = { 0, 0, 0, 0 },
	})
	a("Button!relcal-event-static:hover", {
		backgroundColor1 = { 0, 0, 0, 0 },
	})
	a("TextView!relcal-event-link", {
		color = { 0.55, 0.72, 1.0, 1.0 },
	})
	a("Button!relcal-event-name:hover TextView!relcal-event-link", {
		color = { 0.80, 0.88, 1.0, 1.0 },
	})

	-- vehicle info: the native vehicle store block (vehicle_details.tl, vanilla styles from vehicle_store.css.lua);
	-- width as the store's right column (rightColumnWidth 588 + padding): without it the block spans the whole screen
	a("Window#relcal_vehicle_info_window", {
		gravity = { 0.5, 0.5 },
		anchorPoint = { 0.5, 0.5 },
	})
	a("!relcal-vehicle-info", {
		size = { 604, -1 },
		minSize = { 604, 0 },
		maxSize = { 604, 100000 },
	})

	return result
end

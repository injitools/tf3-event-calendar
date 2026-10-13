-- Styles of the event calendar mod: clock in the bottom bar info strip, calendar window, vehicle info window.
local color_util = require "::/gui/main/color_util.tl"
local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
	local result = {}
	local a = ssu.makeAdder(result)

	-- only the game's colors, so the mod follows color themes (13.10.2026, user's rule); its card look (vehicle store
	-- details, line manager list: card_surface + card_contour)
	local colorDefault = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/default_colors.gres")).data
	local transparency = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/transparency.gres")).data
	local function card(extra)
		local t = {
			backgroundImage1 = { fileName = "::/gui/entity_window/design/card_surface.tga", horizontal = { 0, 6, 26, 32 }, vertical = { 0, 6, 26, 32 } },
			borderImage = { fileName = "::/gui/entity_window/design/card_contour.tga", horizontal = { 0, 6, 26, 32 }, vertical = { 0, 6, 26, 32 } },
			borderColor = colorDefault.Invisible,
			backgroundColor1 = colorDefault.BaseMedium,
		}
		for k, v in pairs(extra or {}) do
			t[k] = v
		end
		return t
	end

	-- reporting-year clock in the bottom bar's info strip: a flat button like the strip's texts
	a("Button!relcal-cycle-clock", {
		backgroundColor1 = colorDefault.Invisible,
		borderColor = colorDefault.Invisible,
		padding = { 0, 6, 0, 6 },
	})
	a("Button!relcal-cycle-clock:hover", {
		backgroundColor1 = color_util.withTransparencyRaw(colorDefault.NeutralLightest, transparency.VeryHigh),
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
	-- the bottom-right corner of the window sits at initialX / initialY (calendar_window.toggle). The size is set on the
	-- window and the scroll area fills it: a fixed-size scroll area spilled below a shorter window (12.10.2026)
	-- 640 since the filters are in two rows (13.10.2026, was 700); the minimum widths inside stay below the window
	-- width: larger ones widened the window past its size at the largest UI scale, and the info window overlapped it
	-- anchored by the bottom-right corner: the list is in the left half of the screen, the info window in the right
	a("Window!relcal-events-window", {
		anchorPoint = { 1.0, 1.0 },
		-- as wide as the info window (card 604 + its frame), 13.10.2026
		-- compact window (no title bar): the size is the whole window, 640 + the title bar's 48 keeps its height
		size = { 620, 688 },
	})
	-- search above the panel (like the line manager's "Search..." field; size as statistics' R::StatisticsContainer !search)
	a("!relcal-search-row", {
		padding = { 8, 8, 0, 8 },
	})
	a("TextInputField!relcal-search", {
		size = { 300, 28 },
		gravity = { 0, 0.5 },
	})
	-- the list in a panel like the line manager's (R::LineManager: card, light border, padding 1), 8 from the
	-- window edges
	a("!relcal-events-panel", card({
		borderColor = colorDefault.BaseVeryLight,
		gravity = { -1, -1 },
		padding = { 1, 1, 1, 1 },
		margin = { 8, 8, 8, 8 },
	}))
	a("ScrollArea!relcal-events-scroll", {
		gravity = { -1, -1 },
		minSize = { 560, 200 },
	})
	-- vehicle type filter above the list (like R::StatisticsContainer !filter in statistics.css.lua)
	-- content 8 units from the window edges, like the info card (13.10.2026); between the two filter rows 8 too
	a("!relcal-filter", {
		padding = { 8, 8, 0, 8 },
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
		color = colorDefault.NeutralMedium,
	})
	a("ImageView!relcal-filter-icon", {
		size = { 18, 18 },
		padding = { 6, 6, 6, 6 },
	})
	-- the list starts 8 units from the window edge, as the filters and the info card
	-- up to the scroll bar: the window's 620 minus the panel's margins and padding (18) and the bar's slot
	a("!relcal-events-list", {
		minSize = { 592, 0 },
		padding = { 8, 8, 8, 8 },
	})
	-- no gaps: the striped rows touch like in the vanilla tables
	a("!relcal-events-list BoxLayout", {
		innerSpacing = { 0, 0 },
	})
	-- the year is a full-width separator bar
	a("!relcal-event-year", {
		gravity = { -1, 0 },
		minSize = { 576, 0 },
		backgroundColor = colorDefault.AccentVeryDark,
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
		minSize = { 576, 0 },
		padding = { 2, 4, 2, 12 },
	})
	-- striped rows like the vanilla tables: every second row a step lighter than the panel (BaseMedium)
	a("!relcal-event-row", {
		gravity = { -1, 0 },
		minSize = { 576, 0 },
	})
	a("!relcal-event-row!relcal-row-alt", {
		backgroundColor = colorDefault.BaseLightMedium,
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
		color = colorDefault.NeutralLight,
	})
	a("TextView!relcal-event-link!relcal-past", {
		color = colorDefault.AccentMedium,
	})
	a("ImageView!relcal-past", {
		color = colorDefault.NeutralLight,
	})
	a("!relcal-list-end", {
		size = { 1, 1 },
	})
	a("!relcal-event-year!relcal-past", {
		backgroundColor = colorDefault.BaseLight,
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
	-- info window next to the list: its top-left corner sits at initialX / initialY; the height follows the card
	-- (its scroll area is at most the list's height), the width comes from relcal-vehicle-info. No maxSize: it counts
	-- the title bar too and cut off the bottom of long cards (13.10.2026); the windows that jumped in the first frame
	-- are handled by the empty first frame (calendar_window CARD_DELAY_STEPS)
	a("Window!relcal-info-window", {
		anchorPoint = { 0.0, 0.0 },
	})
	-- infrastructure and inflation cards scroll (calendar_window): only a maximum height, so the area follows shorter
	-- cards; 624 = the info window's bottom on the list's. The area keeps a slot of about 7 for its bar even with
	-- nothing to scroll: the card padding has 1 on the right (relcal-info-scrolling), 1 + 7 = 8 like the left side;
	-- 8 + 595 + 1 = 604. A size on the window was not applied (it grew off the screen, 13.10.2026)
	a("ScrollArea!relcal-info-scroll", {
		maxSize = { 595, 624 }, -- 576 + 48: the list window grew by its former title bar when it became compact
		-- a fixed width: with only the maximum, scrolling cards were 10 px narrower than the others (screenshots
		-- 13.10.2026)
		minSize = { 595, 0 },
	})
	a("!relcal-info-scroll-content", {
		size = { 588, -1 },
		maxSize = { 588, 100000 },
	})
	a("!relcal-vehicle-info!relcal-info-scrolling", {
		padding = { 8, 1, 8, 8 },
	})
	-- infrastructure and inflation cards (info_cards.tl); the text width is that of the card (604 - padding 16)
	-- every variant (and the inflation card) on a card like the vehicle details (R::VehicleStoreDetails)
	a("!relcal-infra-block", card({
		padding = { 8, 8, 8, 8 },
		margin = { 0, 0, 8, 0 },
	}))
	a("!relcal-infra-block BoxLayout", {
		innerSpacing = { 10, 4 },
	})
	a("ImageView!relcal-infra-picture", {
		maxSize = { 160, 96 },
		gravity = { 0, 0 },
	})
	a("TextView!relcal-infra-sub", {
		color = colorDefault.NeutralLight,
	})
	a("TextView!relcal-infra-desc", {
		size = { 556, -1 }, -- card 588 - its padding 16 - a little
		textAutoWrap = true,
		color = colorDefault.NeutralVeryLight,
		margin = { 4, 0, 4, 0 },
	})
	a("!relcal-infra-numbers BoxLayout", {
		innerSpacing = { 8, 0 },
	})
	-- price year selector under the numbers of an infrastructure variant: small buttons
	a("!relcal-price-years", {
		margin = { 4, 0, 0, 0 },
	})
	a("ToggleButton!relcal-price-year", {
		padding = { 1, 6, 1, 6 },
	})
	a("TextView!relcal-price-years-label", {
		gravity = { 0, 0.5 },
		margin = { 0, 0, 0, 8 },
	})
	a("TextView!relcal-inflation-head", {
		margin = { 10, 0, 4, 0 },
	})
	a("!relcal-inflation-table", {
		minSize = { 300, 0 },
	})
	a("!relcal-inflation-table TextView", {
		margin = { 2, 0, 2, 16 },
	})

	-- model name links to the vehicle info
	a("Button!relcal-event-name", {
		backgroundColor1 = colorDefault.Invisible,
		borderColor = colorDefault.Invisible,
		padding = { 0, 0, 0, 0 },
	})
	a("Button!relcal-event-static:hover", {
		backgroundColor1 = colorDefault.Invisible,
	})
	a("TextView!relcal-event-link", {
		color = colorDefault.AccentVeryLight,
	})
	a("Button!relcal-event-name:hover TextView!relcal-event-link", {
		color = colorDefault.NeutralLightest,
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
		-- 8 units from the window edges on every side; 604 - 16 = the depot store's column width 588 (13.10.2026)
		padding = { 8, 8, 8, 8 },
	})

	return result
end

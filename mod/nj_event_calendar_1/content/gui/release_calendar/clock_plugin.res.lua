-- Reporting-year clock in the bottom bar's info strip (next to Earnings / Transported): GameBarInfoDisplayExtension.
function data()
	return {
		type = "react-plugin ::GameBarInfoDisplayExtension",
		data = {
			filePath = "nj_event_calendar_1::/gui/release_calendar/clock_plugin.script@ReleaseCalendarClockPlugin",
			priority = 10, -- vanilla Earnings is -2, Transported -1: append to the right of them
		}
	}
end

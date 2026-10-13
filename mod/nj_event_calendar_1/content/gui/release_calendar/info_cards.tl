-- Info cards of the event calendar besides the vehicle one (vehicle_details.tl): an infrastructure entry (every
-- variant with its menu picture, years, the game's description and the construction menu's numbers: cost, upkeep,
-- top speed, noise, pollution) and an inflation step (what it multiplies, the factor now and by year).
-- The numbers are formatted by the construction menu's own code (construction_desc_react_util.formatNumbers and
-- ConstructionInfoNumberList), so they read like the menu tooltip.

local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local react = ug_require "::/gui/main/react.lua" as React
local construction_desc_react_util = ug_require "::/gui/construction/construction_desc_react_util.tl" as ConstructionDescReactUtil
local i18n = ug_require "/gui/release_calendar/i18n.tl" as ReleaseCalendarI18n

local tr = i18n.tr

local info_cards : ReleaseCalendarInfoCards = {}

local function text(value : string, classes? : string) : TreeNodeId
	return builtin.TextView{
		meta = { class = "font-scale-body" .. (classes and (", " .. classes) or "") },
		text = value,
	}
end

-- inflation factor of a year, as the game computes it for construction prices (nil without the base config table)
local function costMultiplier(year : integer) : number
	local base = api.res.getBaseConfig()
	local mult = base and base.treeCostYearMultipliers
	if not mult then
		return nil
	end
	local ok, m = pcall(api.engine.util.construction.getCostMultiplierForYear, mult, year)
	return ok and m as number or nil
end

local function formatFactor(m : number) : string
	return string.format("×%.1f", m)
end

local function years(d : ReleaseCalendarInfra.Detail) : string
	if not d.yearFrom or d.yearFrom <= 0 then
		return d.yearTo and d.yearTo > 0 and ("– " .. tostring(d.yearTo)) or ""
	end
	-- like the vehicle details title ("1950 – 2005")
	return tostring(d.yearFrom) .. " – " .. ((d.yearTo and d.yearTo > 0) and tostring(d.yearTo) or "")
end

-- the construction menu's number lines for one item; prices of buildings that follow the year are those of priceYear
local function numberLines(d : ReleaseCalendarInfra.Detail, priceYear : integer) : {TreeNodeId}, boolean
	local scale = 1.0
	local scaled = false
	if d.yearProgression and (d.cost or d.maintenanceCost) then
		local m = costMultiplier(priceYear)
		if m then
			scale = m
			scaled = true
		end
	end
	local function single(v : number) : ConstructionDescReactUtil.MinMax
		return v and { min = v, max = -1 } or nil
	end
	local numbers : ConstructionDescReactUtil.Numbers = {
		cost = single(d.cost and d.cost * scale),
		maintenanceCost = single(d.maintenanceCost and d.maintenanceCost * scale),
		costPerKm = d.costPerKm,
		speedLimit = single(d.speedLimit),
		noise = single(d.noise),
		pollution = single(d.pollution),
	}
	local result : {TreeNodeId} = {}
	local ok, linesAny = pcall(construction_desc_react_util.formatNumbers, numbers)
	if ok then
		for __, line in ipairs(linesAny as {{ConstructionDescReactUtil.FormatNumberDesc}}) do
			result[#result + 1] = construction_desc_react_util.ConstructionInfoNumberList{ line = line }
		end
	else
		log.warning("release_calendar: number lines: " .. tostring(linesAny))
	end
	return result, scaled
end

-- inflation steps of the base config, by year
local function inflationSteps() : {{integer, number}}
	local base = api.res.getBaseConfig()
	local steps : {{integer, number}} = {}
	for y, m in pairs(base and base.treeCostYearMultipliers or {}) do
		steps[#steps + 1] = { y, m }
	end
	table.sort(steps, function(a : {integer, number}, b : {integer, number}) : boolean return a[1] < b[1] end)
	return steps
end

local record DetailParams
	detail : ReleaseCalendarInfra.Detail
	appears : integer -- year the variant appears (its prices by default)
end

-- one variant. Prices of buildings that follow the year: of the year the variant appears (13.10.2026: not the
-- current year), or, chosen under the numbers, of a later inflation step while the variant is still available
local DetailBlock = react.RegisterRecipe("ReleaseCalendarInfraDetail", function(params : DetailParams) : TreeNodeId
	local d = params.detail
	local yearState = react.useState(params.appears) as ReactStateT<integer>
	local priceYear = yearState:old()
	local picture = d.previewIcon or d.icon
	local titleChildren : {TreeNodeId} = { text(d.name, "font-scale-headline") }
	local span = years(d)
	if span ~= "" then
		titleChildren[#titleChildren + 1] = text(span, "relcal-infra-sub")
	end
	local header : {TreeNodeId} = {}
	if picture then
		header[#header + 1] = builtin.ImageView{
			meta = { class = "relcal-infra-picture" },
			path = picture,
			scaling = builtin.type.ImageViewScaling.AutoFit,
		}
	end
	header[#header + 1] = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = titleChildren }
	local children : {TreeNodeId} = {
		builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = header },
	}
	if d.description then
		children[#children + 1] = text(d.description, "relcal-infra-desc")
	end
	local lines, scaled = numberLines(d, priceYear)
	if #lines > 0 then
		-- the menu puts every number on a line of its own; here they share one row (13.10.2026)
		children[#children + 1] = builtin.Component{
			meta = { class = "relcal-infra-numbers" },
			layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = lines },
		}
	end
	if scaled then
		-- the year it appears, then the later inflation steps until it can no longer be built
		local choices : {integer} = { params.appears }
		for __, st in ipairs(inflationSteps()) do
			if st[1] > params.appears and (not d.yearTo or d.yearTo <= 0 or st[1] < d.yearTo) then
				choices[#choices + 1] = st[1]
			end
		end
		if #choices > 1 then
			local buttons : {Builtin.ToggleButtonGroupChildParam} = {}
			for __, y in ipairs(choices) do
				local m = costMultiplier(y)
				buttons[#buttons + 1] = {
					meta = { class = "relcal-price-year", tooltip = m and formatFactor(m) or nil },
					content = text(tostring(y), "font-scale-annotation"),
				}
			end
			children[#children + 1] = builtin.Component{
				meta = { class = "relcal-price-years" },
				layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = {
					text(tr("prices_label") .. ":", "font-scale-annotation, relcal-price-years-label"),
					builtin.ToggleButtonGroup{
						buttons = buttons,
						layout = "Flow",
						onValueChange = function(index : integer, value : integer)
							if value == 1 and choices[index] then
								yearState:set(choices[index])
							end
						end,
					},
				} },
			}
		else
			children[#children + 1] = text(tr("prices_in", { year = priceYear }), "font-scale-annotation, relcal-infra-sub")
		end
	end
	-- a recipe inside a layout must return a layout
	return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = {
		builtin.Component{
			meta = { class = "relcal-infra-block" },
			layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = children },
		},
	} }
end)

info_cards.Infra = react.RegisterRecipe("ReleaseCalendarInfraCard", function(params : ReleaseCalendarInfoCards.InfraParams) : TreeNodeId
	local blocks : {TreeNodeId} = {}
	for __, d in ipairs(params.entry.details or {}) do
		-- available from the start of the game: the year of the event
		local appears = (d.yearFrom and d.yearFrom > 0) and d.yearFrom or params.entry.year
		blocks[#blocks + 1] = DetailBlock({ detail = d, appears = appears })
	end
	return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = blocks }
end)

info_cards.Inflation = react.RegisterRecipe("ReleaseCalendarInflationCard", function(params : ReleaseCalendarInfoCards.InflationParams) : TreeNodeId
	local now = costMultiplier(api.engine.util.getYear())
	local children : {TreeNodeId} = {
		text(tr("inflation_text", { year = params.year, mult = string.format("%.1f", params.mult), now = now and string.format("%.1f", now) or "?" }), "relcal-infra-desc"),
		text(tr("inflation_steps"), "font-scale-headline, relcal-inflation-head"),
	}
	local steps = inflationSteps()
	-- the step in force now: the last one not after the current year
	local current : integer = nil
	for __, st in ipairs(steps) do
		if st[1] <= api.engine.util.getYear() then
			current = st[1]
		end
	end
	local rows : {TreeNodeId} = {}
	for __, st in ipairs(steps) do
		local cls = st[1] == params.year and "positive" or nil
		rows[#rows + 1] = builtin.Row{ cells = {
			text(tostring(st[1]), cls),
			text(formatFactor(st[2]), cls),
			text(st[1] == current and tr("inflation_current") or "", "relcal-infra-sub"),
		} }
	end
	children[#children + 1] = builtin.TableLayout{
		meta = { class = "relcal-inflation-table" },
		columnWeights = { 1.0, 1.0, 2.0 },
		rows = rows,
	}
	-- a recipe inside a layout must return a layout ("Recipe child must be a layout", 13.10.2026)
	return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = {
		builtin.Component{
			meta = { class = "relcal-infra-block" },
			layout = builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = children },
		},
	} }
end)

return info_cards

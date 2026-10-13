recordDef = true

global record ReleaseCalendarI18n
	--- language of the mod strings: en de es fr it ja ko nl pl pt_BR ru zh_CN zh_TW
	language : function() : string
	--- string by key in the game language; {name} placeholders are filled from vars
	tr : function(key : string, vars? : {string : any}) : string
end

global record ReleaseCalendarWindow
	--- place: screen point (fractions) for the bottom center of the window; nil: near the screen bottom
	--- unit: screen fraction per UI unit on each axis (to place the vehicle info window next to the list)
	toggle : function(place? : Vec2f, unit? : Vec2f)
end

global record ReleaseCalendarInfra
	--- one infrastructure item for the info window (texts and pictures as in the construction menu)
	record Detail
		name : string
		description : string
		icon : string
		--- the menu's larger preview picture
		previewIcon : string
		yearFrom : integer
		--- 0: no end
		yearTo : integer
		--- menu attributes; streets and tracks: per km (costPerKm)
		cost : number
		maintenanceCost : number
		costPerKm : boolean
		--- m/s
		speedLimit : number
		noise : number
		pollution : number
		--- cost and upkeep follow the inflation factor of the year (costsYearProgression)
		yearProgression : boolean
	end
	--- one row of the calendar: infrastructure items of one notification group (or filter category) that change in
	--- the same year
	record Entry
		year : integer
		--- "new" | "retire" | "milestone" (a year switch of the base config) | "start" (available when the game started)
		kind : string
		--- filter category: "road" | "track" | "bridge" | "station" | "depot"
		category : string
		--- first variant, with "(+N)" for the others
		name : string
		--- distinct names of all items
		variants : {string}
		--- up to 3 distinct menu icons
		icons : {string}
		--- one per variant name, in the order of variants
		details : {Detail}
	end
	--- entries from after startYear on (items available at the start are not events)
	collect : function(startYear : integer) : {Entry}
end

global record ReleaseCalendarInfoCards
	record InfraParams
		entry : ReleaseCalendarInfra.Entry
	end
	record InflationParams
		year : integer
		--- factor from that year on
		mult : number
	end
	Infra : Recipe<InfraParams>
	Inflation : Recipe<InflationParams>
end

global record VehicleDetails
	record DetailsParams
		repId : integer
		multipleUnit : boolean
	end
	Details : Recipe<DetailsParams>
end

recordDef = false

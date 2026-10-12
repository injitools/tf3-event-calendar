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

global record VehicleDetails
	record DetailsParams
		repId : integer
		multipleUnit : boolean
	end
	Details : Recipe<DetailsParams>
end

recordDef = false

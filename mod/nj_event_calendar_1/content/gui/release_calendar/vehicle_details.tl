-- Vehicle info block: a COPY of the native one from the vehicle store (gui/line_vehicle_mgmt/vehicle_store_window.tl:
-- DetailsTitle, CargoIcons, CapacityIcons, LargeImage, VehicleStatsTable, VehicleDescription verbatim; VehicleStats
-- without the color button, which only works with the store cart). In the game these are local recipes, and future
-- models are not in the store, hence the copy. Recipes are registered under the SAME names, the container as
-- "VehicleStoreDetails": the store styles (vehicle_store.css.lua) are bound to the names (R::VehicleStoreDetails
-- R::LargeImage …) and apply by themselves. ⚠ After a game update compare with vanilla (vendor/).

local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local cargo_react_util = ug_require "::/gui/main/cargo_react_util.tl" as CargoReactUtil
local cargo_util = ug_require "::/gui/main/cargo_util.tl" as CargoUtil
local lang_util = ug_require "::/scripts/lang_util.tl" as LangUtil
local mathutil = ug_require "::/scripts/mathutil.lua" as MathUtil
local react = ug_require "::/gui/main/react.lua" as React
local table_util = ug_require "::/scripts/table_util.tl" as TableUtil
local vehicle_store_util = ug_require "::/gui/line_vehicle_mgmt/vehicle_store_util.tl" as VehicleStoreUtil

local formatDelta = function(newVal : number, oldVal : number, formatter : function(number) : string) : string
	if oldVal == nil or oldVal == newVal then
		return formatter(newVal)
	elseif newVal > oldVal then
		return "+" .. formatter(newVal - oldVal)
	else
		return "-" .. formatter(oldVal - newVal)
	end
end

-- ===== verbatim copy of vanilla =====
local DetailsTitle = react.RegisterRecipe("DetailsTitle", function(elemStatic : VehicleStoreUtil.ElementStatic) : TreeNodeId
	local yearText = function() : string
		
		if elemStatic.vehicleData.yearTo > 0 then
			return lang_util.format(_("{from} – {to}"), {
				from = lang_util.formatPlainInt(elemStatic.vehicleData.yearFrom),
				to = lang_util.formatPlainInt(elemStatic.vehicleData.yearTo),
			})
		end
		return lang_util.formatPlainInt(elemStatic.vehicleData.yearFrom)
	end
	return builtin.BoxLayout{
		children = {
			builtin.BoxLayout{
				meta = {
					class = "title-left"
				},
				orientation = builtin.type.Orientation.Vertical,
				children = {
					builtin.ScrollArea{
						content = builtin.TextView{
							meta = {
								class = "font-scale-title-3",
							},
							text = elemStatic.name,
						},
						horizontalPolicy = builtin.type.ScrollBarPolicy.AsNeededButAlwaysReserveSpace,
						verticalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
					},
					builtin.TextView{
						meta = {
							class = "font-scale-headline, title-sub",
						},
						text = yearText(),
					},
				},
			},
			builtin.BoxLayout{
				meta = {
					class = "title-right"
				},
				orientation = builtin.type.Orientation.Vertical,
				children = {
					builtin.TextView{
						meta = {
							class = "font-scale-title-3, right-aligned",
						},
						text = api.util.formatMoney(elemStatic.vehicleData.price)
					},
					builtin.TextView{
						meta = {
							class = "font-scale-headline, title-sub, right-aligned",
						},
						text = lang_util.format(_("{cost}/year"), {
							cost = api.util.formatMoney(mathutil.round(elemStatic.vehicleData.runningCosts))
						}),
					},
				}
			}
		},
		orientation = builtin.type.Orientation.Horizontal,
	}
end)

local CargoIcons = react.RegisterRecipe("CargoIcons", function(
	allCargoTypes : { CargoTypeId : integer },
	allCargoCurrentlyProduced : {CargoTypeId : boolean}
) : TreeNodeId
	local cargoTypeIds : { CargoTypeId } = {}
	for key, __ in pairs(allCargoTypes) do
		table.insert(cargoTypeIds, key)
	end
	if #cargoTypeIds == 0 then
		return nil
	end

	local checkAllCargo = function() : boolean
		if #cargoTypeIds == 1 and cargoTypeIds[1] == cargo_util.getPassengerCargoTypeId() then
			return false
		end

		return true
	end

	local rows : { TreeNodeId } = {}
	local rowIcons : { TreeNodeId } = {}

	if checkAllCargo() then
		for __, id in ipairs(cargoTypeIds) do
			if allCargoCurrentlyProduced[id] == true then
				local iconPath = cargo_util.getCargoIconById(id)
				table.insert(rowIcons,
					builtin.ImageView{
						meta = {
							class = "cargo-icon",
							tooltip = cargo_util.getCargoNameById(id),
						},
						path = iconPath,
						scaling = builtin.type.ImageViewScaling.AutoFit,
					}
				)
				if #rowIcons == 12 then
					table.insert(rows, builtin.BoxLayout{
						children = rowIcons,
						orientation = builtin.type.Orientation.Horizontal,
					})
					rowIcons = {}
				end
			end
		end

		if #rowIcons > 0 then
			table.insert(rows, builtin.BoxLayout{
				children = rowIcons,
				orientation = builtin.type.Orientation.Horizontal,
			})
		end
	end

	return builtin.BoxLayout{
		children = rows,
		orientation = builtin.type.Orientation.Vertical,
	}
end)

local record CapacityIconsParam
	vehicleData : VehicleStoreUtil.VehicleData
	allCargoCurrentlyProduced : {CargoTypeId : boolean}
	comparisonData : VehicleStoreUtil.VehicleData
	showCargoIcons : boolean
	dontShowCompartments : boolean
end

local CapacityIcons = react.RegisterRecipe("CapacityIcons", function(param : CapacityIconsParam) : TreeNodeId
	if param.vehicleData.totalCapacity <= 0 and (not param.comparisonData or param.comparisonData.totalCapacity <= 0) then
		return nil
	end

	if param.comparisonData then
		local newPassengerCap = param.vehicleData.totalCapacityPassengers or 0
		local oldPassengerCap = param.comparisonData.totalCapacityPassengers or 0
		local newCargoCap = param.vehicleData.totalCapacityCargo or 0
		local oldCargoCap = param.comparisonData.totalCapacityCargo or 0

		local showPassengerDiff = param.vehicleData.passengers or param.comparisonData.passengers
		local showCargoDiff = param.vehicleData.anyCargo or param.comparisonData.anyCargo

		local entries : {TreeNodeId} = {}
		if showPassengerDiff then
			local passengerLabel = formatDelta(newPassengerCap, oldPassengerCap,
				function(val : number) : string
					return lang_util.formatInt(val as integer)
				end
			)
			table.insert(entries, builtin.BoxLayout{
				orientation = builtin.type.Orientation.Horizontal,
				children = {
					builtin.ImageView{
						scaling = builtin.type.ImageViewScaling.AutoFit,
						path = "::/gui/line_vehicle_mgmt/icons/symbol_person.tga",
					},
					builtin.TextView{
						meta = {
							class = "font-scale-title-4, capacity-label",
						},
						text = passengerLabel,
					},
				},
			})
		end
		if showCargoDiff then
			local cargoLabel = formatDelta(newCargoCap, oldCargoCap,
				function(val : number) : string
					return lang_util.formatInt(val as integer)
				end
			)
			table.insert(entries, builtin.BoxLayout{
				orientation = builtin.type.Orientation.Horizontal,
				children = {
					builtin.ImageView{
						scaling = builtin.type.ImageViewScaling.AutoFit,
						path = "::/gui/line_vehicle_mgmt/icons/symbol_cargo.tga",
					},
					builtin.TextView{
						meta = {
							class = "font-scale-title-4, capacity-label",
						},
						text = cargoLabel,
					},
				},
			})
		end

		if #entries == 1 then
			return entries[1]
		elseif #entries > 1 then
			return builtin.BoxLayout{
				orientation = builtin.type.Orientation.Horizontal,
				children = entries,
			}
		end
		return nil
	end

	local showCargoIcons = param.showCargoIcons
	if param.showCargoIcons then
		for __, cls in ipairs(param.vehicleData.cargoClasses) do
			if cls == "UNIVERSAL" or cls == "PASSENGERS" then
				showCargoIcons = false
			end
		end
	end

	local showPassengerCapacityIcon = false
	local showCargoCapacityIcon = false
	if table_util.arrayContains(param.vehicleData.cargoClasses, "PASSENGERS") then
		showPassengerCapacityIcon = true
		if table_util.arrayContains(param.vehicleData.cargoClasses, "UNIVERSAL") then
			showCargoCapacityIcon = true
		end
	else
		showCargoCapacityIcon = true
	end

	local capacityChildren : {TreeNodeId} = {}
	local differentCargoCapacity = false
	if showPassengerCapacityIcon then
		table.insert(capacityChildren, builtin.ImageView{
			scaling = builtin.type.ImageViewScaling.AutoFit,
			path = "::/gui/line_vehicle_mgmt/icons/symbol_person.tga",
		})
		if showCargoCapacityIcon then
			differentCargoCapacity = param.vehicleData.totalCapacityPassengers ~= param.vehicleData.totalCapacityCargo
			if differentCargoCapacity then
				table.insert(capacityChildren, builtin.TextView{
					meta = {
						class = "font-scale-title-4, capacity-label",
					},
					text = lang_util.formatInt(param.vehicleData.totalCapacityPassengers),
				})
			end
			table.insert(capacityChildren, builtin.TextView{
				meta = {
					class = "font-scale-title-4",
				},
				text = "/",
			})
		end
	end
	if showCargoCapacityIcon then
		if (param.dontShowCompartments ~= true) and param.vehicleData.numCompartments > 1 then
			table.insert(capacityChildren,
				builtin.TextView{
					meta = {
						class = "compartments, font-scale-body",
					},
					text = lang_util.formatInt(param.vehicleData.numCompartments),
			})
		else
			table.insert(capacityChildren, builtin.ImageView{
				scaling = builtin.type.ImageViewScaling.AutoFit,
				path = "::/gui/line_vehicle_mgmt/icons/symbol_cargo.tga",
			})
		end
	end
	table.insert(capacityChildren, builtin.TextView{
		meta = {
			class = "font-scale-title-4, capacity-label",
		},
		text = lang_util.formatInt(differentCargoCapacity and param.vehicleData.totalCapacityCargo or param.vehicleData.totalCapacity),
	})
	if showCargoIcons then
		table.insert(capacityChildren, CargoIcons(
			param.vehicleData.allCargoTypes,
			param.allCargoCurrentlyProduced
		))
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = capacityChildren,
	}
end)

local record LargeImageParam
	elem : VehicleStoreUtil.Element
	allCargoCurrentlyProduced : {CargoTypeId : boolean}
	comparisonData : VehicleStoreUtil.VehicleData
end

local LargeImage = react.RegisterRecipe("LargeImage", function(param : LargeImageParam) : TreeNodeId
	if param.elem == nil or param.elem.static == nil then
		return nil
	end

	local image : string = vehicle_store_util.getVehicleNameAndIcons(
		param.elem.static.repId,
		param.elem.static.multipleUnit,
		false
	).largeIcon

	local engine = function() : string
		local engineName : string
		for engine, __ in pairs(param.elem.static.vehicleData.engines) do
			if engine == api.type["enum"].VehicleEngineType.HORSE then
				engineName = _("Horse")
			elseif engine == api.type["enum"].VehicleEngineType.STEAM then
				engineName = _("Steam")
			elseif engine == api.type["enum"].VehicleEngineType.DIESEL then
				engineName = _("Diesel")
			elseif engine == api.type["enum"].VehicleEngineType.ELECTRIC then
				engineName = _("Electric")
			end
			break
		end
		return engineName
	end

	local getSize = function() : string
		local tmAircraft   = api.type["enum"].TransportMode.AIRCRAFT
		local tmSmAircraft = api.type["enum"].TransportMode.SMALL_AIRCRAFT
		local tmShip       = api.type["enum"].TransportMode.SHIP
		local tmSmShip     = api.type["enum"].TransportMode.SMALL_SHIP
		local result : string
		if param.elem.static.transportModes[tmAircraft] or param.elem.static.transportModes[tmShip] then
			result = _("Large")
		elseif param.elem.static.transportModes[tmSmAircraft] or param.elem.static.transportModes[tmSmShip] then
			result = _("Small")
		end
		return result
	end
	local size = getSize()

	return builtin.FloatingLayout{
		children = {
			builtin.FloatingLayoutChild{
				v = -1,
				h = -1,
				item = builtin.ImageView{
					meta = {
						class = "vehicle-image",
					},
					path = image,
					scaling = builtin.type.ImageViewScaling.AutoFit,
				}
			},
			builtin.FloatingLayoutChild{
				v = 0,
				h = -1,
				item = DetailsTitle(param.elem.static),
			},
			param.elem.static.vehicleData.totalCapacity > 0 and builtin.FloatingLayoutChild{
				v = 1,
				h = 0,
				item = builtin.BoxLayout{
					meta = {
						class = "capacity-container-on-image",
					},
					orientation = builtin.type.Orientation.Vertical,
					children = {
						builtin.Component{
							meta = {
								class = "specialization-on-image",
							},
							layout = builtin.BoxLayout{
								orientation = builtin.type.Orientation.Horizontal,
								children = {
									cargo_react_util.CargoClassSpecialization({
										cargoClasses = param.elem.static.vehicleData.cargoClasses,
										horizontalLayout = true,
									}),
								},
							},
						},
						CapacityIcons{
							vehicleData = param.elem.static.vehicleData,
							allCargoCurrentlyProduced = param.allCargoCurrentlyProduced,
							comparisonData = param.comparisonData,
							showCargoIcons = true,
						},
					},
				}
			} or nil,
			(param.elem.static.vehicleData.engines and next(param.elem.static.vehicleData.engines) ~= nil) and builtin.FloatingLayoutChild{
				v = 1,
				h = 1,
				item = builtin.TextView{
					meta = {
						class = "engine-on-image, font-scale-title-4",
					},
					text = engine(),
				}
			} or nil,
			size ~= nil and builtin.FloatingLayoutChild{
				v = 1,
				h = 1,
				item = builtin.TextView{
					meta = {
						class = "engine-on-image, font-scale-title-4",
					},
					text = size,
				}
			} or nil,
		},
	}
end)

local record VehicleStatsTableParam
	vehicleData : VehicleStoreUtil.VehicleData
	comparisonData : VehicleStoreUtil.VehicleData
	ranges : VehicleUtil.Ranges
	showAllStats : boolean
end

local VehicleStatsTable = react.RegisterRecipe("VehicleStatsTable", function(param : VehicleStatsTableParam) : TreeNodeId
	local vehicleData = param.vehicleData
	local comparisonData = param.comparisonData
	local ranges = param.ranges

	local hasPowerOnLeft = false
	local rowsLeft : { TreeNodeId } = {}

	local speed = vehicleData.speed
	local speedPercentage = mathutil.mapClamp(speed, ranges.minSpeed, ranges.maxSpeed, 0, 1)
	local speedComparisonPercentage = comparisonData and mathutil.mapClamp(comparisonData.speed, ranges.minSpeed, ranges.maxSpeed, 0, 1) or nil
	local speedString = formatDelta(speed, comparisonData and comparisonData.speed or nil, api.util.formatSpeed)
	rowsLeft[#rowsLeft + 1] = vehicle_store_util.makeVehicleProgressBarRow(
		"::/gui/line_vehicle_mgmt/icons/symbol_speed.tga",
		_("Top Speed"),
		speedPercentage,
		speedString,
		speedComparisonPercentage
	)
	if vehicleData.anyCargo or vehicleData.passengers or param.showAllStats then
		local loadingSpeedFactor = mathutil.mapClamp(vehicleData.loadingSpeed, ranges.loadSpeedScoreRange[1], ranges.loadSpeedScoreRange[2], 0, 1)
		local loadingSpeedComparisonPercentage = comparisonData and mathutil.mapClamp(comparisonData.loadingSpeed, ranges.loadSpeedScoreRange[1], ranges.loadSpeedScoreRange[2], 0, 1) or nil
		local loadingSpeedString = formatDelta(vehicleData.loadingSpeed, comparisonData and comparisonData.loadingSpeed or nil, function(v : number) : string return string.format("%.1fx", v) end)
		rowsLeft[#rowsLeft + 1] = vehicle_store_util.makeVehicleProgressBarRow(
			"::/gui/line_vehicle_mgmt/icons/relation_cargo_time.tga",
			_("Loading Speed"),
			loadingSpeedFactor,
			loadingSpeedString,
			loadingSpeedComparisonPercentage
		)
	end
	if (not param.showAllStats and not (vehicleData.thrust > 0)) and next(vehicleData.allCargoTypes) == nil then
		hasPowerOnLeft = true
		local powerPercentage = vehicleData.power / ranges.maxPower
		local powerComparisonPercentage = comparisonData and comparisonData.power / ranges.maxPower or nil
		rowsLeft[#rowsLeft + 1] = vehicle_store_util.makeVehicleProgressBarRow(
			"::/gui/line_vehicle_mgmt/icons/symbol_chain_drive.tga",
			_("Power"),
			powerPercentage,
			formatDelta(vehicleData.power, comparisonData and comparisonData.power or nil, api.util.formatPower),
			powerComparisonPercentage
		)
	end
	if not param.showAllStats and not (vehicleData.power > 0) and next(vehicleData.allCargoTypes) == nil and vehicleData.thrust > 0 then
		local thrustPercentage = vehicleData.thrust / ranges.maxThrust
		local thrustComparisonPercentage = comparisonData and comparisonData.thrust / ranges.maxThrust or nil
		rowsLeft[#rowsLeft + 1 ] = vehicle_store_util.makeVehicleProgressBarRow(
			"::/gui/line_vehicle_mgmt/icons/thrust.tga",
			_("Thrust"),
			thrustPercentage,
			formatDelta(vehicleData.thrust, comparisonData and comparisonData.thrust or nil, api.util.formatForce),
			thrustComparisonPercentage
		)
	end
	local noisePercentage = mathutil.mapClamp(vehicleData.noise, ranges.noiseScoreRange[1], ranges.noiseScoreRange[2], 1, 0)
	local noiseComparisonPercentage = comparisonData and mathutil.mapClamp(comparisonData.noise, ranges.noiseScoreRange[1], ranges.noiseScoreRange[2], 1, 0) or nil
	rowsLeft[#rowsLeft + 1] = vehicle_store_util.makeVehicleProgressBarRow(
		"::/gui/line_vehicle_mgmt/icons/symbol_noise.tga",
		_("Noise"),
		noisePercentage,
		vehicle_store_util.goodnessToTextString(noisePercentage),
		noiseComparisonPercentage
	)
	local pollutionPercentage = mathutil.mapClamp(vehicleData.pollution, ranges.pollutionScoreRange[1], ranges.pollutionScoreRange[2], 1, 0)
	local pollutionComparisonPercentage = comparisonData and mathutil.mapClamp(comparisonData.pollution, ranges.pollutionScoreRange[1], ranges.pollutionScoreRange[2], 1, 0) or nil
	rowsLeft[#rowsLeft + 1] = vehicle_store_util.makeVehicleProgressBarRow(
		"::/gui/line_vehicle_mgmt/icons/symbol_pollution.tga",
		_("Pollution"),
		pollutionPercentage,
		vehicle_store_util.goodnessToTextString(pollutionPercentage),
		pollutionComparisonPercentage
	)
	if vehicleData.passengers and vehicleData.comfortFactor > 0 or param.showAllStats then
		local comfortFactorPercentage = mathutil.mapClamp(vehicleData.comfortFactor, ranges.comfortScoreRange[1], ranges.comfortScoreRange[2], 0, 1)
		local comfortComparisonPercentage = comparisonData and mathutil.mapClamp(comparisonData.comfortFactor, ranges.comfortScoreRange[1], ranges.comfortScoreRange[2], 0, 1) or nil
		rowsLeft[#rowsLeft + 1] = vehicle_store_util.makeVehicleProgressBarRow(
			"::/gui/line_vehicle_mgmt/icons/symbol_person_comfort.tga",
			_("Comfort"),
			comfortFactorPercentage,
			vehicle_store_util.goodnessToTextString(comfortFactorPercentage),
			comfortComparisonPercentage
		)
	elseif not param.showAllStats then
		rowsLeft[#rowsLeft + 1] = vehicle_store_util.makeVehiclePropertyPlaceholder()
	end


	local rowsRight : { TreeNodeId } = {}
	rowsRight[#rowsRight + 1] = vehicle_store_util.makeVehiclePropertyRow(
		_("Weight"),
		formatDelta(vehicleData.weight, comparisonData and comparisonData.weight or nil, api.util.formatWeight),
		"::/gui/line_vehicle_mgmt/icons/symbol_weight.tga",
		vehicleData.weight,
		comparisonData and comparisonData.weight or nil,
		false
	)
	rowsRight[#rowsRight + 1] = vehicle_store_util.makeVehiclePropertyRow(
		_("Length"),
		formatDelta(vehicleData.length, comparisonData and comparisonData.length or nil, api.util.formatLength),
		"::/gui/line_vehicle_mgmt/icons/relation_train_length.tga",
		vehicleData.length,
		comparisonData and comparisonData.length or nil,
		false
	)
	if vehicleData.tractiveEffort > 0 or param.showAllStats then
		rowsRight[#rowsRight + 1] = vehicle_store_util.makeVehiclePropertyRow(
			_("Tractive Effort"),
			formatDelta(vehicleData.tractiveEffort, comparisonData and comparisonData.tractiveEffort or nil, api.util.formatForce),
			"::/gui/line_vehicle_mgmt/icons/symbol_arrow_circle_dot.tga",
			vehicleData.tractiveEffort,
			comparisonData and comparisonData.tractiveEffort or nil
		)
	end
	if vehicleData.thrust > 0 then
		rowsRight[#rowsRight + 1] = vehicle_store_util.makeVehiclePropertyRow(
			_("Thrust"),
			formatDelta(vehicleData.thrust, comparisonData and comparisonData.thrust or nil, api.util.formatForce),
			"::/gui/line_vehicle_mgmt/icons/thrust.tga",
			vehicleData.thrust,
			comparisonData and comparisonData.thrust or nil
		)
	end
	if (not hasPowerOnLeft and vehicleData.power > 0 and not (vehicleData.thrust > 0)) or (param.showAllStats and not (vehicleData.thrust > 0)) then
		rowsRight[#rowsRight + 1] = vehicle_store_util.makeVehiclePropertyRow(
			_("Power"),
			formatDelta(vehicleData.power, comparisonData and comparisonData.power or nil, api.util.formatPower),
			"::/gui/line_vehicle_mgmt/icons/symbol_chain_drive.tga",
			vehicleData.power,
			comparisonData and comparisonData.power or nil
		)
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			builtin.BoxLayout{
				orientation = builtin.type.Orientation.Vertical,
				children = rowsLeft,
			},
			builtin.BoxLayout{
				orientation = builtin.type.Orientation.Vertical,
				children = rowsRight,
			},
		},
	}
end)

local record VehicleDescriptionParam
	elem : VehicleStoreUtil.Element
end

local VehicleDescription = react.RegisterRecipe("VehicleDescription", function(param : VehicleDescriptionParam) : TreeNodeId
	if param.elem == nil or param.elem.static == nil then
		return nil
	end

	local text : string = nil
	if param.elem.static.multipleUnit then
		local mu = api.res.multipleUnitRep.get(param.elem.static.repId)
		text = mu.desc
	else
		local model : Model = api.res.modelRep.get(param.elem.static.repId)
		local desc = model.metadata["description"] as ModelMetadata.Description
		text = desc.description
	end

	if text == "" then
		text = _("No Description")
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			builtin.Component{
				layout = builtin.BoxLayout{
					children = {
						builtin.ScrollArea{
							content = builtin.TextView{
								meta = {
									class = "font-scale-body",
								},
								text = text,
							},
							horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
							verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
						},
					},
				},
			},
		},
	}
end)

-- ===== end of copy =====

-- vanilla VehicleStats without the color picker button
local record VehicleStatsParam
	elem : VehicleStoreUtil.Element
end

local VehicleStats = react.RegisterRecipe("VehicleStats", function(param : VehicleStatsParam) : TreeNodeId
	if param.elem == nil then
		return nil
	end
	return builtin.FloatingLayout{
		children = {
			builtin.FloatingLayoutChild{
				h = -1,
				v = -1,
				item = VehicleStatsTable{
					ranges = param.elem.dynamic.ranges,
					vehicleData = param.elem.static.vehicleData,
				},
			},
		},
	}
end)

-- store list element for a model / multiple unit, as in VehicleStoreEntryPoint (vehicle_store_window.tl)
local function makeElement(repId : integer, multipleUnit : boolean) : VehicleStoreUtil.Element
	local vehicleData = vehicle_store_util.makeVehicleData(repId, multipleUnit)
	local nameAndIcon = vehicle_store_util.getVehicleNameAndIcons(repId, multipleUnit, false)
	local vehicles : {VehicleStoreUtil.Vehicle}
	if multipleUnit then
		vehicles = vehicle_store_util.makeMultipleVehicles(api.res.multipleUnitRep.get(repId))
	else
		vehicles = { vehicle_store_util.makeSingleVehicle(api.res.modelRep.get(repId)) }
	end
	local carriersMap : {Carrier : boolean} = {}
	local transportModes : {TransportMode : boolean} = {}
	local carrier : Carrier = nil
	for __, v in ipairs(vehicles) do
		carriersMap[v.tv.carrier] = true
		carrier = carrier or v.tv.carrier
		for __, tm in ipairs(v.tv.transportModes) do
			transportModes[tm as TransportMode] = true
		end
	end
	local year = math.max(vehicleData.yearFrom or 0, api.engine.util.getYear())
	return {
		static = {
			repId = repId,
			multipleUnit = multipleUnit,
			icons = nameAndIcon.icons,
			iconsBlend = nameAndIcon.iconsBlend,
			iconOrientations = nameAndIcon.iconOrientations,
			name = nameAndIcon.name,
			names = nameAndIcon.names,
			vehicleData = vehicleData,
			carriersMap = carriersMap,
			transportModes = transportModes,
		},
		dynamic = {
			-- bars use the ranges of the model's release year (for future models, their era)
			ranges = vehicle_store_util.getRangesFromData(vehicleData, carrier or api.type["enum"].Carrier.ROAD, year),
		},
	}
end

local function cargoCurrentlyProduced() : {CargoTypeId : boolean}
	local result : {CargoTypeId : boolean} = {}
	for cargoTypeId, __ in pairs(api.res.cargoTypeRep.getAll()) do
		result[cargoTypeId] = api.engine.util.stock.isCargoTypeCurrentlyProduced(cargoTypeId)
	end
	return result
end

-- same as the "no comparison" branch of the vanilla VehicleStoreDetails: image, stats, description
local VehicleStoreDetails = react.RegisterRecipe("VehicleStoreDetails", function(params : VehicleDetails.DetailsParams) : TreeNodeId
	local elem = react.useRefLazy(function() : VehicleStoreUtil.Element
		return makeElement(params.repId, params.multipleUnit)
	end):get() as VehicleStoreUtil.Element
	local produced = react.useRefLazy(cargoCurrentlyProduced):get() as {CargoTypeId : boolean}
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = {
			LargeImage({ elem = elem, allCargoCurrentlyProduced = produced }),
			VehicleStats({ elem = elem }),
			builtin.Component{
				meta = { class = "description-or-variants" },
				layout = builtin.BoxLayout{ child = VehicleDescription({ elem = elem }) },
			},
		},
	}
end)

local vehicle_details : VehicleDetails = {}
vehicle_details.Details = VehicleStoreDetails
return vehicle_details

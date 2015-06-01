--include=..\..\Common\Scripts\CTA ATC.lua
--include=..\..\Common\Scripts\CTA ATO.lua
--include=..\..\..\..\Common\Scripts\CTA Util.lua

------------------------------------------------------------
-- Simulation file for the Bombardier CTA 5000-series EMU
------------------------------------------------------------
--
-- (c) briman0094 2015
--
------------------------------------------------------------

function Setup()

-- For throttle/brake control.

	gLastDoorsOpen = 0
	gSetReg = 0
	gSetDynamic = 0
	gSetBrake = 0
	gLastSpeed = 0
	gTimeDelta = 0
	gCurrent = 0
	gLastReverser = 0
	gDestSignNext = false
	gDestSignPrev = false
	
	gStoppingTime = 0
	gTimeSinceWheelslip = 0.0
	MAX_STOPPING_TIME = 4.0
	tReg = 0
	tBrake = 0
	
	REG_DELTA = 0.7
	DYN_DELTA = 0.7
	BRK_DELTA = 0.45
	
	MAX_ACCELERATION = 1.0
	MIN_ACCELERATION = 0.125
	MAX_BRAKING = 1.0
	MIN_BRAKING = 0.2
	JERK_LIMIT = 0.90
	SMOOTH_STOP_ACCELERATION = 0.25
	SMOOTH_STOP_CORRECTION = 1.0 / 16.0
	MAX_BRAKE_RELEASE = 0.755
	MAX_SERVICE_BRAKE = 0.875
	--MIN_SERVICE_BRAKE = 0.275
	MIN_SERVICE_BRAKE = 0.0
	MAX_CORRECTION = 1.0 - MAX_BRAKE_RELEASE
	DYNAMIC_BRAKE_AMPS = 500.0
	DYNBRAKE_MAXCARS = 8 -- Number of cars that the dynamic brake force is calibrated to (WTF railworks, you can't do this yourself?)
	
-- Propulsion system variables
	realAccel = 0.0
	tAccel = 0.0
	tTAccel = 0.0
	tThrottle = 0.0
	dDyn = 0.0
	dReg = 0.0
	dBrk = 0.0
	dAccel = 0.0
	MAX_BRAKE = 1.0
	gThrottleTime = 0.0
	gAvgAccel = 0.0
	gAvgAccelTime = 0.0
	gBrakeRelease = 0.0
	brkAdjust = 0.0
	gSign = 0
	gLastAccelSign = 0
	gDAccel = 0

-- For controlling delayed doors interlocks.
	DOORDELAYTIME = 9 -- seconds.
	gDoorsDelay = DOORDELAYTIME
end

------------------------------------------------------------
-- Update
------------------------------------------------------------
-- Called every frame to update the simulation
------------------------------------------------------------
-- Parameters:
--	interval = time since last update
------------------------------------------------------------

function Update(interval)
	local rInterval = round(interval, 5)
	--gTimeDelta = gTimeDelta + rInterval
	gTimeDelta = interval

	if Call( "*:GetControlValue", "Active", 0 ) == 1 then -- This is lead engine.

		if Call( "IsExpertMode" ) == TRUE then -- Expert mode only.

			CombinedLever = Call( "*:GetControlValue", "ThrottleAndBrake", 0 )
			ReverserLever = Call( "*:GetControlValue", "Reverser", 0 )
			TrackBrake = Call( "*:GetControlValue", "TrackBrake", 0 )
			DoorsOpen = Call( "*:GetControlValue", "DoorsOpenCloseRight", 0 ) + Call( "*:GetControlValue", "DoorsOpenCloseLeft", 0 )
			PantoValue = Call( "*:GetControlValue", "PantographControl", 0 )
			ThirdRailValue = Call( "*:GetControlValue", "ThirdRail", 0 )
			TrainSpeed = Call( "*:GetControlValue", "SpeedometerMPH", 0 )
			BrakeCylBAR = Call( "*:GetControlValue", "TrainBrakeCylinderPressureBAR", 0 )
			ATCBrakeApplication = Call( "*:GetControlValue", "ATCBrakeApplication", 0 )
			IsEndCar = Call( "*:GetControlValue", "IsEndCar", 0 ) > 0
			NumCars = Call( "*:GetControlValue", "NumCars", 0 )
			NumCarsOnPower = Call( "*:GetControlValue", "NumCarsOnPower", 0 )
			ATOEnabled = (Call( "*:GetControlValue", "ATOEnabled", 0 ) or -1) > 0.5
			ATOThrottle = (Call( "*:GetControlValue", "ATOThrottle", 0 ) or -1)
			
			DestSignNext = Call( "*:GetControlValue", "DestSignNext", 0 ) > 0
			DestSignPrev = Call( "*:GetControlValue", "DestSignPrev", 0 ) > 0
			DestSign     = Call( "*:GetControlValue", "DestinationSign", 0 )
			
			if (DestSignNext and DestSign < Call("*:GetControlMaximum", "DestinationSign", 0)) then
				if (not gDestSignNext) then
					gDestSignNext = true
					DestSign = math.floor(DestSign + 1)
				end
			else
				gDestSignNext = false
			end
			
			if (DestSignPrev and DestSign > 0) then
				if (not gDestSignPrev) then
					gDestSignPrev = true
					DestSign = math.floor(DestSign - 1)
				end
			else
				gDestSignPrev = false
			end
			
			Call( "*:SetControlValue", "DestinationSign", 0, DestSign )

			if (math.abs(ReverserLever) >= 0.95) then
				gLastReverser = sign(ReverserLever)
			else
				if (TrainSpeed > 0.1) then
					Call( "*:SetControlValue", "Reverser", 0, gLastReverser )
				end
			end
			
			-- Make script think doors are still open while the animation is finishing
			if ( gLastDoorsOpen == TRUE ) and ( DoorsOpen == FALSE ) then
				gDoorsDelay = gDoorsDelay - gTimeDelta
				if gDoorsDelay < 0 then
					gDoorsDelay = DOORDELAYTIME
				else
					DoorsOpen = TRUE
				end
			end
			Call( "*:SetControlValue", "DoorsOpen", 0, math.min(DoorsOpen, 1) )
		
			-- Begin propulsion system
			realAccel = (TrainSpeed - gLastSpeed) / gTimeDelta
			gAvgAccel = gAvgAccel + (TrainSpeed - gLastSpeed)
			gAvgAccelTime = gAvgAccelTime + gTimeDelta
			-- Average out acceleration
			if (gAvgAccelTime >= 1/15) then
				Call( "*:SetControlValue", "Acceleration", 0, round(gAvgAccel / gAvgAccelTime, 2) )
				gAvgAccelTime = 0.0
				gAvgAccel = 0.0
			end
			
			gCurrent = Call( "*:GetControlValue", "Ammeter", 0 )
			
			-- Set throttle based on ATO or not
			if ATOEnabled then
				tThrottle = ATOThrottle
				Call( "*:SetControlValue", "ThrottleLever", 0, 0 )
			else
				tThrottle = CombinedLever * 2.0 - 1.0
				Call( "*:SetControlValue", "ThrottleLever", 0, CombinedLever )
			end
			
			-- Round throttle to 0 if it's below 10% power/brake; widens "coast" gap
			if (math.abs(tThrottle) < 0.1 and not ATOEnabled) then
				tThrottle = 0.0
			end
			
			if (tThrottle >= 0.1) then -- Accelerating; bind range to [ MIN_ACCELERATION, MAX_ACCELERATION ]
				tTAccel = mapRange(tThrottle, 0.1, 0.9, MIN_ACCELERATION, MAX_ACCELERATION)
			elseif (tThrottle <= -0.1) then -- Braking; bind range to [ MIN_BRAKING, MAX_BRAKING ]
				tTAccel = -mapRange(-tThrottle, 0.1, 0.9, MIN_BRAKING, MAX_BRAKING)
			else
				tTAccel = 0.0
			end
			
			-- If requesting acceleration and stopped, release brakes instantly
			if (tTAccel >= 0 and math.abs(TrainSpeed) < 0.1) then
				tAccel = math.max(tAccel, 0.0)
			end
			
			tJerkLimit = 0
			
			if (tAccel < tTAccel) then -- Increase slowly
				tJerkLimit = JERK_LIMIT * clamp((tTAccel - tAccel) / 0.375, 0.0, 1.0)
			elseif (tAccel > tTAccel) then -- Decrease slowly
				tJerkLimit = -JERK_LIMIT * clamp((tAccel - tTAccel) / 0.375, 0.0, 1.0)
			end
			
			if (gDAccel < tJerkLimit) then
				gDAccel = gDAccel + (0.9 * gTimeDelta)
			elseif (gDAccel > tJerkLimit) then
				gDAccel = gDAccel - (0.9 * gTimeDelta)
			end
			
			if (math.abs(TrainSpeed) < 0.1 and BrakeCylBAR > 0.005 and tAccel > 0.0) then
				gDAccel = 0.0
			end
			
			tAccel = tAccel + (gDAccel * gTimeDelta)
			
			-- ATC took over braking due to control timeout
			if (ATCBrakeApplication > 0) then
				tAccel = -1 -- Instant max braking
				tThrottle = -1 -- Force 100% Braking throttle input
				gSetReg = 0.0 -- Drop power instantly
				gThrottleTime = 100 -- Override "propulsion adjustment" period
			end
			
			Call( "*:SetControlValue", "TAccel", 0, tAccel)
			
			-- Max application of dynamic brake based on #cars in consist
			local dynBrakeMax = clamp(NumCars / DYNBRAKE_MAXCARS, 0.0, 1.0)
			
			-- Parked or track brake engaged
			if (math.abs(ReverserLever) < 0.9 or TrackBrake > 0) then
				Call( "*:SetControlValue", "Regulator", 0, 0.0 )
				Call( "*:SetControlValue", "DynamicBrake", 0, dynBrakeMax )
				dynEffective = clamp(math.abs(gCurrent) / (DYNAMIC_BRAKE_AMPS * dynBrakeMax), 0, 1)
				Call( "*:SetControlValue", "TrainBrakeControl", 0, 0.5 + ((1.0 - dynEffective) * 0.5) )
				if (TrackBrake > 0) then
					Call( "*:SetControlValue", "Sander", 0, 1 )
					Call( "*:SetControlValue", "HandBrake", 0, 1 )
					tAccel = math.min(tAccel, 0.0)
				else
					Call( "*:SetControlValue", "Sander", 0, 0 )
					Call( "*:SetControlValue", "HandBrake", 0, 0 )
				end
				gSetReg = 0.0
				gSetDynamic = 0.0
				gSetBrake = 0.0
				brkAdjust = MAX_CORRECTION
				gStoppingTime = MAX_STOPPING_TIME
				if (math.abs(ReverserLever) < 0.9) then
					Call( "*:SetControlValue", "ThrottleAndBrake", 0, -1.0 )
				end
			else
				Call( "*:SetControlValue", "Sander", 0, 0 )
				Call( "*:SetControlValue", "HandBrake", 0, 0 )
				
				-- Cancel smooth-stop if train takes too long to stop
				if (math.abs(TrainSpeed) < 3.0 and not ATOEnabled) then
					gStoppingTime = gStoppingTime + gTimeDelta
				else
					gStoppingTime = 0
					brkAdjust = 0.0
				end
				
				if (math.abs(tAccel) > 0.05) then
					local tAccelSign = sign(tAccel)
					if (tAccelSign ~= gLastAccelSign) then
						gThrottleTime = 0.0
					end
					gLastAccelSign = tAccelSign
				end
				
				if (BrakeCylBAR > 0.005 and tAccel > 0) then
					gThrottleTime = 0.0
				end
				
				if (gThrottleTime < 0.125) then
					gThrottleTime = gThrottleTime + gTimeDelta
					tAccel = 0.01 * gLastAccelSign
					gDAccel = 0.0
				end
				
				if (DoorsOpen == TRUE) then
					gSetReg = 0.0
					gSetDynamic = 0.0
					gSetBrake = 0.95
					brkAdjust = MAX_CORRECTION
				else
					if (math.abs(tAccel) < 0.01) then
						gSetReg = 0.0
						gSetDynamic = 0.0
						gSetBrake = 0.0
					else
						gSetReg = clamp(tAccel, 0.0, 1.0)
						gSetDynamic = clamp(-tAccel, 0.0, 1.0)
						
						dynEffective = clamp(-gCurrent / math.max(DYNAMIC_BRAKE_AMPS * dynBrakeMax * gSetDynamic, 0.001) + 0.05, 0.0, 1.0)
						gSetBrake = mapRange(gSetDynamic * (1.0 - dynEffective), 0.0, 1.0, MIN_SERVICE_BRAKE, MAX_SERVICE_BRAKE)
						
						if (math.abs(TrainSpeed) < 2.5 and tThrottle < 0) then
							if (gStoppingTime < MAX_STOPPING_TIME) then
								gBrakeRelease = clamp((2.75 - math.abs(TrainSpeed)) / 1.75, 0.0, 1.0)
								gSetBrake = gSetBrake - (gBrakeRelease * MAX_BRAKE_RELEASE * gSetBrake)
							end
						end
					end
					
					
					--[[dReg = REG_DELTA * gTimeDelta
					dDyn = DYN_DELTA * gTimeDelta
					dBrk = BRK_DELTA * gTimeDelta
					
					-- Coast command
					if (math.abs(tThrottle) <= 0.01) then
						if (gSetBrake > dBrk) then
							gSetBrake = clamp(gSetBrake - dBrk, 0.0, 1.0)
						else
							gSetBrake = 0.0
						end
						
						if (BrakeCylBAR < 0.005) then
							if (gSetDynamic > dDyn) then
								gSetDynamic = clamp(gSetDynamic - dDyn, 0.0, 1.0)
							else
								gSetDynamic = 0.0
							end
						end
						
						if (gSetReg > dReg) then
							gSetReg = clamp(gSetReg - dReg, 0.0, 1.0)
						else
							gSetReg = 0.0
						end
						
						brkAdjust = 0.0
						gThrottleTime = 0.0
					else
						-- Requesting acceleration
						if (tThrottle >= 0.01) then
							if (gSetBrake > dBrk) then
								if (math.abs(TrainSpeed) < 0.1) then -- Release brakes instantly from a standstill
									gSetBrake = 0.0
								else
									gSetBrake = clamp(gSetBrake - dBrk, 0.0, 1.0)
								end
							else
								gSetBrake = 0.0
							end
							
							if (BrakeCylBAR < 0.001) then
								if (gSetDynamic > dDyn) then
									if (math.abs(TrainSpeed) < 0.1) then -- Release brakes instantly from a standstill
										gSetDynamic = 0.0
									else
										gSetDynamic = clamp(gSetDynamic - dDyn, 0.0, 1.0)
									end
								else
									gSetDynamic = 0.0
								end
							end
							
							if (gSetBrake < 0.001 and BrakeCylBAR < 0.001 and gSetDynamic < 0.001) then
								if (gThrottleTime >= 0.125) then
									if (Call("*:GetControlValue", "Wheelslip", 0) > 1) then
										gTimeSinceWheelslip = 0.0
									end
									
									if (gTimeSinceWheelslip < 1.0) then
										tAccel = math.min(tAccel, 0.6)
										gTimeSinceWheelslip = gTimeSinceWheelslip + gTimeDelta
									end
								
									gSetReg = clamp(tAccel, 0.0, 1.0)
								else
									tAccel = math.min(tAccel, 0.0)									
									if (math.abs(tAccel) < 0.01) then
										gThrottleTime = gThrottleTime + gTimeDelta
									end
								end
							else
								gSetReg = 0.0
								gThrottleTime = 0.0
							end
						elseif (tThrottle < 0.01) then
							if (gSetReg > dReg) then
								gSetReg = clamp(gSetReg - dReg, 0.0, 1.0)
							else
								gSetReg = 0.0
							end
							
							if (gSetReg < 0.001) then
								if (gThrottleTime >= 0.125) then
									dynEffective = -(gCurrent / ((DYNAMIC_BRAKE_AMPS * clamp(NumCars / DYNBRAKE_MAXCARS, 0.0, 1.0)) * -tAccel))
									
									if (Call("*:GetControlValue", "Wheelslip", 0) > 1) then
										gTimeSinceWheelslip = 0.0
									end
									
									if (gTimeSinceWheelslip < 1.0) then
										tAccel = math.max(tAccel, -0.6)
										dynEffective = 0.0
										gTimeSinceWheelslip = gTimeSinceWheelslip + gTimeDelta
									end
								
									gSetDynamic = -tAccel
									--gSetDynamic = 0.15
									gSetBrake = (-(tAccel * (1.0 - dynEffective)) * (MAX_SERVICE_BRAKE - MIN_SERVICE_BRAKE)) + MIN_SERVICE_BRAKE
									if (math.abs(TrainSpeed) < 2.5 and tTAccel < 0 and gStoppingTime < MAX_STOPPING_TIME) then
										gBrakeRelease = clamp((2.75 - math.abs(TrainSpeed)) / 1.75, 0.0, 1.0)
										gSetBrake = gSetBrake - (gBrakeRelease * MAX_BRAKE_RELEASE * gSetBrake)
									end
								else
									tAccel = math.max(tAccel, 0.0)
									if (math.abs(tAccel) < 0.01) then
										gThrottleTime = gThrottleTime + gTimeDelta
									end
								end
							else
								gSetDynamic = 0.0
								gSetBrake = 0.0
								gThrottleTime = 0.0
							end
						end
					end]]
				end
				
				local finalRegulator = gSetReg
				
				if (gSetDynamic < 0.001 and math.abs(TrainSpeed) > 0.1 and tAccel >= 0.0) then
					finalRegulator = math.max(finalRegulator, 0.001) -- Make it so it doesn't reach 0. This way we know if we have power or not by the ammeter value
				end
				
				finalRegulator = finalRegulator * (NumCarsOnPower / NumCars)
				
				Call( "*:SetControlValue", "Regulator", 0, finalRegulator)
				Call( "*:SetControlValue", "DynamicBrake", 0, gSetDynamic * clamp(NumCars / DYNBRAKE_MAXCARS, 0.0, 1.0) )
				Call( "*:SetControlValue", "TrainBrakeControl", 0, gSetBrake )
				Call( "*:SetControlValue", "TrueThrottle", 0, tThrottle )
			end

			-- End propulsion system
			
			-- Begin ATC system
			
			if UpdateATC then
				UpdateATC(gTimeDelta)
			end
			
			if UpdateATO then
				UpdateATO(gTimeDelta)
			end
			
			-- End ATC system

			if ( DoorsOpen ~= FALSE ) then
				Call( "*:SetControlValue", "Regulator", 0, 0 )
			end

			gLastDoorsOpen = DoorsOpen
			gLastSpeed = TrainSpeed
			gTimeDelta = 0
		end
	else -- trail engine.
	
	end
end

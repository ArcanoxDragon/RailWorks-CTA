local debugFile = io.open("lua_debug.log", "w+")
local pi = 3.14159265
local SIGNAL_STATE_SPEED = 20

function debugPrint(msg)
	Print(msg)
	debugFile:seek("end", 0)
	debugFile:write(msg .. "\n")
	debugFile:flush()
end

function clamp(x, xMin, xMax)
	return math.min(math.max(x, xMin), xMax)
end

function round(num, precision)
	local mult = 10 ^ (precision or 0)
	return math.floor(num * mult + 0.5) / mult
end

function sign(num)
	if (num > 0) then return 1 end
	if (num < 0) then return -1 end
	return 0
end

------------------------------------------------------------
-- Simulation file for the Bombardier CTA 5000-series EMU
------------------------------------------------------------
--
-- (c) briman0094 2015
--
------------------------------------------------------------

	TRUE = 1
	FALSE = 0


function Setup()

-- For throttle/brake control.

	gEmergencyAWSSet = 0
	gLastDoorsOpen = 0
	gSetReg = 0
	gSetDynamic = 0
	gSetBrake = 0
	gLastSpeed = 0
	gTimeDelta = 0
	gCurrent = 0
	gLastReverser = 0
	
	gStoppingTime = 0
	MAX_STOPPING_TIME = 4.0
	tReg = 0
	tBrake = 0
	
	REG_DELTA = 0.7
	DYN_DELTA = 0.7
	BRK_DELTA = 0.45
	
	gTimeSinceDyn = 0.0
	gDynOn = false
	DYN_ENGAGE_TIME = 0.0
	
	MAX_ACCELERATION = 1.0
	MIN_ACCELERATION = 0.1
	MAX_BRAKING = 1.0
	MIN_BRAKING = 0.1
	JERK_LIMIT = 0.7
	SMOOTH_STOP_ACCELERATION = 0.25
	SMOOTH_STOP_CORRECTION = 1.0 / 16.0
	MAX_BRAKE_RELEASE = 0.65
	MAX_SERVICE_BRAKE = 0.875
	MAX_CORRECTION = 1.0 - MAX_BRAKE_RELEASE
	DYNAMIC_BRAKE_AMPS = 500.0
	
	-- Default:
	--TARGET_ACCELERATION = 2.10
	
-- Propulsion system variables
	realAccel = 0.0
	tAccel = 0.0
	tTAccel = 0.0
	tThrottle = 0.0
	gLastSigDist = 0
	dDyn = 0.0
	dReg = 0.0
	dBrk = 0.0
	dAccel = 0.0
	MAX_BRAKE = 1.0
	gThrottleTime = 0.0
	gAvgAccel = 0.0
	gAvgAccelTime = 0.0
	gBrakeRelease = 0.0
	
	MIN_THROTTLE = 0.1
	SLOW_MIN = 0.2 -- Minimum acceleration at min throttle below 10MPH
	tMin = 0.0
	tThrtl = 0.0
	brkAdjust = 0.0
	
	gWhine = 0.0

-- For controlling delayed doors interlocks.
	DOORDELAYTIME = 5 -- seconds.
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

function Update ( interval )

	local rInterval = round(interval, 4)
	gTimeDelta = gTimeDelta + rInterval

	if Call( "*:GetControlValue", "Active", 0 ) == 1 then -- This is lead engine.

		if Call( "IsExpertMode" ) == TRUE then -- Expert mode only.

			CombinedLever = Call( "*:GetControlValue", "ThrottleAndBrake", 0 )
			ReverserLever = Call( "*:GetControlValue", "Reverser", 0 )
			TrackBrake = Call( "*:GetControlValue", "TrackBrake", 0 )
			Emergency = Call( "*:GetControlValue", "EmergencyBrake", 0 ) or 0.0
			DoorsOpen = Call( "*:GetControlValue", "DoorsOpenCloseRight", 0 ) + Call( "*:GetControlValue", "DoorsOpenCloseLeft", 0 )
			PantoValue = Call( "*:GetControlValue", "PantographControl", 0 )
			ThirdRailValue = Call( "*:GetControlValue", "ThirdRail", 0 )
			TrainSpeed = Call( "*:GetControlValue", "SpeedometerMPH", 0 )
			BrakeCylBAR = Call( "*:GetControlValue", "TrainBrakeCylinderPressureBAR", 0 )

	-- Override brake if emergency has been set.

			if Emergency == 1 then
				gEmergencyAWSSet = 1
			end
			
			if (math.abs(ReverserLever) >= 0.95) then
				gLastReverser = sign(ReverserLever)
			else
				if (TrainSpeed > 0.1) then
					Call( "*:SetControlValue", "Reverser", 0, gLastReverser )
				end
			end
			
			if (gTimeDelta >= 0.025) then
				-- Allow for delay in closing doors.
				if ( gLastDoorsOpen == TRUE ) and ( DoorsOpen == FALSE ) then
					gDoorsDelay = gDoorsDelay - gTimeDelta
					if gDoorsDelay < 0 then
						gDoorsDelay = DOORDELAYTIME
					else
						DoorsOpen = TRUE
					end
				end
			
				-- Begin propulsion system

				realAccel = (TrainSpeed - gLastSpeed) / gTimeDelta
				gAvgAccel = gAvgAccel + (TrainSpeed - gLastSpeed)
				gAvgAccelTime = gAvgAccelTime + gTimeDelta
				if (gAvgAccelTime >= 1.0) then
					gAvgAccelTime = 0.0
					Call( "*:SetControlValue", "Acceleration", 0, round(gAvgAccel, 2) )
					gAvgAccel = 0.0
				end
				gCurrent = Call( "*:GetControlValue", "Ammeter", 0 )
				
				tThrottle = CombinedLever * 2.0 - 1.0
				if (math.abs(tThrottle) < 0.1) then
					tThrottle = 0.0
				end
				
				if (tThrottle > 0.001) then
					tTAccel = ((tThrottle - 0.1) / 0.9) * (MAX_ACCELERATION - MIN_ACCELERATION) + MIN_ACCELERATION
				elseif (tThrottle < -0.001) then
					tTAccel = -(((-tThrottle - 0.1) / 0.9) * (MAX_BRAKING - MIN_BRAKING) + MIN_BRAKING)
				else
					tTAccel = 0.0
				end
				
				if (math.abs(TrainSpeed) < 0.075 and tThrottle > 0) then
					tAccel = math.max(tAccel, 0.0)
				end
				
				dAccel = JERK_LIMIT * gTimeDelta
				
				if (tAccel < 0 and tTAccel >= 0 and math.abs(TrainSpeed) < 0.1) then
					tAccel = 0
				end
				
				if (tAccel < tTAccel - dAccel) then
					tAccel = tAccel + dAccel
				elseif (tAccel > tTAccel + dAccel) then
					tAccel = tAccel - dAccel
				else
					tAccel = tTAccel
				end
				Call( "*:SetControlValue", "TAccel", 0, tAccel)
				
				if (math.abs(ReverserLever) < 0.9 or TrackBrake > 0) then
					Call( "*:SetControlValue", "Regulator", 0, 0.0 )
					Call( "*:SetControlValue", "DynamicBrake", 0, 1.0 )
					Call( "*:SetControlValue", "TrainBrakeControl", 0, 1.0 )
					gSetReg = 0.0
					gSetDynamic = 0.0
					gSetBrake = 0.0
					brkAdjust = MAX_CORRECTION
					gStoppingTime = MAX_STOPPING_TIME
					Call( "*:SetControlValue", "ThrottleAndBrake", 0, -1.0 )
				else
					if (math.abs(TrainSpeed) < 3.0) then
						gStoppingTime = gStoppingTime + gTimeDelta
					else
						gStoppingTime = 0
						brkAdjust = 0.0
					end
					
					if (DoorsOpen == TRUE) then
						gSetReg = 0.0
						gSetDynamic = 0.0
						gSetBrake = 0.95
						brkAdjust = MAX_CORRECTION
					else
						dReg = REG_DELTA * gTimeDelta
						dDyn = DYN_DELTA * gTimeDelta
						dBrk = BRK_DELTA * gTimeDelta
						if (math.abs(tThrottle) < 0.01) then
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
						else
							if (tThrottle >= 0.0) then
								if (gSetBrake > dBrk) then
									if (math.abs(TrainSpeed) < 0.1) then -- Release brakes instantly from a standstill
										gSetBrake = 0.0
									else
										gSetBrake = clamp(gSetBrake - dBrk, 0.0, 1.0)
									end
									gThrottleTime = 0.0
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
										gThrottleTime = 0.0
									else
										gSetDynamic = 0.0
									end
								end
								
								if (gSetBrake < 0.001 and BrakeCylBAR < 0.001 and gSetDynamic < 0.001 and gThrottleTime >= 0.5) then
									gSetReg = clamp(tAccel, 0.0, 1.0)
								else
									gSetReg = 0.0
									tAccel = math.min(tAccel, 0.0)
									gThrottleTime = gThrottleTime + gTimeDelta
								end
							else
								if (gSetReg > dReg) then
									gSetReg = clamp(gSetReg - dReg, 0.0, 1.0)
									gThrottleTime = 0.0
								else
									gSetReg = 0.0
								end
								
								if (gSetReg < 0.001 and gThrottleTime >= 0.5) then
									--gSetDynamic = -tAccel
									gSetDynamic = 0.15
									dynEffective = -(gCurrent / (DYNAMIC_BRAKE_AMPS * -tAccel))
									gSetBrake = (-(tAccel * (1.0 - dynEffective)) * (MAX_SERVICE_BRAKE - 0.275)) + 0.275
									if (math.abs(TrainSpeed) < 2.5 and tTAccel < 0 and gStoppingTime < 3.0) then
										gBrakeRelease = clamp((2.5 - math.abs(TrainSpeed)) / 1.0, 0.0, 1.0)
										gSetBrake = gSetBrake - (gBrakeRelease * MAX_BRAKE_RELEASE * gSetBrake)
									end
								else
									gSetDynamic = 0.0
									gSetBrake = 0.0
									tAccel = math.max(tAccel, 0.0)
									gThrottleTime = gThrottleTime + gTimeDelta
								end
							end
						end
					end
					
					if (gSetDynamic < 0.001 and math.abs(TrainSpeed) > 0.1 and tAccel >= 0.0) then
						Call( "*:SetControlValue", "Regulator", 0, math.max(gSetReg, 0.001) ) -- Make it so it doesn't reach 0. This way we know if we have power or not by the ammeter value
					else
						Call( "*:SetControlValue", "Regulator", 0, gSetReg )
					end
					Call( "*:SetControlValue", "DynamicBrake", 0, gSetDynamic )
					Call( "*:SetControlValue", "TrainBrakeControl", 0, gSetBrake )
					--Call( "*:SetControlValue", "TractionWhine", 0, math.max(gSetReg, clamp(gSetDynamic / 2.0, 0.0, 0.5)))
					--Call( "*:SetControlValue", "TractionWhine", 0, clamp(math.abs(gCurrent) / 500, 0.0, 1.0) )
					local tWhine = 1.0
					local dWhine = 1.2 * gTimeDelta
					if ( math.abs(gCurrent) < 0.0001 and tAccel >= 0.0 ) then
						tWhine = 0.0
					end
					
					if (gWhine < tWhine - dWhine) then
						gWhine = gWhine + dWhine
					elseif (gWhine > tWhine + dWhine) then
						gWhine = gWhine - dWhine
					else
						gWhine = tWhine
					end
					
					Call( "*:SetControlValue", "TractionWhine", 0, clamp(gWhine, 0.0, 1.0) )
				end

				-- End propulsion system

				if ( DoorsOpen ~= FALSE ) or (( PantoValue < 0.6 ) and ( ThirdRailValue == 0 )) then
					Call( "*:SetControlValue", "Regulator", 0, 0 )
				end

				gLastDoorsOpen = DoorsOpen
				gLastSpeed = TrainSpeed
				gTimeDelta = 0
			end
		end
	else -- trail engine.
	
	end
end

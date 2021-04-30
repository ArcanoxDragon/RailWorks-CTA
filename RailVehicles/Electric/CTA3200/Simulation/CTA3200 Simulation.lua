--include=..\..\Common\Scripts\CTA ATC.lua
--include=..\..\Common\Scripts\CTA ATO DC.lua
--include=..\..\..\..\Common\Scripts\CTA Util.lua

------------------------------------------------------------
-- Simulation file for the Morrison-Knudsen CTA 3200-series EMU
------------------------------------------------------------
--
-- ( c ) briman0094 2016
--
------------------------------------------------------------

function Setup()

-- For throttle/brake control.

	gLastDoorsOpen = 0
	gSetReg = 0
	gSetDynamic = 0
	gTargetBrake = 0
	gSetBrake = 0
	gLastSpeed = 0
	gTimeDelta = 0
	gCurrent = 0
	gLastReverser = 0
	gDestSignNext = false
	gDestSignPrev = false
	gLastTrackBrake = false
	gPrevThrottle = 0.0
	
	THROTTLE_PICKUP_SPEED = 1.0 / 2.0
	BRAKE_DELAY_TIME_COAST = 0.85
	BRAKE_DELAY_TIME_BRAKING = 0.5
	COAST_DELAY_TIME = 0.4
	DYNAMIC_FADE_DELAY = 2.5
	DYNAMIC_FADE_TIMEOUT = 3.0
	MAX_SERVICE_BRAKE = 0.825
	MIN_SERVICE_BRAKE = 0.0
	DYNAMIC_BRAKE_AMPS = 500.0
	DYNAMIC_BRAKE_MIN_FALLOFF_SPEED = 9.0
	DYNAMIC_BRAKE_MAX_FALLOFF_SPEED = 14.0
	DYNBRAKE_MAXCARS = 8 -- Number of cars that the dynamic brake force is calibrated to ( WTF railworks, you can't do this yourself? )
	ATC_REQUIRED_BRAKE = 0.7
	
-- Propulsion system variables
	realAccel = 0.0
	tReg = 0
	tBrake = 0
	tAccel = 0.0
	tTAccel = 0.0
	tThrottle = 0.0
	dDyn = 0.0
	dReg = 0.0
	dBrk = 0.0
	dAccel = 0.0
	MAX_BRAKE = 1.0
	gAvgAccel = 0.0
	gAvgAccelTime = 0.0
	gAvgAccelCalculated = 0.0
	gLastThrottle = 0.0
	gCoastDelay = 0.0
	gBrakeDelay = 0.0
	gDynamicFadeDelay = DYNAMIC_FADE_DELAY
	
-- Other misc. variables
	gRandSeeded = false

-- For controlling delayed doors interlocks.
	DOORDELAYTIME = 8.0 -- seconds.
	gDoorsDelay = DOORDELAYTIME
end

function Round( value, steps )
	return math.floor( ( value * steps ) + 0.5 ) / steps
end

------------------------------------------------------------
-- Update
------------------------------------------------------------
-- Called every frame to update the simulation
------------------------------------------------------------
-- Parameters:
--	interval = time since last update
------------------------------------------------------------

function Update( interval )
	if not gRandSeeded then
		math.randomseed( math.floor( interval * 1000 ) )
		gRandSeeded = true
	end

	local rInterval = round( interval, 5 )
	gTimeDelta = interval
	
	if ( Call( "*:GetControlValue", "Startup", 0 ) > 0 ) then
		Call( "*:SetControlValue", "ThirdRail", 0, 1 )
	else
		Call( "*:SetControlValue", "ThirdRail", 0, 0 )
	end

	if Call( "*:GetControlValue", "Active", 0 ) == 1 then -- This is lead engine.

		if Call( "IsExpertMode" ) == TRUE then -- Expert mode only.
		
			CombinedLever = Call( "*:GetControlValue", "ThrottleAndBrake", 0 )
			ReverserLever = Call( "*:GetControlValue", "Reverser", 0 )
			TrackBrake = Call( "*:GetControlValue", "TrackBrake", 0 )
			DoorsOpen = math.min( 1, Call( "*:GetControlValue", "DoorsOpenCloseRight", 0 ) + Call( "*:GetControlValue", "DoorsOpenCloseLeft", 0 ) + Call( "*:GetControlValue", "DoorsOpen", 0 ) )
			PantoValue = Call( "*:GetControlValue", "PantographControl", 0 )
			ThirdRailValue = Call( "*:GetControlValue", "ThirdRail", 0 )
			TrainSpeed = math.abs( Call( "*:GetControlValue", "SpeedometerMPH", 0 ) )
			BrakeCylBAR = Call( "*:GetControlValue", "TrainBrakeCylinderPressureBAR", 0 )
			ATCBrakeApplication = Call( "*:GetControlValue", "ATCBrakeApplication", 0 )
			IsEndCar = Call( "*:GetControlValue", "IsEndCar", 0 ) > 0
			CarNum = Call( "*:GetControlValue", "CarNum", 0 )
			NumCars = Call( "*:GetControlValue", "NumCars", 0 )
			NumCarsOnPower = Call( "*:GetControlValue", "NumCarsOnPower", 0 )
			ATOEnabled = ( Call( "*:GetControlValue", "ATOEnabled", 0 ) or -1 ) > 0.5
			ATOThrottle = ( Call( "*:GetControlValue", "ATOThrottle", 0 ) or -1 )
			Active = Call( "*:GetControlValue", "Active", 0 ) > 0
			Regulator = Call( "*:GetControlValue", "Regulator", 0 )
			
			DestSignNext = Call( "*:GetControlValue", "DestSignNext", 0 ) > 0
			DestSignPrev = Call( "*:GetControlValue", "DestSignPrev", 0 ) > 0
			DestSign     = Call( "*:GetControlValue", "DestinationSign", 0 )
			
			if ( TrackBrake > 0 ) then
				if ( not gLastTrackBrake ) then
					gPrevThrottle = math.min( CombinedLever, 0.5 )
					gLastTrackBrake = true
				end
				Call( "*:SetControlValue", "ThrottleAndBrake", 0, 0.0 )
			else
				if ( gLastTrackBrake ) then
					Call( "*:SetControlValue", "ThrottleAndBrake", 0, gPrevThrottle )
					gLastTrackBrake = false
				end
				
				if ( CombinedLever < 0.05 ) then
					Call( "*:SetControlValue", "ThrottleAndBrake", 0, 0.05 )
					CombinedLever = 0.05
				end
			end
			
			-- Destination Sign
			
			if ( DestSignNext and DestSign < Call( "*:GetControlMaximum", "DestinationSign", 0 ) ) then
				if ( not gDestSignNext ) then
					gDestSignNext = true
					DestSign = math.floor( DestSign + 1 )
				end
			else
				gDestSignNext = false
			end
			
			if ( DestSignPrev and DestSign > 0 ) then
				if ( not gDestSignPrev ) then
					gDestSignPrev = true
					DestSign = math.floor( DestSign - 1 )
				end
			else
				gDestSignPrev = false
			end
			
			Call( "*:SetControlValue", "DestinationSign", 0, DestSign )

			if ( math.abs( ReverserLever ) >= 0.95 ) then
				gLastReverser = sign( ReverserLever )
			else
				if ( TrainSpeed > 0.1 ) then
					Call( "*:SetControlValue", "Reverser", 0, gLastReverser )
				end
			end
			
			-- Begin propulsion system
			realAccel = ( TrainSpeed - gLastSpeed ) / gTimeDelta
			gAvgAccel = gAvgAccel + ( TrainSpeed - gLastSpeed )
			gAvgAccelTime = gAvgAccelTime + gTimeDelta
			
			-- Average out acceleration
			if ( gAvgAccelTime >= 1/15 ) then -- 15 times/sec
				gAvgAccelCalculated = gAvgAccel / gAvgAccelTime
				Call( "*:SetControlValue", "Acceleration", 0, round( gAvgAccelCalculated, 2 ) )
				gAvgAccelTime = 0.0
				gAvgAccel = 0.0
			end
			
			gCurrent = Call( "*:GetControlValue", "Ammeter", 0 )
			
			-- Set throttle based on ATO or not
			if ATOEnabled then
				tThrottle = math.min( ATOThrottle + 0.01, math.max( ATOThrottle - 0.025, tThrottle ) )
				Call( "*:SetControlValue", "ThrottleLever", 0, 0 )
			else
				tThrottle = CombinedLever * 2.0 - 1.0
				
				Call( "*:SetControlValue", "ThrottleLever", 0, CombinedLever )
				
				if ( Call( "*:GetControlValue", "ATCEnabled", 0 ) > 0 ) then
					local restrictedSpeed = Call( "*:GetControlValue", "ATCRestrictedSpeed", 0 )
				end
			end
			
			-- Round throttle to 0 if it's below 10% power/brake; widens "coast" gap
			if ( math.abs( tThrottle ) < 0.1 and not ATOEnabled ) then
				tThrottle = 0.0
			end
			
			if ( tThrottle > 0.01 ) then
				tTAccel = Round( tThrottle, 3 ) -- 3 points of power
			elseif ( tThrottle < -0.01 ) then
				if ( tThrottle <= -0.715 and tThrottle > -0.95 ) then
					tThrottle = -0.75
				elseif ( tThrottle <= -0.375 and tThrottle > -0.715 ) then
					tThrottle = -0.5
				end
			
				tTAccel = -Round( -tThrottle, 4 ) -- 4 points of braking
			else
				tTAccel = 0.0
			end
			
			Call( "*:SetControlValue", "DisplayThrottle", 0, ( tTAccel + 1 ) / 2 );
			
			tTAccel = clamp( tTAccel, -1.0, 1.0 )
			
			brakesApplied = BrakeCylBAR >= 0.001 or gCurrent < -5
			
			if ( not brakesApplied ) then gBrakeDelayTime = BRAKE_DELAY_TIME_COAST
			else gBrakeDelayTime = BRAKE_DELAY_TIME_BRAKING end
			
			if ( tTAccel < 0.0 ) then
				if ( gLastThrottle >= 0.0 ) then
					gCoastDelay = 0.0
				end
			
				if ( gCoastDelay < COAST_DELAY_TIME ) then
					gCoastDelay = gCoastDelay + gTimeDelta
				else
					tAccel = tTAccel
				end
				
				if ( tAccel > 0.0 or ( math.abs( tTAccel - gLastThrottle ) > 0.01 and gBrakeDelay > gBrakeDelayTime ) ) then
					gBrakeDelay = 0.0
				end
			else
				if ( gLastThrottle < 0.0 ) then
					gBrakeDelay = 0.0
				end
				
				local regDelta = gTimeDelta * THROTTLE_PICKUP_SPEED
				
				if ( tAccel <= tTAccel ) then
					if ( not brakesApplied ) then
						if ( tAccel < tTAccel - regDelta ) then
							tAccel = tAccel + regDelta
						else
							tAccel = tTAccel
						end
					else
						tAccel = math.max( tAccel, 0.0 )
					end
					
					gCoastDelay = 0.0
				elseif ( tAccel > tTAccel ) then
					if ( math.abs( tTAccel - gLastThrottle ) > 0.01 and gCoastDelay > COAST_DELAY_TIME ) then
						gCoastDelay = 0.0
					else
						if ( gCoastDelay < COAST_DELAY_TIME ) then
							gCoastDelay = gCoastDelay + gTimeDelta
						else
							tAccel = tTAccel
						end
					end
				end
			end
			
			Call( "*:SetControlValue", "BrakeDelayTime", 0, gBrakeDelay )
			Call( "*:SetControlValue", "CoastDelayTime", 0, gCoastDelay )
			
			-- ATC took over braking due to control timeout
			if ( ATCBrakeApplication > 0 ) then
				tAccel = -0.75 -- Instant max braking
				tThrottle = math.min( tThrottle, -0.75 ) -- Force 100% Service Braking throttle input
				gSetReg = 0.0 -- Drop power instantly
			end
			
			-- Max application of dynamic brake based on #cars in consist
			local dynBrakeMax = clamp( NumCars / DYNBRAKE_MAXCARS, 0.0, 1.0 )
			
			-- Parked or track brake engaged
			if ( math.abs( ReverserLever ) < 0.9 or TrackBrake > 0 ) then
				Call( "*:SetControlValue", "Regulator", 0, 0.0 )
				Call( "*:SetControlValue", "TrainBrakeControl", 0, 1.0 )
				Call( "*:SetControlValue", "DynamicBrake", 0, dynBrakeMax )
				
				if ( TrackBrake > 0 ) then
					Call( "*:SetControlValue", "Sander", 0, 1 )
					Call( "*:SetControlValue", "HandBrakeCommand", 0, 1 )
					tAccel = math.min( tAccel, 0.0 )
				else
					Call( "*:SetControlValue", "Sander", 0, 0 )
					Call( "*:SetControlValue", "HandBrakeCommand", 0, 0 )
				end
				
				gSetReg = 0.0
				gSetDynamic = 0.0
				gSetBrake = 0.0
				
				if ( math.abs( ReverserLever ) < 0.9 ) then
					Call( "*:SetControlValue", "ThrottleAndBrake", 0, -1.0 )
				end
			else
				Call( "*:SetControlValue", "Sander", 0, 0 )
				Call( "*:SetControlValue", "HandBrakeCommand", 0, 0 )
				
				if ( DoorsOpen == TRUE ) then
					gSetReg = 0.0
					gSetDynamic = 0.0
					gSetBrake = 0.95
				else
					if ( math.abs( tAccel ) < 0.01 ) then
						gSetReg = 0.0
						gTargetBrake = 0.0
						gSetBrake = 0.0
					else
						gSetReg = Round( clamp( tAccel, 0.0, 1.0 ), 3 )
						gTargetBrake = Round( clamp( -tAccel, 0.0, 1.0 ), 4 )
						gMaxServiceBrake = MAX_SERVICE_BRAKE
						
						-- We used to calculate this based on current, but it was too inconsistent, so now we calculate it from the spec speed
						dynEffective = mapRange( TrainSpeed, DYNAMIC_BRAKE_MIN_FALLOFF_SPEED, DYNAMIC_BRAKE_MAX_FALLOFF_SPEED, 0.0, 1.0 )
						dynEffective = clamp( dynEffective, 0.001, 1.0 )
						if ( gTargetBrake < 0.001 ) then
							dynEffective = 1.0
						end
						
						if ( tThrottle < -0.901 ) then
							dynEffective = 0.001 -- Force friction brakes to apply
							Call( "*:SetControlValue", "HandBrakeCommand", 0, 1.0 )
							gMaxServiceBrake = 1.0
							if ( TrainSpeed < 2.0 ) then gDynamicFadeDelay = DYNAMIC_FADE_TIMEOUT end
						end
						
						if ( TrainSpeed < 2.75 and tAccel < 0 ) then
							if ( gDynamicFadeDelay < DYNAMIC_FADE_TIMEOUT ) then
								gDynamicFadeDelay = gDynamicFadeDelay + gTimeDelta
								
								gSetBrake = gTargetBrake * 0.2
							else
								gMaxServiceBrake = gMaxServiceBrake * 0.35
								gSetBrake = mapRange( gTargetBrake * ( 1.0 - dynEffective ), 0.0, 1.0, MIN_SERVICE_BRAKE, gMaxServiceBrake )
							end
						else
							if ( tAccel >= 0 ) then
								if ( TrainSpeed > 2.0 ) then
									gDynamicFadeDelay = 0.0
								else
									gDynamicFadeDelay = DYNAMIC_FADE_TIMEOUT - DYNAMIC_FADE_DELAY -- If already slow, reduce delay
								end
							end
							gSetBrake = mapRange( gTargetBrake * ( 1.0 - dynEffective ), 0.0, 1.0, MIN_SERVICE_BRAKE, gMaxServiceBrake )
						end
					end
						
					if ( gBrakeDelay < gBrakeDelayTime ) then
						gBrakeDelay = gBrakeDelay + gTimeDelta
					else
						gSetDynamic = gTargetBrake
					end
				end
				
				local finalRegulator = gSetReg
				finalRegulator = finalRegulator * ( NumCarsOnPower / NumCars )
				
				Call( "*:SetControlValue", "TAccel", 0, tAccel )
				if ( Active ) then Call( "*:SetControlValue", "Regulator", 0, finalRegulator ) end
				--Call( "*:SetControlValue", "DynamicBrake", 0, gSetDynamic * clamp( NumCars / DYNBRAKE_MAXCARS, 0.0, 1.0 ) )
				Call( "*:SetControlValue", "DynamicBrake", 0, gSetDynamic )
				Call( "*:SetControlValue", "TrainBrakeControl", 0, gSetBrake )
				Call( "*:SetControlValue", "TrueThrottle", 0, tThrottle )
			
				--[[if ( not Active ) then
					Call( "*:SetPowerProportion", CarNum, 0.0 )
					Call( "*:SetControlValue", "HandBrake", 0, Regulator - finalRegulator )
				else
					Call( "*:SetPowerProportion", CarNum, 1.0 )
				end]]
			end

			-- End propulsion system

			if Call( "*:GetControlValue", "Startup", 0 ) < 0 then -- Shutdown...reset everything
				Call( "*:SetControlValue", "Reverser", 0, 0 )
				Call( "*:SetControlValue", "ThrottleAndBrake", 0, 0 )
				Call( "*:SetControlValue", "ATOEnabled", 0, -1 )
				Call( "*:SetControlValue", "DestinationSign", 0, 0 )
				
				Call( "*:SetControlValue", "TrainBrakeControl", 1.0 )
				Call( "*:SetControlValue", "HandBrakeCommand", 1.0 )
				Call( "*:SetControlValue", "Regulator", 0.0 )
				Call( "*:SetControlValue", "DynamicBrake", 0.0 )
				
				tTAccel = 0.0
				tAccel = 0.0
				tThrottle = 0.0
			end
			
			-- Begin ATC system
			
			if ( Active and Call( "*:GetIsPlayer" ) >= 1 ) then
				if UpdateATC then
					UpdateATC( gTimeDelta )
				end
				
				if UpdateATO then
					UpdateATO( gTimeDelta )
				end
			end
			
			-- End ATC system

			if ( DoorsOpen ~= FALSE ) then
				Call( "*:SetControlValue", "Regulator", 0, 0 )
			end

			gLastDoorsOpen = DoorsOpen
			gLastSpeed = TrainSpeed
			gLastThrottle = tTAccel
			gTimeDelta = 0
		end
	else -- trail engine.
	
	end
end
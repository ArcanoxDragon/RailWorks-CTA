--include=..\..\Common\Scripts\CTA ATC.lua
--include=..\..\Common\Scripts\CTA ATO AC.lua
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
	gSetBrake = 0
	gLastSpeed = 0
	gTimeDelta = 0
	gCurrent = 0
	gLastReverser = 0
	gDestSignNext = false
	gDestSignPrev = false
	
	THROTTLE_PICKUP_SPEED = 1.0 / 2.0
	BRAKE_DELAY_TIME = 1.0
	COAST_DELAY_TIME = 0.25
	DYNAMIC_FADE_DELAY = 2.0
	MAX_SERVICE_BRAKE = 0.6
	MIN_SERVICE_BRAKE = 0.0
	DYNAMIC_BRAKE_AMPS = 500.0
	DYNAMIC_BRAKE_MIN_FALLOFF_SPEED = 1.0
	DYNAMIC_BRAKE_MAX_FALLOFF_SPEED = 3.75
	DYNBRAKE_MAXCARS = 8 -- Number of cars that the dynamic brake force is calibrated to ( WTF railworks, you can't do this yourself? )
	ATC_REQUIRED_BRAKE = 0.624
	
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
	gDynamicFadeDelay = 0.0
	
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
			TrainSpeed = Call( "*:GetControlValue", "SpeedometerMPH", 0 )
			BrakeCylBAR = Call( "*:GetControlValue", "TrainBrakeCylinderPressureBAR", 0 )
			ATCBrakeApplication = Call( "*:GetControlValue", "ATCBrakeApplication", 0 )
			IsEndCar = Call( "*:GetControlValue", "IsEndCar", 0 ) > 0
			NumCars = Call( "*:GetControlValue", "NumCars", 0 )
			NumCarsOnPower = Call( "*:GetControlValue", "NumCarsOnPower", 0 )
			ATOEnabled = ( Call( "*:GetControlValue", "ATOEnabled", 0 ) or -1 ) > 0.5
			ATOThrottle = ( Call( "*:GetControlValue", "ATOThrottle", 0 ) or -1 )
			
			DestSignNext = Call( "*:GetControlValue", "DestSignNext", 0 ) > 0
			DestSignPrev = Call( "*:GetControlValue", "DestSignPrev", 0 ) > 0
			DestSign     = Call( "*:GetControlValue", "DestinationSign", 0 )
			
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
				tThrottle = math.min( ATOThrottle, math.max( ATOThrottle - 0.025, tThrottle ) )
				Call( "*:SetControlValue", "ThrottleLever", 0, 0 )
			else
				tThrottle = CombinedLever * 2.0 - 1.0
				
				if ( tThrottle > 0.01 ) then
					tThrottle = Round( tThrottle, 3 ) -- 3 points of power
				elseif ( tThrottle < -0.01 ) then
					tThrottle = -Round( -tThrottle, 4 ) -- 4 points of braking
				else
					tThrottle = 0.0
				end
				
				Call( "*:SetControlValue", "ThrottleLever", 0, CombinedLever )
				
				if ( Call( "*:GetControlValue", "ATCEnabled", 0 ) > 0 ) then
					local restrictedSpeed = Call( "*:GetControlValue", "ATCRestrictedSpeed", 0 )
				end
			end
			
			-- Round throttle to 0 if it's below 10% power/brake; widens "coast" gap
			if ( math.abs( tThrottle ) < 0.1 and not ATOEnabled ) then
				tThrottle = 0.0
			end
			
			tTAccel = clamp( tThrottle, -1.0, 1.0 )
			
			if ( tTAccel < -0.01 ) then
				if ( gBrakeDelay < BRAKE_DELAY_TIME ) then
					gBrakeDelay = gBrakeDelay + gTimeDelta
					
					if ( gCoastDelay < COAST_DELAY_TIME ) then
						gCoastDelay = gCoastDelay + gTimeDelta
					else
						tAccel = 0.0
					end
				else
					tAccel = tTAccel
				end
			else
				gBrakeDelay = 0.0
				local regDelta = gTimeDelta * THROTTLE_PICKUP_SPEED
				
				if ( tAccel < tTAccel - regDelta ) then
					tAccel = tAccel + regDelta
					gCoastDelay = 0.0
				elseif ( tAccel > tTAccel ) then
					if ( math.abs( tThrottle - gLastThrottle ) > 0.01 ) then
						gCoastDelay = 0.0
					else
						if ( gCoastDelay < COAST_DELAY_TIME ) then
							gCoastDelay = gCoastDelay + gTimeDelta
						else
							tAccel = tTAccel
						end
					end
				end
				
				if ( BrakeCylBAR > 0.001 ) then
					tAccel = math.min( tAccel, 0.0 )
					gCoastDelay = 0.0
				end
			end
			
			-- ATC took over braking due to control timeout
			if ( ATCBrakeApplication > 0 ) then
				tAccel = -1 -- Instant max braking
				tThrottle = -1 -- Force 100% Braking throttle input
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
						gSetDynamic = 0.0
						gSetBrake = 0.0
					else
						gSetReg = Round( clamp( tAccel, 0.0, 1.0 ), 3 )
						gSetDynamic = Round( clamp( -tAccel, 0.0, 1.0 ), 4 )
						
						targetAmps = DYNAMIC_BRAKE_AMPS * dynBrakeMax * gSetDynamic
						
						-- We used to calculate this based on current, but it was too inconsistent, so now we calculate it from the spec speed
						dynEffective = mapRange( TrainSpeed, DYNAMIC_BRAKE_MIN_FALLOFF_SPEED, DYNAMIC_BRAKE_MAX_FALLOFF_SPEED, 0.0, 1.0 )
						dynEffective = clamp( dynEffective, 0.001, 1.0 )
						if ( gSetDynamic < 0.001 ) then
							dynEffective = 1.0
						end
						
						if ( dynEffective < 0.375 ) then
							if ( gDynamicFadeDelay < DYNAMIC_FADE_DELAY ) then
								gDynamicFadeDelay = gDynamicFadeDelay + gTimeDelta
								gSetBrake = gSetDynamic * 0.125
							else
								gSetBrake = mapRange( gSetDynamic * ( 1.0 - dynEffective ), 0.0, 1.0, MIN_SERVICE_BRAKE, MAX_SERVICE_BRAKE )
							end
						else
							gDynamicFadeDelay = 0.0
						end
						
						
					end
				end
				
				local finalRegulator = gSetReg
				finalRegulator = finalRegulator * ( NumCarsOnPower / NumCars )
				
				Call( "*:SetControlValue", "TAccel", 0, tAccel )
				Call( "*:SetControlValue", "Regulator", 0, finalRegulator )
				Call( "*:SetControlValue", "DynamicBrake", 0, gSetDynamic * clamp( NumCars / DYNBRAKE_MAXCARS, 0.0, 1.0 ) )
				Call( "*:SetControlValue", "TrainBrakeControl", 0, gSetBrake )
				Call( "*:SetControlValue", "TrueThrottle", 0, tThrottle )
			end

			-- End propulsion system

			if Call( "*:GetControlValue", "Startup", 0 ) < 0 then -- Shutdown...reset everything
				Call( "*:SetControlValue", "Reverser", 0, 0 )
				Call( "*:SetControlValue", "ThrottleAndBrake", 0, 0 )
				Call( "*:SetControlValue", "ATOEnabled", 0, 0 )
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
			
			if UpdateATC then
				UpdateATC( gTimeDelta )
			end
			
			if UpdateATO then
				UpdateATO( gTimeDelta )
			end
			
			-- End ATC system

			if ( DoorsOpen ~= FALSE ) then
				Call( "*:SetControlValue", "Regulator", 0, 0 )
			end

			gLastDoorsOpen = DoorsOpen
			gLastSpeed = TrainSpeed
			gLastThrottle = tThrottle
			gTimeDelta = 0
		end
	else -- trail engine.
	
	end
end
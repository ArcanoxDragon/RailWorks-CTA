--include=..\..\Common\Scripts\CTA ATC.lua
--include=..\..\Common\Scripts\CTA ATO AC.lua
--include=..\..\..\..\Common\Scripts\CTA Util.lua

------------------------------------------------------------
-- Simulation file for the Bombardier CTA 5000-series EMU
------------------------------------------------------------
--
-- ( c ) briman0094 2015
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
	
	MAX_ACCELERATION_MPHPS = 2.8
	MAX_ACCELERATION = 1.0
	MIN_ACCELERATION = 0.13
	MAX_BRAKING = 1.0
	MIN_BRAKING = 0.08
	JERK_LIMIT = 0.8
	SMOOTH_STOP_ACCELERATION = 0.25
	SMOOTH_STOP_CORRECTION = 1.0 / 16.0
	MAX_BRAKE_RELEASE = 0.855
	MIN_BRAKE_RELEASE = 0.755
	MAX_SERVICE_BRAKE = 0.80
	--MIN_SERVICE_BRAKE = 0.275
	MIN_SERVICE_BRAKE = 0.0
	MAX_CORRECTION = 1.0 - MAX_BRAKE_RELEASE
	DYNAMIC_BRAKE_AMPS = 500.0
	DYNAMIC_BRAKE_MIN_FALLOFF_SPEED = 2.0
	DYNAMIC_BRAKE_MAX_FALLOFF_SPEED = 4.5
	DYNBRAKE_MAXCARS = 8 -- Number of cars that the dynamic brake force is calibrated to ( WTF railworks, you can't do this yourself? )
	ATO_COAST_TIME_OFFSET = 0.95
	ATO_COAST_UPPER_LIMIT = 0.0 -- MPH above set speed that triggers coast command
	ATO_COAST_LOWER_LIMIT = 2.0 -- MPH below set speed that cancels coast command and allows power
	ATC_REQUIRED_BRAKE = 0.9
	
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
	gAvgAccelCalculated = 0.0
	gBrakeRelease = 0.0
	gMaxBrakeRelease = -1.0
	brkAdjust = 0.0
	gSign = 0
	gLastAccelSign = 0
	gLastJerkLimit = 0
	gATOCoasting = false
	gRandSeeded = false
	
-- One-shot variables
	gMovingInterlocks = false

-- For controlling delayed doors interlocks.
	DOORDELAYTIME = 8.0 -- seconds.
	gDoorsDelay = DOORDELAYTIME
end

function GetRandomBrakeRelease()
	return ( MAX_BRAKE_RELEASE - MIN_BRAKE_RELEASE ) * math.random() + MIN_BRAKE_RELEASE
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
	--gTimeDelta = gTimeDelta + rInterval
	gTimeDelta = interval
			
	-- Headlights
	
	if ( Call( "*:GetControlValue", "Startup", 0 ) > 0 ) then
		Call( "*:SetControlValue", "ThirdRail", 0, 1 )
	else
		Call( "*:SetControlValue", "ThirdRail", 0, 0 )
	end

	if Call( "*:GetControlValue", "Active", 0 ) == 1 then -- This is lead engine.
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
		
		if ( TrainSpeed > 0.1 ) then
			if ( not gMovingInterlocks ) then
				Call( "*:LockControl", "ATC_R64"   , 0, 1 )
				Call( "*:LockControl", "ATCEnabled", 0, 1 )
				Call( "*:LockControl", "Reverser"  , 0, 1 )
				gMovingInterlocks = true
			end
		else
			if ( gMovingInterlocks ) then
				Call( "*:LockControl", "ATC_R64"   , 0, 0 )
				Call( "*:LockControl", "ATCEnabled", 0, 0 )
				Call( "*:LockControl", "Reverser"  , 0, 0 )
				gMovingInterlocks = false
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
			--[[if ( TrainSpeed > 0.1 ) then
				Call( "*:SetControlValue", "Reverser", 0, gLastReverser )
			end]]
		end
		
		-- Begin propulsion system
		realAccel = ( TrainSpeed - gLastSpeed ) / gTimeDelta
		gAvgAccel = gAvgAccel + ( TrainSpeed - gLastSpeed )
		gAvgAccelTime = gAvgAccelTime + gTimeDelta
		-- Average out acceleration
		if ( gAvgAccelTime >= 1/8 ) then -- 8 times/sec
			gAvgAccelCalculated = gAvgAccel / gAvgAccelTime
			Call( "*:SetControlValue", "Acceleration", 0, round( gAvgAccelCalculated, 2 ) )
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
			
			if ( Call( "*:GetControlValue", "ATCEnabled", 0 ) > 0 ) then
				local restrictedSpeed = Call( "*:GetControlValue", "ATCRestrictedSpeed", 0 )
				
				if not gATOCoasting then
					-- Begin ATO coast-override subsystem ( Section 13.23 in 7000-series RFP )
					local timeToSetSpeed = math.pow( math.max( ( restrictedSpeed + ATO_COAST_UPPER_LIMIT ) - TrainSpeed, 0.0 ) / math.max( math.abs( gAvgAccelCalculated ), 0.01 ), 2 )
					--local timeOffset = ATO_COAST_TIME_OFFSET * ( math.max( realAccel, 0.0 ) / MAX_ACCELERATION_MPHPS )
					
					if ( timeToSetSpeed < ATO_COAST_TIME_OFFSET ) then
						gATOCoasting = true
					end
				else
					tThrottle = math.min( tThrottle, 0.0 ) -- Coast
					
					if ( TrainSpeed <= restrictedSpeed - ATO_COAST_LOWER_LIMIT or tThrottle < 0.0 ) then
						gATOCoasting = false
					end
				end
			else
				gATOCoasting = false
			end
		end
		
		-- Round throttle to 0 if it's below 10% power/brake; widens "coast" gap
		if ( math.abs( tThrottle ) < 0.1 and not ATOEnabled ) then
			tThrottle = 0.0
		end
		
		if ( ATOEnabled ) then
			if ( tThrottle >= 0.001 ) then -- Accelerating; bind range to [ MIN_ACCELERATION, MAX_ACCELERATION ]
				tTAccel = mapRange( tThrottle, 0.0, 1.0, 0.0, MAX_ACCELERATION )
			elseif ( tThrottle <= -0.001 ) then -- Braking; bind range to [ MIN_BRAKING, MAX_BRAKING ]
				tTAccel = -mapRange( -tThrottle, 0.0, 1.0, 0.0, MAX_BRAKING )
			else
				tTAccel = 0.0
			end
		else
			if ( tThrottle >= 0.1 ) then -- Accelerating; bind range to [ MIN_ACCELERATION, MAX_ACCELERATION ]
				tTAccel = mapRange( tThrottle, 0.1, 0.9, MIN_ACCELERATION, MAX_ACCELERATION )
			elseif ( tThrottle <= -0.1 ) then -- Braking; bind range to [ MIN_BRAKING, MAX_BRAKING ]
				tTAccel = -mapRange( -tThrottle, 0.1, 0.9, MIN_BRAKING, MAX_BRAKING )
			else
				tTAccel = 0.0
			end
		end
		
		-- If requesting acceleration and stopped, release brakes instantly
		if ( tTAccel >= 0 and math.abs( TrainSpeed ) < 0.1 ) then
			tAccel = math.max( tAccel, 0.0 )
		end
		
		tJerkLimit = JERK_LIMIT * gTimeDelta
		
		if tAccel < tTAccel - tJerkLimit then
			tAccel = tAccel + tJerkLimit
		elseif tAccel > tTAccel + tJerkLimit then
			tAccel = tAccel - tJerkLimit
		else
			tAccel = tTAccel
		end
		
		-- ATC took over braking due to control timeout
		if ( ATCBrakeApplication > 0 ) then
			tAccel = -1 -- Instant max braking
			tThrottle = -1 -- Force 100% Braking throttle input
			gSetReg = 0.0 -- Drop power instantly
			gThrottleTime = 100 -- Override "propulsion adjustment" period
		end
		
		-- Max application of dynamic brake based on #cars in consist
		local dynBrakeMax = clamp( NumCars / DYNBRAKE_MAXCARS, 0.0, 1.0 )
		
		-- Parked or track brake engaged
		if ( math.abs( ReverserLever ) < 0.9 or TrackBrake > 0 ) then
			Call( "*:SetControlValue", "Regulator", 0, 0.0 )
			Call( "*:SetControlValue", "TrainBrakeControl", 0, 1.0 )
			
			--Call( "*:SetControlValue", "DynamicBrake", 0, dynBrakeMax * ( 1.0 - clamp( BrakeCylBAR / 2.75, 0.0, 1.0 ) ) )
			Call( "*:SetControlValue", "DynamicBrake", 0, 1.0 )
			if ( TrackBrake > 0 ) then
				Call( "*:SetControlValue", "Sander", 0, 1 )
				Call( "*:SetControlValue", "HandBrakeCommand", 0, 1.0 )
				tAccel = math.min( tAccel, 0.0 )
			else
				Call( "*:SetControlValue", "Sander", 0, 0 )
				Call( "*:SetControlValue", "HandBrakeCommand", 0, 0 )
			end
			gSetReg = 0.0
			gSetDynamic = 0.0
			gSetBrake = 0.0
			brkAdjust = MAX_CORRECTION
			gStoppingTime = MAX_STOPPING_TIME
			if ( math.abs( ReverserLever ) < 0.9 ) then
				Call( "*:SetControlValue", "ThrottleAndBrake", 0, -1.0 )
			end
		else
			Call( "*:SetControlValue", "Sander", 0, 0 )
			Call( "*:SetControlValue", "HandBrakeCommand", 0, 0 )
			
			-- Cancel smooth-stop if train takes too long to stop
			if ( math.abs( TrainSpeed ) < 3.0 ) then
				gStoppingTime = gStoppingTime + gTimeDelta
			else
				gStoppingTime = 0
				brkAdjust = 0.0
			end
			
			if ( math.abs( tAccel ) > 0.05 ) then
				local tAccelSign = sign( tAccel )
				if ( tAccelSign ~= gLastAccelSign ) then
					gThrottleTime = 0.0
				end
				gLastAccelSign = tAccelSign
			end
			
			if ( BrakeCylBAR > 0.005 and tAccel > 0 ) then
				gThrottleTime = 0.0
			end
			
			if ( gThrottleTime < 0.125 ) then
				gThrottleTime = gThrottleTime + gTimeDelta
				tAccel = 0.01 * gLastAccelSign
				gLastJerkLimit = 0
			end
			
			if ( DoorsOpen == TRUE ) then
				gSetReg = 0.0
				gSetDynamic = 0.0
				gSetBrake = 0.95
				brkAdjust = MAX_CORRECTION
			else
				if ( math.abs( tAccel ) < 0.01 ) then
					gSetReg = 0.0
					gSetDynamic = 0.0
					gSetBrake = 0.0
				else
					gSetReg = clamp( tAccel, 0.0, 1.0 )
					gSetDynamic = clamp( -tAccel, 0.0, 1.0 )
					
					dynEffective = mapRange( TrainSpeed, DYNAMIC_BRAKE_MIN_FALLOFF_SPEED, DYNAMIC_BRAKE_MAX_FALLOFF_SPEED, 0.0, 1.0 )
					dynEffective = clamp( dynEffective, 0.001, 1.0 )
					if ( gSetDynamic < 0.001 ) then
						dynEffective = 1.0
					end
					
					gSetBrake = mapRange( gSetDynamic * ( 1.0 - dynEffective ), 0.0, 1.0, MIN_SERVICE_BRAKE, MAX_SERVICE_BRAKE )
					
					if ( math.abs( TrainSpeed ) < 3.0 ) then
						if ( tThrottle < -0.15 ) then
							if ( gStoppingTime < MAX_STOPPING_TIME ) then
								if ( gMaxBrakeRelease < 0.0 ) then
									gMaxBrakeRelease = GetRandomBrakeRelease( interval )
								end
								
								gBrakeRelease = clamp( (2.5 - math.abs( TrainSpeed ) ) / 1.5, 0.0, 1.0 )
							else
								gBrakeRelease = 0.0
								gMaxBrakeRelease = -1.0
							end
						else
							if ( gStoppingTime < MAX_STOPPING_TIME ) then
								tAccel = 0.0 -- Prevents jerkiness when going brake -> coast -> brake quickly
							end
							
							gStoppingTime = MAX_STOPPING_TIME
							gBrakeRelease = 0.0
						end
					else
						gBrakeRelease = 0.0
						gMaxBrakeRelease = -1.0
					end
					
					Call( "*:SetControlValue", "Misc1", 0, gMaxBrakeRelease )
					
					gSetBrake = gSetBrake - ( gBrakeRelease * math.max( gMaxBrakeRelease, 0.0 ) * gSetBrake )
				end
			end
			
			local finalRegulator = gSetReg
			
			Call( "*:SetControlValue", "TAccel", 0, tAccel )
			if ( Active ) then Call( "*:SetControlValue", "Regulator", 0, finalRegulator ) end
			Call( "*:SetControlValue", "DynamicBrake", 0, gSetDynamic )
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
		gTimeDelta = 0
	else -- trail engine.
	
	end
end
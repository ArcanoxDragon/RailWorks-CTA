-- Constants
local SIGNAL_STATE_STATION = 21
local ATO_TARGET_DECELERATION = 1.1          -- Meters/second/second
local THROTTLE_PER_SECOND = 0.8              -- Throttle range per second ( jerk limit, used for extra buffers )
local STATION_SIGNAL_SEARCH_BUFFER = 100     -- meters
local STATION_STOP_DISTANCE_BUFFER = 5.5     -- meters; distance short of station marker we want to stop (gives room for acceleration smoothing/smooth stopping and improves stop accuracy)
local STATION_FINAL_STOP_DISTANCE  = 1.5     -- meters; distance prior to station marker at which we will exit closed-loop stopping and begin braking at a fixed rate
local STATION_FINAL_STOP_BRAKING_POWER = 0.4 -- brake power to brake at for final stop distance until the train comes to a complete stop
local STOP_DISTANCE_CORRECTION_RATE = 10     -- meters/second

-- Local functional objects
local atoPid = PID.create( {
	kP = 1 / 3,
	kI = 1 / 5,
	kD = 1 / 4,
	-- dynamicIntegral = true,
	dynamicIntegral = true,
	dynamicIntegralLargeThreshold = 0.75,
	dynamicIntegralSmallThreshold = 0.5,
	errorAvgAlpha = 0.25,
	deltaAvgAlpha = 0.25,
} )
local avgAtoThrottle = MovingAverage.create(15)
local avgTargetSpeed = MovingAverage.create(15)
local stopsFile = io.open( "cta_ato_stops.csv", "w" )

stopsFile:write( "startSpeed_MPH,speedLimit_MPH,distance_m,stopTime_s,berthOffset_cm\n" )
stopsFile:flush()

local function logStop( startingSpeed, speedLimit, distance, totalStopTime, berthOffset )
	stopsFile:write( tostring( round( startingSpeed * MPS_TO_MPH, 2 ) ) .. ",")
	stopsFile:write( tostring( round( speedLimit * MPS_TO_MPH, 2 ) ) .. ",")
	stopsFile:write( tostring( round( distance, 2 ) ) .. ",")
	stopsFile:write( tostring( round( totalStopTime, 2 ) ) .. ",")
	stopsFile:write( tostring( round( berthOffset * 100 --[[ m to cm ]], 2 ) ) )
	stopsFile:write( "\n" )
	stopsFile:flush()
end

-- Other local state objects
local stats = {
	stopStartingSpeed = 0,
	stopSpeedLimit = 0,
	stopDistance = 0,
	stopTime = 0,
}

local ato = {
	sigDirection = 0,
	stopping = false,
	maxSpeed = 100,
	timeStopped = 0,
	stationStopInitialSpeed = 0,
	stationStopInitialBrakingDistance = 0,
	stationStoppingDistance = 0,
	lastStationDistance = -1,
	overrunDist = 0,
	lostTrackedStationSignal = false,
	lostTrackedStationTime = 0.0,
}

local state = {
	lastAtoActive = false,
	lastAtcActive = 1,
	atoActive = false,
	atoThrottle = 0,
	trueThrottle = 0,
	stoppingSpeed = 0,
	stopStage = -1,
	stopStageTime = 0.0,
	targetSpeed = 0,
	trackSpeed = 0,
	trainSpeed = 0,
	trainSpeedMPH = 0,
	doorsLeft = false,
	doorsRight = false,
	speedBiasBuffer = 0,
	accelerationBuffer = 0,
	brakingDistance = 0,
	minStationStoppingDistance = 0,
	lastSignalDistance = 0,
	lastSignalDistanceTime = 0,
	foundStationSignal = false,
}

local signal = {
	type = nil,
	state = nil,
	distance = nil,
	aspect = nil,
}

local controls = {
	trackBrake = 0,
	atoStart = 0,
	atoStartLocked = 0,
	atcRestrictedSpeed = 0,
}

function UpdateATO( dt )
	controls.trackBrake = Call( "*:GetControlValue", "TrackBrake", 0 )

	if controls.trackBrake and controls.trackBrake > 0.5 then
		Call( "*:SetControlValue", "ATOEnabled", 0, -1 )
	end

	if Call( "*:ControlExists", "ATOEnabled", 0 ) < 0.5 then -- Don't update if we don't have ATO installed on the vehicle
		return
	end 

	-- Begin Automatic Train Operation ( ATO )
	state.atoActive = Call( "*:GetControlValue", "ATOEnabled", 0 ) > 0.5
	state.atoThrottle = Call( "*:GetControlValue", "ATOThrottle", 0 )
	controls.atoStart = Call( "*:GetControlValue", "ATOStart", 0 ) > 0.5
	state.trainSpeed = Call( "*:GetSpeed" )
	state.trainSpeedMPH = state.trainSpeed * MPS_TO_MPH
	state.doorsOpen = Call( "*:GetControlValue", "DoorsOpen", 0 ) > 0.1
	state.trueThrottle = Call( "*:GetControlValue", "TrueThrottle", 0 )

	if state.atoActive then
		if not state.lastAtoActive then
			state.lastAtcActive = Call( "*:GetControlValue", "ATCEnabled", 0 )
			ato.stopping = state.trainSpeedMPH < 0.5
			controls.atoStartLocked = 1
			ato.timeStopped = 0
			ato.overrunDist = 0
			state.stopStage = ato.stopping and 2 or -1
			state.stopStageTime = 0
		end

		Call( "*:SetControlValue", "Headlights", 0, 1 )
		Call( "*:SetControlValue", "ATCEnabled", 0, 1 )
		Call( "*:SetControlValue", "Reverser", 0, 1 )
		Call( "*:LockControl", "ThrottleAndBrake", 0, 1 )
		Call( "*:LockControl", "Reverser", 0, 1 )

		controls.atcRestrictedSpeed = Call( "*:GetControlValue", "ATCRestrictedSpeed", 0 )
		state.targetSpeed = controls.atcRestrictedSpeed * MPH_TO_MPS
		state.brakingDistance = math.max( getBrakingDistance( 0.0, state.targetSpeed, -ATO_TARGET_DECELERATION ), 0 )

		-- Calculate search distance buffers
		state.accelerationBuffer = state.trainSpeed * ( ( tAccel - ( -1 ) ) / THROTTLE_PER_SECOND ) -- Estimated time to reach full brakes ( -1 ) from current throttle ( tAccel )
		state.minStationStoppingDistance = state.accelerationBuffer + state.brakingDistance + STATION_STOP_DISTANCE_BUFFER

		-- Get details about the next signal
		state.foundStationSignal = false
		signal.type, signal.state, signal.distance, signal.aspect = Call( "*:GetNextRestrictiveSignal", ato.sigDirection )

		state.lastSignalDistanceTime = state.lastSignalDistanceTime + dt

		if ( signal.distance > state.lastSignalDistance + 0.5 or state.trainSpeed < 0.1 ) and state.lastSignalDistanceTime >= 1.0 then
			if ato.sigDirection < 0.5 then
				ato.sigDirection = 1
			else
				ato.sigDirection = 0
			end
		end

		local searchDist = signal.distance + 0.1
		local searchCount = 0

		if signal.aspect == SIGNAL_STATE_STATION then
			-- First signal ahead of us is a station
			
			state.foundStationSignal = true
		else
			-- Search further away signals to see if any is a station
			
			while ( searchDist < state.minStationStoppingDistance + STATION_SIGNAL_SEARCH_BUFFER and signal.aspect ~= SIGNAL_STATE_STATION and searchCount < 20 ) do -- To avoid potential infinite loops at the end of the track, don't search more than 20 "signals" away
				signal.type, signal.state, signal.distance, signal.aspect = Call( "*:GetNextRestrictiveSignal", ato.sigDirection, searchDist )
				
				if signal.aspect == SIGNAL_STATE_STATION then
					state.foundStationSignal = true
				end
				
				searchDist = signal.distance + 0.01
				searchCount = searchCount + 1
			end
		end

		if state.lastSignalDistance and state.lastSignalDistanceTime >= 1.0 then
			state.lastSignalDistanceTime = 0.0
			state.lastSignalDistance = signal.distance
		end

		Call( "*:SetControlValue", "SpeedBuffer", 0, state.minStationStoppingDistance )

		if state.foundStationSignal and not ato.stopping then
			-- A station stop signal was found along our path within our search distance
			
			if signal.distance <= state.minStationStoppingDistance -- close enough to trigger a station stop
			and signal.distance >= 15 -- far enough away that we should consider it (we don't want to consider stations that are super close)
			and signal.distance < state.lastSignalDistance  -- we're getting closer to it
			and state.trainSpeedMPH >= 3.0 then -- we're moving at a decent speed
				-- Station is a stop candidate; trigger a station stop here
				
				ato.stopping = true
				ato.stationStopInitialSpeed = state.targetSpeed
				ato.stationStopInitialBrakingDistance = state.brakingDistance
				ato.stationStoppingDistance = state.minStationStoppingDistance
				ato.overrunDist = 0
				stats.stopStartingSpeed = state.trainSpeed
				stats.stopSpeedLimit = state.targetSpeed
				stats.stopDistance = signal.distance
				stats.stopTime = 0
			end
		end

		if ato.stopping then
			-- We're in a station stop procedure; we need to slow down as we approach the station and line up with the platform
			
			-- Recalculate our braking distance gradually and adjust stop distance accordingly; allows a more precise stop without random oscillations while stopping
			local currentStationStoppingDistance = ato.stationStopInitialBrakingDistance + state.accelerationBuffer + STATION_STOP_DISTANCE_BUFFER
			local stopDistanceDelta = STOP_DISTANCE_CORRECTION_RATE * dt
			
			if ato.stationStoppingDistance > currentStationStoppingDistance + stopDistanceDelta then
				ato.stationStoppingDistance = ato.stationStoppingDistance - stopDistanceDelta
			elseif ato.stationStoppingDistance < currentStationStoppingDistance - stopDistanceDelta then
				ato.stationStoppingDistance = ato.stationStoppingDistance + stopDistanceDelta
			else
				ato.stationStoppingDistance = ato.stationStoppingDistance
			end
			
			local stoppingSpeed = getStoppingSpeed( ato.stationStopInitialSpeed, -ATO_TARGET_DECELERATION, ato.stationStoppingDistance - signal.distance )
			
			-- Factor in predicted P-error on PID
			state.stoppingSpeed = math.max( stoppingSpeed - (1 / atoPid.kP) * MPH_TO_MPS, 1.0 * MPH_TO_MPS )
			state.targetSpeed = math.min( controls.atcRestrictedSpeed * MPH_TO_MPS, state.stoppingSpeed )
			stats.stopTime = stats.stopTime + dt
			
			if state.targetSpeed <= 1.05 * MPH_TO_MPS and state.trainSpeedMPH <= 2.5 and state.stopStage < 0 then
				-- Stage 0: coast until we are STATION_FINAL_STOP_DISTANCE meters away from the station marker
				
				state.stopStage = 0
			end

			if signal.distance < STATION_FINAL_STOP_DISTANCE or ato.overrunDist > 0 then
				-- We're close enough that we should come to a complete stop immediately
				
				state.targetSpeed = 0.0

				if state.stopStage <= 0 then
					-- Stage 1 = apply brakes at STATION_FINAL_STOP_BRAKING_POWER for a gradual stop
					
					state.stopStage = 1
				end
			end

			if state.stopStage == 1 then
				-- Stage 2 = apply brakes at full power once train stops to hold it still safely
				
				if state.trainSpeedMPH > 0.05 then
					state.stopStageTime = 0.25
				elseif state.stopStageTime <= 0.0 then
					state.stopStage = 2
				end
			end

			if state.trainSpeed <= 0.025 and state.stopStage == 2 then
				-- We just came to a complete stop and the driver can now open the doors and eventually proceed to the next station
				
				state.targetSpeed = 0.0
				controls.atoStartLocked = state.doorsOpen and 1 or 0
				
				if not state.doorsOpen and controls.atoStart then
					-- Driver has closed the doors and requested an ATO Start command; we should resume driving now
					
					ato.timeStopped = ato.timeStopped + dt
					
					if ato.timeStopped >= 0.5 then
						ato.stopping = false
						ato.timeStopped = 0.0
						state.stopStage = -1

						local berthOffset = (ato.overrunDist > 0) and -ato.overrunDist or signal.distance
						
						-- Log stats about this station stop to a log file just before we depart
						logStop( stats.stopStartingSpeed, stats.stopSpeedLimit, stats.stopDistance, stats.stopTime, berthOffset )

						stats.stopStartingSpeed = 0
						stats.stopSpeedLimit = 0
						stats.stopDistance = 0
						stats.stopTime = 0
						ato.overrunDist = 0
					end
				else
					ato.timeStopped = 0.0
				end
			end

			if state.stopStageTime > 0.0 then state.stopStageTime = state.stopStageTime - dt end

			if not state.foundStationSignal or (ato.lastStationDistance > 0 and signal.distance > ato.lastStationDistance + 1) then -- Lost station marker; possibly overshot
				if not ato.lostTrackedStationSignal then
					ato.lostTrackedStationSignal = true
					ato.lostTrackedStationTime = 0.0
					debugPrint("Lost a station signal! Signal distance: " .. tostring(signal.distance) .. ". Last signal distance: " .. tostring(ato.lastStationDistance))
				end
			end
			
			if ato.lostTrackedStationSignal then
				ato.lostTrackedStationTime = ato.lostTrackedStationTime + dt
				
				if ato.lostTrackedStationTime >= 1.0 then
					-- Couldn't rediscover the station we were tracking; stop immediately as a fail-safe
					
					state.targetSpeed = 0.0
					debugPrint("Couldn't reacquire station signal! Stopping train immediately.")
				end
				
				-- Keep track of how far we've overrun the station
				ato.overrunDist = ato.overrunDist + ( state.trainSpeed * dt )
			end
			
			if state.foundStationSignal then
				ato.lastStationDistance = signal.distance
				ato.lostTrackedStationSignal = false
				ato.lostTrackedStationTime = 0.0
				
				if state.stopStage < 0 then
					ato.overrunDist = 0.0
				end
			else
				ato.lastStationDistance = -1
			end
		else
			state.stopStage = -1
			state.stopStageTime = 0.0
		end

		state.targetSpeed = math.floor( state.targetSpeed * MPS_TO_MPH * 10 ) / 10 -- Round down to nearest 0.1
		
		Call( "*:SetControlValue", "ATOTargetSpeed", 0, state.targetSpeed )
		Call( "*:SetControlValue", "ATOOverrun", 0, round( ato.overrunDist * 100.0, 2 ) )
		Call( "*:SetControlValue", "ATOBrakingDistance", 0, ato.stationStoppingDistance )
		Call( "*:SetControlValue", "ATOSignalDistance", 0, signal.distance )
		Call( "*:SetControlValue", "ATOSpeedCalcDistance", 0, ato.stationStoppingDistance - signal.distance )
		Call( "*:SetControlValue", "ATOSignalAspect", 0, signal.aspect )
		Call( "*:SetControlValue", "ATOStopping", 0, ato.stopping and 1 or 0 )
		Call( "*:SetControlValue", "ATOStoppingSpeed", 0, state.stoppingSpeed )
		Call( "*:SetControlValue", "ATOStoppingInitialSpeed", 0, ato.stationStopInitialSpeed )
		
		if ato.stopping and state.stopStage == 0 then
			state.atoThrottle = math.max(state.atoThrottle, mapRange(state.trainSpeedMPH, 2.5, 2.0, -1.0, 0.0, true))
		elseif state.targetSpeed < 0.25 then
			if state.stopStage == 1 then
				state.atoThrottle = -STATION_FINAL_STOP_BRAKING_POWER
			else
				state.atoThrottle = -1.0
			end
		else
			-- Prevents I buildup while brakes are releasing, etc
			-- if state.trainSpeedMPH < 5.0 and state.atoThrottle > 0.0 then atoPid:reset() end

			state.atoThrottle = atoPid:update( avgTargetSpeed:get(state.targetSpeed), state.trainSpeedMPH, dt )
			
			Call( "*:SetControlValue", "PID_P", 0, atoPid.p )
			Call( "*:SetControlValue", "PID_I", 0, atoPid.i )
			Call( "*:SetControlValue", "PID_D", 0, atoPid.d )
			Call( "*:SetControlValue", "PID_Error", 0, atoPid.error )
			Call( "*:SetControlValue", "PID_Delta", 0, atoPid.delta )
			Call( "*:SetControlValue", "PID_Output", 0, atoPid.value )
		end

		if Call( "*:GetControlValue", "ATCBrakeApplication", 0 ) > 0.5 then -- ATO got overridden by ATC ( not likely in production but needs to be handled )
			state.atoThrottle = -1
		end

		Call( "*:SetControlValue", "ATOThrottle", 0, state.atoThrottle )
		Call( "*:SetControlValue", "ThrottleAndBrake", 0, ( avgAtoThrottle:get(state.atoThrottle) + 1 ) / 2 )
		Call( "*:SetControlValue", "Misc1", 0, avgTargetSpeed:peek() )
		Call( "*:LockControl", "ATOStart", 0, controls.atoStartLocked )

		if controls.atoStartLocked > 0.5 then
			Call( "*:SetControlValue", "ATOStart", 0, 0 )
		end
	else
		if state.lastAtoActive then
			Call( "*:SetControlValue", "ThrottleAndBrake", 0, 0 )
			Call( "*:SetControlValue", "ATCEnabled", 0, state.lastAtcActive )
			state.atoThrottle = -1
			ato.stopping = false
			ato.timeStopped = 0.0
			state.stopStage = -1
		end
		
		atoPid:reset()
		avgAtoThrottle:reset(-1)
		avgTargetSpeed:reset()
		
		Call( "*:SetControlValue", "ATOThrottle", 0, -1 )
		Call( "*:LockControl", "ThrottleAndBrake", 0, 0 )
		Call( "*:LockControl", "Reverser", 0, 0 )
		Call( "*:LockControl", "ATOStart", 0, 1 )
	end

	state.lastAtoActive = state.atoActive
end
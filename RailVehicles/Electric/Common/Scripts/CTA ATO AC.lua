local MI_TO_M = 1609.34 -- Miles to Meters
local M_TO_MI = 1.0 / MI_TO_M -- Meters to Miles
local SIGNAL_STATE_SPEED = 20
local SIGNAL_STATE_STATION = 21
local ATO_TARGET_DECELERATION = 1.1 -- Meters/second/second
local ACCEL_PER_SECOND = 1.125 -- Units of acceleration per second ( jerk limit, used for extra buffers )
atoK_P = 1.0 / 3.5
atoK_I = 1.0 / 6.5
atoK_D = 0.0
atoMAX_ERROR = 1.0 / atoK_I
atoMIN_ERROR = -atoMAX_ERROR
atoD_THRESHOLD = 0.4
atoRESET_THRESHOLD = 1.8
atoSigDirection = 0
gLastSigDistTime = 0
atoOverrunDist = 0
stopStage = -1
stopStageTime = 0.0
atoPid = PID:create( atoK_P, atoK_I, atoK_D, atoMIN_ERROR, atoMAX_ERROR, atoD_THRESHOLD, atoRESET_THRESHOLD )

-- Stats variables
statStopStartingSpeed = 0
statStopSpeedLimit = 0
statStopDistance = 0
statStopTime = 0

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

function getBrakingDistance( vF, vI, a )
	return ( ( vF * vF ) - ( vI * vI ) ) / ( 2 * a )
end

function getStoppingSpeed( vI, a, d )
	return math.sqrt( math.max( ( vI * vI ) + ( 2 * a * d ), 0.0 ) )
end

local gLastATO = 1
local gLastATC = 1
local gLastATOThrottle = 0
atoSigDirection = 0
atoStopping = 0
atoMaxSpeed = 100
atoIsStopped = 0
atoTimeStopped = 0
atoStartingSpeedBuffer = 0

function UpdateATO( interval )
	-- Original plan was to allocate these *outside* the function for performance reasons
	-- But Lua is stupid so that's not going to happen
	local atoActive, atoThrottle, targetSpeed, trackSpeed, trainSpeed, doorsLeft, doorsRight, tThrottle, distCorrection, spdBuffer, trainSpeedMPH
	local sigType, sigState, sigDist, sigAspect
	local p, i, d
	local distBuffer

	local TrackBrake = Call( "*:GetControlValue", "TrackBrake", 0  )
	if TrackBrake and TrackBrake > 0.5 then
		Call( "*:SetControlValue", "ATOEnabled", 0, -1  )
	end

	if Call( "*:ControlExists", "ATOEnabled", 0  ) < 0.5 then -- Don't update if we don't have ATO installed on the vehicle
		return
	end

	-- Begin Automatic Train Operation ( ATO )
	atoActive = Call( "*:GetControlValue", "ATOEnabled", 0  )
	atoThrottle = Call( "*:GetControlValue", "ATOThrottle", 0  )
	atoStart = Call( "*:GetControlValue", "ATOStart", 0 ) > 0.5

	if ( atoActive > 0.0 ) then
		if ( gLastATO < 0.0 ) then
			gLastATC = Call( "*:GetControlValue", "ATCEnabled", 0  )
			atoStopping = 1
			atoIsStopped = 1
			atoTimeStopped = 0
			atoOverrunDist = 0
			stopStage = 0
			stopStageTime = 0
		end

		Call( "*:SetControlValue", "Headlights", 0, 1  )
		Call( "*:SetControlValue", "ATCEnabled", 0, 1  )
		Call( "*:SetControlValue", "Reverser", 0, 1  )
		Call( "*:LockControl", "ThrottleAndBrake", 0, 1  )
		Call( "*:LockControl", "Reverser", 0, 1  )

		trainSpeed = Call( "*:GetSpeed" )
		trainSpeedMPH = trainSpeed * MPS_TO_MPH
		distBuffer = 2.0 + ( clamp( ( trainSpeedMPH - 8.0 ) * 0.5, 0.0, 20.0 ) )
		doors = Call( "*:GetControlValue", "DoorsOpen", 0  ) > 0.1
		tThrottle = Call( "*:GetControlValue", "TrueThrottle", 0  )
		lockAtoStart = 1

		ATCRestrictedSpeed = Call( "*:GetControlValue", "ATCRestrictedSpeed", 0  )
		targetSpeed = ATCRestrictedSpeed * MPH_TO_MPS

		spdBuffer = math.max( getBrakingDistance( 0.0, targetSpeed, -ATO_TARGET_DECELERATION ), 0 ) + distBuffer

		accelBuff = ( ( tAccel - ( -1  ) ) / ACCEL_PER_SECOND ) -- Estimated time to reach full brakes ( -1  ) from current throttle ( tAccel )
		accelBuff = accelBuff * trainSpeed -- Estimated meters covered in the time taken to reach full brakes

		spdBuffer = spdBuffer + accelBuff -- Accomodate for jerk limit

		sigType, sigState, sigDist, sigAspect = Call( "*:GetNextRestrictiveSignal", atoSigDirection  )

		gLastSigDistTime = gLastSigDistTime + interval

		if ( ( sigDist > gLastSigDist + 0.5 or trainSpeed < 0.1 ) and gLastSigDistTime >= 1.0 ) then
			if ( atoSigDirection < 0.5 ) then
				atoSigDirection = 1
			else
				atoSigDirection = 0
			end
		end

		searchDist = sigDist + 0.1
		searchCount = 0
		while ( searchDist < spdBuffer and sigAspect ~= SIGNAL_STATE_STATION and searchCount < 20 ) do -- To avoid potential infinite loops at the end of the track, don't search more than 20 "signals" away
			tSigType, tSigState, tSigDist, tSigAspect = Call( "*:GetNextRestrictiveSignal", atoSigDirection, searchDist  )
			if ( tSigAspect == SIGNAL_STATE_STATION ) then
				sigType, sigState, sigDist, sigAspect = tSigType, tSigState, tSigDist, tSigAspect
			end
			searchDist = tSigDist + 0.1
			searchCount = searchCount + 1
		end

		if ( gLastSigDistTime >= 1.0 ) then
			gLastSigDistTime = 0.0
			gLastSigDist = sigDist
		end

		Call( "*:SetControlValue", "SpeedBuffer", 0, spdBuffer  )
		--Call("*:SetControlValue", "NextSignalDist", 0, round( sigDist * 100.0, 2 ) )
		--Call( "*:SetControlValue", "NextSignalAspect", 0, sigAspect  )

		if ( sigAspect == SIGNAL_STATE_STATION ) then
			if ( sigDist <= spdBuffer and sigDist >= 15 --[[ we don't want to stop at stations we're too close to ]] and sigDist < gLastSigDist and trainSpeedMPH >= 3.0 ) then
				if ( atoStopping < 0.25 ) then
					statStopStartingSpeed = trainSpeed
					statStopSpeedLimit = targetSpeed
					statStopDistance = sigDist
					atoStartingSpeedBuffer = spdBuffer
					statStopTime = 0
					atoOverrunDist = 0
					atoStopping = 1
				end
			end
		end

		if ( atoStopping > 0 ) then
			targetSpeed = math.min( ATCRestrictedSpeed * MPH_TO_MPS, math.max( getStoppingSpeed( targetSpeed, -ATO_TARGET_DECELERATION, spdBuffer - sigDist ), 1.0 * MPH_TO_MPS ) )

			statStopTime = statStopTime + interval

			if ( sigDist < 1.75 or ( atoOverrunDist > 0 and atoOverrunDist < 5.0 ) ) then
				targetSpeed = 0.0

				if ( stopStage < 0 ) then
					stopStage = 0
					stopStageTime = 0.0
				end
			end

			if ( trainSpeedMPH < 1.0 and stopStage == 0 ) then
				stopStage = 1
				stopStageTime = 0.25
			end

			if ( stopStage == 1 and stopStageTime <= 0.0 ) then
				stopStage = 2
			end

			if ( trainSpeed <= 0.025 and stopStage == 2 ) then
				if ( atoIsStopped < 0.25 ) then
					targetSpeed = 0.0
					atoIsStopped = 0.5
				end

				if ( doors ) then
					atoIsStopped = 1
				end

				if ( atoIsStopped > 0.25 ) then
					lockAtoStart = doors and 1 or 0
					if ( not doors and atoStart ) then
						atoTimeStopped = atoTimeStopped + interval
						if ( atoTimeStopped >= 0.5 ) then
							atoStopping = 0
							atoIsStopped = 0
							atoTimeStopped = 0.0
							stopStage = -1

							local berthOffset
							if ( atoOverrunDist > 0 ) then
								berthOffset = -atoOverrunDist
							else
								berthOffset = sigDist
							end
							logStop( statStopStartingSpeed, statStopSpeedLimit, statStopDistance, statStopTime, berthOffset )

							statStopStartingSpeed = 0
							statStopSpeedLimit = 0
							statStopDistance = 0
							statStopTime = 0
							atoOverrunDist = 0
						end
					else
						atoTimeStopped = 0.0
					end
				end
			end

			if ( stopStageTime > 0.0 ) then stopStageTime = stopStageTime - interval end

			if ( sigAspect ~= SIGNAL_STATE_STATION or sigDist > atoStartingSpeedBuffer + 15 ) then -- Lost station marker; possibly overshot
				atoOverrunDist = atoOverrunDist + ( trainSpeed * interval )
				targetSpeed = 0.0
				if ( atoOverrunDist > 5.0 ) then -- overshot station by 5.0 meters -- something went wrong; cancel stop
					atoOverrunDist = 0
					atoStopping = 0
					atoTimeStopped = 0
				end
			end
		else
			stopStage = 0
			stopStageTime = 0.0
		end

		targetSpeed = math.floor( targetSpeed * MPS_TO_MPH * 10 ) / 10 -- Round down to nearest 0.1
		pidTargetSpeed = targetSpeed
		Call( "*:SetControlValue", "ATOTargetSpeed", 0, targetSpeed  )
		Call( "*:SetControlValue", "ATOOverrun", 0, round( atoOverrunDist * 100.0, 2 ) )
		if ( targetSpeed < 0.25 ) then
			if ( stopStage == 1 ) then
				atoThrottle =  0.0
			elseif ( stopStage == 2 ) then
				atoThrottle = -0.3
			else
				atoThrottle = -1.0
			end
		else
			atoPid.kP = atoK_P
			if ( atoStopping > 0 ) then atoPid.kP = atoPid.kP * 2.0 end

			-- Prevents I buildup while brakes are releasing, etc
			if ( trainSpeedMPH < 5.0 and atoThrottle > 0.0 ) then atoPid:reset() end

			atoPid:update( targetSpeed, trainSpeedMPH, interval )
			p, i, d = atoPid.p, atoPid.i, atoPid.d
			atoThrottle = clamp( atoPid.value, -1.0, 1.0 )

			Call( "*:SetControlValue", "PID_Settled", 0, atoPid.settled and 1 or 0 )
			Call( "*:SetControlValue", "PID_P", 0, p )
			Call( "*:SetControlValue", "PID_I", 0, i )
			Call( "*:SetControlValue", "PID_D", 0, d )
		end

		if ( Call( "*:GetControlValue", "ATCBrakeApplication", 0  ) > 0.5 ) then -- ATO got overridden by ATC ( not likely in production but needs to be handled )
			atoThrottle = -1
		end

		--[[if ( ATCRestrictedSpeed <= 0.1 and trainSpeed <= 0.01 ) then
			Call( "*:SetControlValue", "Headlights", 0, 0  )
			Call( "*:SetControlValue", "Reverser", 0, 0  ) -- Park train
			Call( "*:SetControlValue", "DestinationSign", 0, 1  ) -- "Not In Service"
		end]]

		Call( "*:SetControlValue", "ThrottleAndBrake", 0, ( Call( "*:GetControlValue", "ATOThrottle", 0  ) + 1 ) / 2 )
		Call( "*:LockControl", "ATOStart", 0, lockAtoStart )

		if ( lockAtoStart > 0.5 ) then
			Call( "*:SetControlValue", "ATOStart", 0, 0 )
		end
	else
		if ( gLastATO > 0.0 ) then
			debugPrint("Turning on ATC and restoring " .. tostring( gLastATC ) )
			Call( "*:SetControlValue", "ThrottleAndBrake", 0, 0  )
			Call( "*:SetControlValue", "ATCEnabled", 0, gLastATC  )
			atoThrottle = 0.0
			atoStopping = 0
			atoIsStopped = 0
			atoTimeStopped = 0.0
			atoPid:reset()
		end
		
		Call( "*:LockControl", "ThrottleAndBrake", 0, 0  )
		Call( "*:LockControl", "Reverser", 0, 0  )
		Call( "*:LockControl", "ATOStart", 0, 1 )
	end

	--[[atoThrottle = atoThrottle * ( 1 + ( 1/8 ) )

	if ( atoThrottle >= gLastATOThrottle + ( 1/8 ) ) then
		gLastATOThrottle = atoThrottle - ( 1/8 )
	elseif ( atoThrottle <= gLastATOThrottle - ( 1/8 ) ) then
		gLastATOThrottle = atoThrottle + ( 1/8 )
	end

	gLastATOThrottle = clamp( gLastATOThrottle, -1.0, 1.0 )

	Call("*:SetControlValue", "ATOThrottle", 0, math.floor( ( math.abs( gLastATOThrottle ) * 10 ) + 0.5 ) / 10 * sign( gLastATOThrottle ) )]]

	gLastATOThrottle = atoThrottle
	Call( "*:SetControlValue", "ATOThrottle", 0, atoThrottle )

	gLastATO = atoActive
end
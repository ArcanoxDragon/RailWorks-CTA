local MPS_TO_MPH = 2.23694 -- Meters/Second to Miles/Hour
local MPH_TO_MPS = 1.0 / MPS_TO_MPH
local MPH_TO_MiPS = 0.000277777778 -- Miles/Hour to Miles/Second
local MI_TO_M = 1609.34 -- Miles to Meters
local M_TO_MI = 1.0 / MI_TO_M -- Meters to Miles
local SIGNAL_STATE_SPEED = 20
local SIGNAL_STATE_STATION = 21
local ATO_TARGET_DECELERATION = 0.9 -- Meters/second/second
atoK_P = 1.0 / 5.0
atoK_I = 1.0 / 10.0
atoK_D = 0.0
atoMIN_ERROR = -3.0
atoMAX_ERROR =  3.0
atoSigDirection = 0
gLastSigDistTime = 0

function getBrakingDistance(vF, vI, a)
	return ((vF * vF) - (vI * vI)) / (2 * a)
end

function getStoppingSpeed(vI, a, d)
	return math.sqrt(math.max((vI * vI) + (2 * a * d), 0.0))
end

local gErrorSums = { }
local gLastErrors = { }
local gSettled = { }
local gSettledTime = { }
local gSettleTarget = { }

function resetPid(pidName)
	local pN = pidName or "default"
	gErrorSums[pN] = 0.0
	gLastErrors[pN] = 0.0
	gSettled[pN] = false
	gSettledTime[pN] = 0.0
	gSettleTarget[pN] = 0.0
end

function pid(pidName, tD, kP, kI, kD, target, real, minErr, maxErr)
	local pN = pidName or "default"
	local e = target - real
	local mnErr = minErr or -1
	local mxErr = maxErr or 1
	
	if (gErrorSums[pN] == nil or gLastErrors[pN] == nil or gSettled[pN] == nil or gSettleTarget[pN] == nil or gSettledTime[pN] == nil) then resetPid(pN) end
	if (gSettled[pN]) then
		gErrorSums[pN] = math.max(math.min(gErrorSums[pN] + (e * tD), mxErr), mnErr)
	else
		gErrorSums[pN] = 0.0
	end
	
	local p = kP * e
	local i = kI * gErrorSums[pN]
	local d = kD * (e - gLastErrors[pN]) / tD
	
	if (math.abs((e - gLastErrors[pN]) / tD) < 1.0) then
		if (gSettledTime[pN] > 1.0) then
			gSettled[pN] = true
		else
			gSettledTime[pN] = gSettledTime[pN] + tD
		end
		gSettleTarget[pN] = target
	else
		gSettledTime[pN] = 0
	end
	
	if (math.abs(gSettleTarget[pN] - target) > 0.1) then
		gSettled[pN] = false
		gSettledTime[pN] = 0
	end
	
	--debugPrint("[" .. pN .. "] gES: " .. tostring(gErrorSums[pN]) .. " gLE: " .. tostring(gLastErrors[pN]) .. " gS: " .. tostring(gSettled[pN]))
	--debugPrint("[" .. pN .. "] gSTm: " .. tostring(gSettledTime[pN]) .. " gSTg: " .. tostring(gSettleTarget[pN]) .. " gED: " .. tostring((e - gLastErrors[pN]) * tD))
	
	gLastErrors[pN] = e
	return p + i + d, p, i, d
end

local gLastATO = 0
local gLastATC = 0
atoSigDirection = 0
atoStopping = 0
atoMaxSpeed = 100
atoIsStopped = 0
atoTimeStopped = 0

function UpdateATO(interval)
	-- Original plan was to allocate these *outside* the function for performance reasons
	-- But Lua is retarded so that's not going to happen
	local atoActive, atoThrottle, targetSpeed, trackSpeed, trainSpeed, doorsLeft, doorsRight, tThrottle, distCorrection, spdBuffer, trainSpeedMPH
	local spdType, spdLimit, spdDist
	local spdType2, spdLimit2, spdDist2 -- Second check, to make sure we don't miss a hidden "end-of-track" speed limit
	local sigType, sigState, sigDist, sigAspect
	local t, p, i, d

	if Call("*:ControlExists", "ATOEnabled", 0) < 0.5 then -- Don't update if we don't have ATO installed on the vehicle
		return
	end
	-- Begin Automatic Train Operation (ATO)
	atoActive = Call("*:GetControlValue", "ATOEnabled", 0)
	atoThrottle = Call("*:GetControlValue", "ATOThrottle", 0)
	if (atoActive > 0.0) then
		if (gLastATO < 0.0) then
			gLastATC = Call("*:GetControlValue", "ATCEnabled", 0)
			debugPrint("Turning off ATC and storing " .. tostring(gLastATC))
		end
		
		Call("*:SetControlValue", "Headlights", 0, 1)
		Call("*:SetControlValue", "ATCEnabled", 0, 0)
		Call("*:SetControlValue", "Reverser", 0, 1)
		Call("*:LockControl", "ThrottleAndBrake", 0, 1)
		Call("*:LockControl", "Reverser", 0, 1)
		targetSpeed = Call("*:GetCurrentSpeedLimit")
		trackSpeed = targetSpeed
		trainSpeed = Call("*:GetSpeed")
		trainSpeedMPH = trainSpeed * MPS_TO_MPH
		spdType, spdLimit, spdDist = Call("*:GetNextSpeedLimit", 0, 0)
		spdType2, spdLimit2, spdDist2 = Call("*:GetNextSpeedLimit", 0, spdDist + 0.1)
		--debugPrint("st1 " .. tostring(spdType) .. "; sl1 " .. tostring(spdLimit) .. "; sd1 " .. tostring(spdDist))
		--debugPrint("st2 " .. tostring(spdType2) .. "; sl2 " .. tostring(spdLimit2) .. "; sd2 " .. tostring(spdDist2))
		if (spdType2 == 0 and spdType ~= 0) then
			--debugPrint("Found track end " .. tostring(spdDist2) .. "m away, hidden behind a " .. tostring(math.floor(spdLimit * MPS_TO_MPH)) .. "MPH " .. tostring(spdDist) .. "m away.")
			spdType, spdLimit, spdDist = spdType2, spdLimit2, spdDist2
		end
		sigType, sigState, sigDist, sigAspect = Call("*:GetNextRestrictiveSignal", atoSigDirection)
		doorsLeft = Call("*:GetControlValue", "DoorsOpenCloseLeft", 0) > 0.1
		doorsRight = Call("*:GetControlValue", "DoorsOpenCloseRight", 0) > 0.1
		tThrottle = Call("*:GetControlValue", "TrueThrottle", 0)
		
		if (spdType == 0) then -- End of line...stop the train
			spdBuffer = (getBrakingDistance(0.0, targetSpeed, -ATO_TARGET_DECELERATION) + 6)
			Call("*:SetControlValue", "SpeedBuffer", 0, spdBuffer)
			if (spdDist <= spdBuffer) then
				targetSpeed = math.max(getStoppingSpeed(trackSpeed, -ATO_TARGET_DECELERATION, (spdBuffer + 3.0) - spdDist) - 0.25, 1.0 * MPH_TO_MPS)
				if (spdDist <= 50) then
					targetSpeed = math.min(targetSpeed, 6 * MPH_TO_MPS)
					atoMaxSpeed = 6 * MPH_TO_MPS
				end
				if (spdDist < 5) then
					targetSpeed = 0
					if (trainSpeed <= 0.1) then
						Call("*:SetControlValue", "Headlights", 0, 0)
						Call("*:SetControlValue", "Reverser", 0, 0) -- Park train
						Call("*:SetControlValue", "DestinationSign", 0, 1) -- "Not In Service"
					end
				end
			end
		elseif (spdType > 0) then
			if (spdLimit < targetSpeed) then
				spdBuffer = (getBrakingDistance(spdLimit, targetSpeed, -ATO_TARGET_DECELERATION) + 6)
				if (spdDist <= spdBuffer) then
					targetSpeed = spdLimit
				end
			end
		end
		
		if ((sigDist > gLastSigDist + 0.5 or trainSpeed < 0.1) and gLastSigDistTime >= 1.0) then
			if (atoSigDirection < 0.5) then
				atoSigDirection = 1
			else
				atoSigDirection = 0
			end
		end
		spdBuffer = math.max(getBrakingDistance(0.0, targetSpeed, -ATO_TARGET_DECELERATION) + 1.5, 0)
		Call("*:SetControlValue", "SpeedBuffer", 0, spdBuffer)
		Call("*:SetControlValue", "NextSignalDist", 0, round(sigDist * 100.0, 2))
		
		if ((sigAspect == SIGNAL_STATE_STATION and sigDist < spdBuffer + 10) or atoStopping > 0) then
			if (sigDist <= spdBuffer and sigDist >= 5 --[[ we don't want to stop at stations we're too close to ]] and sigDist < gLastSigDist) then
				atoStopping = 1
			end
			if (atoStopping > 0) then
				--targetSpeed = math.max(math.pow(sigDist / spdBuffer, 1 / 1.6) * targetSpeed, 3.5)
				targetSpeed = math.min(atoMaxSpeed, math.max(getStoppingSpeed(targetSpeed, -ATO_TARGET_DECELERATION, spdBuffer - sigDist) - 0.25 --[[ speed buffer to make sure we don't overshoot at all ]], 1.0 * MPH_TO_MPS))
			end
		end
		
		if (atoStopping > 0) then
			if (sigAspect ~= SIGNAL_STATE_STATION or sigDist > spdBuffer + 10 or sigDist < 0.8) then
				targetSpeed = 0.0
				if (trainSpeed <= 0.025) then
					if (atoIsStopped < 0.25) then
						targetSpeed = 0.0
						atoIsStopped = 0.5
						--SysCall("*:LoadCargo")
						--Call("*:SetControlValue", "LoadCargo", 0, 1)
						--debugPrint("Opening doors")
					end
					
					if (doorsLeft or doorsRight) then
						atoIsStopped = 1
					end
					
					if (atoIsStopped > 0.75) then
						if (not doorsLeft and not doorsRight) then
							atoTimeStopped = atoTimeStopped + interval
							if (atoTimeStopped >= 2.0) then
								--Call("*:SetControlValue", "LoadCargo", 0, 0)
								atoStopping = 0
								atoIsStopped = 0
								atoTimeStopped = 0.0
							end
						else
							atoTimeStopped = 0.0
						end
					end
				end
			end
		end
		
		gLastSigDistTime = gLastSigDistTime + interval
		if (gLastSigDistTime >= 1.0) then
			gLastSigDistTime = 0.0
			gLastSigDist = sigDist
		end
		
		targetSpeed = math.floor((targetSpeed * MPS_TO_MPH * 10) + 0.5) / 10 -- Round to nearest 0.1
		Call("*:SetControlValue", "ATOTargetSpeed", 0, targetSpeed)
		if (targetSpeed < 0.25) then
			atoThrottle = -1.0
		else
			-- pid(tD, kP, kI, kD, e, minErr, maxErr)
			atoK_P = 1.0 / 3.0 -- Adjust proportional gain based on speed
			if (atoStopping > 0 and atoThrottle < 0) then
				atoK_P = atoK_P * 2.0 -- Double influence for braking; make sure we're accurate
			end
			t, p, i, d = pid("ato", interval, atoK_P, atoK_I, atoK_D, targetSpeed, trainSpeedMPH, -2.5, 2.5)
			atoThrottle = clamp(t, -1.0, 1.0)
			if (atoStopping > 0) then
				if (sigDist > 5) then
					atoThrottle = clamp(atoThrottle, -1.0, 0.25)
				else
					atoThrottle = clamp(atoThrottle, -1.0, 0.0)
				end
			end
			Call( "*:SetControlValue", "PID_Settled", 0, gSettled["ato"] and 1 or 0 )
			Call( "*:SetControlValue", "PID_P", 0, p )
			Call( "*:SetControlValue", "PID_I", 0, i )
			Call( "*:SetControlValue", "PID_D", 0, d )
		end
		
		if (Call("*:GetControlValue", "ATCBrakeApplication", 0) > 0.5) then -- ATO got overridden by ATC (not likely in production but needs to be handled)
			atoThrottle = -1
		end
		
		Call("*:SetControlValue", "ThrottleAndBrake", 0, (atoThrottle + 1) / 2)
	else
		if (gLastATO > 0.0) then
			Call("*:SetControlValue", "ThrottleAndBrake", 0, 0)
			Call("*:SetControlValue", "ATCEnabled", 0, gLastATC)
			debugPrint("Turning on ATC and restoring " .. tostring(gLastATC))
			Call("*:LockControl", "ThrottleAndBrake", 0, 0)
			Call("*:LockControl", "Reverser", 0, 0)
			atoThrottle = 0.0
			atoStopping = 0
			atoIsStopped = 0
			atoTimeStopped = 0.0
			resetPid("ato")
		end
	end
	Call("*:SetControlValue", "ATOThrottle", 0, atoThrottle)
	
	gLastATO = atoActive
end